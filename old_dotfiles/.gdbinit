add-auto-load-safe-path /home/steph/miniGW/gewiss-fenice-minigateway/.gdbinit
add-auto-load-safe-path /home/steph/tmp/cmake/.gdbinit
add-auto-load-safe-path /home/steph/joinon/test/cmake/.gdbinit

set confirm off

# c++ containers print pretty
python
import sys
sys.path.insert(0, '/usr/share/gcc/python/')
from libstdcxx.v6.printers import register_libstdcxx_printers
register_libstdcxx_printers (None)
end
set print pretty
