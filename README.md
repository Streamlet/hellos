# HellOS

`HellOS` stands for "Hello, OS!". As its name suggests, it is an OS for learning and practice.

![HelloOS](hellos.png)

## Getting Started

### Environment

* Shell:  Bash on Linux/WSL or MSYS2/MinGW on Windows
* Assemble: NASM
* C Compile: OpenWatcom (16-bit), GCC(32-bit)
* Disk Tools: `fdisk` (from util-linux), `mkfs.fat` (from dosfstools), `mcopy`(from mtools)
* VM: QEMU

### Steps

 1. Go to a target directory (e.g. `src/boot/hello`).
 2. Run `build.sh`. This will assemble the .asm files and compile any .c files, producing the necessary binary files (.bin, etc.).
 3. If `mkdisk.sh` exists, run it. This will create the virtual disk images (.img files) needed for booting.
 4. Run `run.sh`. This will start QEMU and boot the target Bootloader/OS.

Example using `src/boot/hello`:

```sh
cd src/boot/hello
./build.sh
./run.sh
```

## Roadmap

* Bootloader (MBR)
    * ✓ Print Hello 
    * ✓ Interactive Console (Echo, `shutdown`, `reboot`)
    * ✓ Two-stage loader
        * ✓ FAT driver (Read Only & Root Dir Only)
            * ✓ FAT 12
            * ✓ FAT 16
            * ✓ FAT 32
        * ✓ Load kernel file
        * ✓ Interactive Console
* 16-bit Real Mode:
    * ✓ Hello in C Language
    * ✓ Interactive Console in C Language
        * ✓ Override VGA Text Mode Driver (Replace int 10h)
        * ✓ Override PS/2 Keyboard Driver (Replace int 16h)
        * ✓ Override System & Power Services (Replace int 15h/19h)
    * File System Commands (`cat`, `echo >`, `touch`, `ls`, `cd`, `mkdir`, `rmdir`, `rm`, `cp`, `mv`)
        * Override Disk Driver (Replace int 13h)
        * FAT Driver (Read & Write)
    * External Command
        * Execute Flat Binary From Disk
        * Provide stdio.h — Run Classic C Exercises (printf, puts, file I/O)
        * Provide dos.h — Porting Tank War, My University C Course Project
* 16-bit Protected Mode
    * Hello in Ring 3
        * IO Interrupts
        * Memory Management
        * Process Context (Single Process)
        * Protected Mode API
    * Interactive Console in Ring 3
    * File System Commands in Ring 3
    * External Command in Ring 3
* 32-bit Protected Mode
    * Hello (32-bit)
        * Process with Memory Paging
    * Interactive Console (32-bit)
    * File System Commands (32-bit)
        * Cooperative Multitasking
        * Preemptive Multitasking
* 64-bit Long Mode
    * Hello (64-bit)
    * Interactive Console (64-bit)
    * File System Commands (64-bit)
    * External Command (64-bit)
    * UEFI Support
