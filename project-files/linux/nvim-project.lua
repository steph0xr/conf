-- Embedded Linux kernel debug project, read by ~/.config/nvim/lua/mcu (dotfiles: tag-vim/config/nvim/lua/mcu,
-- the fields and keys are documented at the top of lua/mcu/linux/init.lua).
-- Paths are relative to this folder. Leave out what you don't use: its keys / dap configs are left out too.
-- Example values: i.MX93 11x11 EVK, NXP BSP 6.6.36-2.1.0 (~/tmpcode/imx-example).
return {
  platform = 'linux',

  -- Yocto SDK (populate_sdk), installed with: sh <sdk>.sh -y -d sdk   -> gdb = its $GDB
  sdk = 'sdk/environment-setup-armv8a-poky-linux',
  -- gdb = 'gdb-multiarch',                          -- instead of sdk

  -- local copy of the kernel debug files, made by `sync` (<leader>mv):
  -- vmlinux + vmlinux-gdb.py + scripts/gdb (lx-* commands) + src/ (the sources)
  vmlinux = 'kernel/vmlinux',
  sync = 'sync-kernel',                              -- rsync over ssh from the build server (edit HOST / BUILD in it)

  -- vmlinux has Yocto's debug-prefix-map paths: C files /usr/src/kernel, .S /usr/src/debug/linux-imx/<PV>
  source_map = {
    ['/usr/src/kernel'] = 'kernel/src',
    ['/usr/src/debug/linux-imx/6.6.36+git'] = 'kernel/src',
  },

  -- board console UART (here the EVK's FT4232H, 3rd port = A55 console ttyLP0)
  console = { port = '/dev/serial/by-id/usb-FT4232H_FT4232H_<serial>-if02-port0', baud = 115200 },

  -- kgdb over the console: kdmx shares the UART between gdb and the terminal (<leader>mk)
  kdmx = '~/repo/agent-proxy/kdmx/kdmx',
  kgdb_tty = 'ttyLP0',                               -- board side name of the console UART
  kgdb_bootargs = 'kgdboc=ttyLP0,115200 kgdbwait',   -- <leader>mr: one boot with these
  -- ssh = 'root@<board-ip>',                        -- reboot / sysrq-g / shell over the network

  -- JTAG: OpenOCD cfg (adapter part + jtag/imx93-a55-linux.cfg) and the dtb <leader>mj boots once
  openocd_cfg = 'jtag/imx93-evk-jlink.cfg',          -- J-Link; jtag/imx93-evk.cfg = EVK on-board FT4232H
  jtag_fdtfile = 'imx93-11x11-evk-jtag.dtb',         -- jtag/build-dtb, copied to the boot partition

  -- U-Boot proper over JTAG (<leader>mu, then <leader>mg + "U-Boot chain-load"); files from ./sync-kernel uboot
  uboot = {
    elf = 'uboot/u-boot',                          -- symbols
    bin = 'uboot/u-boot.bin',                      -- written to RAM (code + appended dtb)
    text_base = '0x80200000',                      -- CONFIG_TEXT_BASE
    source_map = { ['/usr/src/debug/u-boot-imx/2024.04'] = 'uboot/src' },
    gdb_commands = {},                             -- after the load, e.g. 'break board_init_f'
  },

  -- gdb_server = 'localhost:1234',                  -- any TCP gdb stub (QEMU -s)
  gdb_commands = {},                                 -- gdb commands after connecting
}
