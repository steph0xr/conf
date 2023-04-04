source .commands.py
esp-init
# esp-all
##set remotetimeout 15000
# file build/driver_testing.elf
# target remote :3333
##target extended-remote :3333
# mon esp appimage_offset 0x430000a --> ota
# mon esp appimage_offset 0x10000   --> se viene spostata ptabl va istruito openocd prima di fare la connessione target remote, dove deve trovare la appimage (errore flash map read failure)
# target remote :3333
##set remote hardware-watchpoint-limit 2
# mon adapter_khz 5000 esp-prog
# mon adapter_khz 10000 jlink
# mon reset halt
# flash-esp
##mon reset halt
##flushregs
# b app_main
# thb app_main
# hb IQS7222B.cpp:199
# hb IQS7222B.cpp:206
# hb Wire.cpp:457
# hb IQS7222B.cpp:1063
# b emberAfFormNetwork
# b ezspNetworkInit
##set print pretty on
# continue


# define esp-flash
# mon reset halt
# mon program_esp /home/steph/teqqo/air-purifier/test/build/driver_testing.bin 0x10000 verify
# file build/hello_world.elf
# mon reset init
# end

# define esp-flash-launch
# mon reset halt
# mon program_esp /home/steph/teqqo/air-purifier/test/build/driver_testing.bin 0x10000 verify
# file build/driver_testing.elf
# mon reset init
# continue
# end

# define reconnect
    # target extended-remote :3333
# end

# define esp-from-ram
# # Run to a specific point in ROM code,
# #  where most of initialization is complete.
  # thb *0x40007d54
  # c
  # # Load the application into RAM
  # load
  # # Run till app_main
  # tb app_main
  # c
# end

