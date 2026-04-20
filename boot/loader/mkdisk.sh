#!/bin/sh

type=$1
if [ -z "$type" ]; then
    echo "Usage: $0 <type>"
    echo 'Types: 1=FAT12, 4=FAT16, 6=FAT16B, b=FAT32, c=FAT32LBA, e=FAT16LBA'
    exit 1
fi

dd if=/dev/zero of=disk.img bs=512 count=65536
fdisk disk.img << EOF
n
p
1
2048
65535
a
t
$type
w
EOF
dd if=disk.img of=partition.img bs=512 skip=2048
# yum install -y dosfstools
case $type in
    1) mkfs.fat -F 12 partition.img ;;
    4|6|e) mkfs.fat -F 16 partition.img ;;
    b|c) mkfs.fat -F 32 partition.img ;;
    *) echo "Unsupported type $type"; exit 1 ;;
esac
# yum install -y mtools
mcopy -i partition.img kernel.bin ::/KERNEL.BIN
dd if=boot.bin of=disk.img bs=512 seek=0 conv=notrunc
printf '\x55\xAA' | dd of=disk.img bs=1 seek=510 count=2 conv=notrunc
dd if=stage2.bin of=disk.img bs=512 seek=1 conv=notrunc
dd if=partition.img of=disk.img bs=512 seek=2048 conv=notrunc
#rm -f partition.img
