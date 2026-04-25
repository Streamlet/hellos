#!/bin/sh

type=$1
if [ -z "$type" ]; then
    echo "Usage: $0 <type>"
    echo '  types: 1=FAT12, 4=FAT16, 6=FAT16B, b=FAT32, c=FAT32LBA, e=FAT16LBA'
    exit 1
fi

if ! command -v fdisk >/dev/null 2>&1 || ! command -v mkfs.fat >/dev/null 2>&1 || ! command -v mcopy >/dev/null 2>&1; then
    if ! command -v fdisk >/dev/null 2>&1; then
        echo 'fdisk is required but not found. Please install util-linux.'
    fi
    if ! command -v mkfs.fat >/dev/null 2>&1; then
        echo 'mkfs.fat is required but not found. Please install dosfstools.'
    fi
    if ! command -v mcopy >/dev/null 2>&1; then
        echo 'mcopy is required but not found. Please install mtools.'
    fi
    exit 1
fi

echo Creating disk image ...
dd if=/dev/zero of=disk.img bs=512 count=65536 > /dev/null 2>&1

echo Creating partition ...
fdisk disk.img > /dev/null 2>&1 << EOF
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

echo Creating filesystem ...
dd if=disk.img of=partition.img bs=512 skip=2048 > /dev/null 2>&1
case $type in
    1) mkfs.fat -F 12 partition.img > /dev/null 2>&1;;
    4|6|e) mkfs.fat -F 16 partition.img > /dev/null 2>&1;;
    b|c) mkfs.fat -F 32 partition.img > /dev/null 2>&1;;
    *) echo "Unsupported type $type"; exit 1 ;;
esac

echo Writing kernel ...
mcopy -i partition.img kernel.bin ::/KERNEL.BIN

echo Writing stage1 bootloader ...
dd if=stage1.bin of=disk.img bs=512 seek=0 conv=notrunc > /dev/null 2>&1
printf '\x55\xAA' | dd of=disk.img bs=1 seek=510 count=2 conv=notrunc > /dev/null 2>&1

echo Writing stage2 bootloader ...
dd if=stage2.bin of=disk.img bs=512 seek=1 conv=notrunc > /dev/null 2>&1

echo Combining partition with disk image ...
dd if=partition.img of=disk.img bs=512 seek=2048 conv=notrunc > /dev/null 2>&1

echo Done
