#include "types.h"
#include "macros.h"
#include <stdbool.h>
#include <stdio.h>
#include <signal.h>

/*
 * simulator for my non von neumann mc cpu
 */

#define PROGMEM_SIZE 256
#define DATAMEM_SIZE 256

u8 Datamem[DATAMEM_SIZE] = {};
// can change on SIGINT
volatile CPUFlags Flags = {};
u8 ProgramPointer = 0;
u8 Registers[4] = {0};

Instruction Progmem[PROGMEM_SIZE] = {
    {Opcode_LI, 1, 0},
    // reading loop : 1
    {Opcode_RD, 0},
    {Opcode_STR, 1, 0},
    {Opcode_ADDI, 1, 1},

    // newline?
    {Opcode_CP, 2, 0},
    {Opcode_SUBI, 2, '\n'},
    {Opcode_JNZ, 2, 1},

    // {Opcode_ADDI, 1, '0'},
    // {Opcode_WR, 1},
    // {Opcode_LI, 0, 0b01000000},
    // {Opcode_STFL, 0},

    // start printing loop
    {Opcode_LI, 0, 0},  // i = 0
    {Opcode_LDR, 2, 0}, // letter = *i
    {Opcode_WR, 2},     // write(letter)
    {Opcode_CP, 3, 1},  // code = l
    {Opcode_ADDI, 0, 1},// i++
    {Opcode_SUB, 3, 0}, // code = code - i
    {Opcode_JII, 0, 16},// if interrupt goto exit
    {Opcode_JNZ, 3, 8}, // if c != 0 goto start
    {Opcode_JMP, 0,7},

    // exit / halt
    {Opcode_LI, 0, 0b01000000},
    {Opcode_STFL, 0},
};

void interrupt_handler(int signal) {
    Flags.interrupt = true;
}

int main(int argc, char* argv[]) {
    signal(SIGINT, interrupt_handler);
    bool did_jump = false;

    while (!Flags.halt) {
        Instruction op = Progmem[ProgramPointer];
        switch (op.opcode) {
            // clang-format off
        case Opcode_NOOP: OP_NONE()
        case Opcode_ST: OP_LONG(Datamem[data] = Registers[reg1])
        case Opcode_STR: OP_DUAL(Datamem[Registers[reg1]] = Registers[reg2]);
        case Opcode_LD: OP_LONG(Registers[reg1] = Datamem[data]);
        case Opcode_LDR: OP_DUAL(Registers[reg1] = Datamem[Registers[reg2]])
        case Opcode_LI: OP_LONG(Registers[reg1] = data);
        case Opcode_CP: OP_DUAL(Registers[reg1] = Registers[reg2])

        case Opcode_CLC: OP_NONE(Flags.carry = false);
        case Opcode_CLI: OP_NONE(Flags.interrupt = false);
        case Opcode_CLN: OP_NONE(Flags.negative = false);

        case Opcode_SUB: {
            u8 reg1 = op.reg1;
            u8 reg2 = op.Dual.reg2;

            u8 val1 = Registers[reg1];
            u8 val2 = Registers[reg2];

            i16 res = (i16)val1 - (i16)val2;
            bool negative = res < 0;
            Flags.negative = negative;
            Registers[reg1] = (negative ? -res : res);
            break;
        }
        case Opcode_SUBI: {
            u8 reg1 = op.reg1;
            u8 val2 = op.Long.data;

            u8 val1 = Registers[reg1];

            i16 res = (i16)val1 - (i16)val2;
            bool negative = res < 0;

            Flags.negative = negative;
            Registers[reg1] = (negative ? -res : res);
            break;
        }
        case Opcode_ADD: {
            u8 reg1 = op.reg1;
            u8 reg2 = op.Dual.reg2;

            u8 val1 = Registers[reg1];
            u8 val2 = Registers[reg2];

            i16 res = (i16)val1 + (i16)val2;
            bool carry = res > 255;
            Flags.carry = carry;
            Registers[reg1] = (u8)res;
            break;
        }
        case Opcode_ADDI: {
            u8 reg1 = op.reg1;
            u8 val2 = op.Long.data;

            u8 val1 = Registers[reg1];

            i16 res = (i16)val1 + (i16)val2;
            bool carry = res > 255;
            Flags.carry = carry;
            Registers[reg1] = (u8)res;
            break;
        }

        case Opcode_AND: OP_DUAL(Registers[reg1] = (Registers[reg1] & Registers[reg2]))
        case Opcode_OR: OP_DUAL(Registers[reg1] = (Registers[reg1] | Registers[reg2]))
        case Opcode_XOR: OP_DUAL(Registers[reg1] = (Registers[reg1] ^ Registers[reg2]))
        case Opcode_NOT: OP_SHORT(Registers[reg] = ~Registers[reg])
        case Opcode_SHL: OP_SHORT(Registers[reg] = Registers[reg] << 1)
        case Opcode_SHR: OP_SHORT(Registers[reg] = Registers[reg] >> 1)

        case Opcode_ANDI: OP_LONG(Registers[reg1] = (Registers[reg1] & data))
        case Opcode_ORI: OP_LONG(Registers[reg1] = (Registers[reg1] | data))
        case Opcode_XORI: OP_LONG(Registers[reg1] = (Registers[reg1] ^ data))

        case Opcode_JMP: OP_DATA(JUMP(data));
        case Opcode_JIZ: OP_LONG(if (Registers[reg1] == 0){JUMP(data)});
        case Opcode_JNZ: OP_LONG(if (Registers[reg1] != 0){JUMP(data)});
        case Opcode_JIC: OP_DATA(if (Flags.carry){JUMP(data)});
        case Opcode_JNC: OP_DATA(if (!Flags.carry){JUMP(data)});
        case Opcode_JII: OP_DATA(if (Flags.interrupt){JUMP(data)});
        case Opcode_JNI: OP_DATA(if (!Flags.interrupt){JUMP(data)});

        case Opcode_LDFL: OP_SHORT(Registers[reg] = Flags.flags)
        case Opcode_STFL: OP_SHORT(Flags.flags = Registers[reg])

        case Opcode_WR: OP_SHORT(putchar(Registers[reg]));
        case Opcode_RD: OP_SHORT(Registers[reg] = getchar());
            // clang-format on
        }
        if (!did_jump) {
            ProgramPointer++;
        } else {
            did_jump = false;
        }
    }
}
