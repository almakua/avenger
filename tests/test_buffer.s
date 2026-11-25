// buffer/file unit tests, CLI only, exit code 1 on any failure

.include "macros.inc"
.include "buffer.inc"

// x0 holds the actual value
.macro CHECK id, expected
    ldr x1, =\expected
    mov x2, #\id
    bl Lcheck
.endm

.macro CALL0 fn, buf
    LADDR x0, \buf
    bl \fn
.endm

.macro CALL1 fn, buf, a
    LADDR x0, \buf
    ldr x1, =\a
    bl \fn
.endm

    .zerofill __DATA,__bss,_tbuf,BUF_SIZE,4
    .zerofill __DATA,__bss,_tbuf2,BUF_SIZE,4
    .zerofill __DATA,__bss,_tbuf3,BUF_SIZE,4
    .zerofill __DATA,__bss,_tscratch,64,4
    .zerofill __DATA,__bss,_tchecks,8,3
    .zerofill __DATA,__bss,_tfails,8,3

    .section __TEXT,__cstring,cstring_literals
Ls_hw:     .asciz "hello\nworld"
Ls_x:      .asciz "X\n"
Ls_ab:     .asciz "ab\n"
Ls_z:      .asciz "Z\n"
Ls_exp:    .asciz "hellorld"
Ls_utf8:   .asciz "a\303\251\342\202\254b"
Ls_path:   .asciz "build/test.tmp"
Ls_fail:   .asciz "FAIL #%ld: got %ld want %ld\n"
Ls_ok:     .asciz "ok: %ld checks\n"
Ls_bad:    .asciz "%ld/%ld checks failed\n"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]

    // empty buffer
    CALL1 _av_buf_init, _tbuf, 0
    CHECK 1, 0
    CALL0 _av_buf_len, _tbuf
    CHECK 2, 0
    CALL0 _av_buf_line_count, _tbuf
    CHECK 3, 1

    // "hello\nworld"
    LADDR x0, _tbuf
    mov x1, #0
    LADDR x2, Ls_hw
    mov x3, #11
    bl _av_buf_insert
    CHECK 4, 0
    CALL0 _av_buf_len, _tbuf
    CHECK 5, 11
    CALL0 _av_buf_line_count, _tbuf
    CHECK 6, 2
    CALL1 _av_buf_line_start, _tbuf, 1
    CHECK 7, 6

    // "helX\nlo\nworld"
    LADDR x0, _tbuf
    mov x1, #3
    LADDR x2, Ls_x
    mov x3, #2
    bl _av_buf_insert
    CHECK 8, 0
    CALL0 _av_buf_len, _tbuf
    CHECK 9, 13
    CALL0 _av_buf_line_count, _tbuf
    CHECK 10, 3
    CALL1 _av_buf_line_start, _tbuf, 1
    CHECK 11, 5
    CALL1 _av_buf_line_start, _tbuf, 2
    CHECK 12, 8
    CALL1 _av_buf_byte_at, _tbuf, 3
    CHECK 13, 'X'
    CALL1 _av_buf_byte_at, _tbuf, 5
    CHECK 14, 'l'
    CALL1 _av_buf_line_of, _tbuf, 4
    CHECK 15, 0
    CALL1 _av_buf_line_of, _tbuf, 5
    CHECK 16, 1
    CALL1 _av_buf_line_of, _tbuf, 12
    CHECK 17, 2
    CALL1 _av_buf_line_end, _tbuf, 0
    CHECK 43, 4
    CALL1 _av_buf_line_end, _tbuf, 2
    CHECK 44, 13

    // back to "hello\nworld", then "hellorld"
    LADDR x0, _tbuf
    mov x1, #3
    mov x2, #2
    bl _av_buf_delete
    CALL0 _av_buf_len, _tbuf
    CHECK 18, 11
    CALL0 _av_buf_line_count, _tbuf
    CHECK 19, 2
    CALL1 _av_buf_line_start, _tbuf, 1
    CHECK 20, 6
    LADDR x0, _tbuf
    mov x1, #4
    mov x2, #3
    bl _av_buf_delete
    CALL0 _av_buf_len, _tbuf
    CHECK 21, 8
    CALL0 _av_buf_line_count, _tbuf
    CHECK 22, 1
    LADDR x0, _tbuf
    mov x1, #0
    LADDR x2, _tscratch
    mov x3, #8
    bl _av_buf_copy
    LADDR x0, _tscratch
    LADDR x1, Ls_exp
    mov x2, #8
    bl _memcmp
    sxtw x0, w0
    CHECK 23, 0

    // growth: append 20000 lines forces gap and line index reallocation
    mov x19, #20000
