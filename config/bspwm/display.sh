#!/usr/bin/env bash

my_laptop_external_monitor=$(xrandr --query | grep 'DP-2')
if [[ $my_laptop_external_monitor = *connected* ]]; then
  xrandr --output DP-1 --primary --mode 2560x1440 --rotate normal --output DP-2 --mode 2560x1440 --rotate normal --right-of DP-1
fi

