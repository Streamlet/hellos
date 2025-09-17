# HellOS

`HellOS` stands for "Hello, OS!". As its name suggests, it is an OS for learning and practice.

## Roadmap

* 16-bit real mode:
    * Legacy BIOS
        * Bootloader OS (MBR)
            * ✓ Print Hello 
            * ✓ Process keyboard input (Echo, Reboot, Shutdown)
        * Disk OS demo
            * ✓ Two-stage loader
            * Use BIOS services
                * Print Hello
                * Process keyboard input
            * Override BIOS interrupts (no BIOS service dependency)
                * Print Hello
                * Process keyboard input
    * UEFI
        * Bootloader OS (EFI)
            * Print Hello
            * Process keyboard input (Echo, Reboot, Quit)
        * Disk OS demo
            * Use UEFI services
                * Print Hello
                * Process keyboard input
            * `ExitBootServices()`(no UEFI service dependency)
                * Print Hello
                * Process keyboard input
    * Disk OS (switch to C language)
        * Launched by both legacy BIOS and UEFI (no BIOS or UEFI service dependency)
            * Print Hello
            * Process keyboard input
        * Implement a file system 'driver'
        * Implement a simple shell
        * Implement Tetris game (0xB8000 text mode or 0xA0000 graphic mode)
* 16-bit protected mode
    * Print Hello in Ring 3
    * Process I/O interrupts
    * Implement system calls
    * Implement a file system driver
    * Implement a simple shell
    * Implement Tetris game
    * Multiple processes/threads
        * Cooperative Multitasking
        * Preemptive multitasking
* 32-bit protected mode
    * (almost same as in '16-bit protected mode', pay attention to memory paging)
* 64-bit long mode
    * (almost same as in '32-bit protected mode', pay attention to 32-bit compatibility mode)
