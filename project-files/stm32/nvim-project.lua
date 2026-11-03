-- MCU project settings, read by ~/.config/nvim/lua/mcu (dotfiles: tag-vim/config/nvim/lua/mcu).
-- Its presence makes this folder an STM32 project when nvim starts here (or on :cd here).
-- nvim asks to trust this file the first time and after every change; reload with :Mcu.
-- Every field is optional.
return {
  -- OpenOCD target script for <leader>mg (gdb server) and <leader>mF (flash), e.g. target/stm32g4x.cfg
  openocd_target = 'target/stm32u0x.cfg',

  -- UART speed of the printf output on the ST-LINK virtual COM port (<leader>ms)
  serial_baud = 115200,

  -- extra gdb commands sent after connecting, in both dap configs (before `tbreak main`).
  -- Typical use: freeze a timer while the core is halted, so a breakpoint doesn't leave PWM
  -- running on power hardware. The DBGMCU register address and bit are different on every
  -- family, so take them from the reference manual. Example from the STM32G431 motor project:
  --   'set *(unsigned int *)0xE0042010 |= 0x800', -- DBGMCU_APB2FZ.DBG_TIM1_STOP (G4 only!)
  halt_commands = {},

  -- tables usable in LiveWatch formulas, e.g.  faults: Mci[0].CurrentFaults => flags(x, MY_FLAGS)
  helpers = {},

  -- initial LiveWatch list, used until .livewatch.json exists (it's created on the first change)
  defaults = {
    { expr = 'uwTick' },
    { expr = 'counter' },
    { expr = 'button_presses' },
    { name = 'led', expr = 'GPIOA->ODR', formula = 'bit(x, 5)' },    -- LD4 on PA5
    { name = 'button', expr = 'GPIOC->IDR', formula = 'bit(x, 13)' }, -- B1 on PC13 (1 = released)
  },
}
