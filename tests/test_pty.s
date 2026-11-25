// pty: a command runs on a pseudo terminal with our TERM, its output goes through the emulator

.include "macros.inc"
.include "vt.inc"
.include "harness.inc"

.set POLLIN, 1

.macro CP id, x, y, want
    LDRG x0, _tvt
    mov x1, #\y
    bl _av_vt_line
    ldr x0, [x0, #(\x * 8)]
    and x0, x0, #CELL_CP
    CHECK \id, \want
.endm

    .zerofill __DATA,__bss,_tvt,8,3
    .zerofill __DATA,__bss,_tbuf,4096,4

    .section __TEXT,__cstring,cstring_literals
Lcmd: .asciz "stty size; printf 'hi\\n%s' \"$TERM\""

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    bl _av_vt_new
    STRG x0, _tvt, x9
    mov x0, #24
    mov x1, #80
    LADDR x2, Lcmd
    add x3, sp, #32
    bl _av_pty_spawn
    mov x19, x0
    cmp x0, #0
    cset x0, gt
    CHECK 1, 1
    ldr w20, [sp, #32]

    // read until the child is gone (EOF or EIO), at most 3 s per wait
1:  str w20, [sp, #40]
    mov w9, #POLLIN
    strh w9, [sp, #44]
    strh wzr, [sp, #46]
    add x0, sp, #40
    mov w1, #1
    mov w2, #3000
    bl _poll
    cmp w0, #0
    b.le 2f
    mov w0, w20
    LADDR x1, _tbuf
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.le 2f
    mov x2, x0
    LDRG x0, _tvt
    LADDR x1, _tbuf
    bl _av_vt_feed
    b 1b

    // "24 80", then "hi" and TERM, newlines arrive as CR LF
2:  CP 2, 0, 0, '2'
    CP 3, 3, 0, '8'
    CP 4, 0, 1, 'h'
    CP 5, 1, 1, 'i'
    CP 6, 0, 2, 'x'
    CP 7, 13, 2, 'r'
    mov x0, x19
    add x1, sp, #40
    mov w2, #0
    bl _waitpid
    cmp w0, w19
    cset x0, eq
    CHECK 8, 1
    ldr w0, [sp, #40]
    CHECK 9, 0
    mov w0, w20
    bl _close

    LDRG x0, _tvt
    bl _av_vt_free
    bl Lsummary
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
