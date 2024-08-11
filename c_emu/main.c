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

volatile CPUFlags* G_Flags;

void interrupt_handler(int signal) { G_Flags->interrupt = true; }

int program_loop(Instruction code[PROGMEM_SIZE], u8 memory[DATAMEM_SIZE]) {
    u8* registers = malloc(4);
    CPUFlags* flags = malloc(sizeof(CPUFlags));
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

        case Opcode_LDFL: OP_SHORT(registers[reg] = flags->flags)
        case Opcode_STFL: OP_SHORT(flags->flags = registers[reg])

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
                size);
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
                "Usage: %s CODE [MEMORY]\n"
                "Run CODE on emulated cpu, using MEMORY or all 0s as the "
                "starting memory\n",
                argv[0]);
        return 1;
    }

    Instruction* code_mem = read_memfile(argv[1], sizeof(Instruction), PROGMEM_SIZE);
    if (!code_mem) {
        return errno;
    }
    u8* data_mem = NULL;
    if (argc == 3) {
        data_mem = read_memfile(argv[2], sizeof(u8), DATAMEM_SIZE);
        if (!data_mem) {
            return errno;
        }
    } else {
        data_mem = malloc(DATAMEM_SIZE);
        if (!data_mem) {
            return errno;
        }
    }

    return program_loop(code_mem, data_mem);
}
