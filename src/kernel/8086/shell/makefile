ASM = nasm
CC = wcc
CFLAGS = -0 -s -os -d0 -ecc -ms -zastd=c99
LD = wlink
LDFLAGS = format raw bin name kernel.bin option nodefaultlibs option eliminate option offset=0x77C00 option start=_start

# FAT12: 1
# FAT16: 4, 6, e
# FAT32: b, c
FS ?= b

QEMU := $(shell \
	command -v qemu-system-i386 2>/dev/null || \
	command -v qemu-system-i386.exe 2>/dev/null || \
	echo "qemu-system-i386")

C_SRCS = kernel.c int.c keyboard.c power.c timer.c vga.c
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
	printf "n\np\n1\n2048\n65535\na\nt\n$(FS)\nw\n" | fdisk disk.img > /dev/null 2>&1

	echo Creating filesystem ...
	dd if=disk.img of=partition.img bs=512 skip=2048 > /dev/null 2>&1
	case $(FS) in \
		1) mkfs.fat -F 12 partition.img > /dev/null 2>&1;; \
		4|6|e) mkfs.fat -F 16 partition.img > /dev/null 2>&1;; \
		b|c) mkfs.fat -F 32 partition.img > /dev/null 2>&1;; \
		*) echo "Unsupported type $(FS)"; exit 1 ;; \
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

run:
	"$(QEMU)" -drive format=raw,file=disk.img
