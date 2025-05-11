.code16

.global init

init: 
    mov $0x0e41, %ax # set AH register to 0xe (function teletype) and AL register to 0x41 (ASCII "A") 
    int $0x10 # call function in AH from interrupt 0x10
    hlt # Stops executing

.fill 510-(.-init), 1, 0 # add zeros to make it 510 bytes long

.word 0xaa55 # mark as BIOS bootable