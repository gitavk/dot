#!/usr/bin/env bash

my_laptop_external_monitor=$(xrandr --query | grep 'DP2')
if [[ $my_laptop_external_monitor = *connected* ]]; then
  xrandr --output DP1 --primary --mode 2560x1440 --rotate normal --output DP2 --mode 2560x1440 --rotate normal --right-of DP1
fi

