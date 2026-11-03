-- STM32 (platform = 'stm32', the default): Makefile build, STM32_Programmer_CLI / OpenOCD flash,
-- nvim-dap over OpenOCD + ST-LINK, LiveWatch, picocom on the ST-LINK virtual COM port.
--
--   * tool paths (CubeCLT gcc/gdb, OpenOCD, picocom) and the commands that use them live here
--   * the ELF path comes from the project's Makefile (TARGET := ..., BUILD := ...)
--   * nvim-project.lua: openocd_target, serial_baud, halt_commands, LiveWatch helpers/defaults

local mcu = require('mcu')
local map = mcu.map

local M = {}

local clt = '/opt/st/stm32cubeclt'
local gdb = clt .. '/GNU-tools-for-STM32/bin/arm-none-eabi-gdb'
-- Upstream OpenOCD build (the distro 0.12.0 has no STM32U0)
local openocd = vim.env.HOME .. '/.local/bin/openocd'
local serial_glob = '/dev/serial/by-id/usb-STMicroelectronics_STM32_STLink*'

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

function M.setup(root, project)
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

  map('<leader>mg', function()
    if not mcu.openocd_busy() then
      mcu.term(openocd_args, root)
    end
  end, 'OpenOCD gdb server (:3333, TCL :6666)')

  map('<leader>mF', function()
    if not mcu.openocd_busy() then
      mcu.term(vim.list_extend(vim.deepcopy(openocd_args), { '-c', 'program ' .. elf .. ' verify reset exit' }), root)
    end
  end, 'flash with OpenOCD')

  -- printf goes to the UART / ST-LINK virtual COM port, not to the DAP console.
  -- picocom: quit with Ctrl-A Ctrl-X; --imap lfcrlf so a bare "\n" in printf still starts a new line
  map('<leader>ms', function()
    local port = project.serial_port or vim.fn.glob(serial_glob, false, true)[1]
    if not port then
      vim.notify('serial: no ST-LINK virtual COM port in /dev/serial/by-id (board plugged in?)', vim.log.levels.ERROR)
      return
    end
    mcu.term({ 'picocom', '-q', '-b', tostring(serial_baud), '--imap', 'lfcrlf', port }, root)
  end, 'serial terminal (ST-LINK VCP, picocom)')

  -- nvim-dap: needs the OpenOCD gdb server (<leader>mg) running on :3333 ------------------------
  local function config(name, commands)
    vim.list_extend(commands, halt_commands)
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
      postRemoteConnectCommands = mcu.gdb_cmds(commands),
    }
  end
  local flash_debug = config('STM32 flash + debug (stop at main)', { 'monitor reset halt', 'load', 'monitor reset halt' })
  -- tbreak last, after the project's halt_commands
  table.insert(flash_debug.postRemoteConnectCommands, { text = 'tbreak main' })
  mcu.set_dap_configs({ flash_debug, config('STM32 attach (no reset, no flash)', {}) })

  -- live watch (reads RAM / registers via OpenOCD while the MCU runs; needs <leader>mg) -----------
  local lw = require('mcu.livewatch')
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
end

return M
