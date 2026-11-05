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

function M.map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc })
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
  mod.setup(root, project)
  return true
end

-- set up the cwd when it is an MCU project (now and after :cd)
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
end

return M
