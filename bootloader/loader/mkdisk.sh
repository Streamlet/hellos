#!/bin/sh

dd if=/dev/zero of=disk.img bs=512 count=17
dd if=boot.bin of=disk.img bs=512 seek=0 conv=notrunc
printf '\x55\xAA' | dd of=disk.img bs=1 seek=510 count=2 conv=notrunc
dd if=stage2.bin of=disk.img bs=512 seek=1 conv=notrunc
