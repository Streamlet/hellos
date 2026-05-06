#!/bin/sh

nasm -f bin -i ../../../boot/two-stage/ ../../../boot/two-stage/stage1.asm -o stage1.bin
nasm -f bin -i ../../../boot/two-stage/ ../../../boot/two-stage/stage2.asm -o stage2.bin

nasm -f obj bootstrap.asm -o bootstrap.obj
wcc -0 -s -os -d0 -ecc -ms -zastd=c99 -fo=kernel.obj kernel.c
wlink format raw bin name kernel.bin option nodefaultlibs option eliminate option offset=0x88000 option start=_start file bootstrap.obj,kernel.obj
