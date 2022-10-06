#! /bin/bash

# keyboard settings
xset r rate 250 60 

# multi screen
xrandr --output HDMI-0 --auto --mode "1920x1080" --right-of eDP-1-1

# _vga=$( xrandr  | sed -n 's/^\(VGA.\).*/\1/pg')
# alias laptop='xrandr --output LVDS1 --auto --output $_vga --off'
# alias monitor='xrandr --output LVDS1 --off --output $_vga --auto'
# alias dual='xrandr --output LVDS1 --auto --left-of $_vga --output $_vga --auto'

# caps lock remap to ctrl
setxkbmap -option ctrl:nocaps

# bg image
feh --bg-scale /home/steph/Immagini/elCap.jpg

# keyring chiavi ssh
eval $(/usr/bin/gnome-keyring-daemon --start)
export SSH_AUTH_SOCK

exec i3
