-- ESP32 (platform = 'esp32'): ESP-IDF build (idf.py), flash, nvim-dap over Espressif's OpenOCD,
-- serial console (picocom, or idf.py monitor), clangd (esp-clangd, see M.clangd_cmd; used by init.vim
-- for any folder with an sdkconfig, needs build/compile_commands.json from a first idf.py build).
--
-- ESP-IDF version per project: `idf = 'v6.1'` in nvim-project.lua (or a full path to an esp-idf
-- checkout). The module runs its export.sh in the background and copies the environment into nvim,
-- so idf.py, the xtensa/riscv gdb and Espressif's OpenOCD of that version are used by :Make, dap and
-- the terminals; no idf61 / idf54 ... in the shell needed. Switching project (:cd) drops the previous
-- version's environment first. Without `idf`, the environment of the shell that started nvim is used.
-- Names and offsets come from what `idf.py build` writes:
--   build/project_description.json  app_elf, app_bin, monitor_toolprefix (gdb), target
--   build/flasher_args.json         app offset (no hard-coded 0x10000, OTA layouts work)
--
-- nvim-project.lua:
--   platform      = 'esp32'
--   idf           = 'v6.1'          -- /opt/esp/esp-idf-v6.1 (or '/path/to/esp-idf')
--   openocd_cfg   = 'openocd.cfg'   -- probe + board, relative to the project (default)
--   openocd       = 'openocd'       -- optional explicit binary of the Espressif fork
--   serial_port   = '/dev/ttyUSB1'  -- optional, default: first USB-UART of serial_globs below
--   serial_baud   = 115200          -- optional, default: CONFIG_ESP_CONSOLE_UART_BAUDRATE (sdkconfig)
--   halt_commands = {}              -- extra gdb commands after connecting
--   rtos          = 'hwthread'      -- OpenOCD thread model (ESP_RTOS), see below
--
-- rtos: with OpenOCD's default 'FreeRTOS', the boot "thread" disappears when the scheduler starts;
-- gdb copes, but cppdbg takes the =thread-group-exited as "program exited with code 42" and ends
-- the session. 'hwthread' (default here) shows one thread per core, from reset on: breakpoints,
-- stepping and call stacks work the same, only the threads view lists CPU0/CPU1, not the tasks.
-- 'FreeRTOS' is fine for plain gdb (idf.py gdb), 'none' disables thread support.
--
-- No LiveWatch here: on Xtensa, OpenOCD can only read memory while the cores are halted
-- ("[esp32.cpu0] not halted" otherwise; no background access port like ARM's AHB-AP). Polling with
-- halt/read/resume stops both cores ~15 ms per sample (measured) and gets in the way of dap.
-- Values are visible in the dap UI (scopes / watches) whenever the session is stopped.

local mcu = require('mcu')
local map = mcu.map

local M = {}

local function read_json(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local ok, data = pcall(vim.fn.json_decode, f:read('*a'))
  f:close()
  return ok and data or nil
end

-- what idf.py build wrote; errors (shown by dap / the keymap) when the project isn't built
local function build_info(root)
  local desc = read_json(root .. '/build/project_description.json')
  local flasher = read_json(root .. '/build/flasher_args.json')
  if not (desc and flasher and flasher.app) then
    error('ESP32: no build/project_description.json or flasher_args.json, run idf.py build first (<leader>mb)')
  end
  return {
    elf = root .. '/build/' .. desc.app_elf,
    bin = root .. '/build/' .. flasher.app.file,
    offset = flasher.app.offset,
    gdb = (desc.monitor_toolprefix or 'xtensa-esp32-elf-') .. 'gdb',
    target = desc.target,
  }
end

-- USB-UARTs an ESP32 console shows up on, first match wins (serial_port in nvim-project.lua overrides):
-- esp-prog / WROVER-KIT channel B, then the usual devkit bridges, then the built-in USB-Serial-JTAG
local serial_globs = {
  '/dev/serial/by-id/usb-FTDI_Dual_RS232*-if01-port0',
  '/dev/serial/by-id/usb-Silicon_Labs_CP210*',
  '/dev/serial/by-id/usb-1a86_*',
  '/dev/serial/by-id/usb-Espressif_*',
}

-- clangd for ESP-IDF projects (called by init.vim's clangd cmd for every project root) -----------
-- Ubuntu's clangd has no Xtensa target ("unknown target triple 'xtensa-esp32-unknown-elf'"), so ESP
-- projects get Espressif's esp-clangd (installed by idf_tools.py into ~/.espressif/tools/esp-clangd):
--   --query-driver  the ESP gcc's (xtensa / riscv) system include dirs (picolibc, ...)
--   --resource-dir  clang's builtin headers (stddef.h, stdarg.h); the esp-clangd package has none,
--                   the system LLVM's are target independent
--   XDG_CONFIG_HOME so it reads mcu/clangd/config.yaml, which drops the gcc-only -f/-m flags
-- Returns nil for anything that isn't an ESP-IDF project (sdkconfig in the root), or when
-- esp-clangd isn't installed; init.vim then starts the normal clangd.
-- highest version among the paths a glob finds (by the first number in the path: esp-21.1.3, llvm-18)
local function newest(glob)
  local function ver(path)
    return vim.version.parse(path:match('%d+[%d.]*') or '0', { strict = false }) or vim.version.parse('0')
  end
  local found = vim.fn.glob(glob, false, true)
  table.sort(found, function(a, b) return ver(a) < ver(b) end)
  return found[#found]
end

function M.clangd_cmd(root)
  if not root or not vim.uv.fs_stat(root .. '/sdkconfig') then
    return nil
  end
  local home = vim.env.HOME
  local clangd = newest(home .. '/.espressif/tools/esp-clangd/*/esp-clangd/bin/clangd')
  if not clangd then
    vim.notify('ESP32: esp-clangd not installed, clangd will not understand this project '
               .. '(python $IDF_PATH/tools/idf_tools.py install esp-clang)', vim.log.levels.WARN)
    return nil
  end
  local argv = {
    clangd, '--background-index', '--pch-storage=memory', '--limit-results=20',
    '--query-driver=' .. home .. '/.espressif/tools/**/bin/*-elf-gcc,' .. home .. '/.espressif/tools/**/bin/*-elf-g++',
  }
  local stddef = newest('/usr/lib/llvm-*/lib/clang/*/include/stddef.h')
  if stddef then
    table.insert(argv, '--resource-dir=' .. stddef:gsub('/include/stddef%.h$', ''))
  end
  return argv, { XDG_CONFIG_HOME = vim.fn.stdpath('config') .. '/lua/mcu' }
end

local IDF_ROOT = '/opt/esp' -- where the esp-idf-vX.Y checkouts live (idf61 = /opt/esp/esp-idf-v6.1/export.sh)

-- ESP-IDF environment ---------------------------------------------------------------------------
local idf = { base = nil, loaded = nil, loading = nil }

-- 'v6.1' -> /opt/esp/esp-idf-v6.1; a path is used as it is
local function idf_path(spec)
  if spec:match('^[/~]') then
    return vim.fn.expand(spec)
  end
  return IDF_ROOT .. '/esp-idf-' .. spec
end

-- environment of nvim minus what a previous load_idf added
local function restore_base()
  if not idf.base then
    return
  end
  local cur = vim.fn.environ()
  for k in pairs(cur) do
    if idf.base[k] == nil then
      vim.env[k] = nil
    end
  end
  for k, v in pairs(idf.base) do
    if cur[k] ~= v then
      vim.env[k] = v
    end
  end
end

-- source <idf>/export.sh in bash (asynchronously) and apply the resulting environment to nvim
local function load_idf(spec)
  if not spec then
    restore_base() -- project without `idf`: back to the shell's environment
    idf.loaded = nil
    return
  end
  local path = idf_path(spec)
  if idf.loaded == path or idf.loading == path then
    return
  end
  if not vim.uv.fs_stat(path .. '/export.sh') then
    vim.notify('ESP32: no export.sh in ' .. path .. " (idf = '" .. spec .. "' in nvim-project.lua)", vim.log.levels.ERROR)
    return
  end
  restore_base()
  idf.base = idf.base or vim.fn.environ()
  idf.loading = path
  local out, err = {}, {}
  -- print the environment even when export.sh fails (it can fail its Python check after setting PATH)
  vim.fn.jobstart({ 'bash', '-c', '. "$1/export.sh" >&2; rc=$?; env -0; exit $rc', 'export_idf', path }, {
    env = idf.base,
    clear_env = true,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) out = data end,
    on_stderr = function(_, data) err = data end,
    on_exit = function(_, code)
      if idf.loading ~= path then
        return -- another project was opened meanwhile
      end
      idf.loading = nil
      -- env -0: NUL-separated; jobstart turns NUL into "\n" inside an item and splits on newlines
      local env = {}
      for _, item in ipairs(vim.split(table.concat(out, '\n'), '\n', { plain = true })) do
        local k, v = item:match('^([%w_]+)=(.*)$')
        if k then
          env[k] = v
        end
      end
      if code ~= 0 then
        local lines = vim.tbl_filter(function(l) return l ~= '' end, err)
        local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 6)), '\n')
        if not env.IDF_PATH or env.IDF_PATH == idf.base.IDF_PATH then
          vim.notify('ESP32: ' .. path .. '/export.sh failed:\n' .. tail, vim.log.levels.ERROR)
          return
        end
        -- same as the idfXY alias in the shell: PATH / IDF_PATH are set, but the Python check failed
        -- (e.g. an old IDF whose python_env was made for another Python version)
        vim.notify('ESP32: ' .. path .. '/export.sh reported an error, environment applied anyway '
                   .. '(like the shell alias):\n' .. tail, vim.log.levels.WARN)
      end
      for k, v in pairs(env) do
        if vim.env[k] ~= v then
          vim.env[k] = v
        end
      end
      idf.loaded = path
      vim.notify('ESP32: ESP-IDF ' .. (env.ESP_IDF_VERSION or spec) .. ' environment loaded (' .. path .. ')')
    end,
  })
