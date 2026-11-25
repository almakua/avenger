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

// frame with callee-saved x19..x28 pairs; size must be a multiple of 16
.macro FUNC_BEGIN name
    .globl \name
    .p2align 2
\name:
.endm
