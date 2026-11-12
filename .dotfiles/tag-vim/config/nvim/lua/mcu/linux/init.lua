-- Embedded Linux kernel (platform = 'linux'): nvim-dap on vmlinux over kgdb (serial console,
-- optionally shared through kdmx), JTAG (OpenOCD) or any TCP gdb stub (QEMU -s), console, ssh.
-- Written for the i.MX93 EVK (NXP Yocto BSP), works for any board whose kernel has kgdb.
--
-- nvim-project.lua (paths relative to the project folder; leave out what you don't use, the matching
-- keys and dap configurations are left out too):
--   platform      = 'linux'
--   sdk           = 'sdk/environment-setup-armv8a-poky-linux' -- Yocto SDK: gdb = its $GDB
--   gdb           = 'gdb-multiarch'         -- instead of sdk
--   vmlinux       = 'kernel/vmlinux'        -- vmlinux-gdb.py + scripts/gdb next to it: lx-* commands
--   remote_build  = 'rootfs/.../linux-imx-6.6.36+git' -- kernel build dir ($B), <leader>mv copies from it
--   remote_src    = 'rootfs/workspace/sources/linux-imx' -- kernel sources ($S), <leader>mv copies the
--                   .c/.h/.S into <vmlinux folder>/src (a network mount is too slow / unreliable to debug from)
--   sync          = 'sync-kernel'           -- <leader>mv runs this script instead of the rsync of
--                   remote_build / remote_src (e.g. tar over ssh from the build server)
--   source_map    = { ['/usr/src/kernel'] = 'kernel/src' } -- DW_AT paths -> sources
--                   (Yocto: C files /usr/src/kernel, .S files /usr/src/debug/linux-imx/<PV>: map both)
--   console       = { port = '/dev/serial/by-id/...', baud = 115200 }
--   kdmx          = '~/repo/agent-proxy/kdmx/kdmx'  -- (or true: on PATH) share the console with kgdb
--   ssh           = 'root@imx93'            -- reboot / sysrq break-in / shell
--   kgdb_tty      = 'ttyLP0'                -- board side console UART (kgdboc=)
--   kgdb_bootargs = 'kgdboc=ttyLP0,115200 kgdbwait' -- added for one boot by <leader>mr
--   openocd_cfg   = 'jtag/imx93-evk.cfg'    -- JTAG: <leader>mg + "Linux JTAG"
--   jtag_fdtfile  = 'imx93-11x11-evk-jtag.dtb' -- <leader>mj boots once with this dtb (on the boot
--                   partition next to the normal one: e.g. JTAG pins not muxed away, no deep idle)
--   uboot         = { elf = 'uboot/u-boot', bin = 'uboot/u-boot.bin', text_base = '0x80200000',
--                     source_map = { ['/usr/src/debug/u-boot-imx/2024.04'] = 'uboot/src' },
--                     kernel = false,                            -- no vmlinux symbols in that session
--                     gdb_commands = { 'break board_init_f' } }  -- <leader>mu + "U-Boot chain-load"
--   keep_hw_breakpoints = false             -- JTAG: let the kernel clear the hardware breakpoints at
--                   arch_initcall (default: skipped, kernel-gdb.py kernel-keep-hwbp, costs 1 of 6)
--   gdb_server    = 'localhost:1234'        -- "gdb server" config (QEMU -s, kgdb over telnet, ...)
--   gdb_commands  = { 'source .breakpoints' } -- after connecting
--
-- Keys:
--   <leader>mk  kdmx on the console UART: two ptys, one for gdb (.kdmx_gdb), one for the terminal (.kdmx_trm)
--   <leader>ms  console (picocom: on kdmx's terminal pty when kdmx runs, else on the UART). Quit: Ctrl-A Ctrl-X
--   <leader>mr  reboot into kgdbwait (ssh reboot or RESET, U-Boot: one-shot bootargs, no saveenv)
--   <leader>mj  reboot for JTAG (the same, U-Boot: one-shot fdtfile = jtag_fdtfile), then <leader>mg
--   <leader>mu  reset into the U-Boot prompt with caches off (U-Boot debug: then <leader>mg, "U-Boot chain-load")
--   <leader>mx  break into the running kernel (sysrq-g over ssh, else typed on the console), then <leader>dc
--   <leader>dk  the same + start "Linux kgdb ..." right away: one key from a running kernel to gdb
--   <leader>mg  OpenOCD (JTAG) gdb server :3333; again while it runs = restart (stops the debug session)
--   <leader>mG  the same with core 0 only (openocd -c 'set CHIPCORES 1'): from U-Boot / early boot with an
--               OpenOCD without jtag/openocd-smp-skip-unexamined.patch (with it, <leader>mg works there too)
--   <leader>mS  ssh shell on the board
--   <leader>mv  update vmlinux + gdb scripts + sources: runs `sync`, else rsync of remote_build / remote_src
-- dap (<leader>dc): "Linux kgdb (kdmx)" | "Linux kgdb (serial)" | "Linux JTAG (OpenOCD :3333)" | "Linux gdb server ..."
--
-- kgdb notes: gdb sees every task as a thread (info threads, thread N, bt); lx-symbols loads the
-- symbols of the modules that are loaded (.ko searched under the vmlinux folder); `continue` resumes
-- the kernel. Over a plain UART (no kdmx) the console is gone while gdb is attached.

local mcu = require('mcu')
local map = mcu.map

local M = {}

local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))