end

local function need(exe)
  if vim.fn.executable(exe) == 1 then
    return true
  end
  if idf.loading then
    vim.notify('ESP32: ESP-IDF environment still loading, try again in a moment', vim.log.levels.WARN)
  else
    vim.notify('ESP32: ' .. exe .. " not on PATH. Set idf = 'vX.Y' in nvim-project.lua, or start nvim "
               .. 'from a shell with the ESP-IDF environment (idf61, idf54, ...)', vim.log.levels.ERROR)
  end
  return false
end

function M.setup(root, project)
  local openocd = project.openocd or 'openocd'
  local openocd_cfg = project.openocd_cfg or 'openocd.cfg'
  local halt_commands = project.halt_commands or {}

  -- console baud: nvim-project.lua serial_baud, else the project's sdkconfig, else 115200
  local function console_baud()
    if project.serial_baud then
      return project.serial_baud
    end
    local f = io.open(root .. '/sdkconfig', 'r')
    if f then
      local baud = f:read('*a'):match('\nCONFIG_ESP_CONSOLE_UART_BAUDRATE=(%d+)')
      f:close()
      if baud then
        return tonumber(baud)
      end
    end
    return 115200
  end

  load_idf(project.idf)
  if not project.idf and vim.fn.executable('idf.py') == 0 then
    vim.notify("ESP32 project, but idf.py is not on PATH: set idf = 'vX.Y' in nvim-project.lua "
               .. '(or run idf61 / idf54 / ... before nvim)', vim.log.levels.WARN)
  end

  vim.o.makeprg = 'idf.py -C ' .. root
  map('<leader>mb', '<Cmd>Make build<CR>', 'idf.py build')
  map('<leader>mB', '<Cmd>Make fullclean build<CR>', 'idf.py fullclean build')
  map('<leader>mf', '<Cmd>Make flash<CR>', 'idf.py flash (UART)')

  -- Espressif's OpenOCD: program_esp and the esp32 targets only exist in the fork, not upstream
  local function openocd_ok()
    if not need(openocd) then
      return false
    end
    if not vim.fn.system({ openocd, '--version' }):match('esp32') then
      vim.notify('ESP32: ' .. vim.fn.exepath(openocd) .. ' is not the Espressif OpenOCD fork '
                 .. '(load the ESP-IDF environment, or set openocd = ... in nvim-project.lua)', vim.log.levels.ERROR)
      return false
    end
    if not vim.uv.fs_stat(root .. '/' .. openocd_cfg) then
      vim.notify('ESP32: ' .. openocd_cfg .. ' not found in ' .. root, vim.log.levels.ERROR)
      return false
    end
    return true
  end

  -- ESP_RTOS has to be set before the target is created, i.e. before -f
  local openocd_argv = { openocd, '-c', 'set ESP_RTOS ' .. (project.rtos or 'hwthread'), '-f', openocd_cfg }

  map('<leader>mg', mcu.openocd_key(function() return openocd_ok() and openocd_argv or nil end, root),
      'OpenOCD (Espressif) gdb server (:3333); again = restart it (stops the debug session)')

  map('<leader>mF', function()
    local ok, info = pcall(build_info, root)
    if not ok then
      vim.notify(info, vim.log.levels.ERROR)
      return
    end
    if openocd_ok() and not mcu.openocd_busy() then
      mcu.term(vim.list_extend(vim.deepcopy(openocd_argv),
                 { '-c', string.format('program_esp %s %s verify reset exit', info.bin, info.offset) }), root)
    end
  end, 'flash app with OpenOCD (JTAG)')

  -- serial port: nvim-project.lua serial_port, else the first USB-UART found
  local function serial_port()
    if project.serial_port then
      return project.serial_port
    end
    for _, glob in ipairs(serial_globs) do
      local found = vim.fn.glob(glob, false, true)[1]
      if found then
        return found
      end
    end
    vim.notify('ESP32 serial: no USB-UART in /dev/serial/by-id (esp-prog / board plugged in?), '
               .. 'or set serial_port in nvim-project.lua', vim.log.levels.ERROR)
  end

  -- picocom, like on STM32: quit with Ctrl-A Ctrl-X. Opening the port leaves DTR = RTS, so the
  -- auto-reset circuit doesn't reset the chip (a debug session keeps running).
  map('<leader>ms', function()
    local port = serial_port()
    if port then
      mcu.term({ 'picocom', '-q', '-b', tostring(console_baud()), '--imap', 'lfcrlf', port }, root)
    end
  end, 'serial terminal (picocom)')

  -- idf.py monitor decodes panic backtraces / addresses with the ELF, but resets the chip on open
  -- (don't use it during a debug session); quit: Ctrl-]
  map('<leader>mS', function()
    local port = serial_port()
    if port and need('idf.py') then
      mcu.term({ 'idf.py', '-C', root, '-p', port, 'monitor' }, root)
    end
  end, 'idf.py monitor (quit: Ctrl-])')

  -- nvim-dap: needs the OpenOCD gdb server (<leader>mg) running on :3333 ------------------------
  -- values are functions, so they are read from the build when the session starts
  local function config(name, stop_at_app_main, commands_fn)
    return {
      name = name,
      type = 'cppdbg',
      request = 'launch',
      MIMode = 'gdb',
      miDebuggerPath = function()
        local info = build_info(root)
        return vim.fn.exepath(info.gdb) ~= '' and vim.fn.exepath(info.gdb) or info.gdb
      end,
      -- ignore a project ./.gdbinit (the old Termdebug one kills / starts OpenOCD and connects by
      -- itself); ~/.gdbinit and ~/.config/gdb/gdbinit are still read
      miDebuggerArgs = '-iex "set auto-load local-gdbinit off"',
      miDebuggerServerAddress = 'localhost:3333',
      program = function() return build_info(root).elf end,
      cwd = root,
      stopAtEntry = false,
      postRemoteConnectCommands = function()
        local cmds = { 'set remote hardware-watchpoint-limit 2' }
        vim.list_extend(cmds, commands_fn(build_info(root)))
        vim.list_extend(cmds, halt_commands)
        table.insert(cmds, 'maintenance flush register-cache')
        if stop_at_app_main then
          table.insert(cmds, 'thb app_main') -- 2 hardware breakpoints on the ESP32: this uses one
        end
        return mcu.gdb_cmds(cmds)
      end,
    }
  end
  mcu.set_dap_configs({
    config('ESP32 flash + debug (stop at app_main)', true, function(info)
      return { 'monitor reset halt',
               string.format('monitor program_esp %s %s verify', info.bin, info.offset),
               'monitor reset halt' }
    end),
    config('ESP32 attach (no reset, no flash)', false, function() return {} end),
  })
end

-- for tests: true while an export.sh runs
function M._loading() return idf.loading ~= nil end

-- workflow part of <leader>mh (mcu.help)
M.help = {
  '1. first `<leader>mb` (idf.py build): creates build/ and compile_commands.json for clangd',
  '2. flash: `<leader>mf` over the UART, or `<leader>mF` over JTAG (OpenOCD)',
  '3. `<leader>mg`: Espressif OpenOCD in a terminal split, leave it running',
  '4. `<leader>dc` -> "ESP32 flash + debug (stop at app_main)": flashes, resets, stops at app_main',
  '   or "ESP32 attach (no reset, no flash)": debug what already runs',
  '5. after a change: `<leader>mb`, then `<leader>dl` (runs the last config again = flashes the new build)',
  '6. console: `<leader>ms` picocom (quit: Ctrl-A Ctrl-X) or `<leader>mS` idf.py monitor (quit: Ctrl-])',
  '',
  'Threads view = CPU0 / CPU1 (rtos hwthread), not the FreeRTOS tasks. No LiveWatch on ESP32:',
  'values are visible in dap-ui only while the target is stopped. `<leader>mB`: idf.py fullclean build.',
}

return M
