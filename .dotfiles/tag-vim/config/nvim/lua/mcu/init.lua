-- Microcontroller projects in nvim: build / flash / OpenOCD / nvim-dap / serial (+ LiveWatch on STM32).
--
-- Loaded from init.vim with  require('mcu').autoload()
-- A folder is an MCU project when it contains nvim-project.lua (when nvim starts there, or on :cd).
-- nvim-project.lua returns a table; `platform` picks the module (lua/mcu/<platform>.lua):
--   platform = 'stm32' (default)  see mcu/stm32.lua
--   platform = 'esp32'            see mcu/esp32.lua
--   platform = 'linux'            see mcu/linux/init.lua (embedded Linux kernel: kgdb / JTAG / gdb stub)
-- The file is read through vim.secure.read, so nvim asks once (and after every change) whether to
-- trust it, like 'exrc'. Load by hand with  :Mcu [dir]

local M = {}

M.PROJECT_FILE = 'nvim-project.lua'
M.root = nil -- project currently loaded

-- nvim-project.lua through the trust database (nil when not trusted / broken)
local function load_project(path)
  local src = vim.secure.read(path)
  if not src then
    vim.notify('mcu: ' .. path .. ' is not trusted, setup skipped (:trust it, then :Mcu)', vim.log.levels.WARN)
    return nil
  end
  local chunk, err = loadstring(src, '@' .. path)
  if not chunk then
    vim.notify('mcu: ' .. err, vim.log.levels.ERROR)
    return nil
  end
  local ok, res = pcall(chunk)
  if not ok or type(res) ~= 'table' then
    vim.notify('mcu: ' .. path .. ': ' .. tostring(res), vim.log.levels.ERROR)
    return nil
  end
  return res
end

-- helpers shared by the platform modules ------------------------------------------------------

-- normal mode mapping of the project; also listed by <leader>mh (help) with its desc
M.keys = M.keys or {}
function M.map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc })
  for _, k in ipairs(M.keys) do
    if k.lhs == lhs then
      k.desc = desc
      return
    end
  end
  table.insert(M.keys, { lhs = lhs, desc = desc })
end

-- run argv in a terminal split at the bottom of the screen; returns the job id.
-- prog: the program that reads the keyboard, for the quit key on exit (default: argv[1]),
-- e.g. 'picocom' for an expect script that ends in picocom
function M.term(argv, cwd, prog)
  vim.cmd('botright 10split | enew')
  local job = vim.fn.termopen(argv, { cwd = cwd })
  if job > 0 then
    M.jobs[job] = prog or vim.fs.basename(argv[1])
  end
  return job
end

-- true while a job started by M.term runs
function M.running(job)
  return job ~= nil and M.jobs[job] ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
end

-- stop a job started by M.term with its quit key (like typing it), jobstop() after `ms` ms
function M.quit(job, ms)
  if not M.running(job) then
    return
  end
  vim.fn.chansend(job, M.quit_keys[M.jobs[job]] or '\3')
  if vim.fn.jobwait({ job }, ms or 2000)[1] == -1 then
    vim.fn.jobstop(job)
  end
  M.jobs[job] = nil
end

-- terminal jobs started by M.term (OpenOCD, picocom, idf.py monitor): stopped cleanly when nvim exits
M.jobs = M.jobs or {}

-- the key each program quits on, typed into its terminal like by hand
M.quit_keys = {
  picocom = '\1\24', -- Ctrl-A Ctrl-X (a Ctrl-C would just go out on the UART)
  ['idf.py'] = '\29', -- Ctrl-]
  ssh = '\r~.', -- ssh escape: disconnect (a Ctrl-C would go to the remote shell)
}
local quit_keys = M.quit_keys

-- ExitPre (:qa, :q in the last window, ...): send each running job its quit key (Ctrl-C for OpenOCD:
-- clean shutdown, frees the probe and ports 3333/6666), wait up to 3 s, then jobstop() what is left.
-- If a normal buffer has unsaved changes, the quit fails anyway (E37/E162), so the jobs keep running.
vim.api.nvim_create_autocmd('ExitPre', {
  group = vim.api.nvim_create_augroup('mcu_jobs', { clear = true }),
  callback = function()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].modified and vim.bo[b].buftype == '' then
        return
      end
    end
    local running = {}
    for job, prog in pairs(M.jobs) do
      if vim.fn.jobwait({ job }, 0)[1] == -1 then
        vim.fn.chansend(job, quit_keys[prog] or '\3')
        table.insert(running, job)
      end
      M.jobs[job] = nil
    end
    if #running > 0 then
      for i, res in ipairs(vim.fn.jobwait(running, 3000)) do
        if res == -1 then
          vim.fn.jobstop(running[i])
        end
      end
    end
  end,
})

