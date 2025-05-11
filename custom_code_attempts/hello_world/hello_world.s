.code16

.global init

init: 
    mov $msg, %si # loads the first address of msg into si
    mov $0x0e, %ah # sets AH register to 0xe (function teletype)
print_char:
    lodsb # loads the byte from the address (in si) into al and increments si
    cmp $0, %al # compares content in AL with zero
    je done # if al == 0, go to "done"
    int $0x10 # prints next character in AL register to screen
    jmp print_char # repeat with next byte
done:
    hlt # Stops executing

msg: .asciz "Hello world!" # stores the string (plus a byte with value "0") and gives access via the $msg label

.fill 510-(.-init), 1, 0 # add zeros to make it 510 bytes long

.word 0xaa55 # mark as BIOS bootable