1:  CALL0 _av_buf_len, _tbuf
    mov x1, x0
    LADDR x0, _tbuf
    LADDR x2, Ls_ab
    mov x3, #3
    bl _av_buf_insert
    subs x19, x19, #1
    b.ne 1b
    CALL0 _av_buf_len, _tbuf
    CHECK 24, 60008
    CALL0 _av_buf_line_count, _tbuf
    CHECK 25, 20001
    CALL1 _av_buf_line_start, _tbuf, 20000
    CHECK 26, 60008
    CALL1 _av_buf_line_start, _tbuf, 1
    CHECK 27, 11

    // insert at the front, gap ends up mid-buffer before saving
    LADDR x0, _tbuf
    mov x1, #0
    LADDR x2, Ls_z
    mov x3, #2
    bl _av_buf_insert
    CALL0 _av_buf_line_count, _tbuf
    CHECK 28, 20002
    CALL1 _av_buf_line_start, _tbuf, 20001
    CHECK 29, 60010

    // save and reload
    LADDR x0, _tbuf
    LADDR x1, Ls_path
    bl _av_buf_save
    CHECK 30, 0
    LADDR x0, _tbuf2
    LADDR x1, Ls_path
    bl _av_buf_load
    CHECK 31, 0
    CALL0 _av_buf_len, _tbuf2
    CHECK 32, 60010
    CALL0 _av_buf_line_count, _tbuf2
    CHECK 33, 20002
    CALL1 _av_buf_line_start, _tbuf2, 20001
    CHECK 34, 60010
    CALL1 _av_buf_byte_at, _tbuf2, 2
    CHECK 45, 'h'

    // utf8 navigation over "a é € b"
    CALL1 _av_buf_init, _tbuf3, 0
    LADDR x0, _tbuf3
    mov x1, #0
    LADDR x2, Ls_utf8
    mov x3, #7
    bl _av_buf_insert
    CALL1 _av_utf8_next, _tbuf3, 1
    CHECK 35, 3
    CALL1 _av_utf8_next, _tbuf3, 3
    CHECK 36, 6
    CALL1 _av_utf8_prev, _tbuf3, 6
    CHECK 37, 3
    CALL1 _av_utf8_prev, _tbuf3, 3
    CHECK 38, 1
    CALL1 _av_utf8_next, _tbuf3, 6
    CHECK 39, 7
    CALL1 _av_utf8_next, _tbuf3, 7
    CHECK 40, 7

    // delete everything
    CALL0 _av_buf_len, _tbuf2
    mov x2, x0
    LADDR x0, _tbuf2
    mov x1, #0
    bl _av_buf_delete
    CALL0 _av_buf_len, _tbuf2
    CHECK 41, 0
    CALL0 _av_buf_line_count, _tbuf2
    CHECK 42, 1

    CALL0 _av_buf_free, _tbuf
    CALL0 _av_buf_free, _tbuf2
    CALL0 _av_buf_free, _tbuf3
    LADDR x0, Ls_path
    bl _unlink

    // summary
    sub sp, sp, #16
    LDRG x19, _tfails
    LDRG x20, _tchecks
    cbnz x19, 2f
    str x20, [sp]
    LADDR x0, Ls_ok
    bl _printf
    mov w0, #0
    b 3f
2:  stp x19, x20, [sp]
    LADDR x0, Ls_bad
    bl _printf
    mov w0, #1
3:  add sp, sp, #16
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// check(actual, expected, id)
    .p2align 2
Lcheck:
    LDRG x3, _tchecks
    add x3, x3, #1
    STRG x3, _tchecks, x4
    cmp x0, x1
    b.ne 1f
    ret
1:  stp x29, x30, [sp, #-48]!
    mov x29, sp
    LDRG x3, _tfails
    add x3, x3, #1
    STRG x3, _tfails, x4
    // printf varargs go on the stack: id, got, want
    sub sp, sp, #32
    str x2, [sp]
    stp x0, x1, [sp, #8]
    LADDR x0, Ls_fail
    bl _printf
    add sp, sp, #32
    ldp x29, x30, [sp], #48
    ret