-- only one OpenOCD can own the probe and ports 3333/6666: say who has them
function M.openocd_busy()
  local listen = vim.fn.system({ 'ss', '-ltnp' })
  if not (listen:match(':3333%s') or listen:match(':6666%s')) then
    return false
  end
  local who = vim.fn.system({ 'sh', '-c', "pgrep -af '[o]penocd|[S]T-LINK_gdbserver' || ss -ltnp | grep -E ':(3333|6666)\\b'" })
  vim.notify('OpenOCD: ports 3333/6666 already in use by:\n' .. who
             .. 'stop it first (close the other gdbserver terminal, or kill <pid>)', vim.log.levels.ERROR)
  return true
end

-- is an OpenOCD TCL server listening on :6666 (ours from <leader>mg, or any other)?
function M.openocd_tcl_up()
  return vim.fn.system({ 'ss', '-ltn' }):match(':6666%s') ~= nil
end

-- send one command to the running OpenOCD's TCL port (:6666) and call on_done(output, err) in the
-- main loop. `capture` returns what the command prints (e.g. the program / verify messages).
function M.openocd_tcl(cmd, on_done)
  local tcp = vim.uv.new_tcp()
  local buf = ''
  local function finish(out, err)
    if not tcp:is_closing() then
      tcp:close()
    end
    vim.schedule(function() on_done(out, err) end)
  end
  tcp:connect('127.0.0.1', 6666, function(err)
    if err then
      return finish(nil, err)
    end
    tcp:read_start(function(rerr, data)
      if rerr or not data then
        return finish(buf, rerr or 'connection closed')
      end
      buf = buf .. data
      if buf:sub(-1) == '\26' then
        finish(buf:sub(1, -2), nil)
      end
    end)
    tcp:write('capture {' .. cmd .. '}\26')
  end)
end

-- the <leader>mg key of every platform: start OpenOCD in a terminal split; pressed again while that
-- OpenOCD runs = restart it (e.g. after a board reset, or a probe that got stuck): a running debug
-- session is stopped first (its view of the target is stale; the detach lets the target run), OpenOCD
-- gets Ctrl-C (frees the probe and the ports), the old terminal is closed, a new OpenOCD starts.
-- argv(): OpenOCD's command line, or nil when something is missing (argv reports it).
-- Someone else's OpenOCD / gdbserver on the ports: refused with a message (openocd_busy), not killed.
function M.openocd_key(argv, cwd)
  local job, buf
  local function close_old()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    buf = nil
  end
  local function start(cmd)
    if M.openocd_busy() then
      return
    end
    close_old() -- an exited one ([Process exited])
    job = M.term(cmd, cwd)
    buf = vim.api.nvim_get_current_buf()
  end
  return function()
    local cmd = argv()
    if not cmd then
      return
    end
    if not M.running(job) then
      start(cmd)
      return
    end
    local wait = 0
    local ok, dap = pcall(require, 'dap')
    if ok and dap.session() then
      dap.terminate()
      wait = 1500 -- gdb detaches, then quits
    end
    vim.notify('mcu: restarting OpenOCD')
    vim.defer_fn(function()
      M.quit(job, 3000)
      close_old()
      start(cmd)
    end, wait)
  end
end

-- gdb commands as cppdbg wants them
function M.gdb_cmds(list)
  local out = {}
  for _, c in ipairs(list) do
    table.insert(out, { text = c })
  end
  return out
end

-- the project's dap configurations (replaced by the next project / reload). Given to nvim-dap as a
-- configuration provider, so <leader>dc offers them from any buffer: also from a terminal (OpenOCD,
-- kdmx, console), an .S / .dts file or an empty one, not only from c / cpp buffers.
-- nvim-dap lists the providers sorted by name: '!' puts ours before dap.global (dap.configurations.<ft>)
M.dap_configs = M.dap_configs or {}
function M.set_dap_configs(list)
  local dap = require('dap')
  M.dap_configs = list
  if not dap.providers.configs['!mcu'] then
    dap.providers.configs['!mcu'] = function() return M.dap_configs end
  end
end

-- loading ---------------------------------------------------------------------------------------

function M.setup(root)
  root = vim.fn.fnamemodify(root, ':p'):gsub('/$', '')
  local project = load_project(root .. '/' .. M.PROJECT_FILE)
  if not project then
    return false
  end
  local platform = project.platform or 'stm32'
  local ok, mod = pcall(require, 'mcu.' .. platform)
  if not ok then
    vim.notify('mcu: unknown platform "' .. platform .. '" in ' .. M.PROJECT_FILE .. '\n' .. mod, vim.log.levels.ERROR)
    return false
  end
  M.root = root
  M.platform, M.module = platform, mod
  M.keys = {}
  M.map('<leader>mh', M.help, 'this help: keys + workflow of the project')
  mod.setup(root, project)
  return true
end

-- help (<leader>mh, :McuHelp) -------------------------------------------------------------------

