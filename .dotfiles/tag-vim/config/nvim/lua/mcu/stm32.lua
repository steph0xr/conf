-- STM32 (platform = 'stm32', the default): Makefile build, STM32_Programmer_CLI / OpenOCD flash,
-- nvim-dap over OpenOCD + ST-LINK, LiveWatch, picocom on the ST-LINK virtual COM port.
--
--   * tool paths (CubeCLT gcc/gdb, OpenOCD, picocom) and the commands that use them live here
--   * the ELF path comes from the project's Makefile: TARGET, and BUILD (our template) or BUILD_DIR
--     (STM32CubeMX "Makefile" toolchain); works with a plain CubeMX-generated Makefile
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

-- does the Makefile define the rule `name:`?
local function make_target(root, name)
  local f = io.open(root .. '/Makefile', 'r')
  if not f then
    return false
  end
  local found = f:read('a'):find('\n' .. name .. '%s*:') ~= nil
  f:close()
  return found
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
  local build = make_var(root, 'BUILD') or make_var(root, 'BUILD_DIR', 'build')
  local elf = root .. '/' .. build .. '/' .. make_var(root, 'TARGET', 'firmware') .. '.elf'
  local halt_commands = project.halt_commands or {}

  setup_path()
  vim.o.makeprg = 'make -C ' .. root .. ' -j8'

  -- CubeMX main.c has "ex: printf(...)" near its end: no modelines in the project (see mcu.no_modelines)
  mcu.no_modelines(root)

  -- shell command through vim-dispatch, errors parsed like :Make (gcc)
  local function dispatch(cmd)
    vim.cmd('Dispatch -compiler=gcc -dir=' .. vim.fn.fnameescape(root) .. ' sh -c ' .. vim.fn.shellescape(cmd))
  end

  map('<leader>mb', '<Cmd>Make<CR>', 'build')
  -- clean + build instead of `make -B`: CubeMX Makefiles have a `$(BUILD_DIR):` mkdir rule that -B breaks
  map('<leader>mB', function() dispatch('make clean && make -j8 OPT=-Og') end, 'clean rebuild for debugging (-Og)')
  -- the project's own `flash` rule if it has one (our template), else program the ELF directly
  map('<leader>mf', function()
    if make_target(root, 'flash') then
      vim.cmd('Make flash')
    else
      dispatch('STM32_Programmer_CLI -c port=SWD -w ' .. vim.fn.shellescape(elf) .. ' -v -rst')
    end
  end, 'flash (STM32_Programmer_CLI)')
  -- bear records the compiler calls of a full build; works with any Makefile (template, CubeMX, ...)
  map('<leader>mc', function() dispatch('make clean && bear -- make -j8') end, 'compile_commands.json for clangd (bear)')

  -- OpenOCD + serial terminal ----------------------------------------------------------------
  -- `transport select swd` must come before the target: stm32u0x.cfg uses `swd newdap`;
  -- older scripts (stm32g4x.cfg, ...) accept it too.
  local openocd_target = project.openocd_target or 'target/stm32u0x.cfg'
  local openocd_args = { openocd, '-f', 'interface/stlink.cfg', '-c', 'transport select swd', '-f', openocd_target }
  local serial_baud = project.serial_baud or 115200

  map('<leader>mg', mcu.openocd_key(function() return openocd_args end, root),
      'OpenOCD gdb server (:3333, TCL :6666); again = restart it (stops the debug session)')

  -- an OpenOCD gdb server already running (<leader>mg) owns the probe: flash through its TCL port,
  -- it keeps running (LiveWatch too). Otherwise a one-shot OpenOCD in a terminal.
  map('<leader>mF', function()
    if mcu.openocd_tcl_up() then
      local ok, dap = pcall(require, 'dap')
      if ok and dap.session() then
        vim.notify('flash: stop the debug session first (<leader>dq), gdb would keep the old program',
                   vim.log.levels.WARN)
        return
      end
      vim.notify('flash: programming through the running OpenOCD ...')
      mcu.openocd_tcl('program ' .. elf .. ' verify reset', function(out, err)
        local good = not err and out and out:find('Verified OK', 1, true)
        vim.notify('flash: ' .. (good and 'verified OK, target reset' or ('FAILED\n' .. (err or '') .. (out or ''))),
                   good and vim.log.levels.INFO or vim.log.levels.ERROR)
      end)
    elseif not mcu.openocd_busy() then
      mcu.term(vim.list_extend(vim.deepcopy(openocd_args), { '-c', 'program ' .. elf .. ' verify reset exit' }), root)
    end
  end, 'flash with OpenOCD (through the running gdb server if there is one)')

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

-- workflow part of <leader>mh (mcu.help)
M.help = {
  '1. once, and after adding files / changing flags: `<leader>mc` (compile_commands.json for clangd)',
  '2. build: `<leader>mb` (errors in the quickfix list); for stepping `<leader>mB` (clean rebuild, -Og)',
  '3. `<leader>mg`: OpenOCD in a terminal split, leave it running',
  '4. `<leader>dc` -> "STM32 flash + debug (stop at main)": flashes the ELF, stops at main',
  '   or "STM32 attach (no reset, no flash)": debug what already runs',
  '5. after a change: `<leader>mb`, then `<leader>dl` (runs the last config again = flashes the new build)',
  '6. `<leader>dw`: LiveWatch, variables read while the target runs (`a` add, `f` search, `dd` delete, `q` close)',
  '7. `<leader>ms`: serial terminal on the ST-LINK virtual COM port (quit: Ctrl-A Ctrl-X)',
  '',
  'Without a debug session: `<leader>mf` flashes with STM32_Programmer_CLI, `<leader>mF` with OpenOCD.',
  'LiveWatch on #define registers (GPIOA->ODR) needs -g3, see ~/dotfiles/project-files/stm32/readme.',
}

return M
