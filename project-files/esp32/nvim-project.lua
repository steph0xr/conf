-- MCU project settings, read by ~/.config/nvim/lua/mcu (dotfiles: tag-vim/config/nvim/lua/mcu).
return {
  platform = 'esp32',

  -- ESP-IDF version: /opt/esp/esp-idf-v6.1 (like idf61); its export.sh is loaded into nvim
  idf = 'v6.1',

  -- probe + board for Espressif's OpenOCD, relative to this folder (esp-prog + WROVER-KIT here)
  openocd_cfg = 'openocd.cfg',

  -- serial_port = '/dev/ttyUSB1', -- idf.py monitor finds the port by itself when unset

  -- extra gdb commands after connecting (both dap configs)
  halt_commands = {},
}
