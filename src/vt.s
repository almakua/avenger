// vt: VT100/xterm subset emulator (cursor, erase, SGR, scroll regions, alt screen), no AppKit
// rows leaving the top of the main screen go to a scrollback ring that hands back recycled rows

.include "macros.inc"
.include "vt.inc"

.set S_GROUND,    0
.set S_ESC,       1
.set S_ESC_INTER, 2
.set S_CSI,       3
.set S_OSC,       4            // states from here on swallow printable bytes
.set S_OSC_ESC,   5
.set S_DCS,       6
.set S_DCS_ESC,   7

// cursor and charset state kept by DECSC/DECRC
.set M_SAVED, M_ORIGIN | M_G0GFX | M_G1GFX | M_SHIFTOUT

    .section __TEXT,__const
    .p2align 1
    // DEC special graphics for 0x5f..0x7e
Ldec_gfx:
    .short 0x0020, 0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a, 0x00b0
    .short 0x00b1, 0x2424, 0x240b, 0x2518, 0x2510, 0x250c, 0x2514, 0x253c
    .short 0x23ba, 0x23bb, 0x2500, 0x23bc, 0x23bd, 0x251c, 0x2524, 0x2534
    .short 0x252c, 0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3, 0x00b7
    // SGR 1..9 -> attribute bit, 0 for codes without one
Lsgr_bits:
    .byte AB_BOLD, AB_DIM, AB_ITALIC, AB_UNDER, AB_BLINK, 0, AB_REVERSE, AB_HIDDEN, AB_STRIKE

    .section __TEXT,__cstring,cstring_literals
Lr_da:   .asciz "\033[?1;2c"
Lr_da2:  .asciz "\033[>0;10;1c"
Lr_ok:   .asciz "\033[0n"
Lr_csi:  .asciz "\033["
Lr_size: .asciz "\033[8;"
Lr_semi: .asciz ";"
Lr_R:    .asciz "R"
Lr_t:    .asciz "t"

