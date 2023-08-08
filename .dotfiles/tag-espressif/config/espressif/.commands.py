import gdb
import os
import json


def getProjectName():
    outfile = open("build/project_description.json", 'r')
    output = outfile.read()
    #  print(output)
    dict = json.loads(output)
    name = dict['project_name']
    print("project name parsed: " + name)
    outfile.close()
    return name

binary_name = getProjectName()
binary_path = os.getcwd() + "/build/"


class EspInit(gdb.Command):
  """ connect to openocd, file the bin, configure esp32 target"""

  def __init__ (self):
    super (EspInit, self).__init__ ("esp-init", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("initializing esp connection..")
    ret = os.system("killall openocd")
    if ret == 0:
        print ("Previous openocd process killed")
    print ("Launching new openocd istance")
    os.system("openocd -f openocd.cfg &")
    print ("Starting gdb ops..")
    gdb.execute("file build/" + binary_name + ".elf")
    gdb.execute("set remotetimeout 15000")
    gdb.execute("set print pretty on")
    gdb.execute("target extended-remote :3333")
    gdb.execute("mon reset init")
    gdb.execute("mon reset halt")
    gdb.execute("set remote hardware-watchpoint-limit 2")
    #  gdb.execute("set scheduler-locking on")
    #  gdb.execute("mon esp appimage_offset 0x10000")
    gdb.execute("source .breakpoints")
    gdb.execute("hb app_main")
    #  gdb.execute("flushregs")
    gdb.execute("maintenance flush register-cache")
    gdb.execute("continue")
EspInit()



class EspFlash(gdb.Command):
  """ flash esp"""

  def __init__ (self):
    super (EspFlash, self).__init__ ("eflash", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("CMD: flash on esp..")
    #  os.system("uname -a")
    gdb.execute("mon reset halt")
    print("CMD: flashing: " + binary_path + binary_name + ".bin ...")
    gdb.execute("mon program_esp " + binary_path + binary_name + ".bin 0x10000 verify")
    #  gdb.execute("mon program_esp /hdd1/esp/esp-idf-v4.4/examples/get-started/hello_world/build/hello_world.bin 0x10000 verify")
    print("CMD: sourcing file "+ binary_name +".elf ...")
    gdb.execute("file build/" + binary_name + ".elf")
    print("CMD: reset target..")
    gdb.execute("mon reset init")
EspFlash()



class EspFlashLaunch(gdb.Command):
  """ compile flash and lauch on esp """

  def __init__ (self):
    super (EspFlashLaunch, self).__init__ ("esp-all", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("---]]] compile flash and launch..")
    os.system("idf.py build")
    gdb.execute("mon reset halt")
    print("---]]] flashing: " + binary_path + binary_name + ".bin ...")
    gdb.execute("mon program_esp " + binary_path + binary_name + ".bin 0x10000 verify")
    #  gdb.execute("mon program_esp /hdd1/esp/esp-idf-v4.4/examples/get-started/hello_world/build/hello_world.bin 0x10000 verify")
    gdb.execute("file build/" + binary_name + ".elf")
    print ("---]]] resetting target init..")
    gdb.execute("mon reset init")
    print ("---]]] launching application..")
    gdb.execute("continue")
EspFlashLaunch()



class ReconnectOpenOCD(gdb.Command):
  """ reconnect to openocd """

  def __init__ (self):
    super (ReconnectOpenOCD, self).__init__ ("reconnect-openocd", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("trying reconnect to openocd..")
    gdb.execute("target extended-remote :3333")
ReconnectOpenOCD()

class EspRestart(gdb.Command):
  """ reset target """

  def __init__ (self):
    super (EspRestart, self).__init__ ("esp-restart", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("reset esp...")
    gdb.execute("mon reset init")
EspRestart()

class EspRestartLaunch(gdb.Command):
  """ reset target and lauch """

  def __init__ (self):
    super (EspRestartLaunch, self).__init__ ("esp-restart-continue", gdb.COMMAND_USER)

  def invoke (self, arg, from_tty):
    print ("reset esp...")
    gdb.execute("mon reset init")
    gdb.execute("continue")
EspRestartLaunch()
