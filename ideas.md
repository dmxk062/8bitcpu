# ISA

- Non von Neumann architecture
- 2^8 * 16 bit words for instructions: 256 instructions 
- 2^8 * 8 bit words for data: 256 bytes of memory
- 16 * 16 bit hardware call stack(not accessible)
- 4 general purpose registers
- 2 special, not directly accessible registers
- program code accessible via special instructions and flag in flags register

# Registers

#### `r0`, `r1`, `r2`, `r3` - General Purpose

#### Coding:

`r0`: `0`  
`r1`: `1`  
`r2`: `2`  
`r3`: `3`  

#### `rf` - Flags

Not directly accessible, use `ldfl` and `stfl` to access

```
00000000
PH---NIC
```

| Bit       | Meaning           
|-          |-      
| C         | Carry
| I         | Hardare interrupt
| N         | Result was negative
|           | 
|           |  
|           | 
| H         | Halt, stop the CPU. Requires hardware power cycle to unset
| P         | Program address low/high byte addressing switch
#### `rp` - Program Pointer

Not directly accessible, use `ldpr` to access


## Instruction coding

#### `short`: no arguments, only register

```
xxxxxx   xx   00000000
+----+   ++   +------+
  OP     REG    NULL
```
#### `dual`: uses last two bits of second word for target register
```
xxxxxx   xx   000000   XX
+----+   ++   +----+   ++
  OP    REG1   NULL   REG2
```
#### `long`: second word is argument
```
xxxxxx   xx   XXXXXXXX
+----+   ++   +------+
  OP    REG1    ARG
```

# Instructions

#### Argument types:
- `addr`: Immediate working memory address
- `paddr`: Immediate address in program memory
- `byte`: Immediate value


| Mnemonic      |Type   | Argument      | Coding    | Name                  | Description
|-              |-      |-              |-          |-                      |-
| `noop`        |short  | -             | `0o00`    | No operation          | Do nothing
| `st[r]`       |long   | `addr`        | `0o01`    | Store                 | Store `byte` from `r` into `addr`
| `str[r1][r2]` |dual   | -             | `0o02`    | Store register        | Store `r2` into the address in `r1`
| `ld[r]`       |long   | `addr`        | `0o03`    | Load                  | Load `byte` from `addr` into `r`
| `ldr[r1][r2]` |dual   | -             | `0o04`    | Load register         | Load `byte` addressed by `r2` into `r1`
| `li[r]`       |long   | `byte`        | `0o05`    | Load immediate        | Load `byte` into `r`
| `cp[r1][r2]`  |dual   | -             | `0o06`    | Copy                  | Copy bytes from `r2` into `r1`
| `sub[r1][r2]` |dual   | -             | `0o10`    | Subtract              | Subtract value in `r2` from `r1`
| `add[r1][r2]` |dual   | -             | `0o11`    | Add                   | Add value in `r2` to `r1`
| `subi[r]`     |long   | `byte`        | `0o12`    | Subtract immediate    | Subtract `byte` from value in `r`
| `addi[r]`     |long   | `byte`        | `0o13`    | Add immediate         | Add `byte` to value in `r`
| `clc`         |short  | -             | `0o14`    | Clear carry           | Clear carry bit
| `cli`         |short  | -             | `0o15`    | Clear interrupt       | Clear interrupt bit
| `cln`         |short  | -             | `0o15`    | Clear negative        | Clear negative bit
| `and[r1][r2]` |dual   | -             | `0o20`    | And                   | Logical and of `r1` and `r2` to `r1`
| `or[r1][r2]`  |dual   | -             | `0o21`    | Or                    | Logical or of `r1` and `r2` to `r1`
| `xor[r1][r2]` |dual   | -             | `0o22`    | Xor                   | Logical xor of `r1` and `r2` to `r1`
| `not[r]`      |short  | -             | `0o23`    | Not                   | Logical not of `r`
| `shl[r]`      |short  | -             | `0o24`    | Shift left            | Shift `r` left by one bit
| `shr[r]`      |short  | -             | `0o25`    | Shift right           | Shift `r` right by one bit
| `andi[r]`     |long   | `byte`        | `0o30`    | And immediate         | Logical and of `r` and `byte` to `r`
| `ori[r]`      |long   | `byte`        | `0o31`    | Or immediate          | Logical or of `r` and `byte` to `r`
| `xori[r]`     |long   | `byte`        | `0o32`    | Xor immediate         | Logical xor of `r` and `byte` to `r`
| `jmp`         |long   | `paddr`       | `0o40`    | Jump                  | Set execution to `paddr`
| `jiz[r]`      |long   | `paddr`       | `0o41`    | Jump if zero          | Set execution to `paddr` if `r` is 0
| `jnz[r]`      |long   | `paddr`       | `0o42`    | Jump if not zero      | Set execution to `paddr` if `r` is not 0
| `jic`         |long   | `paddr`       | `0o43`    | Jump if carry         | Set execution to `paddr` if `C` is set
| `jnc`         |long   | `paddr`       | `0o44`    | Jump if not carry     | Set execution to `paddr` if `C` is not set
| `jii`         |long   | `paddr`       | `0o45`    | Jump if interrupt     | Set execution to `paddr` if `I` is set
| `jni`         |long   | `paddr`       | `0o46`    | Jump if not interrupt | Set execution to `paddr` if `I` is not set
| `jmr[r]`      |short  | -             | `0o47`    | Jump to register      | Set execution to `paddr` inside `r`
| `ldpr[r]`     |short  | -             | `0o50`    | Load program pointer  | Store `rp` into `r`
| `ldfl[r]`     |short  | -             | `0o51`    | Load flags register   | Store `rf` into `r`
| `stfl[r]`     |short  | -             | `0o52`    | Set flags register    | Set `rf` to the value in `r`
| `ldin[r1][r2]`|short  | `paddr`       | `0o53`    | Load instruction      | Load instruction in `r2` + `P` into `r[1]`
| `stin[r1][r2]`|short  | `paddr`       | `0o54`    | Store instruction     | Store instruction in `r2` to `r[1]` + `P`
| `call`        |long   | `paddr`       | `0o61`    | Call subroutine       | Call subroutine at `paddr`
| `ret`         |short  | -             | `0o62`    | Return from subroutine| Return from subroutine
| `wr[r]`       |short  | -             | `0o71`    | Write                 | Write contents of `r` to IO port
| `rd[r]`       |short  | -             | `0o72`    | Read                  | Read from IO port into `r`


> Note: all arithmetic operations are unsigned  
> They set carry if the result is larger than 8 bits  
> If the result is negative, the absolute value is loaded and the negative bit is set
