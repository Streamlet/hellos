@Echo Off

nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin
