ASM = nasm
CC = wcc
CFLAGS = -0 -s -os -d0 -ecc -ms -zastd=c99
LD = wlink
LDFLAGS = format raw bin name kernel.bin option nodefaultlibs option eliminate option offset=0x9C000 option start=_start

# FAT12: 1
# FAT16: 4, 6, e
# FAT32: b, c
FS ?= b

QEMU := $(shell \
	command -v qemu-system-i386 2>/dev/null || \
	command -v qemu-system-i386.exe 2>/dev/null || \
	echo "qemu-system-i386")

C_SRCS = kernel.c heap.c ide.c int.c keyboard.c mm.c power.c timer.c vga.c
C_OBJS = $(C_SRCS:.c=.obj)

ASM_SRCS = bootstrap.asm
ASM_OBJS = $(ASM_SRCS:.asm=.obj)

.SILENT:

all: stage1.bin stage2.bin kernel.bin

kernel.bin: $(ASM_OBJS) $(C_OBJS)
	$(LD) $(LDFLAGS) file $(shell echo $(ASM_OBJS) $(C_OBJS) | tr ' ' ',') >/dev/null

%.obj: %.c
	$(CC) $(CFLAGS) -fo=$@ $< >/dev/null

%.obj: %.asm
	$(ASM) -f obj $< -o $@ >/dev/null

%.bin: ../../../boot/two-stage/%.asm
	$(ASM) -f bin -i $(dir $<) $< -o $@ >/dev/null

clean:
	rm -f *.bin *.obj *.img


disk:
	echo Creating disk image ...
	dd if=/dev/zero of=disk.img bs=512 count=65536 > /dev/null 2>&1

	echo Creating partition ...
	printf "n\np\n1\n2048\n32768\na\nt\nc\nn\ne\n2\n34816\n49152\nn\nl\n36864\n49152\nt\n5\ne\nn\np\n3\n51200\n65535\nt\n3\n1\nw\n" | fdisk disk.img > /dev/null 2>&1

	echo Creating filesystem ...
	dd if=disk.img of=partition1.img bs=512 skip=2048 count=30720 > /dev/null 2>&1
	mkfs.fat -F 32 partition1.img > /dev/null 2>&1
	dd if=disk.img of=partition2.img bs=512 skip=36864 count=12288 > /dev/null 2>&1
	mkfs.fat -F 16 partition2.img > /dev/null 2>&1
	dd if=disk.img of=partition3.img bs=512 skip=51200 count=14304 > /dev/null 2>&1
	mkfs.fat -F 12 partition3.img > /dev/null 2>&1

	echo Writing files ...
	mcopy -o -i partition1.img kernel.bin ::/KERNEL.BIN

	echo Writing stage1 bootloader ...
	dd if=stage1.bin of=disk.img bs=512 seek=0 conv=notrunc > /dev/null 2>&1
	printf '\x55\xAA' | dd of=disk.img bs=1 seek=510 count=2 conv=notrunc > /dev/null 2>&1

	echo Writing stage2 bootloader ...
	dd if=stage2.bin of=disk.img bs=512 seek=1 conv=notrunc > /dev/null 2>&1

	echo Combining partition with disk image ...
	dd if=partition1.img of=disk.img bs=512 seek=2048 conv=notrunc > /dev/null 2>&1
	dd if=partition2.img of=disk.img bs=512 seek=36864 conv=notrunc > /dev/null 2>&1
	dd if=partition3.img of=disk.img bs=512 seek=51200 conv=notrunc > /dev/null 2>&1

	echo Done

run:
	"$(QEMU)" -drive format=raw,file=disk.img
