.zstr question "Hi! What's your name? "
.zstr ending "!\n"

# take advantage of the fact that the strings will be adjacent
.nstr answer   "Nice to meet you "
.bytes buffer 128 0 # not strictly necessary to 0 initialize, that's the default anyways

start:
    # display prompt
    li      r0,     question
    call    puts

    # read answer
    li      r0,     buffer
    call    reads

    # print answer + name
    li      r0,     answer
    call    puts

    # print exclamation mark and newline
    li      r0,     ending
    call    puts

    jmp     exit

# print characters given by the pointer in r0 until it encounters a null byte
puts:
    ldr     r1,     r0
    jiz     r1,     puts_done
    wr      r1
    addi    r0,     1
    jmp     puts
puts_done:
    ret

# read max. 127 characters into the buffer given in r0 and null terminate
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

# exit the program by setting the halt flag
exit:
    ldfl    r0
    ori     r0,     0b01000000
    stfl    r0
