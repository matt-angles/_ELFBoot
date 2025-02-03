#!/bin/sh
# Script to run the OS virtual machine
# Dependencies: qemu

cd "$(dirname "$0")"    # set Current Working Directory (CWD) to script folder

while getopts "dfg:" opt; do
    case "$opt" in
        d)debug=true;;
        f)fullscreen=true;;
        g)graphic_mode=$OPTARG;;
        *)exit 1;;
    esac
done


QEMU_BASE_OPTIONS="-name OS                             \
                   -machine pc-i440fx-9.1,accel=tcg     \
                   -m 128M                              \
                   -boot c                              \
                   -drive file=bin/os.img,format=raw,index=0,media=disk"

case "$graphic_mode" in
    advanced)   QEMU_DISPLAY="-display gtk,gl=on,window-close=on,show-tabs=on,grab-on-hover=on";;
    curses)     QEMU_DISPLAY="-display curses";;
    none)       QEMU_DISPLAY="-nographic";;
    *)          QEMU_DISPLAY="-display sdl,gl=on,window-close=on";;
esac
if [ "$fullscreen" = true ]; then
    QEMU_DISPLAY+=" -full-screen"
fi
if [ "$debug" = true ]; then
    QEMU_DEBUG="-d int,pcall,guest_errors -no-reboot -no-shutdown"
fi

qemu-system-x86_64 $QEMU_BASE_OPTIONS $QEMU_DISPLAY $QEMU_DEBUG