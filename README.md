# HellOS

`HellOS` stands for "Hello, OS!". As its name suggests, it is an OS for learning and practice.

![HelloOS](hellos.png)

## Getting Started

### Environment

* Shell:  Bash on Linux/WSL or MSYS2/MinGW on Windows
* Assemble: NASM
* C Compile: GCC
* Disk Tools: `fdisk` (from util-linux), `mkfs.fat` (from dosfstools), `mcopy`(from mtools)
* VM: QEMU

### Steps

 1. Go to a target directory (e.g. `boot/hello`).
 2. Run `build.sh`. This will assemble the .asm files and compile any .c files, producing the necessary binary files (.bin, etc.).
 3. If `mkdisk.sh` exists, run it. This will create the virtual disk images (.img files) needed for booting.
 4. Run `run.sh`. This will start QEMU and boot the target Bootloader/OS.

Example using `boot/hello`:

```sh
cd boot/hello
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
    * Hello in C Language
    * Interactive Console in C Language
        * Override VGA Text Mode Driver (Replace int 10h)
        * Override PS/2 Keyboard Driver (Replace int 16h)
        * Override System & Power Services (Replace int 15h/19h)
        * Override Disk Driver (Replace int 13h)
    * Shell with File System Commands (`cat`, `echo >`, `touch`, `ls`, `cd`, `mkdir`, `rmdir`, `rm`, `cp`, `mv`)
        * FAT Driver (Read & Write)
* 16-bit Protected Mode
    * Hello in Ring 3
        * IO Interrupts
        * Memory Management
        * Process Context (Single Process)
        * System Call
    * Interactive Console in Ring 3
    * Shell with File System Commands in Ring 3
* 32-bit Protected Mode
    * Hello
        * Process with Memory Paging
    * Interactive Console in Ring 3
    * Shell with File System Commands in Ring 3
    * Shell with External Command
        * Cooperative Multitasking
        * Preemptive Multitasking
* 64-bit Long Mode
    * Hello
    * Interactive Console in Ring 3
    * Shell with File System Commands in Ring 3
    * Shell with External Command
    * UEFI Support
