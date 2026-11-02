-- STM32: build / flash / debug with nvim-dap + cppdbg + OpenOCD, LiveWatch, serial terminal.
--
-- Loaded from init.vim with  require('stm32').autoload()
-- A folder is an STM32 project when it contains nvim-project.lua (when nvim starts there, or on :cd).
-- Load by hand with  :Stm32 [dir]
--
--   * tool paths (CubeCLT gcc/gdb, OpenOCD, picocom) and the commands that use them live here
--   * the ELF path comes from the project's Makefile (TARGET := ..., BUILD := ...)
--   * chip/board specifics go in the project's nvim-project.lua: openocd_target, serial_baud,
--     halt_commands, LiveWatch helpers/defaults. It is read through vim.secure.read, so nvim asks
--     once (and after every change) whether to trust it, like 'exrc'.

local M = {}

local clt = '/opt/st/stm32cubeclt'
local gdb = clt .. '/GNU-tools-for-STM32/bin/arm-none-eabi-gdb'
-- Upstream OpenOCD build (the distro 0.12.0 has no STM32U0)
local openocd = vim.env.HOME .. '/.local/bin/openocd'
local serial_glob = '/dev/serial/by-id/usb-STMicroelectronics_STM32_STLink*'
local PROJECT_FILE = 'nvim-project.lua'

M.root = nil -- project currently loaded

-- `NAME := value` / `NAME = value` / `NAME ?= value` from the Makefile
local function make_var(root, name, default)
  local f = io.open(root .. '/Makefile', 'r')
  if f then
    for line in f:lines() do
      local v = line:match('^%s*' .. name .. '%s*[:?]?=%s*(%S+)')
      if v then
        f:close()
        return v
      end
    end
    f:close()
  end
  return default
end

-- nvim-project.lua through the trust database (nil when not trusted / broken)
local function load_project(path)
  local src = vim.secure.read(path)
  if not src then
    vim.notify('stm32: ' .. path .. ' is not trusted, STM32 setup skipped (:trust it, then :Stm32)',
               vim.log.levels.WARN)
    return nil
  end
  local chunk, err = loadstring(src, '@' .. path)
  if not chunk then
    vim.notify('stm32: ' .. err, vim.log.levels.ERROR)
    return nil
  end
  local ok, res = pcall(chunk)
  if not ok or type(res) ~= 'table' then
    vim.notify('stm32: ' .. path .. ': ' .. tostring(res), vim.log.levels.ERROR)
    return nil
  end
  return res
end

-- PATH for :make, :Make, terminals: the ARM toolchain goes first; CubeCLT's STM32_Programmer_CLI is only
-- appended as a fallback, so a newer one found earlier on PATH (e.g. ~/.local/bin symlink to the standalone
-- STM32CubeProgrammer, needed for STM32U0) keeps priority.
local function setup_path()
  local toolchain = clt .. '/GNU-tools-for-STM32/bin'
  if not vim.env.PATH:find(toolchain, 1, true) then
    vim.env.PATH = toolchain .. ':' .. vim.env.PATH
  end
  local cubeprog = clt .. '/STM32CubeProgrammer/bin'
  if not vim.env.PATH:find(cubeprog, 1, true) then
    vim.env.PATH = vim.env.PATH .. ':' .. cubeprog
  end
end

local function map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc })
end

