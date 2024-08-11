; print string from memory (file)
; to run:
; - assemble as usual
; - run with interpreter giving it a file with a string in it as an argument
start:
    li      r1,     0
loop:
    ldr     r0,     r1
    jiz     r0,     exit
    wr      r0
    addi    r1,	    1
    jmp     loop
exit:
    li      r3,     0b01000000
    stfl    r3
