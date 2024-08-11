.zstr msg "Hello World!\n"
.bytes buffer 8 'H', 'i', 10, 0
start:
    li      r1, buffer
    jmp     print
exit:
    li      r0, 0b01000000
    stfl    r0
print:
    ldr     r0, r1
    jiz     r0, exit
    wr      r0
    addi    r1, 1
    jmp     print
