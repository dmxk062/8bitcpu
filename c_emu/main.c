#include "macros.h"
#include "types.h"
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/*
 * simulator for my non von neumann mc cpu
 */

#define PROGMEM_SIZE 256
#define DATAMEM_SIZE 256
#define CALLSTACK_SIZE 16

volatile CPUFlags* G_Flags;

void interrupt_handler(int signal) { G_Flags->interrupt = true; }

int program_loop(Instruction code[PROGMEM_SIZE], u8 memory[DATAMEM_SIZE]) {
    u8* registers = calloc(4, sizeof(u8));
    Callstack* stack = calloc(1, sizeof(Callstack));
    CPUFlags* flags = calloc(1, sizeof(CPUFlags));
    if (!memory || !registers || !flags) {
        return 1;
    }
    G_Flags = flags;
    // signal(SIGINT, interrupt_handler);

    bool did_jump = false;
    u8 program_pointer = 0;
    while (!flags->halt) {
        Instruction op = code[program_pointer];
        switch (op.opcode) {
            // clang-format off
        case Opcode_NOOP: OP_NONE()
        case Opcode_ST:   OP_LONG(memory[data] = registers[reg1])
        case Opcode_STR:  OP_DUAL(memory[registers[reg1]] = registers[reg2]);
        case Opcode_LD:   OP_LONG(registers[reg1] = memory[data]);
        case Opcode_LDR:  OP_DUAL(registers[reg1] = memory[registers[reg2]])
        case Opcode_LI:   OP_LONG(registers[reg1] = data);
        case Opcode_CP:   OP_DUAL(registers[reg1] = registers[reg2])

        case Opcode_CLC: OP_NONE(flags->carry = false);
        case Opcode_CLI: OP_NONE(flags->interrupt = false);
        case Opcode_CLN: OP_NONE(flags->negative = false);

        case Opcode_SUB: {
            u8 reg1 = op.reg1;
            u8 reg2 = op.Dual.reg2;

            u8 val1 = registers[reg1];
            u8 val2 = registers[reg2];

            i16 res = (i16)val1 - (i16)val2;
            bool negative = res < 0;
            flags->negative = negative;
            registers[reg1] = (negative ? -res : res);
            break;
        }
        case Opcode_SUBI: {
            u8 reg1 = op.reg1;
            u8 val2 = op.Long.data;

            u8 val1 = registers[reg1];

            i16 res = (i16)val1 - (i16)val2;
            bool negative = res < 0;

            flags->negative = negative;
            registers[reg1] = (negative ? -res : res);
            break;
        }
        case Opcode_ADD: {
            u8 reg1 = op.reg1;
            u8 reg2 = op.Dual.reg2;

            u8 val1 = registers[reg1];
            u8 val2 = registers[reg2];

            i16 res = (i16)val1 + (i16)val2;
            bool carry = res > 255;
            flags->carry = carry;
            registers[reg1] = (u8)res;
            break;
        }
        case Opcode_ADDI: {
            u8 reg1 = op.reg1;
            u8 val2 = op.Long.data;

            u8 val1 = registers[reg1];

            i16 res = (i16)val1 + (i16)val2;
            bool carry = res > 255;
            flags->carry = carry;
            registers[reg1] = (u8)res;
            break;
        }

        case Opcode_AND: OP_DUAL(registers[reg1] = (registers[reg1] & registers[reg2]))
        case Opcode_OR:  OP_DUAL(registers[reg1] = (registers[reg1] | registers[reg2]))
        case Opcode_XOR: OP_DUAL(registers[reg1] = (registers[reg1] ^ registers[reg2]))
        case Opcode_NOT: OP_SHORT(registers[reg] = ~registers[reg])
        case Opcode_SHL: OP_SHORT(registers[reg] = registers[reg] << 1)
        case Opcode_SHR: OP_SHORT(registers[reg] = registers[reg] >> 1)

        case Opcode_ANDI: OP_LONG(registers[reg1] = (registers[reg1] & data))
        case Opcode_ORI:  OP_LONG(registers[reg1] = (registers[reg1] | data))
        case Opcode_XORI: OP_LONG(registers[reg1] = (registers[reg1] ^ data))

        case Opcode_JMP: OP_DATA(JUMP(data));
        case Opcode_JIZ: OP_LONG(if (registers[reg1] == 0){JUMP(data)})
        case Opcode_JNZ: OP_LONG(if (registers[reg1] != 0){JUMP(data)})
        case Opcode_JIC: OP_DATA(if (flags->carry){JUMP(data)})
        case Opcode_JNC: OP_DATA(if (!flags->carry){JUMP(data)})
        case Opcode_JII: OP_DATA(if (flags->interrupt){JUMP(data)})
        case Opcode_JNI: OP_DATA(if (!flags->interrupt){JUMP(data)})

        case Opcode_LDPR: OP_SHORT(registers[reg] = program_pointer)
        case Opcode_LDFL: OP_SHORT(registers[reg] = flags->flags)
        case Opcode_STFL: OP_SHORT(flags->flags = registers[reg])

        case Opcode_CALL: {
            u8 address = op.Long.data;
            if (stack->index < CALLSTACK_SIZE) {
                stack->stack[stack->index++] = program_pointer;
            } else {
                for (int i = 1; i < CALLSTACK_SIZE; i++) {
                    stack->stack[i - 1] = stack->stack[i];
                }
                stack->stack[CALLSTACK_SIZE - 1] = program_pointer;
            }
            program_pointer = address;
            did_jump = true;
            break;
        }

        case Opcode_RET: {
            if (stack->index > 0) {
                program_pointer = stack->stack[--stack->index];
            }
            did_jump = false;
            break;
        }

        case Opcode_WR: OP_SHORT(putchar(registers[reg]));
        case Opcode_RD: OP_SHORT(registers[reg] = getchar())
            // clang-format on
        }
        if (!did_jump) {
            program_pointer++;
        } else {
            did_jump = false;
        }
    }
    free(flags);
    free(stack);
    free(registers);
    return 0;
}

void* read_memfile(char* path, size_t size, size_t n) {
    struct stat st;
    int err = stat(path, &st);
    if (err) {
        fprintf(stderr, "Failed to stat %s: %s\n", path, strerror(errno));
        return NULL;
    }
    if (!S_ISREG(st.st_mode)) {
        fprintf(stderr, "Not a regular file: %s\n", path);
        return NULL;
    }
    if (st.st_size > size * n) {
        fprintf(stderr, "%s: too large (%ld B > %zu B)", path, st.st_size,
                size * n);
    }

    FILE* fl = fopen(path, "r");
    if (!fl) {
        fprintf(stderr, "Failed to open %s: %s\n", path, strerror(errno));
        return NULL;
    }
    u8* memory = calloc(n, size);
    if (!memory) {
        fclose(fl);
        return NULL;
    }
    size_t ret = fread(memory, 1, st.st_size, fl);
    fclose(fl);
    return memory;
}

int main(int argc, char* argv[]) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr,
                "Usage: %s IMAGE\n"
                "Run IMAGE on emulated cpu\n",
                argv[0]);
        return 1;
    }

    u8* input = read_memfile(argv[1], sizeof(u8),
                             (PROGMEM_SIZE * sizeof(Instruction)) +
                                 (DATAMEM_SIZE * sizeof(u8)));
    if (!input) {
        return 1;
    }

    Instruction* code_mem = (Instruction*)input;
    u8* data_mem = input + (PROGMEM_SIZE * sizeof(Instruction));

    return program_loop(code_mem, data_mem);
}
