#define OP_NONE(code)                                                          \
    {                                                                          \
        code;                                                                  \
        break;                                                                 \
    }
#define OP_SHORT(code)                                                         \
    {                                                                          \
        u8 reg = op.reg1;                                                      \
        code;                                                                  \
        break;                                                                 \
    }
#define OP_DUAL(code)                                                          \
    {                                                                          \
        u8 reg1 = op.reg1;                                                     \
        u8 reg2 = op.Dual.reg2;                                                \
        code;                                                                  \
        break;                                                                 \
    }
#define OP_LONG(code)                                                          \
    {                                                                          \
        u8 reg1 = op.reg1;                                                     \
        u8 data = op.Long.data;                                                \
        code;                                                                  \
        break;                                                                 \
    }

#define OP_DATA(code)                                                          \
    {                                                                          \
        u8 data = op.Long.data;                                                \
        code;                                                                  \
        break;                                                                 \
    }

#define JUMP(_addr)                                                            \
    {                                                                          \
        ProgramPointer = _addr;                                                \
        did_jump = true;                                                       \
        break;                                                                 \
    }
