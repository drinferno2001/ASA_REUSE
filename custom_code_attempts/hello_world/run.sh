#!/bin/bash

# Assemble File
as -o hello_world.o --32 hello_world.s

# Link File
ld -o hello_world.bin -e init -m elf_i386 hello_world.o