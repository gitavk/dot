xrdb -merge $HOME/.Xresources
xsetroot -cursor_name left_ptr
setxkbmap -model pc105 -layout us,ru -option grp:caps_toggle
exec bspwm
