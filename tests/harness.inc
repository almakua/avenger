// minimal test harness: CHECK compares x0 with an expected value, Lsummary prints and returns the exit code

// x0 holds the actual value
.macro CHECK id, expected
    ldr x1, =\expected
    mov x2, #\id
    bl Lcheck
.endm

.macro CALL0 fn, obj
    LADDR x0, \obj
    bl \fn
.endm

.macro CALL1 fn, obj, a
    LADDR x0, \obj
    ldr x1, =\a
    bl \fn
.endm

// x0 = 0 when the first n bytes of buffer obj equal string lit
.macro CHECK_TEXT id, obj, lit, n
    LADDR x0, \obj
    mov x1, #0
    LADDR x2, _tscratch
    mov x3, #\n
    bl _av_buf_copy
    LADDR x0, _tscratch
    LADDR x1, \lit
    mov x2, #\n
    bl _memcmp
    sxtw x0, w0
    CHECK \id, 0
.endm

    .zerofill __DATA,__bss,_tscratch,256,4
    .zerofill __DATA,__bss,_tchecks,8,3
    .zerofill __DATA,__bss,_tfails,8,3

    .section __TEXT,__cstring,cstring_literals
Lh_fail:   .asciz "FAIL #%ld: got %ld want %ld\n"
Lh_ok:     .asciz "ok: %ld checks\n"
Lh_bad:    .asciz "%ld/%ld checks failed\n"

    .text
// check(actual, expected, id)
    .p2align 2
Lcheck:
    LDRG x3, _tchecks
    add x3, x3, #1
    STRG x3, _tchecks, x4
    cmp x0, x1
    b.ne 1f
    ret
1:  stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x3, _tfails
    add x3, x3, #1
    STRG x3, _tfails, x4
    // printf varargs go on the stack: id, got, want
    sub sp, sp, #32
    str x2, [sp]
    stp x0, x1, [sp, #8]
    LADDR x0, Lh_fail
    bl _printf
    add sp, sp, #32
    ldp x29, x30, [sp], #16
    ret

// int summary(void), 0 when every check passed
    .p2align 2
Lsummary:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    LDRG x3, _tfails
    LDRG x4, _tchecks
    cbnz x3, 1f
    sub sp, sp, #16
    str x4, [sp]
    LADDR x0, Lh_ok
    bl _printf
    add sp, sp, #16
    mov w0, #0
    b 2f
1:  sub sp, sp, #16
    stp x3, x4, [sp]
    LADDR x0, Lh_bad
    bl _printf
    add sp, sp, #16
    mov w0, #1
2:  ldp x29, x30, [sp], #32
    ret
