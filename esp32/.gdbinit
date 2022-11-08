set remotetimeout 15000
file build/hello_world.elf
# target remote :3333
target extended-remote :3333
# mon esp appimage_offset 0x430000
# mon esp appimage_offset 0x10000
# target remote :3333
set remote hardware-watchpoint-limit 2
# mon adapter_khz 5000 esp-prog
# mon adapter_khz 10000 jlink
# mon reset halt
# flash-esp
mon reset halt
flushregs
thb app_main
# hb IQS7222B.cpp:199
# hb IQS7222B.cpp:206
# hb Wire.cpp:457
# hb IQS7222B.cpp:1063
# b emberAfFormNetwork
# b ezspNetworkInit
set print pretty on
c


define flash-esp    
mon reset halt
mon program_esp /hdd1/esp/esp-idf-v4.4/examples/get-started/hello_world/build/hello_world.bin 0x10000 verify
mon reset halt
end

