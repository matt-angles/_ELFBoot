#!/bin/sh
# Crude run script for the AcceptableOS virtual machine
# Dependencies: qemu

cd "$(dirname "$0")"    # Set Current Working Directory (CWD) to script folder

QEMU_BASE_OPTIONS="-name AcceptableOS                   \
                   -machine pc-i440fx-9.1,accel=tcg     \
                   -m 128M                              \
                   -boot c                              \
                   -drive file=acceptableOS.img,format=raw,index=0,media=disk"

# Personal options
QEMU_DISPLAY_SIMPLE="-display sdl,gl=on,window-close=on"
QEMU_DISPLAY_ADVANCED="-display gtk,gl=on,window-close=on,show-tabs=on,grab-on-hover=on"
QEMU_DISPLAY_CURSES="-display curses"
QEMU_NODISPLAY="-no-graphic"

QEMU_DISPLAY=$QEMU_DISPLAY_SIMPLE
QEMU_DISPLAY+=" -full-screen"

#QEMU_DEBUG="-d int,pcall,guest_errors -no-reboot -no-shutdown"

qemu-system-x86_64 $QEMU_BASE_OPTIONS $QEMU_DISPLAY $QEMU_DEBUG