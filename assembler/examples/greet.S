.zstr question "Hi! What's your name? "
.byte newline 10
.byte exclam '!'

# take advantage of the fact that the strings will be adjacent
.nstr answer   "Nice to meet you "
.bytes buffer 128 0

start:
    li      r0,     question
    call    puts

    li      r0,     buffer
    call    reads

    li      r0,     answer
    call    puts
    ld      r0,     exclam
    wr      r0
    ld      r0,     newline
    wr      r0

    jmp     exit

puts:
    ldr     r1,     r0
    jiz     r1,     puts_done
    wr      r1
    addi    r0,     1
    jmp     puts
puts_done:
    ret

reads:
    cp      r1,     r0
reads_loop:
    rd      r0

    cp      r2,     r0
    subi    r2,     10
    jiz     r2,     reads_done

    cp      r2,     r1
    subi    r2,     127
    jiz     r2,     reads_done

    str     r1,     r0
    addi    r1,     1
    jmp     reads_loop
    
reads_done:
    addi    r1,     1
    li      r2,     0
    str     r1,     r2
    ret

exit:
    ldfl    r0
    ori     r0,     0b01000000
    stfl    r0
