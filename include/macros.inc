// generic helpers

// address of a local/global symbol into reg
.macro LADDR reg, sym
    adrp \reg, \sym@PAGE
    add \reg, \reg, \sym@PAGEOFF
.endm

// load 64-bit value stored at sym
.macro LDRG reg, sym
    adrp \reg, \sym@PAGE
    ldr \reg, [\reg, \sym@PAGEOFF]
.endm

// store 64-bit reg to sym, clobbers tmp
.macro STRG reg, sym, tmp
    adrp \tmp, \sym@PAGE
    str \reg, [\tmp, \sym@PAGEOFF]
.endm

// exported, 4-byte aligned function label
.macro FUNC_BEGIN name
    .globl \name
    .p2align 2
\name:
.endm

// load double stored at sym, clobbers x16
.macro LDRD dreg, sym
    adrp x16, \sym@PAGE
    ldr \dreg, [x16, \sym@PAGEOFF]
.endm
