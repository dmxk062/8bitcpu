.zstr hello "Hello World!\n"
.zstr goodbye "Goodbye World!\n"
start:
    li      r0,     hello
    call    puts
    li      r0,     goodbye
    call    puts
puts:
    ldr     r1,     r0
    jiz     r1,     puts_done
    wr      r1
    addi    r0,     1
    jmp     puts
puts_done:
    ret

exit:
    ldfl    r0
    ori     r0,     0b01000000
    stfl    r0
