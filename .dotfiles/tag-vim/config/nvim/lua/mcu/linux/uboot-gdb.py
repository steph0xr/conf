# gdb helpers for debugging U-Boot proper over JTAG (sourced by the "U-Boot chain-load" dap config,
# lua/mcu/linux). Use them from the dap REPL as `-exec uboot-reloc`.
#
# U-Boot starts at its link address (CONFIG_TEXT_BASE), then relocate_code copies it to the top of
# DRAM and continues there (board_init_r ...). The ELF symbols only match before that copy:
#   uboot-reloc   once relocate_code has run (gd->reloc_off is set in board_init_f), e.g. stopped at
#                 relocate_code or anywhere later: reloads the symbols at the relocated address.
#                 Breakpoints are moved along by gdb (re-set from their source lines).
#   uboot-add-symbols FILE
#                 add another symbol file at its own link addresses, e.g. vmlinux: breakpoints in the
#                 kernel (kernel_init ...) work in the same session, U-Boot -> Linux. uboot-reloc
#                 loads these files again (its symbol-file clears all).
# arm64 U-Boot keeps gd (global_data) in register x18.

#   uboot-chainload BIN BASE
#                 with the running U-Boot halted (at its prompt, caches off): write BIN (u-boot.bin)
#                 to BASE (CONFIG_TEXT_BASE) and set pc there, so `continue` starts a fresh copy.
#                 i.MX8/9: the copy's first instruction saves x1..x4 into rom_pointer (from ATF: OP-TEE
#                 base / size, dram_init subtracts it: else "DRAM: 16 EiB" and a crash), so they are
#                 set to what the running copy got (its rom_pointer, at the relocated address).

import struct

import gdb

extra_files = []  # uboot-add-symbols


class UbootAddSymbols(gdb.Command):
    """uboot-add-symbols FILE: add FILE's symbols at its link addresses (kept by uboot-reloc)."""

    def __init__(self):
        super().__init__('uboot-add-symbols', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        path = arg.strip()
        if not path:
            raise gdb.GdbError('usage: uboot-add-symbols FILE')
        gdb.execute('add-symbol-file %s' % path, to_string=True)
        if path not in extra_files:
            extra_files.append(path)
        print('uboot-add-symbols: %s' % path)


UbootAddSymbols()


class UbootChainload(gdb.Command):
    """uboot-chainload BIN BASE: start a fresh U-Boot copy over the halted one (see uboot-gdb.py)."""

    def __init__(self):
        super().__init__('uboot-chainload', gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = gdb.string_to_argv(arg)
        if len(args) != 2:
            raise gdb.GdbError('usage: uboot-chainload BIN BASE')
        path, base = args
        vals = None
        try:
            off = int(gdb.parse_and_eval('((gd_t *)$x18)->reloc_off')) & 0xffffffffffffffff
            rp = (int(gdb.parse_and_eval('(unsigned long)&rom_pointer')) + off) & 0xffffffffffffffff
            vals = struct.unpack('<4Q', bytes(gdb.selected_inferior().read_memory(rp, 32)))
        except gdb.error as e:
            print('uboot-chainload: no rom_pointer of the running U-Boot (%s): x1..x4 left as they are' % e)
        gdb.execute('restore %s binary %s' % (path, base), to_string=True)
        gdb.execute('set $pc = %s' % base)
        if vals:
            for i, v in enumerate(vals):
                gdb.execute('set $x%d = 0x%x' % (i + 1, v))
        # stop right after the first instruction (_start: b reset): cppdbg sends -exec-continue after
        # connecting when the first stop has no symbol (the old copy runs at its relocated address),
        # so "stay at _start" doesn't hold; a temporary breakpoint on the branch target does
        stop = ''
        b = base_addr = int(gdb.parse_and_eval(base)) & 0xffffffffffffffff
        insn = struct.unpack('<I', bytes(gdb.selected_inferior().read_memory(base_addr, 4)))[0]
        if insn >> 26 == 0b000101:  # B imm26
            imm = insn & 0x3ffffff
            if imm & 0x2000000:
                imm -= 0x4000000
            b = base_addr + imm * 4
            gdb.execute('tbreak *0x%x' % b, to_string=True)
            stop = ', stops at 0x%x' % b
        print('uboot-chainload: %s at %s, pc = %s%s%s' % (path, base, base,
              ', x1..x4 = ' + ' '.join('0x%x' % v for v in vals) if vals else '', stop))


UbootChainload()


class UbootReloc(gdb.Command):
    """Load the U-Boot symbols at the relocated address (gd->reloc_off from x18)."""

    def __init__(self):
        super().__init__('uboot-reloc', gdb.COMMAND_USER)
        self.elf = None

    def invoke(self, arg, from_tty):
        elf = arg.strip() or gdb.current_progspace().filename or self.elf
        if not elf:
            raise gdb.GdbError('uboot-reloc: no ELF (give it: uboot-reloc <u-boot>)')
        self.elf = elf
        off = int(gdb.parse_and_eval('((gd_t *)$x18)->reloc_off')) & 0xffffffffffffffff
        if off == 0:
            raise gdb.GdbError('uboot-reloc: gd->reloc_off is 0 (not relocated yet: stop at relocate_code or later)')
        gdb.execute('symbol-file', to_string=True)
        gdb.execute('add-symbol-file %s -o 0x%x' % (elf, off), to_string=True)
        for f in extra_files:
            gdb.execute('add-symbol-file %s' % f, to_string=True)
        print('uboot-reloc: %s symbols at +0x%x (relocaddr 0x%x)' % (elf, off, int(gdb.parse_and_eval('(unsigned long)&_start'))))


UbootReloc()