function M.setup(root)
  root = vim.fn.fnamemodify(root, ':p'):gsub('/$', '')
  local project = load_project(root .. '/' .. PROJECT_FILE)
  if not project then
    return false
  end
  M.root = root
  local elf = root .. '/' .. make_var(root, 'BUILD', 'build') .. '/' .. make_var(root, 'TARGET', 'firmware') .. '.elf'
  local halt_commands = project.halt_commands or {}

  setup_path()
  vim.o.makeprg = 'make -C ' .. root .. ' -j8'

  map('<leader>mb', '<Cmd>Make<CR>', 'build')
  map('<leader>mB', '<Cmd>Make -B OPT=-Og<CR>', 'rebuild for debugging (-Og)')
  map('<leader>mf', '<Cmd>Make flash<CR>', 'flash (STM32_Programmer_CLI)')
  map('<leader>mc', '<Cmd>Make compiledb<CR>', 'compile_commands.json for clangd')

  -- OpenOCD + serial terminal ----------------------------------------------------------------
  -- `transport select swd` must come before the target: stm32u0x.cfg uses `swd newdap`;
  -- older scripts (stm32g4x.cfg, ...) accept it too.
  local openocd_target = project.openocd_target or 'target/stm32u0x.cfg'
  local openocd_args = { openocd, '-f', 'interface/stlink.cfg', '-c', 'transport select swd', '-f', openocd_target }
  local serial_baud = project.serial_baud or 115200

  -- run argv in a terminal split at the bottom of the screen
  local function term(argv)
    vim.cmd('botright 10split | enew')
    vim.fn.termopen(argv, { cwd = root })
  end

  -- only one OpenOCD can own the ST-LINK and ports 3333/6666
  local function openocd_busy()
    local listen = vim.fn.system({ 'ss', '-ltnp' })
    if not (listen:match(':3333%s') or listen:match(':6666%s')) then
      return false
    end
    local who = vim.fn.system({ 'sh', '-c', "pgrep -af '[o]penocd|[S]T-LINK_gdbserver' || ss -ltnp | grep -E ':(3333|6666)\\b'" })
    vim.notify('OpenOCD: ports 3333/6666 already in use by:\n' .. who
               .. 'stop it first (close the other gdbserver terminal, or kill <pid>)', vim.log.levels.ERROR)
    return true
  end

  map('<leader>mg', function()
    if not openocd_busy() then
      term(openocd_args)
    end
  end, 'OpenOCD gdb server (:3333, TCL :6666)')

  map('<leader>mF', function()
    if not openocd_busy() then
      term(vim.list_extend(vim.deepcopy(openocd_args), { '-c', 'program ' .. elf .. ' verify reset exit' }))
    end
  end, 'flash with OpenOCD')

  -- printf goes to the UART / ST-LINK virtual COM port, not to the DAP console.
  -- picocom: quit with Ctrl-A Ctrl-X; --imap lfcrlf so a bare "\n" in printf still starts a new line
  map('<leader>ms', function()
    local port = vim.fn.glob(serial_glob, false, true)[1]
    if not port then
      vim.notify('serial: no ST-LINK virtual COM port in /dev/serial/by-id (board plugged in?)', vim.log.levels.ERROR)
      return
    end
    term({ 'picocom', '-q', '-b', tostring(serial_baud), '--imap', 'lfcrlf', port })
  end, 'serial terminal (ST-LINK VCP, picocom)')

  -- nvim-dap: needs the OpenOCD gdb server (<leader>mg) running on :3333 ------------------------
  local dap = require('dap')

  local function cmds(list)
    local out = {}
    for _, c in ipairs(list) do
      table.insert(out, { text = c })
    end
    for _, c in ipairs(halt_commands) do
      table.insert(out, { text = c })
    end
    return out
  end

  local function stm32(name, commands)
    return {
      name = name,
      type = 'cppdbg',
      request = 'launch',
      MIMode = 'gdb',
      miDebuggerPath = gdb,
      miDebuggerServerAddress = 'localhost:3333',
      program = elf,
      cwd = root,
      stopAtEntry = false,
      postRemoteConnectCommands = commands,
    }
  end

  local stm32_configs = {
    stm32('STM32 flash + debug (stop at main)',
          cmds({ 'monitor reset halt', 'load', 'monitor reset halt' })),
    stm32('STM32 attach (no reset, no flash)', cmds({})),
  }
  -- tbreak last, after the project's halt_commands
  table.insert(stm32_configs[1].postRemoteConnectCommands, { text = 'tbreak main' })

  -- ours first (choice 1 and 2), then the global C configurations; drop old copies on reload
  local configs = {}
  for _, c in ipairs(stm32_configs) do
    table.insert(configs, c)
  end
  for _, c in ipairs(dap.configurations.c or {}) do
    if not c.name:match('^STM32 ') then
      table.insert(configs, c)
    end
  end
  dap.configurations.c = configs
  dap.configurations.cpp = configs

  -- live watch (reads RAM / registers via OpenOCD while the MCU runs; needs <leader>mg) -----------
  local lw = require('stm32.livewatch')
  lw.stop() -- reload: drop the old timer / window
  lw.setup({
    root = root,
    elf = elf,
    gdb = gdb,
    helpers = project.helpers or {},
    defaults = project.defaults or { { expr = 'uwTick' } }, -- used until .livewatch.json exists
  })
  map('<leader>dw', '<Cmd>LiveWatch<CR>', 'live watch window')
  map('<leader>da', function() lw.add_at_cursor() end, 'live watch: add C expression under cursor')
  map('<leader>dA', function() lw.prompt_at_cursor() end, 'live watch: edit/add expression under cursor')
  map('<leader>dW', function() lw.pick() end, 'live watch: search global variables')
  vim.keymap.set('x', '<leader>da', function()
    local saved = vim.fn.getreg('z')
    vim.cmd('noautocmd normal! "zy')
    lw.add(vim.fn.getreg('z'))
    vim.fn.setreg('z', saved)
  end, { silent = true, desc = 'live watch: add selection' })

  return true
end

-- set up the cwd when it is an STM32 project (now and after :cd)
function M.autoload()
  local function try(dir)
    if dir ~= M.root and vim.loop.fs_stat(dir .. '/' .. PROJECT_FILE) then
      M.setup(dir)
    end
  end
  try(vim.fn.getcwd())
  vim.api.nvim_create_autocmd('DirChanged', {
    group = vim.api.nvim_create_augroup('stm32_autoload', { clear = true }),
    pattern = 'global',
    callback = function() try(vim.fn.getcwd()) end,
  })
  vim.api.nvim_create_user_command('Stm32', function(c)
    M.setup(c.args ~= '' and c.args or vim.fn.getcwd())
  end, { nargs = '?', complete = 'dir', desc = 'load the STM32 setup for a project folder' })
end

return M
