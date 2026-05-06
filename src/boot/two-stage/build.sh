#!/bin/sh

nasm -f bin stage1.asm -o stage1.bin
nasm -f bin stage2.asm -o stage2.bin
nasm -f bin -dKERNEL ../shell/boot.asm -o kernel.bin