-- nvim-dap keys from init.vim (the same for every platform)
local dap_keys = {
  { '<leader>dc', 'start a session (pick a configuration) / continue' },
  { '<leader>dq', 'stop the session' },
  { '<leader>dl', 'run the last configuration again' },
  { '<leader>db / dB', 'toggle breakpoint / conditional breakpoint' },
  { '<leader>dlp', 'log point' },
  { '<leader>dn / ds / df', 'step over / into / out' },
  { '<leader>dh / dp', 'value under the cursor (hover / preview)' },
  { '<leader>dr', 'gdb REPL (gdb commands: -exec <cmd>)' },
  { '<leader>du', 'dap-ui on / off' },
}

local function table_lines(rows)
  local w = 3
  for _, r in ipairs(rows) do
    w = math.max(w, #r[1] + 2)
  end
  local out = { '| Key' .. string.rep(' ', w - 3) .. ' | Action |',
                '|' .. string.rep('-', w + 2) .. '|--------|' }
  for _, r in ipairs(rows) do
    local k = '`' .. r[1] .. '`'
    table.insert(out, '| ' .. k .. string.rep(' ', w - #k) .. ' | ' .. r[2] .. ' |')
  end
  return out
end

-- a scratch buffer on the right: the project's keys (as mapped, with their desc), the nvim-dap keys,
-- and the platform's workflow (M.help in mcu/<platform>.lua). q closes it.
function M.help()
  if not M.root then
    vim.notify('mcu: no project loaded (no nvim-project.lua here, or not trusted)', vim.log.levels.WARN)
    return
  end
  local lines = { '# ' .. M.platform .. ' project: ' .. vim.fn.fnamemodify(M.root, ':~'), '',
                  '## Project keys', '' }
  local rows = {}
  for _, k in ipairs(M.keys) do
    table.insert(rows, { k.lhs, k.desc or '' })
  end
  vim.list_extend(lines, table_lines(rows))
  vim.list_extend(lines, { '', '## Debug keys (nvim-dap)', '' })
  vim.list_extend(lines, table_lines(dap_keys))
  local wf = M.module and M.module.help
  if type(wf) == 'function' then
    wf = wf()
  end
  if wf then
    vim.list_extend(lines, { '', '## Workflow', '' })
    vim.list_extend(lines, wf)
  end
  vim.list_extend(lines, { '', '(q: close; the keys are defined in ~/.config/nvim/lua/mcu/' .. M.platform
                           .. (M.platform == 'linux' and '/init.lua' or '.lua') .. ', the dap keys in init.vim)' })

  local name = 'mcu-help://' .. M.platform
  local buf = vim.fn.bufnr(name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].filetype = 'markdown'
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd('botright vsplit')
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_width(win, math.min(110, math.floor(vim.o.columns * 0.6)))
  end
  vim.api.nvim_set_current_win(win)
  vim.wo[win].wrap = false
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, silent = true })
end

-- set up the cwd when it is an MCU project (now and after :cd)
-- No modelines for files of the project. CubeMX main.c ends with "ex: printf(...)" in the
-- assert_failed() comment: vim takes it for a modeline (E518 on open, and again when :Make / Dispatch
-- re-checks the buffers).
function M.no_modelines(root)
  local function off(buf)
    if vim.api.nvim_buf_get_name(buf):sub(1, #root + 1) == root .. '/' then
      vim.bo[buf].modeline = false
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    off(buf)
  end
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = vim.api.nvim_create_augroup('mcu_no_modelines', { clear = true }),
    callback = function(ev) off(ev.buf) end,
  })
end

function M.autoload()
  local function try(dir)
    if dir ~= M.root and vim.uv.fs_stat(dir .. '/' .. M.PROJECT_FILE) then
      M.setup(dir)
    end
  end
  local group = vim.api.nvim_create_augroup('mcu_autoload', { clear = true })
  -- after startup, so a project-local .exrc (sourced after init.vim) can't override makeprg & co.
  if vim.v.vim_did_enter == 1 then
    try(vim.fn.getcwd())
  else
    -- `nvim Src/main.c`: the files on the command line are read before VimEnter
    local cwd = vim.fn.getcwd()
    if vim.uv.fs_stat(cwd .. '/' .. M.PROJECT_FILE) then
      M.no_modelines(cwd)
    end
    vim.api.nvim_create_autocmd('VimEnter', { group = group, once = true, callback = function() try(vim.fn.getcwd()) end })
  end
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    pattern = 'global',
    callback = function() try(vim.fn.getcwd()) end,
  })
  vim.api.nvim_create_user_command('Mcu', function(c)
    M.setup(c.args ~= '' and c.args or vim.fn.getcwd())
  end, { nargs = '?', complete = 'dir', desc = 'load the MCU (STM32 / ESP32) setup for a project folder' })
  vim.api.nvim_create_user_command('McuHelp', function() M.help() end, { desc = 'keys + workflow of the MCU project' })
end

return M
