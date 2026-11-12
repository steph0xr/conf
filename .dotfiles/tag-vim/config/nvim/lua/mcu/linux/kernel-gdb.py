# gdb helpers for debugging the arm64 Linux kernel over JTAG (sourced by the JTAG / U-Boot dap
# configs, lua/mcu/linux).
#
#   kernel-keep-hwbp
#       Keep the debugger's hardware breakpoints across the kernel's own reset of the debug
#       registers. At arch_initcall (inside kernel_init_freeable) arch_hw_breakpoint_init runs
#       hw_breakpoint_reset() on every CPU (also on CPU hotplug / resume), which zeroes all
#       breakpoint / watchpoint registers, the ones OpenOCD wrote included: breakpoints on later
#       code (async_synchronize_full, driver probes ...) would never hit. This puts a breakpoint on
#       hw_breakpoint_reset's first instruction that does not stop: it makes the function return 0
#       right away (pc = lr, x0 = 0) and continues, so the registers are left alone.
#       Costs one of the 6 hardware breakpoints. Side effect: the kernel's own hw_breakpoint users
#       (perf / ptrace watchpoints) don't get their registers restored after CPU hotplug / resume.

import gdb


class KeepHwBp(gdb.Breakpoint):
    def __init__(self):
        super().__init__('*hw_breakpoint_reset', internal=False)
        self.skips = 0

    def stop(self):
        # at the entry (paciasp not executed yet): return straight to the caller with 0
        gdb.execute('set $x0 = 0', to_string=True)
        gdb.execute('set $pc = $x30', to_string=True)
        self.skips += 1
        gdb.write('kernel-keep-hwbp: hw_breakpoint_reset skipped (%d), hardware breakpoints kept\n' % self.skips)
        return False


class KernelKeepHwbp(gdb.Command):
    """kernel-keep-hwbp: skip the kernel's hw_breakpoint_reset (see kernel-gdb.py)."""

    def __init__(self):
        super().__init__('kernel-keep-hwbp', gdb.COMMAND_USER)
        self.bp = None

    def invoke(self, arg, from_tty):
        if self.bp and self.bp.is_valid():
            print('kernel-keep-hwbp: already set (breakpoint %d)' % self.bp.number)
            return
        try:
            gdb.parse_and_eval('hw_breakpoint_reset')
        except gdb.error:
            raise gdb.GdbError('kernel-keep-hwbp: no hw_breakpoint_reset symbol (vmlinux not loaded?)')
        self.bp = KeepHwBp()
        print('kernel-keep-hwbp: breakpoint %d on hw_breakpoint_reset (kernel debug-register reset skipped)'
              % self.bp.number)


KernelKeepHwbp()