function M.setup(root, project)
  local function abs(p)
    if not p then
      return nil
    end
    p = vim.fn.expand(p)
    -- one value only (gsub also returns a count, which `{ abs(x) }` would add to an argv)
    return (select(1, (p:match('^/') and p or root .. '/' .. p):gsub('/$', '')))
  end

  local console = project.console or {}
  local port, baud = console.port, console.baud or 115200
  local ssh = project.ssh
  local kgdb_tty = project.kgdb_tty or 'ttyLP0'
  local bootargs = project.kgdb_bootargs or string.format('kgdboc=%s,%d kgdbwait', kgdb_tty, baud)
  local vmlinux = abs(project.vmlinux or 'vmlinux')
  local kdir = vim.fs.dirname(vmlinux)
  local kdmx_status = root .. '/.kdmx'
  local kdmx = project.kdmx
  if kdmx then
    kdmx = kdmx == true and 'kdmx' or vim.fn.expand(kdmx)
  end

  -- gdb: the SDK's $GDB (full path, nvim's own environment stays as it is)
  local gdb = project.gdb
  if not gdb and project.sdk then
    local env = abs(project.sdk)
    gdb = vim.trim(vim.fn.system({ 'bash', '-c', '. "$1" >/dev/null 2>&1 && command -v "$GDB"', 'sdk', env }))
    if vim.v.shell_error ~= 0 or gdb == '' then
      vim.notify('linux: no $GDB from ' .. env .. ', using gdb-multiarch', vim.log.levels.WARN)
      gdb = nil
    end
  end
  gdb = gdb or 'gdb-multiarch'

  local function need(what, value, field)
    if value then
      return true
    end
    vim.notify('linux: ' .. what .. ': set ' .. field .. ' in nvim-project.lua', vim.log.levels.ERROR)
    return false
  end

  local function read_line(path)
    local f = io.open(path, 'r')
    if not f then
      return nil
    end
    local l = f:read('*l')
    f:close()
    return l and vim.trim(l) or nil
  end

  -- kdmx ---------------------------------------------------------------------------------------
  local kdmx_job
  -- pty kdmx wrote for 'gdb' / 'trm', while our kdmx runs
  local function kdmx_pty(which)
    if not mcu.running(kdmx_job) then
      return nil
    end
    local pty = read_line(kdmx_status .. '_' .. which)
    return pty and vim.uv.fs_stat(pty) and pty or nil
  end

  if kdmx then
    map('<leader>mk', function()
      if not need('kdmx', port, 'console.port') then
        return
      end
      if mcu.running(kdmx_job) then
        vim.notify('linux: kdmx already runs (gdb ' .. tostring(kdmx_pty('gdb')) .. ', terminal '
                   .. tostring(kdmx_pty('trm')) .. ')')
        return
      end
      os.remove(kdmx_status .. '_gdb')
      os.remove(kdmx_status .. '_trm')
      kdmx_job = mcu.term({ kdmx, '-p', port, '-b', tostring(baud), '-s', kdmx_status }, root)
    end, 'kdmx: split the console UART into gdb + terminal ptys')
  end

  -- the console tty to open: kdmx's terminal pty while kdmx runs (kgdb), else the UART itself
  -- (JTAG: no kdmx needed, and nothing in between that can swallow the output)
  local function console_tty()
    local pty = kdmx and kdmx_pty('trm')
    if pty then
      return pty
    end
    if kdmx then
      vim.notify('linux: kdmx is not running: console directly on the UART (for kgdb: <leader>mk first)')
    end
    return need('console', port, 'console.port') and port or nil
  end

  -- one console terminal at a time (two readers on one tty steal each other's characters)
  local console_job
  local function close_console()
    mcu.quit(console_job)
    console_job = nil
  end

  if port then
    map('<leader>ms', function()
      local tty = console_tty()
      if tty then
        close_console()
        console_job = mcu.term({ 'picocom', '-q', '-b', tostring(baud), tty }, root)
      end
    end, 'console (picocom, quit: Ctrl-A Ctrl-X)')

    -- reboot, stop U-Boot, type `commands`, boot, wait for `wait` (uboot-boot.exp); the console
    -- terminal stays open when keep (else closed: gdb opens the UART itself)
    local function uboot_boot(keep, wait, commands)
      local tty = console_tty()
      if not tty then
        return
      end
      close_console()
      console_job = mcu.term(vim.list_extend({ 'expect', here .. '/uboot-boot.exp', tty, tostring(baud),
                                               ssh or '-', keep and '1' or '0', wait }, commands),
                             root, 'picocom')
    end

    map('<leader>mr', function()
      -- ${mmcargs} is expanded by U-Boot right away, its own ${console} / ${mmcroot} at boot time
      uboot_boot(kdmx and true or false, 'Waiting for connection from remote gdb',
                 { 'setenv mmcargs "${mmcargs} ' .. bootargs .. '"' })
    end, 'reboot into kgdbwait (one-shot U-Boot bootargs)')

    if project.jtag_fdtfile then
      map('<leader>mj', function()
        uboot_boot(true, 'login:', { 'setenv fdtfile ' .. project.jtag_fdtfile })
      end, 'reboot for JTAG (one-shot U-Boot fdtfile ' .. project.jtag_fdtfile .. ')')
    end

    if project.uboot then
      -- caches (and the MMU) off: the U-Boot copy gdb starts must not inherit this one's page tables
      -- (it would overwrite them when it relocates), and JTAG writes then go straight to RAM
      map('<leader>mu', function()
        uboot_boot(true, '-', { 'dcache off', 'icache off' })
      end, 'reset into the U-Boot prompt, caches off (then <leader>mg, "U-Boot chain-load")')
    end
  end

  -- break into the running kernel: kgdboc on the console UART (if not set at boot), then sysrq-g.
  -- ssh hangs once the kernel stops, hence the timeout.
  local break_cmd = string.format('f=/sys/module/kgdboc/parameters/kgdboc; grep -q . $f || echo %s,%d > $f; '
                                  .. 'sync; echo g > /proc/sysrq-trigger', kgdb_tty, baud)
  -- break_in(on_halted): stop the running kernel in kgdb, then call on_halted().
  --   ssh       run break_cmd over ssh (the shell runs as root, no login on the console needed)
  --   kdmx      type it into kdmx's terminal pty, i.e. the board console: needs a root shell prompt there
  --   console   no kdmx: type it into the open console terminal (<leader>ms), then close that, gdb
  --             needs the UART
  -- Ctrl-U first clears whatever is half-typed on the console's command line.
  local typed = '\21' .. break_cmd .. '\r'
  local function break_in(on_halted)
    if ssh then
      if not kdmx and mcu.running(console_job) then
        close_console()
      end
      vim.system({ 'timeout', '5', 'ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=3', ssh, break_cmd }, {},
        vim.schedule_wrap(function(r)
          if r.code == 124 then -- timeout: the kernel stopped under ssh's feet
            on_halted()
          else
            vim.notify('linux: ssh ' .. ssh .. ' failed (' .. r.code .. '):\n' .. (r.stderr or ''), vim.log.levels.ERROR)
          end
        end))
      return
    end
    if kdmx then
      local pty = kdmx_pty('trm')
      local f = pty and io.open(pty, 'w')
      if not f then
        vim.notify('linux: kdmx is not running, start it first (<leader>mk)', vim.log.levels.ERROR)
        return
      end
      f:write(typed)
      f:close()
    elseif mcu.running(console_job) then
      vim.fn.chansend(console_job, typed)
      vim.defer_fn(close_console, 500)
    else
      vim.notify('linux: no ssh / kdmx / console to send sysrq-g: open the console (<leader>ms), log in as root',
                 vim.log.levels.ERROR)
      return
    end
    vim.defer_fn(on_halted, 1500) -- shell runs it, the kernel enters kgdb
  end

  map('<leader>mx', function()
    break_in(function() vim.notify('linux: kernel stopped in kgdb: <leader>dc -> "Linux kgdb ..." (or <leader>dk next time)') end)
  end, 'break into kgdb (sysrq-g over ssh / console)')

  if project.openocd_cfg then
    -- again while it runs = restart (e.g. after a board reset: the cores are examined fresh; core 1
    -- exists only once Linux has started it), see mcu.openocd_key
    -- <leader>mG: core 0 only (cfg variable CHIPCORES = 1, see jtag/imx93-a55-linux.cfg), for U-Boot /
    -- early boot while core 1 is off. One OpenOCD for both keys: either key while it runs = restart
    -- in that key's mode.
    local core0_only = false
    local key = mcu.openocd_key(function()
      local cfg = abs(project.openocd_cfg)
      if not vim.uv.fs_stat(cfg) then
        vim.notify('linux: ' .. cfg .. ' not found', vim.log.levels.ERROR)
        return nil
      end
      local cmd = { project.openocd or 'openocd' }
      if core0_only then vim.list_extend(cmd, { '-c', 'set CHIPCORES 1' }) end
      return vim.list_extend(cmd, { '-f', cfg })
    end, root)
    map('<leader>mg', function() core0_only = false; key() end,
      'OpenOCD (JTAG) gdb server (:3333), both cores; again = restart it (stops the debug session)')
    map('<leader>mG', function() core0_only = true; key() end,
      'OpenOCD core 0 only (U-Boot / early boot with an unpatched OpenOCD); again = restart it')
  end

  if ssh then
    map('<leader>mS', function() mcu.term({ 'ssh', ssh }, root) end, 'ssh shell on the board (quit: Enter ~ .)')
  end

  if project.sync then
    -- a project script (e.g. tar over ssh from the build server: much faster than a network mount)
    map('<leader>mv', function()
      mcu.term({ abs(project.sync) }, root)
    end, 'update vmlinux + gdb scripts + sources (' .. project.sync .. ')')
  elseif project.remote_build or project.remote_src then
    map('<leader>mv', function()
      local q = vim.fn.shellescape
      local cmds = { 'set -e' }
      vim.fn.mkdir(kdir, 'p')
      if project.remote_build then
        -- -L: vmlinux-gdb.py is a symlink into the source tree
        table.insert(cmds, string.format('cd %s && rsync -aL vmlinux %s/ && rsync -aL --relative --include="*/" '
                                         .. '--include="*.py" --exclude="*" vmlinux-gdb.py scripts/gdb %s/',
                                         q(abs(project.remote_build)), q(kdir), q(kdir)))
      end
      if project.remote_src then
        -- only what the debug info points to; -m: no empty dirs, --delete: files removed upstream go too
        table.insert(cmds, string.format('cd %s && rsync -a -m --delete --exclude=.git --exclude=/Documentation '
                                         .. '--exclude=/tools --exclude=/samples --include="*/" --include="*.[chS]" '
                                         .. '--include="*.lds" --exclude="*" ./ %s/src/', q(abs(project.remote_src)), q(kdir)))
      end
      table.insert(cmds, 'ls -l ' .. q(kdir .. '/vmlinux') .. '; echo done')
      mcu.term({ 'sh', '-c', table.concat(cmds, '\n') }, root)
    end, 'copy vmlinux + gdb scripts + sources from the kernel build')
  end

  -- nvim-dap ------------------------------------------------------------------------------------
  local source_map = {}
  for from, to in pairs(project.source_map or {}) do
    source_map[from] = abs(to)
  end

  local function config(name, address, setup)
    return {
      name = name,
      type = 'cppdbg',
      request = 'launch', -- (attach wants a local process id)
      MIMode = 'gdb',
      targetArchitecture = project.arch or 'arm64', -- cppdbg can't tell from vmlinux, assumes x86_64
      miDebuggerPath = gdb,
      -- vmlinux-gdb.py is auto-loaded from the vmlinux folder (lx-* commands); a project .gdbinit is not.
      -- no debuginfod (Ubuntu's DEBUGINFOD_URLS): vmlinux has everything, and the query stalls the start
      miDebuggerArgs = string.format('-iex "set auto-load local-gdbinit off" -iex "set debuginfod enabled off" '
                                     .. '-iex "add-auto-load-safe-path %s"', kdir),
      miDebuggerServerAddress = address,
      program = vmlinux,
      cwd = kdir, -- lx-symbols looks for vmlinux and the .ko here
      sourceFileMap = source_map,
      -- cppdbg takes the stop it finds after connecting as the program's entry point: true = stay
      -- there (where kgdb / JTAG halted the kernel); false would send -exec-continue right away
      stopAtEntry = true,
      setupCommands = mcu.gdb_cmds(setup or {}),
      postRemoteConnectCommands = mcu.gdb_cmds(project.gdb_commands or {}),
    }
  end

  local configs = {}
  local kgdb_config
  if kdmx then
    kgdb_config = config('Linux kgdb (kdmx)', function()
      local pty = kdmx_pty('gdb')
      if not pty then
        error('linux: kdmx is not running (<leader>mk)')
      end
      return pty
    end)
  elseif port then
    kgdb_config = config('Linux kgdb (serial ' .. vim.fs.basename(port) .. ')', function()
      if mcu.running(console_job) then
        close_console() -- gdb needs the UART for itself
      end
      return port
    end, { 'set serial baud ' .. baud, 'set remotetimeout 10' })
  end
  table.insert(configs, kgdb_config)
  if project.openocd_cfg then
    local jtag = config('Linux JTAG (OpenOCD :3333)', 'localhost:3333')
    jtag.useExtendedRemote = true -- what OpenOCD expects ("Prefer GDB command target extended-remote")
    -- no `run` after connecting (cppdbg's default exec-run): over extended-remote OpenOCD turns it into
    -- "reset halt" = a board reset (the cfg also makes it a plain halt)
    jtag.launchCompleteCommand = 'None'
    -- kernel-keep-hwbp (kernel-gdb.py): the kernel's hw_breakpoint_reset (arch_initcall, hotplug) is
    -- skipped, so breakpoints survive it; one of the 6 hardware breakpoints. keep_hw_breakpoints = false: off
    vim.list_extend(jtag.setupCommands, mcu.gdb_cmds({ 'source ' .. here .. '/kernel-gdb.py' }))
    if project.keep_hw_breakpoints ~= false then
      table.insert(jtag.postRemoteConnectCommands, 1, { text = 'kernel-keep-hwbp' })
    end
    table.insert(configs, jtag)
  end
  if project.openocd_cfg and project.uboot then
    -- U-Boot proper from its first instruction: the running U-Boot (halted at its prompt, caches off:
    -- <leader>mu) is replaced by a fresh copy written over JTAG. u-boot.bin, not the ELF: with
    -- CONFIG_OF_SEPARATE the dtb is appended to the .bin only. SPL already set up the DDR, so U-Boot
    -- proper can run again; clocks / pins are set up a second time.
    local u = project.uboot
    local elf, bin = abs(u.elf or 'uboot/u-boot'), abs(u.bin or 'uboot/u-boot.bin')
    local base = u.text_base or '0x80200000'
    -- + the kernel's paths: its symbols are loaded too (below), for U-Boot -> Linux in one session
    local umap = vim.deepcopy(source_map)
    for from, to in pairs(u.source_map or {}) do
      umap[from] = abs(to)
    end
    local c = config('U-Boot chain-load (OpenOCD :3333)', 'localhost:3333')
    c.useExtendedRemote = true
    c.launchCompleteCommand = 'None' -- no `run` = no board reset (see the JTAG config)
    c.program = elf
    c.cwd = vim.fs.dirname(elf)
    c.sourceFileMap = umap
    c.miDebuggerArgs = '-iex "set auto-load local-gdbinit off" -iex "set debuginfod enabled off"'
    -- uboot-reloc (REPL: -exec uboot-reloc): symbols at the relocated address, see uboot-gdb.py
    c.setupCommands = mcu.gdb_cmds({ 'source ' .. here .. '/uboot-gdb.py', 'source ' .. here .. '/kernel-gdb.py' })
    -- restore u-boot.bin, pc = base, x1..x4 = the running copy's boot registers (uboot-gdb.py)
    -- + vmlinux's symbols (kernel_init ... breakpoints in the same session; ~1 s), unless kernel = false
    local cmds = { 'uboot-chainload ' .. bin .. ' ' .. base }
    if u.kernel ~= false then
      table.insert(cmds, 'uboot-add-symbols ' .. vmlinux)
      if project.keep_hw_breakpoints ~= false then
        table.insert(cmds, 'kernel-keep-hwbp') -- see the JTAG config
      end
    end
    c.postRemoteConnectCommands = mcu.gdb_cmds(vim.list_extend(cmds, u.gdb_commands or {}))
    table.insert(configs, c)
  end
  if project.gdb_server then
    table.insert(configs, config('Linux gdb server ' .. project.gdb_server, project.gdb_server))
  end
  mcu.set_dap_configs(configs)

  -- one key: stop the kernel (sysrq-g) and attach gdb to it
  if kgdb_config then
    map('<leader>dk', function()
      local dap = require('dap')
      if dap.session() then
        vim.notify('linux: a debug session is already running (continue / <leader>dq first)', vim.log.levels.WARN)
        return
      end
      break_in(function() dap.run(kgdb_config) end)
    end, 'break into the kernel (sysrq-g) + attach gdb (kgdb)')
  end

  if not vim.uv.fs_stat(vmlinux) then
    vim.notify('linux: ' .. vmlinux .. ' not found' .. (project.remote_build and ' (<leader>mv copies it)' or ''),
               vim.log.levels.WARN)
  end
end

-- workflow part of <leader>mh (mcu.help)
M.help = {
  'After every kernel bitbake: `<leader>mv` (copies vmlinux, gdb scripts and sources from the build server).',
  'After changing nvim-project.lua: `:trust`.',
  '',
  '### JTAG (OpenOCD; e.g. J-Link on the i.MX93 EVK)',
  '1. board: boot the JTAG dtb (`<leader>mj`, press RESET when asked; or saved in U-Boot: fdtfile)',
  '2. `<leader>ms`: console directly on the UART (no kdmx), log in',
  '3. `<leader>mg`: OpenOCD (in Linux both cores "Examination succeed")',
  '4. `<leader>dc` -> "Linux JTAG (OpenOCD :3333)": halts both cores (threads = CPUs)',
  '5. breakpoints (hardware, 6), continue; stop the session = the kernel keeps running',
  '6. after a board reset: `<leader>mg` again = restart OpenOCD (stops the session), then `<leader>dc`',
  'While halted the whole SoC stops, the console too.',
  '',
  '### JTAG from early boot (e.g. `kernel_init`)',
  '1. reset the board, stop autoboot (any key) -> `u-boot=>`',
  '2. `<leader>mg`: "a55.1 examination failed" is normal (core 1 is off until the kernel\'s smp_init)',
  '3. `<leader>dc` -> "Linux JTAG": core 0 halts in U-Boot (`?? ()` and some aborts: normal)',
  '4. breakpoint(s), `<leader>dc` continue (U-Boot answers again), type `boot` on the console',
  'Core 1 is examined at the first halt after smp_init ("core 1 is up" in the OpenOCD log), its gdb',
  'thread appears at the halt after that. Breakpoints set before: core 0 only (gdb re-inserts them on',
  'both cores at the next continue). The kernel\'s breakpoint reset at arch_initcall is skipped (kernel-keep-hwbp).',
  'Needs OpenOCD with jtag/openocd-smp-skip-unexamined.patch; without it: `<leader>mG` (core 0 only).',
  '',
  '### U-Boot proper over JTAG (chain-load: a fresh copy from its first instruction)',
  '1. `<leader>mv` once (sync: uboot/ = ELF, u-boot.bin, sources)',
  '2. `<leader>mu`: press RESET when asked; stops at `u-boot=>` and types `dcache off`, `icache off`',
  '3. `<leader>mg`, then `<leader>dc` -> "U-Boot chain-load": writes u-boot.bin to 0x80200000 (a few s),',
  '   x1..x4 = the old copy\'s boot registers (OP-TEE base/size), stops at `reset` (start.S, after _start)',
  '   (OpenOCD log at the halt: "MMU: disabled"; "enabled" = <leader>mu skipped)',
  '4. breakpoints (e.g. board_init_f), continue: the new U-Boot prints its banner on the console',
  '5. after relocation (stopped at relocate_code or later): REPL `-exec uboot-reloc` = symbols at the',
  '   relocated address (breakpoints move along)',
  'Hardware breakpoints survive the kernel\'s debug-register reset at arch_initcall: a hidden breakpoint',
  'on hw_breakpoint_reset skips it ("kernel-keep-hwbp: ... skipped" in the debug console); 5 of 6 left.',
  'The kernel symbols (vmlinux) are loaded too: breakpoints in the kernel (e.g. `kernel_init`) work in',
  'the same session, U-Boot -> Linux (`uboot.kernel = false` in nvim-project.lua: U-Boot only).',
  'U-Boot proper only: SPL / DDR init can\'t run again. Clocks / pins are set up a second time.',
  '',
  '### kgdb (serial console)',
  '1. `<leader>mk`: kdmx (splits the console UART: gdb + terminal), then `<leader>ms` and log in as root',
  '2. `<leader>dk`: breaks into the running kernel (sysrq-g) and attaches gdb',
  '   (or `<leader>mx` = break-in only, then `<leader>dc` -> "Linux kgdb ...")',
  '3. breakpoints, continue; stop the session = the kernel keeps running',
  '4. from early boot: `<leader>mr` reboots once with kgdbwait (kgdb starts late in boot: earlier code = JTAG)',
  'One debugger at a time: close OpenOCD before kgdb and the other way round.',
  '',
  'gdb REPL (`<leader>dr`): `-exec lx-dmesg`, `-exec lx-ps`, `-exec lx-symbols` (modules), `-exec info threads`.',
}

return M
