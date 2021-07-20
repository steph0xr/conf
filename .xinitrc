#! /bin/bash

# keyboard settings
xset r rate 250 60

# multi screen
xrandr --output HDMI-0 --auto --right-of eDP-1-1

# caps lock remap to ctrl
setxkbmap -option ctrl:nocaps

# bg image
feh --bg-scale /home/steph/Immagini/elCap.jpg

# keyring chiavi ssh
eval $(/usr/bin/gnome-keyring-daemon --start)
export SSH_AUTH_SOCK

exec i3