// dst = row y of the active screen
.macro ROW dst, vt, y
    ldr \dst, [\vt, #VT_MAP]
    ldr \dst, [\dst, \y, lsl #3]
.endm

// dst = erased cell: only the current background survives, like xterm
.macro BLANK dst, vt
    ldr \dst, [\vt, #VT_PEN]
    and \dst, \dst, #0xffff000000000000
.endm

.macro NOWRAP vt, tmp
    ldr \tmp, [\vt, #VT_MODE]
    and \tmp, \tmp, #~M_WRAPNEXT
    str \tmp, [\vt, #VT_MODE]
.endm

// wdst = CSI parameter i, def when missing or zero; needs x19 = vt, clobbers w9
.macro PARAM wdst, i, def
    ldr \wdst, [x19, #(VT_PARAMS + 4 * \i)]
    cmp \wdst, #0
    mov w9, #\def
    csel \wdst, w9, \wdst, eq
.endm

    .text
// Vt *av_vt_new(void), 24x80 until resized, NULL on failure
FUNC_BEGIN _av_vt_new
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    ldr x0, =VT_ALLOC
    bl _av_pages_alloc
    cbz x0, 9f
    mov x19, x0
    // main and alt maps are contiguous: their rows are the first pool rows
    add x9, x19, #VT_POOL
    add x10, x19, #VT_MAP_MAIN
    mov x11, #0
1:  str x9, [x10, x11, lsl #3]
    add x9, x9, #VT_ROWB
    add x11, x11, #1
    cmp x11, #(2 * VT_MAXROWS)
    b.lo 1b
    str x11, [x19, #VT_POOLN]
    mov x9, #24
    mov x10, #80
    stp x9, x10, [x19, #VT_ROWS]
    mov x0, x19
    bl Lreset
    mov x0, x19
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_vt_free(Vt *vt)
FUNC_BEGIN _av_vt_free
    ldr x1, =VT_ALLOC
    b _av_pages_free

// void reset(Vt *vt): RIS, scrollback and title survive
    .p2align 2
Lreset:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    str xzr, [x19, #VT_PEN]
    mov x9, #(M_AUTOWRAP | M_CURSOR)
    str x9, [x19, #VT_MODE]
    add x9, x19, #VT_MAP_MAIN
    str x9, [x19, #VT_MAP]
    stp xzr, xzr, [x19, #VT_CX]
    stp xzr, xzr, [x19, #VT_SAVE_X]
    stp xzr, xzr, [x19, #VT_SAVE_PEN]
    str xzr, [x19, #VT_STATE]
    str xzr, [x19, #VT_TOP]
    ldr x9, [x19, #VT_ROWS]
    sub x9, x9, #1
    str x9, [x19, #VT_BOT]
    mov x0, x19
    mov x1, #0
    ldr x2, [x19, #VT_ROWS]
    bl Lclear_rows
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void clear_row(Vt *vt, u64 *row): blank cells, anything past the width zeroed
    .p2align 2
Lclear_row:
    BLANK x9, x0
    cbnz x9, 1f
    mov x0, x1
    mov x1, #VT_ROWB
    b _bzero
1:  ldr x10, [x0, #VT_COLS]
    mov x11, #0
2:  str x9, [x1, x11, lsl #3]
    add x11, x11, #1
    cmp x11, x10
    b.lo 2b
    add x0, x1, x10, lsl #3
    mov x1, #VT_ROWB
    sub x1, x1, x10, lsl #3
    b _bzero

// void clear_rows(Vt *vt, size_t y0, size_t y1)
    .p2align 2
Lclear_rows:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
1:  cmp x20, x21
    b.hs 2f
    ROW x1, x19, x20
    mov x0, x19
    bl Lclear_row
    add x20, x20, #1
    b 1b
2:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void fill(Vt *vt, u64 *row, size_t from, size_t to): erase cells [from, to)
    .p2align 2
Lfill:
    BLANK x9, x0
1:  cmp x2, x3
    b.hs 2f
    str x9, [x1, x2, lsl #3]
    add x2, x2, #1
    b 1b
2:  ret

// u64 *sb_push(Vt *vt, u64 *row): row joins the scrollback, returns the row to reuse
// that is the evicted oldest line, a row parked by a resize, or a fresh pool row
    .p2align 2
Lsb_push:
    add x9, x0, #VT_SBRING
    ldr x10, [x0, #VT_SB_HEAD]
    ldr x11, [x9, x10, lsl #3]
    str x1, [x9, x10, lsl #3]
    add x10, x10, #1
    cmp x10, #VT_SBLINES
    csel x10, xzr, x10, hs
    str x10, [x0, #VT_SB_HEAD]
    ldr x10, [x0, #VT_SB_N]
    add x10, x10, #1
    mov x12, #VT_SBLINES
    cmp x10, x12
    csel x10, x12, x10, hi
    str x10, [x0, #VT_SB_N]
    cbnz x11, 1f
    ldr x10, [x0, #VT_POOLN]
    add x12, x0, #VT_POOL
    add x11, x12, x10, lsl #12
    add x10, x10, #1
    str x10, [x0, #VT_POOLN]
1:  mov x0, x11
    ret

// void scroll_up(Vt *vt, size_t top, size_t bot, size_t n, int sb)
// sb: lines leaving the top of the full main screen are kept in the scrollback
    .p2align 2
Lscroll_up:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x9, [x19, #VT_MODE]
    tst x9, #M_ALT
    ccmp x20, #0, #0, eq
    csel x23, x4, xzr, eq
    sub x9, x21, x20
    add x9, x9, #1
    cmp x22, x9
    csel x22, x9, x22, hi
1:  cbz x22, 9f
    ldr x10, [x19, #VT_MAP]
    ldr x24, [x10, x20, lsl #3]
    mov x11, x20
2:  cmp x11, x21
    b.hs 3f
    add x12, x11, #1
    ldr x13, [x10, x12, lsl #3]
    str x13, [x10, x11, lsl #3]
    mov x11, x12
    b 2b
3:  cbz x23, 4f
    mov x0, x19
    mov x1, x24
    bl Lsb_push
    mov x24, x0
4:  ldr x10, [x19, #VT_MAP]
    str x24, [x10, x21, lsl #3]
    mov x0, x19
    mov x1, x24
    bl Lclear_row
    sub x22, x22, #1
    b 1b
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void scroll_down(Vt *vt, size_t top, size_t bot, size_t n)
    .p2align 2
Lscroll_down:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    sub x9, x21, x20
    add x9, x9, #1
    cmp x22, x9
    csel x22, x9, x22, hi
1:  cbz x22, 9f
    ldr x10, [x19, #VT_MAP]
    ldr x23, [x10, x21, lsl #3]
    mov x11, x21
2:  cmp x11, x20
    b.ls 3f
    sub x12, x11, #1
    ldr x13, [x10, x12, lsl #3]
    str x13, [x10, x11, lsl #3]
    mov x11, x12
    b 2b
3:  str x23, [x10, x20, lsl #3]
    mov x0, x19
    mov x1, x23
    bl Lclear_row
    sub x22, x22, #1
    b 1b
9:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void index(Vt *vt): line feed, scrolls at the bottom margin
    .p2align 2
Lindex:
    ldr x9, [x0, #VT_CY]
    ldr x10, [x0, #VT_BOT]
    cmp x9, x10
    b.ne 1f
    ldr x1, [x0, #VT_TOP]
    mov x2, x10
    mov x3, #1
    mov x4, #1
    b Lscroll_up
1:  ldr x10, [x0, #VT_ROWS]
    sub x10, x10, #1
    cmp x9, x10
    b.hs 2f
    add x9, x9, #1
    str x9, [x0, #VT_CY]
2:  ret

// void rindex(Vt *vt): reverse line feed, scrolls down at the top margin
    .p2align 2
Lrindex:
    ldr x9, [x0, #VT_CY]
    ldr x10, [x0, #VT_TOP]
    cmp x9, x10
    b.ne 1f
    mov x1, x10
    ldr x2, [x0, #VT_BOT]
    mov x3, #1
    b Lscroll_down
1:  cbz x9, 2f
    sub x9, x9, #1
    str x9, [x0, #VT_CY]
2:  ret

// void put(Vt *vt, u32 cp): print at the cursor with deferred autowrap
    .p2align 2
Lput:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov w20, w1
    // zero-width: combining marks, ZWSP..RLM, variation selectors
    sub w9, w20, #0x300
    cmp w9, #0x6f
    b.ls 9f
    mov w10, #0x200b
    sub w9, w20, w10
    cmp w9, #4
    b.ls 9f
    mov w10, #0xfe00
    sub w9, w20, w10
    cmp w9, #15
    b.ls 9f
    ldr x21, [x19, #VT_MODE]
    tbz x21, #MB_WRAPNEXT, 1f
    and x21, x21, #~M_WRAPNEXT
    str x21, [x19, #VT_MODE]
    str xzr, [x19, #VT_CX]
    mov x0, x19
    bl Lindex
1:  tst x21, #M_SHIFTOUT
    mov x9, #M_G0GFX
    mov x10, #M_G1GFX
    csel x9, x10, x9, ne
    tst x21, x9
    b.eq 2f
    sub w9, w20, #0x5f
    cmp w9, #31
    b.hi 2f
    LADDR x10, Ldec_gfx
    ldrh w20, [x10, x9, lsl #1]
2:  ldp x11, x12, [x19, #VT_CX]
    ROW x22, x19, x12
    ldr x13, [x19, #VT_COLS]
    tbz x21, #MB_INSERT, 3f
    add x1, x22, x11, lsl #3
    add x0, x1, #8
    sub x2, x13, x11
    sub x2, x2, #1
    lsl x2, x2, #3
    bl _memmove
    ldr x11, [x19, #VT_CX]
    ldr x13, [x19, #VT_COLS]
3:  ldr x9, [x19, #VT_PEN]
    orr x9, x9, x20
    str x9, [x22, x11, lsl #3]
    str x20, [x19, #VT_LAST]
    add x11, x11, #1
    cmp x11, x13
    b.hs 4f
    str x11, [x19, #VT_CX]
    b 9f
4:  tbz x21, #MB_AUTOWRAP, 9f
    ldr x9, [x19, #VT_MODE]
    orr x9, x9, #M_WRAPNEXT
    str x9, [x19, #VT_MODE]
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// DECSC / DECRC
    .p2align 2
Lsave_cursor:
    ldp x9, x10, [x0, #VT_CX]
    stp x9, x10, [x0, #VT_SAVE_X]
    ldr x9, [x0, #VT_PEN]
    ldr x10, [x0, #VT_MODE]
    stp x9, x10, [x0, #VT_SAVE_PEN]
    ret

    .p2align 2
Lrestore_cursor:
    ldp x9, x10, [x0, #VT_SAVE_X]
    ldp x11, x12, [x0, #VT_ROWS]
    sub x11, x11, #1
    sub x12, x12, #1
    cmp x9, x12
    csel x9, x12, x9, hi
    cmp x10, x11
    csel x10, x11, x10, hi
    stp x9, x10, [x0, #VT_CX]
    ldp x9, x10, [x0, #VT_SAVE_PEN]
    str x9, [x0, #VT_PEN]
    ldr x11, [x0, #VT_MODE]
    mov x12, #(M_SAVED | M_WRAPNEXT)
    bic x11, x11, x12
    mov x12, #M_SAVED
    and x10, x10, x12
    orr x11, x11, x10
    str x11, [x0, #VT_MODE]
    ret

// void reply(Vt *vt, const char *s), dropped when the buffer is full
    .p2align 2
Lreply:
    ldr x9, [x0, #VT_REPLY_LEN]
    add x10, x0, #VT_REPLY
1:  ldrb w11, [x1], #1
    cbz w11, 2f
    cmp x9, #VT_REPLY_MAX
    b.hs 2f
    strb w11, [x10, x9]
    add x9, x9, #1
    b 1b
2:  str x9, [x0, #VT_REPLY_LEN]
    ret

// void reply_num(Vt *vt, u64 n), decimal
    .p2align 2
Lreply_num:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x2, sp, #47
    strb wzr, [x2]
    mov x3, #10
1:  udiv x4, x1, x3
    msub x5, x4, x3, x1
    add w5, w5, #'0'
    strb w5, [x2, #-1]!
    mov x1, x4
    cbnz x1, 1b
    mov x1, x2
    bl Lreply
    ldp x29, x30, [sp], #48
    ret

// void osc_end(Vt *vt): OSC 0 and 2 set the title
    .p2align 2
Losc_end:
    ldr x9, [x0, #VT_OSC_LEN]
    add x10, x0, #VT_OSC
    strb wzr, [x10, x9]
    ldrb w11, [x10]
    cmp w11, #'0'
    b.eq 1f
    cmp w11, #'2'
    b.ne 9f
1:  ldrb w11, [x10, #1]
    cmp w11, #';'
    b.ne 9f
    add x10, x10, #2
    add x12, x0, #VT_TITLE
    mov x13, #0
2:  ldrb w11, [x10, x13]
    cbz w11, 3f
    cmp x13, #VT_TITLE_MAX
    b.hs 3f
    strb w11, [x12, x13]
    add x13, x13, #1
    b 2b
3:  strb wzr, [x12, x13]
    ldr x9, [x0, #VT_TITLE_GEN]
    add x9, x9, #1
    str x9, [x0, #VT_TITLE_GEN]
9:  ret

// u32 param_at(Vt *vt, size_t i), 0 past the parameter array
    .p2align 2
Lparam_at:
    cmp x1, #16
    b.hs 1f
    add x9, x0, #VT_PARAMS
    ldr w0, [x9, x1, lsl #2]
    ret
1:  mov w0, #0
    ret

// void alt(Vt *vt, int on, int save): switch screens, 1049 also saves the cursor
    .p2align 2
Lalt:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x2
    ldr x9, [x19, #VT_MODE]
    cbz x1, 2f
    tbnz x9, #MB_ALT, 9f
    cbz x20, 1f
    mov x0, x19
    bl Lsave_cursor
1:  ldr x9, [x19, #VT_MODE]
    orr x9, x9, #M_ALT
    str x9, [x19, #VT_MODE]
    add x9, x19, #VT_MAP_ALT
    str x9, [x19, #VT_MAP]
    mov x0, x19
    mov x1, #0
    ldr x2, [x19, #VT_ROWS]
    bl Lclear_rows
    b 9f
2:  tbz x9, #MB_ALT, 9f
    and x9, x9, #~M_ALT
    str x9, [x19, #VT_MODE]
    add x9, x19, #VT_MAP_MAIN
    str x9, [x19, #VT_MAP]
    cbz x20, 9f
    mov x0, x19
    bl Lrestore_cursor
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void set_mode(Vt *vt, u32 mode, int on), DEC private modes
    .p2align 2
Lset_mode:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x9, #M_APPCUR
    cmp x1, #1
    b.eq 1f
    mov x9, #M_AUTOWRAP
    cmp x1, #7
    b.eq 1f
    mov x9, #M_CURSOR
    cmp x1, #25
    b.eq 1f
    mov x9, #M_PASTE
    cmp x1, #2004
    b.eq 1f
    mov x9, #M_ORIGIN
    cmp x1, #6
    b.eq 2f
    mov x20, #0
    cmp x1, #47
    b.eq 3f
    cmp x1, #1047
    b.eq 3f
    mov x20, #1
    cmp x1, #1049
    b.eq 3f
    b 9f
1:  ldr x10, [x19, #VT_MODE]
    orr x11, x10, x9
    bic x12, x10, x9
    cmp x2, #0
    csel x10, x12, x11, eq
    str x10, [x19, #VT_MODE]
    b 9f
    // origin mode also homes the cursor into the region
2:  ldr x10, [x19, #VT_MODE]
    orr x11, x10, x9
    bic x12, x10, x9
    cmp x2, #0
    csel x10, x12, x11, eq
    str x10, [x19, #VT_MODE]
    ldr x11, [x19, #VT_TOP]
    csel x11, xzr, x11, eq
    stp xzr, x11, [x19, #VT_CX]
    b 9f
3:  mov x0, x19
    mov x1, x2
    mov x2, x20
    bl Lalt
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void csi(Vt *vt, u32 final): execute a complete control sequence
// x19 vt, w20 final, x21/x22 parameters, x23 index, x24 scratch
    .p2align 2
Lcsi:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov w20, w1
    ldr x9, [x19, #VT_PRIV]
    cbnz x9, Lc_priv
    ldr x9, [x19, #VT_INTER]
    cbnz x9, Lc_inter
    sub w9, w20, #0x40
    cmp w9, #0x3e
    b.hi Lc_out
    adr x10, Lc_table
    add x10, x10, x9, lsl #2
    br x10
Lc_table:
    b Lc_ich        // @
    b Lc_cuu        // A
    b Lc_cud        // B
    b Lc_cuf        // C
    b Lc_cub        // D
    b Lc_cnl        // E
    b Lc_cpl        // F
    b Lc_cha        // G
    b Lc_cup        // H
    b Lc_cht        // I
    b Lc_ed         // J
    b Lc_el         // K
    b Lc_il         // L
    b Lc_dl         // M
    b Lc_out        // N
    b Lc_out        // O
    b Lc_dch        // P
    b Lc_out        // Q
    b Lc_out        // R
    b Lc_su         // S
    b Lc_sd         // T
    b Lc_out        // U
    b Lc_out        // V
    b Lc_out        // W
    b Lc_ech        // X
    b Lc_out        // Y
    b Lc_cbt        // Z
    b Lc_out        // [
    b Lc_out        // backslash
    b Lc_out        // ]
    b Lc_out        // ^
    b Lc_out        // _
    b Lc_cha        // `
    b Lc_cuf        // a
    b Lc_rep        // b
    b Lc_da         // c
    b Lc_vpa        // d
    b Lc_cud        // e
    b Lc_cup        // f
    b Lc_out        // g
    b Lc_sm         // h
    b Lc_out        // i
    b Lc_out        // j
    b Lc_out        // k
    b Lc_rm         // l
    b Lc_sgr        // m
    b Lc_dsr        // n
    b Lc_out        // o
    b Lc_out        // p
    b Lc_out        // q
    b Lc_stbm       // r
    b Lc_save       // s
    b Lc_winops     // t
    b Lc_restore    // u
    .rept 9
    b Lc_out        // v..~
    .endr

    // vertical moves stop at the margins when the cursor is inside them
Lc_cuu:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CY]
    ldr x10, [x19, #VT_TOP]
    cmp x9, x10
    csel x10, x10, xzr, hs
    sub x9, x9, x21
    cmp x9, x10
    csel x9, x10, x9, lt
    str x9, [x19, #VT_CY]
    b Lc_nowrap
Lc_cud:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CY]
    ldr x10, [x19, #VT_BOT]
    ldr x11, [x19, #VT_ROWS]
    sub x11, x11, #1
    cmp x9, x10
    csel x10, x10, x11, ls
    add x9, x9, x21
    cmp x9, x10
    csel x9, x10, x9, gt
    str x9, [x19, #VT_CY]
    b Lc_nowrap
Lc_cnl:
    str xzr, [x19, #VT_CX]
    b Lc_cud
Lc_cpl:
    str xzr, [x19, #VT_CX]
    b Lc_cuu
Lc_cuf:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CX]
    ldr x10, [x19, #VT_COLS]
    sub x10, x10, #1
    add x9, x9, x21
    cmp x9, x10
    csel x9, x10, x9, hi
    str x9, [x19, #VT_CX]
    b Lc_nowrap
Lc_cub:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CX]
    subs x9, x9, x21
    csel x9, xzr, x9, lt
    str x9, [x19, #VT_CX]
    b Lc_nowrap
Lc_cha:
    PARAM w21, 0, 1
    sub x21, x21, #1
    ldr x10, [x19, #VT_COLS]
    sub x10, x10, #1
    cmp x21, x10
    csel x21, x10, x21, hi
    str x21, [x19, #VT_CX]
    b Lc_nowrap
Lc_cup:
    PARAM w22, 1, 1
    sub x22, x22, #1
    ldr x10, [x19, #VT_COLS]
    sub x10, x10, #1
    cmp x22, x10
    csel x22, x10, x22, hi
    str x22, [x19, #VT_CX]
Lc_vpa:
    PARAM w21, 0, 1
    sub x21, x21, #1
    // row x21 is relative to the region in origin mode
    ldr x9, [x19, #VT_MODE]
    tbz x9, #MB_ORIGIN, 1f
    ldr x10, [x19, #VT_TOP]
    add x21, x21, x10
    ldr x10, [x19, #VT_BOT]
    b 2f
1:  ldr x10, [x19, #VT_ROWS]
    sub x10, x10, #1
2:  cmp x21, x10
    csel x21, x10, x21, hi
    str x21, [x19, #VT_CY]
    b Lc_nowrap
Lc_cht:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CX]
    ldr x10, [x19, #VT_COLS]
    sub x10, x10, #1
1:  cbz x21, 2f
    and x9, x9, #~7
    add x9, x9, #8
    sub x21, x21, #1
    cmp x9, x10
    b.lo 1b
2:  cmp x9, x10
    csel x9, x10, x9, hi
    str x9, [x19, #VT_CX]
    b Lc_nowrap
Lc_cbt:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CX]
1:  cbz x21, 2f
    cbz x9, 2f
    sub x9, x9, #1
    and x9, x9, #~7
    sub x21, x21, #1
    b 1b
2:  str x9, [x19, #VT_CX]
    b Lc_nowrap

Lc_ed:
    PARAM w21, 0, 0
    ldr x22, [x19, #VT_CY]
    cmp w21, #1
    b.eq 1f
    b.hi 2f
    ROW x1, x19, x22
    mov x0, x19
    ldr x2, [x19, #VT_CX]
    ldr x3, [x19, #VT_COLS]
    bl Lfill
    mov x0, x19
    add x1, x22, #1
    ldr x2, [x19, #VT_ROWS]
    bl Lclear_rows
    b Lc_out
1:  mov x0, x19
    mov x1, #0
    mov x2, x22
    bl Lclear_rows
    ROW x1, x19, x22
    mov x0, x19
    mov x2, #0
    ldr x3, [x19, #VT_CX]
    add x3, x3, #1
    ldr x4, [x19, #VT_COLS]
    cmp x3, x4
    csel x3, x4, x3, hi
    bl Lfill
    b Lc_out
    // 3 also drops the scrollback
2:  cmp w21, #3
    b.ne 3f
    str xzr, [x19, #VT_SB_N]
3:  mov x0, x19
    mov x1, #0
    ldr x2, [x19, #VT_ROWS]
    bl Lclear_rows
    b Lc_out

Lc_el:
    PARAM w21, 0, 0
    ldr x22, [x19, #VT_CY]
    ROW x1, x19, x22
    mov x0, x19
    cmp w21, #1
    b.eq 1f
    b.hi 2f
    ldr x2, [x19, #VT_CX]
    ldr x3, [x19, #VT_COLS]
    bl Lfill
    b Lc_out
1:  mov x2, #0
    ldr x3, [x19, #VT_CX]
    add x3, x3, #1
    ldr x4, [x19, #VT_COLS]
    cmp x3, x4
    csel x3, x4, x3, hi
    bl Lfill
    b Lc_out
2:  mov x2, #0
    ldr x3, [x19, #VT_COLS]
    bl Lfill
    b Lc_out

Lc_il:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CY]
    ldr x10, [x19, #VT_TOP]
    ldr x11, [x19, #VT_BOT]
    cmp x9, x10
    b.lo Lc_out
    cmp x9, x11
    b.hi Lc_out
    mov x0, x19
    mov x1, x9
    mov x2, x11
    mov x3, x21
    bl Lscroll_down
    str xzr, [x19, #VT_CX]
    b Lc_nowrap
Lc_dl:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_CY]
    ldr x10, [x19, #VT_TOP]
    ldr x11, [x19, #VT_BOT]
    cmp x9, x10
    b.lo Lc_out
    cmp x9, x11
    b.hi Lc_out
    mov x0, x19
    mov x1, x9
    mov x2, x11
    mov x3, x21
    mov x4, #0
    bl Lscroll_up
    str xzr, [x19, #VT_CX]
    b Lc_nowrap
Lc_su:
    PARAM w21, 0, 1
    mov x0, x19
    ldr x1, [x19, #VT_TOP]
    ldr x2, [x19, #VT_BOT]
    mov x3, x21
    mov x4, #1
    bl Lscroll_up
    b Lc_out
Lc_sd:
    PARAM w21, 0, 1
    mov x0, x19
    ldr x1, [x19, #VT_TOP]
    ldr x2, [x19, #VT_BOT]
    mov x3, x21
    bl Lscroll_down
    b Lc_out

    // ICH, DCH, ECH: n clamped to the cells right of the cursor; x22 cx, x23 cols, x24 row
Lc_cells:
    ldr x22, [x19, #VT_CX]
    ldr x23, [x19, #VT_COLS]
    ldr x9, [x19, #VT_CY]
    ROW x24, x19, x9
    sub x9, x23, x22
    cmp x21, x9
    csel x21, x9, x21, hi
    ret
Lc_ich:
    PARAM w21, 0, 1
    bl Lc_cells
    add x1, x24, x22, lsl #3
    add x0, x1, x21, lsl #3
    sub x2, x23, x22
    sub x2, x2, x21
    lsl x2, x2, #3
    bl _memmove
    mov x0, x19
    mov x1, x24
    mov x2, x22
    add x3, x22, x21
    bl Lfill
    b Lc_nowrap
Lc_dch:
    PARAM w21, 0, 1
    bl Lc_cells
    add x0, x24, x22, lsl #3
    add x1, x0, x21, lsl #3
    sub x2, x23, x22
    sub x2, x2, x21
    lsl x2, x2, #3
    bl _memmove
    mov x0, x19
    mov x1, x24
    sub x2, x23, x21
    mov x3, x23
    bl Lfill
    b Lc_nowrap
Lc_ech:
    PARAM w21, 0, 1
    bl Lc_cells
    mov x0, x19
    mov x1, x24
    mov x2, x22
    add x3, x22, x21
    bl Lfill
    b Lc_nowrap

Lc_rep:
    PARAM w21, 0, 1
    mov x9, #0xffff
    cmp x21, x9
    csel x21, x9, x21, hi
1:  ldr x1, [x19, #VT_LAST]
    cbz x1, Lc_out
    cbz x21, Lc_out
    mov x0, x19
    bl Lput
    sub x21, x21, #1
    b 1b

Lc_da:
    PARAM w21, 0, 0
    cbnz w21, Lc_out
    mov x0, x19
    LADDR x1, Lr_da
    bl Lreply
    b Lc_out
Lc_dsr:
    PARAM w21, 0, 0
    cmp w21, #5
    b.ne 1f
    mov x0, x19
    LADDR x1, Lr_ok
    bl Lreply
    b Lc_out
1:  cmp w21, #6
    b.ne Lc_out
    mov x0, x19
    LADDR x1, Lr_csi
    bl Lreply
    ldr x1, [x19, #VT_CY]
    add x1, x1, #1
    mov x0, x19
    bl Lreply_num
    mov x0, x19
    LADDR x1, Lr_semi
    bl Lreply
    ldr x1, [x19, #VT_CX]
    add x1, x1, #1
    mov x0, x19
    bl Lreply_num
    mov x0, x19
    LADDR x1, Lr_R
    bl Lreply
    b Lc_out
    // 18: text area size in cells
Lc_winops:
    PARAM w21, 0, 0
    cmp w21, #18
    b.ne Lc_out
    mov x0, x19
    LADDR x1, Lr_size
    bl Lreply
    mov x0, x19
    ldr x1, [x19, #VT_ROWS]
    bl Lreply_num
    mov x0, x19
    LADDR x1, Lr_semi
    bl Lreply
    mov x0, x19
    ldr x1, [x19, #VT_COLS]
    bl Lreply_num
    mov x0, x19
    LADDR x1, Lr_t
    bl Lreply
    b Lc_out

    // ANSI modes: only 4 (insert)
Lc_sm:
    mov x24, #M_INSERT
    b 1f
Lc_rm:
    mov x24, #0
1:  PARAM w21, 0, 0
    cmp w21, #4
    b.ne Lc_out
    ldr x9, [x19, #VT_MODE]
    and x9, x9, #~M_INSERT
    orr x9, x9, x24
    str x9, [x19, #VT_MODE]
    b Lc_out

Lc_stbm:
    PARAM w21, 0, 1
    ldr x9, [x19, #VT_ROWS]
    ldr w22, [x19, #(VT_PARAMS + 4)]
    cmp x22, #0
    csel x22, x9, x22, eq
    cmp x22, x9
    csel x22, x9, x22, hi
    cmp x21, x22
    b.hs Lc_out
    sub x21, x21, #1
    sub x22, x22, #1
    str x21, [x19, #VT_TOP]
    str x22, [x19, #VT_BOT]
    ldr x9, [x19, #VT_MODE]
    tst x9, #M_ORIGIN
    csel x21, x21, xzr, ne
    stp xzr, x21, [x19, #VT_CX]
    b Lc_nowrap

Lc_save:
    mov x0, x19
    bl Lsave_cursor
    b Lc_out
Lc_restore:
    mov x0, x19
    bl Lrestore_cursor
    b Lc_out

    // SGR, x22 pen being built, x23 parameter index
Lc_sgr:
    ldr x22, [x19, #VT_PEN]
    mov x23, #0
Lsgr_loop:
    ldr x9, [x19, #VT_NPARAM]
    cmp x23, x9
    b.hi Lsgr_done
    mov x0, x19
    mov x1, x23
    bl Lparam_at
    mov w21, w0
    add x23, x23, #1
    cbz w21, Lsgr_reset
    sub w9, w21, #1
    cmp w9, #8
    b.hi 1f
    LADDR x10, Lsgr_bits
    ldrb w9, [x10, x9]
    cbz w9, Lsgr_loop
    mov x10, #1
    lsl x10, x10, x9
    orr x22, x22, x10
    b Lsgr_loop
    // 22..29 clear what 2..9 set, 22 also clears bold
1:  sub w9, w21, #22
    cmp w9, #7
    b.hi 2f
    add w9, w9, #1
    LADDR x10, Lsgr_bits
    ldrb w9, [x10, x9]
    cbz w9, Lsgr_loop
    mov x10, #1
    lsl x10, x10, x9
    bic x22, x22, x10
    cmp w21, #22
    b.ne Lsgr_loop
    and x22, x22, #~AT_BOLD
    b Lsgr_loop
2:  cmp w21, #21
    b.ne 3f
    orr x22, x22, #AT_UNDER
    b Lsgr_loop
3:  sub w9, w21, #30
    cmp w9, #7
    b.hi 4f
    add w9, w9, #1
    bfi x22, x9, #32, #16
    b Lsgr_loop
4:  cmp w21, #39
    b.ne 5f
    bfi x22, xzr, #32, #16
    b Lsgr_loop
5:  sub w9, w21, #40
    cmp w9, #7
    b.hi 6f
    add w9, w9, #1
    bfi x22, x9, #48, #16
    b Lsgr_loop
6:  cmp w21, #49
    b.ne 7f
    bfi x22, xzr, #48, #16
    b Lsgr_loop
7:  sub w9, w21, #90
    cmp w9, #7
    b.hi 8f
    add w9, w9, #9
    bfi x22, x9, #32, #16
    b Lsgr_loop
8:  sub w9, w21, #100
    cmp w9, #7
    b.hi 81f
    add w9, w9, #9
    bfi x22, x9, #48, #16
    b Lsgr_loop
81: mov x24, #0
    cmp w21, #38
    b.eq Lsgr_ext
    mov x24, #1
    cmp w21, #48
    b.eq Lsgr_ext
    b Lsgr_loop
Lsgr_reset:
    mov x22, #0
    b Lsgr_loop
    // 38/48 ;5;n indexed or ;2;r;g;b direct (kept as rgb555), x24 0 fg 1 bg
Lsgr_ext:
    mov x0, x19
    mov x1, x23
    bl Lparam_at
    cmp w0, #5
    b.eq 1f
    cmp w0, #2
    b.ne Lsgr_loop
    mov x0, x19
    add x1, x23, #1
    bl Lparam_at
    and w21, w0, #0xf8
    lsl w21, w21, #7
    mov x0, x19
    add x1, x23, #2
    bl Lparam_at
    and w0, w0, #0xf8
    orr w21, w21, w0, lsl #2
    mov x0, x19
    add x1, x23, #3
    bl Lparam_at
    ubfx w0, w0, #3, #5
    orr w21, w21, w0
    orr w21, w21, #COLOR_RGB
    add x23, x23, #4
    b 2f
1:  mov x0, x19
    add x1, x23, #1
    bl Lparam_at
    and w21, w0, #0xff
    add w21, w21, #1
    add x23, x23, #2
2:  cbnz x24, 3f
    bfi x22, x21, #32, #16
    b Lsgr_loop
3:  bfi x22, x21, #48, #16
    b Lsgr_loop
Lsgr_done:
    str x22, [x19, #VT_PEN]
    b Lc_out

    // CSI ? h/l private modes, CSI > c secondary attributes
Lc_priv:
    cmp x9, #'>'
    b.ne 1f
    cmp w20, #'c'
    b.ne Lc_out
    mov x0, x19
    LADDR x1, Lr_da2
    bl Lreply
    b Lc_out
1:  cmp x9, #'?'
    b.ne Lc_out
    cmp w20, #'h'
    cset x24, eq
    b.eq 2f
    cmp w20, #'l'
    b.ne Lc_out
2:  mov x23, #0
3:  ldr x9, [x19, #VT_NPARAM]
    cmp x23, x9
    b.hi Lc_out
    mov x0, x19
    mov x1, x23
    bl Lparam_at
    mov x1, x0
    mov x0, x19
    mov x2, x24
    bl Lset_mode
    add x23, x23, #1
    b 3b

    // CSI ! p soft reset
Lc_inter:
    cmp x9, #'!'
    b.ne Lc_out
    cmp w20, #'p'
    b.ne Lc_out
    str xzr, [x19, #VT_PEN]
    ldr x9, [x19, #VT_MODE]
    and x9, x9, #M_ALT
    orr x9, x9, #(M_AUTOWRAP | M_CURSOR)
    str x9, [x19, #VT_MODE]
    str xzr, [x19, #VT_TOP]
    ldr x9, [x19, #VT_ROWS]
    sub x9, x9, #1
    str x9, [x19, #VT_BOT]
    b Lc_out

Lc_nowrap:
    NOWRAP x19, x9
Lc_out:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_vt_feed(Vt *vt, const u8 *p, size_t n): parser state survives across calls
// x19 vt, x20 cursor, x21 end, w22 byte
FUNC_BEGIN _av_vt_feed
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    add x21, x1, x2
Lf_next:
    cmp x20, x21
    b.hs Lf_done
    ldrb w22, [x20], #1
    ldr x9, [x19, #VT_STATE]
    cmp x9, #S_OSC
    b.hs Lf_string
    cmp w22, #0x20
    b.lo Lf_c0
    cmp w22, #0x7f
    b.eq Lf_next
    cbz x9, Lf_print
    cmp x9, #S_CSI
    b.eq Lf_csi
    cmp x9, #S_ESC
    b.eq Lf_esc
    b Lf_esc_inter

    // UTF-8 decoding, malformed input prints U+FFFD
Lf_print:
    ldr x10, [x19, #VT_UNEED]
    cmp w22, #0x80
    b.hs 1f
    str xzr, [x19, #VT_UNEED]
    mov w1, w22
    b Lf_put
1:  cmp w22, #0xc0
    b.hs 2f
    cbz x10, Lf_bad
    ldr x11, [x19, #VT_UCP]
    and w12, w22, #0x3f
    orr x11, x12, x11, lsl #6
    str x11, [x19, #VT_UCP]
    sub x10, x10, #1
    str x10, [x19, #VT_UNEED]
    cbnz x10, Lf_next
    mov x1, x11
    b Lf_put
2:  cmp w22, #0xe0
    b.hs 3f
    and w11, w22, #0x1f
    mov x10, #1
    b 5f
3:  cmp w22, #0xf0
    b.hs 4f
    and w11, w22, #0x0f
    mov x10, #2
    b 5f
4:  cmp w22, #0xf8
    b.hs Lf_bad
    and w11, w22, #0x07
    mov x10, #3
5:  str x11, [x19, #VT_UCP]
    str x10, [x19, #VT_UNEED]
    b Lf_next
Lf_bad:
    str xzr, [x19, #VT_UNEED]
    mov w1, #0xfffd
Lf_put:
    mov x0, x19
    bl Lput
    b Lf_next

    // C0 controls run in every state except strings
Lf_c0:
    str xzr, [x19, #VT_UNEED]
    cmp w22, #0x1b
    b.eq Lf_to_esc
    cmp w22, #0x0d
    b.eq Lf_cr
    sub w9, w22, #0x0a
    cmp w9, #2
    b.ls Lf_lf
    cmp w22, #0x08
    b.eq Lf_bs
    cmp w22, #0x09
    b.eq Lf_ht
    cmp w22, #0x07
    b.eq Lf_bel
    cmp w22, #0x0e
    b.eq Lf_so
    cmp w22, #0x0f
    b.eq Lf_si
    cmp w22, #0x18
    b.eq Lf_ground
    cmp w22, #0x1a
    b.eq Lf_ground
    b Lf_next
Lf_cr:
    str xzr, [x19, #VT_CX]
    NOWRAP x19, x9
    b Lf_next
Lf_lf:
    NOWRAP x19, x9
    mov x0, x19
    bl Lindex
    b Lf_next
Lf_bs:
    NOWRAP x19, x9
    ldr x9, [x19, #VT_CX]
    cbz x9, Lf_next
    sub x9, x9, #1
    str x9, [x19, #VT_CX]
    b Lf_next
Lf_ht:
    ldr x9, [x19, #VT_CX]
    and x9, x9, #~7
    add x9, x9, #8
    ldr x10, [x19, #VT_COLS]
    sub x10, x10, #1
    cmp x9, x10
    csel x9, x10, x9, hi
    str x9, [x19, #VT_CX]
    b Lf_next
Lf_bel:
    ldr x9, [x19, #VT_BELL]
    add x9, x9, #1
    str x9, [x19, #VT_BELL]
    b Lf_next
Lf_so:
    ldr x9, [x19, #VT_MODE]
    orr x9, x9, #M_SHIFTOUT
    str x9, [x19, #VT_MODE]
    b Lf_next
Lf_si:
    ldr x9, [x19, #VT_MODE]
    and x9, x9, #~M_SHIFTOUT
    str x9, [x19, #VT_MODE]
    b Lf_next
Lf_ground:
    str xzr, [x19, #VT_STATE]
    b Lf_next
Lf_to_esc:
    mov x9, #S_ESC
    str x9, [x19, #VT_STATE]
    str xzr, [x19, #VT_INTER]
    b Lf_next

Lf_esc:
    str xzr, [x19, #VT_STATE]
    cmp w22, #'['
    b.eq Lf_csi_entry
    cmp w22, #']'
    b.eq Lf_osc_entry
    cmp w22, #'P'
    b.eq Lf_dcs_entry
    cmp w22, #'X'
    b.eq Lf_dcs_entry
    cmp w22, #'^'
    b.eq Lf_dcs_entry
    cmp w22, #'_'
    b.eq Lf_dcs_entry
    cmp w22, #0x30
    b.lo Lf_esc_int_start
    mov x0, x19
    cmp w22, #'7'
    b.eq 1f
    cmp w22, #'8'
    b.eq 2f
    cmp w22, #'D'
    b.eq 3f
    cmp w22, #'E'
    b.eq 4f
    cmp w22, #'M'
    b.eq 5f
    cmp w22, #'c'
    b.eq 6f
    b Lf_next
1:  bl Lsave_cursor
    b Lf_next
2:  bl Lrestore_cursor
    b Lf_next
4:  str xzr, [x19, #VT_CX]
3:  NOWRAP x19, x9
    bl Lindex
    b Lf_next
5:  NOWRAP x19, x9
    bl Lrindex
    b Lf_next
6:  bl Lreset
    b Lf_next
Lf_csi_entry:
    add x9, x19, #VT_PARAMS
    stp xzr, xzr, [x9]
    stp xzr, xzr, [x9, #16]
    stp xzr, xzr, [x9, #32]
    stp xzr, xzr, [x9, #48]
    str xzr, [x19, #VT_NPARAM]
    str xzr, [x19, #VT_PRIV]
    str xzr, [x19, #VT_INTER]
    mov x9, #S_CSI
    str x9, [x19, #VT_STATE]
    b Lf_next
Lf_osc_entry:
    str xzr, [x19, #VT_OSC_LEN]
    mov x9, #S_OSC
    str x9, [x19, #VT_STATE]
    b Lf_next
Lf_dcs_entry:
    mov x9, #S_DCS
    str x9, [x19, #VT_STATE]
    b Lf_next
Lf_esc_int_start:
    str x22, [x19, #VT_INTER]
    mov x9, #S_ESC_INTER
    str x9, [x19, #VT_STATE]
    b Lf_next

    // ESC ( 0 / ESC ) 0 select line drawing, any other final selects ASCII
Lf_esc_inter:
    cmp w22, #0x30
    b.lo Lf_next
    str xzr, [x19, #VT_STATE]
    ldr x9, [x19, #VT_INTER]
    mov x10, #M_G0GFX
    cmp x9, #'('
    b.eq 1f
    mov x10, #M_G1GFX
    cmp x9, #')'
    b.ne Lf_next
1:  ldr x11, [x19, #VT_MODE]
    orr x12, x11, x10
    bic x11, x11, x10
    cmp w22, #'0'
    csel x11, x12, x11, eq
    str x11, [x19, #VT_MODE]
    b Lf_next

Lf_csi:
    sub w9, w22, #'0'
    cmp w9, #9
    b.ls 1f
    cmp w22, #';'
    b.eq 2f
    cmp w22, #':'
    b.eq 2f
    cmp w22, #0x30
    b.lo 3f
    cmp w22, #0x40
    b.hs 4f
    cmp w22, #0x3c
    b.lo Lf_next
    str x22, [x19, #VT_PRIV]
    b Lf_next
1:  ldr x10, [x19, #VT_NPARAM]
    add x11, x19, #VT_PARAMS
    ldr w12, [x11, x10, lsl #2]
    mov w13, #10
    madd w12, w12, w13, w9
    mov w13, #0xffff
    cmp w12, w13
    csel w12, w13, w12, hi
    str w12, [x11, x10, lsl #2]
    b Lf_next
2:  ldr x10, [x19, #VT_NPARAM]
    cmp x10, #15
    cinc x10, x10, lo
    str x10, [x19, #VT_NPARAM]
    b Lf_next
3:  str x22, [x19, #VT_INTER]
    b Lf_next
4:  str xzr, [x19, #VT_STATE]
    cmp w22, #0x7f
    b.hs Lf_next
    mov x0, x19
    mov w1, w22
    bl Lcsi
    b Lf_next

    // OSC collects until BEL or ST; DCS, SOS, PM and APC are skipped
Lf_string:
    cmp x9, #S_OSC
    b.eq 1f
    cmp x9, #S_OSC_ESC
    b.eq 3f
    cmp x9, #S_DCS
    b.eq 5f
    cmp w22, #'\\'
    b.eq Lf_ground
    b 4f
1:  cmp w22, #0x07
    b.eq 2f
    cmp w22, #0x1b
    b.ne 11f
    mov x9, #S_OSC_ESC
    str x9, [x19, #VT_STATE]
    b Lf_next
11: cmp w22, #0x18
    b.eq Lf_ground
    cmp w22, #0x1a
    b.eq Lf_ground
    ldr x10, [x19, #VT_OSC_LEN]
    cmp x10, #VT_OSC_MAX
    b.hs Lf_next
    add x11, x19, #VT_OSC
    strb w22, [x11, x10]
    add x10, x10, #1
    str x10, [x19, #VT_OSC_LEN]
    b Lf_next
2:  mov x0, x19
    bl Losc_end
    b Lf_ground
3:  mov x0, x19
    bl Losc_end
    cmp w22, #'\\'
    b.eq Lf_ground
    // the ESC started a new sequence
4:  mov x9, #S_ESC
    str x9, [x19, #VT_STATE]
    str xzr, [x19, #VT_INTER]
    cmp w22, #0x20
    b.lo Lf_next
    b Lf_esc
5:  cmp w22, #0x1b
    b.ne 51f
    mov x9, #S_DCS_ESC
    str x9, [x19, #VT_STATE]
    b Lf_next
51: cmp w22, #0x18
    b.eq Lf_ground
    cmp w22, #0x1a
    b.eq Lf_ground
    b Lf_next

Lf_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_vt_resize(Vt *vt, size_t rows, size_t cols), clamped to 1..256 x 2..512
// shrinking pushes lines above the cursor to the scrollback, growing pulls them back
FUNC_BEGIN _av_vt_resize
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x9, #1
    cmp x1, x9
    csel x1, x9, x1, lo
    mov x9, #VT_MAXROWS
    cmp x1, x9
    csel x20, x9, x1, hi
    mov x9, #2
    cmp x2, x9
    csel x2, x9, x2, lo
    mov x9, #VT_MAXCOLS
    cmp x2, x9
    csel x21, x9, x2, hi
    ldp x22, x23, [x19, #VT_ROWS]
    // wider: cells past the old width may be stale
    cmp x21, x23
    b.ls 2f
    mov x24, #0
1:  cmp x24, x22
    b.hs 2f
    add x9, x19, #VT_MAP_MAIN
    ldr x0, [x9, x24, lsl #3]
    add x0, x0, x23, lsl #3
    sub x1, x21, x23
    lsl x1, x1, #3
    bl _bzero
    add x9, x19, #VT_MAP_ALT
    ldr x0, [x9, x24, lsl #3]
    add x0, x0, x23, lsl #3
    sub x1, x21, x23
    lsl x1, x1, #3
    bl _bzero
    add x24, x24, #1
    b 1b
2:  str x21, [x19, #VT_COLS]
    cmp x20, x22
    b.eq 6f
    b.hi 4f
    ldr x9, [x19, #VT_CY]
    cmp x9, x20
    b.lo 6f
    sub x24, x9, x20
    add x24, x24, #1
    mov x0, x19
    mov x1, #0
    sub x2, x22, #1
    mov x3, x24
    mov x4, #1
    bl Lscroll_up
    ldr x9, [x19, #VT_CY]
    sub x9, x9, x24
    str x9, [x19, #VT_CY]
    b 6f
    // taller: blank the new rows on both screens
4:  mov x24, x22
5:  cmp x24, x20
    b.hs 51f
    add x9, x19, #VT_MAP_MAIN
    ldr x1, [x9, x24, lsl #3]
    mov x0, x19
    bl Lclear_row
    add x9, x19, #VT_MAP_ALT
    ldr x1, [x9, x24, lsl #3]
    mov x0, x19
    bl Lclear_row
    add x24, x24, #1
    b 5b
    // then scroll scrollback lines back in on top, the spare row parks in the freed slot
51: ldr x9, [x19, #VT_MODE]
    tbnz x9, #MB_ALT, 6f
    mov x24, x22
    add x11, x19, #VT_MAP_MAIN
    add x15, x19, #VT_SBRING
52: cmp x24, x20
    b.hs 6f
    ldr x10, [x19, #VT_SB_N]
    cbz x10, 6f
    ldr x12, [x11, x24, lsl #3]
    mov x13, x24
53: cbz x13, 54f
    sub x14, x13, #1
    ldr x9, [x11, x14, lsl #3]
    str x9, [x11, x13, lsl #3]
    mov x13, x14
    b 53b
54: ldr x14, [x19, #VT_SB_HEAD]
    cbnz x14, 55f
    mov x14, #VT_SBLINES
55: sub x14, x14, #1
    str x14, [x19, #VT_SB_HEAD]
    ldr x9, [x15, x14, lsl #3]
    str x12, [x15, x14, lsl #3]
    str x9, [x11]
    sub x10, x10, #1
    str x10, [x19, #VT_SB_N]
    ldr x9, [x19, #VT_CY]
    add x9, x9, #1
    str x9, [x19, #VT_CY]
    add x24, x24, #1
    b 52b
6:  str x20, [x19, #VT_ROWS]
    str xzr, [x19, #VT_TOP]
    sub x9, x20, #1
    str x9, [x19, #VT_BOT]
    sub x10, x21, #1
    ldp x11, x12, [x19, #VT_CX]
    cmp x11, x10
    csel x11, x10, x11, hi
    cmp x12, x9
    csel x12, x9, x12, hi
    stp x11, x12, [x19, #VT_CX]
    ldp x11, x12, [x19, #VT_SAVE_X]
    cmp x11, x10
    csel x11, x10, x11, hi
    cmp x12, x9
    csel x12, x9, x12, hi
    stp x11, x12, [x19, #VT_SAVE_X]
    NOWRAP x19, x9
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// u64 *av_vt_line(Vt *vt, long y): screen row y >= 0, scrollback line y < 0 (-1 newest)
FUNC_BEGIN _av_vt_line
    tbnz x1, #63, 1f
    ldr x9, [x0, #VT_MAP]
    ldr x0, [x9, x1, lsl #3]
    ret
1:  ldr x9, [x0, #VT_SB_HEAD]
    adds x9, x9, x1
    b.pl 2f
    add x9, x9, #VT_SBLINES
2:  add x10, x0, #VT_SBRING
    ldr x0, [x10, x9, lsl #3]
    ret

// size_t av_utf8_encode(u32 cp, u8 *out)
FUNC_BEGIN _av_utf8_encode
    cmp w0, #0x80
    b.hs 1f
    strb w0, [x1]
    mov x0, #1
    ret
1:  cmp w0, #0x800
    b.hs 2f
    lsr w2, w0, #6
    orr w2, w2, #0xc0
    strb w2, [x1]
    and w2, w0, #0x3f
    orr w2, w2, #0x80
    strb w2, [x1, #1]
    mov x0, #2
    ret
2:  cmp w0, #0x10, lsl #12
    b.hs 3f
    lsr w2, w0, #12
    orr w2, w2, #0xe0
    strb w2, [x1]
    ubfx w2, w0, #6, #6
    orr w2, w2, #0x80
    strb w2, [x1, #1]
    and w2, w0, #0x3f
    orr w2, w2, #0x80
    strb w2, [x1, #2]
    mov x0, #3
    ret
3:  lsr w2, w0, #18
    orr w2, w2, #0xf0
    strb w2, [x1]
    ubfx w2, w0, #12, #6
    orr w2, w2, #0x80
    strb w2, [x1, #1]
    ubfx w2, w0, #6, #6
    orr w2, w2, #0x80
    strb w2, [x1, #2]
    and w2, w0, #0x3f
    orr w2, w2, #0x80
    strb w2, [x1, #3]
    mov x0, #4
    ret
