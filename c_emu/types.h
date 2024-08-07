#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef uint8_t u8;
typedef int8_t i8;
typedef uint16_t u16;
typedef int16_t i16;

enum Opcodes {
    Opcode_NOOP = 000,
    Opcode_ST = 001,
    Opcode_STR = 002,
    Opcode_LD = 003,
    Opcode_LDR = 004,
    Opcode_LI = 005,
    Opcode_CP = 006,

    Opcode_SUB = 010,
    Opcode_ADD = 011,
    Opcode_SUBI = 012,
    Opcode_ADDI = 013,
    Opcode_CLC = 014,
    Opcode_CLI = 015,
    Opcode_CLN = 016,

    Opcode_AND = 020,
    Opcode_OR = 021,
    Opcode_XOR = 022,
    Opcode_NOT = 023,
    Opcode_SHL = 024,
    Opcode_SHR = 025,

    Opcode_ANDI = 030,
    Opcode_ORI = 031,
    Opcode_XORI = 032,

    Opcode_JMP = 040,
    Opcode_JIZ = 041,
    Opcode_JNZ = 042,
    Opcode_JIC = 043,
    Opcode_JNC = 044,
    Opcode_JII = 045,
    Opcode_JNI = 046,

    // Opcode_LDPR = 050,
    Opcode_LDFL = 051,
    Opcode_STFL = 052,

    Opcode_RD   = 071,
    Opcode_WR   = 072,
};

typedef union {
    struct {
        enum Opcodes opcode : 6;
        u8 reg1 : 2;
        union {
            struct {
                u8 unused;
            } Short;
            struct {
                u8 unused : 6;
                u8 reg2 : 2;
            } Dual;
            struct {
                u8 data;
            } Long;
        };
    };
    u8 high;
    u8 low;
} Instruction;

typedef union {
    struct {
        bool carry : 1;
        bool interrupt : 1;
        bool negative : 1;
        u8 : 3;
        bool halt : 1;
        bool low_high : 1;
    };
    u8 flags;
} CPUFlags;
