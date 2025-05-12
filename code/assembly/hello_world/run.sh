#!/bin/bash

# Assemble File
as -o hello_world.o --32 hello_world.s

# Link File
ld -o hello_world.bin --oformat binary -e init -Ttext 0x7c00 -m elf_i386 hello_world.o

# Run QEMU Emulation (For Testing) (Control A + X to terminate)
qemu-system-i386 -nographic hello_world.bin 