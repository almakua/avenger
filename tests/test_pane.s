// pane trees: split, layout, neighbours, resize, divider hits, remove

.include "macros.inc"
.include "pane.inc"
.include "harness.inc"

// x0 == reg
.macro IS id, reg
    cmp x0, \reg
    cset x0, eq
    CHECK \id, 1
.endm

// integer part of the double at [reg, #off]
.macro FIELD id, reg, off, expected
    ldr d0, [\reg, #\off]
    fcvtzs x0, d0
    CHECK \id, \expected
.endm

.macro LAYOUT
    LDRG x0, _troot
    movi d0, #0
    movi d1, #0
    mov x9, #201
    ucvtf d2, x9
    mov x9, #100
    ucvtf d3, x9
    bl _av_pane_layout
.endm

.macro NEIGHBOR id, from, dir, want
    LDRG x0, _troot
    mov x1, \from
    mov x2, #\dir
    bl _av_pane_neighbor
    IS \id, \want
.endm

    .zerofill __DATA,__bss,_troot,8,3

    .section __TEXT,__const
    .p2align 3
Ld_100_5: .double 100.5
Ld_50_5:  .double 50.5
Ld_9_9:   .double 9.9

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]

    mov x0, #PK_EDITOR
    mov x1, #1
    mov x2, #2
    mov x3, #3
    bl _av_pane_leaf
    mov x19, x0
    ldr x0, [x19, #P_DOC]
    CHECK 1, 3
    STRG x19, _troot, x9
    mov x0, #PK_TERMINAL
    mov x1, #4
    mov x2, #5
    mov x3, #0
    bl _av_pane_leaf
    mov x20, x0
    mov x0, #PK_EDITOR
    mov x1, #6
    mov x2, #7
    mov x3, #0
    bl _av_pane_leaf
    mov x21, x0

    // A | B, then B over C
    LADDR x0, _troot
    mov x1, x19
    mov x2, x20
    mov x3, #PK_ROW
    bl _av_pane_split
    mov x22, x0
    LDRG x0, _troot
    IS 2, x22
    ldr x0, [x19, #P_PARENT]
    IS 3, x22
    ldr x0, [x22, #P_KIND]
    CHECK 4, PK_ROW
    LAYOUT
    FIELD 5, x19, P_W, 100
    FIELD 6, x20, P_X, 101
    FIELD 7, x20, P_W, 100
    LADDR x0, _troot
    mov x1, x20
    mov x2, x21
    mov x3, #PK_COL
    bl _av_pane_split
    mov x23, x0
    ldr x0, [x22, #P_B]
    IS 8, x23
    LAYOUT
    FIELD 9, x20, P_H, 50
    FIELD 10, x21, P_Y, 51
    FIELD 11, x21, P_H, 49
    FIELD 12, x21, P_X, 101

    NEIGHBOR 20, x19, DIR_RIGHT, x20
    NEIGHBOR 21, x21, DIR_LEFT, x19
    NEIGHBOR 22, x20, DIR_DOWN, x21
    NEIGHBOR 23, x21, DIR_UP, x20
    NEIGHBOR 24, x19, DIR_LEFT, xzr
    NEIGHBOR 25, x20, DIR_RIGHT, xzr
    NEIGHBOR 26, x19, DIR_UP, xzr

    LDRG x0, _troot
    mov x1, x19
    bl _av_pane_next
    IS 30, x20
    LDRG x0, _troot
    mov x1, x20
    bl _av_pane_next
    IS 31, x21
    LDRG x0, _troot
    mov x1, x21
    bl _av_pane_next
    IS 32, x19
    LDRG x0, _troot
    bl _av_pane_last
    IS 33, x21

    LDRG x0, _troot
    LDRD d0, Ld_100_5
    fmov d1, #20.0
    fmov d2, #3.0
    bl _av_pane_divider_at
    IS 40, x22
    LDRG x0, _troot
    LDRD d1, Ld_50_5
    fmov d0, #31.0
    fmov d2, #5.0
    fmul d0, d0, d2
    fmov d2, #3.0
    bl _av_pane_divider_at
    IS 41, x23
    LDRG x0, _troot
    fmov d0, #20.0
    fmov d1, #20.0
    fmov d2, #3.0
    bl _av_pane_divider_at
    IS 42, xzr

    // moving the root divider 20 points right on a 200 point split
    mov x0, x19
    mov x1, #DIR_RIGHT
    fmov d0, #20.0
    bl _av_pane_resize
    CHECK 50, 1
    LAYOUT
    FIELD 51, x19, P_W, 120
    FIELD 52, x20, P_W, 80
    mov x0, x19
    mov x1, #DIR_UP
    fmov d0, #10.0
    bl _av_pane_resize
    CHECK 53, 0
    mov x0, x21
    mov x1, #DIR_UP
    LDRD d0, Ld_9_9
    bl _av_pane_resize
    CHECK 54, 1
    LAYOUT
    FIELD 55, x20, P_H, 40
    // clamped to a tenth
    mov x0, x20
    mov x1, #DIR_LEFT
    fmov d0, #31.0
    fmov d1, #31.0
    fmul d0, d0, d1
    bl _av_pane_resize
    LAYOUT
    FIELD 56, x19, P_W, 20
    mov x0, x22
    LDRD d0, Ld_100_5
    movi d1, #0
    bl _av_pane_drag
    CHECK 57, 1
    LAYOUT
    FIELD 58, x19, P_W, 100

    // removing B leaves A | C, then C alone, then nothing
    LADDR x0, _troot
    mov x1, x20
    bl _av_pane_remove
    IS 60, x21
    LDRG x0, _troot
    IS 61, x22
    ldr x0, [x22, #P_B]
    IS 62, x21
    ldr x0, [x21, #P_PARENT]
    IS 63, x22
    LADDR x0, _troot
    mov x1, x19
    bl _av_pane_remove
    IS 64, x21
    LDRG x0, _troot
    IS 65, x21
    ldr x0, [x21, #P_PARENT]
    CHECK 66, 0
    // removing the right child picks the last leaf of its sibling
    mov x0, #PK_EDITOR
    mov x1, #8
    mov x2, #9
    mov x3, #0
    bl _av_pane_leaf
    mov x20, x0
    LADDR x0, _troot
    mov x1, x21
    mov x2, x20
    mov x3, #PK_COL
    bl _av_pane_split
    LADDR x0, _troot
    mov x1, x20
    bl _av_pane_remove
    IS 67, x21
    LADDR x0, _troot
    mov x1, x21
    bl _av_pane_remove
    CHECK 68, 0
    LDRG x0, _troot
    CHECK 69, 0

    // freed nodes come back zeroed
    bl _av_pane_new
    IS 70, x21
    ldr x0, [x21, #P_KIND]
    CHECK 71, 0

    bl Lsummary
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
