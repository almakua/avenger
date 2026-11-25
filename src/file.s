// file load (single read into the buffer) and atomic save (temp file + rename)

.include "macros.inc"
.include "buffer.inc"

.set O_RDONLY, 0
.set O_WRONLY_CREAT_TRUNC, 0x601
.set STAT_SIZE, 144
.set ST_MODE, 4
.set ST_SIZE, 96
.set PATH_MAX_LOCAL, 1000

    .section __TEXT,__cstring,cstring_literals
Ltmp_suffix:
    .asciz ".avtmp"

    .text
// int av_buf_load(Buffer *b, const char *path), b must be zeroed
FUNC_BEGIN _av_buf_load
    stp x29, x30, [sp, #-(64 + STAT_SIZE)]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov x0, x1
    mov w1, #O_RDONLY
    bl _open
    tbnz w0, #31, 9f
    mov w20, w0
    add x1, sp, #64
    bl _fstat
    cbnz w0, 8f
    ldr x21, [sp, #(64 + ST_SIZE)]
    mov x0, x19
    add x1, x21, #0x10000
    bl _av_buf_init
    cbnz x0, 8f
    mov x22, #0
1:  cmp x22, x21
    b.hs 2f
    mov w0, w20
    ldr x1, [x19, #BUF_DATA]
    add x1, x1, x22
    sub x2, x21, x22
    bl _read
    tbnz x0, #63, 7f
    cbz x0, 2f
    add x22, x22, x0
    b 1b
2:  mov w0, w20
    bl _close
    str x22, [x19, #BUF_GS]
    ldr x0, [x19, #BUF_DATA]
    mov x1, x22
    bl _av_count_newlines
    mov x23, x0
    mov x0, x19
    add x1, x23, #1
    bl _av_buf_lines_reserve
    cbnz x0, 6f
    ldr x0, [x19, #BUF_DATA]
    mov x1, x22
    ldr x2, [x19, #BUF_LINES]
    add x2, x2, #8
    mov x3, #1
    bl _av_find_newlines
    add x23, x23, #1
    str x23, [x19, #BUF_NLINES]
    str xzr, [x19, #BUF_FLAGS]
    mov x0, #0
    b 5f
7:  mov x0, x19
    bl _av_buf_free
8:  mov w0, w20
    bl _close
    b 9f
6:  mov x0, x19
    bl _av_buf_free
9:  mov x0, #-1
5:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #(64 + STAT_SIZE)
    ret

// int av_buf_save(Buffer *b, const char *path), keeps the original file mode
// locals: [sp, 16) open() vararg, [16, 160) stat, [160, 1184) temp path
FUNC_BEGIN _av_buf_save
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    sub sp, sp, #1184
    mov x19, x0
    mov x20, x1
    mov x0, x20
    bl _strlen
    cmp x0, #PATH_MAX_LOCAL
    b.hs 9f
    mov x21, x0
    add x0, sp, #160
    mov x1, x20
    mov x2, x21
    bl _memcpy
    add x0, sp, #160
    add x0, x0, x21
    LADDR x1, Ltmp_suffix
    mov x2, #7
    bl _memcpy

    mov x0, x20
    add x1, sp, #16
    bl _stat
    mov x22, #0x1a4
    cbnz w0, 1f
    ldrh w1, [sp, #(16 + ST_MODE)]
    and x22, x1, #0x1ff
    // open is variadic, Apple arm64 passes the mode on the stack
1:  str x22, [sp]
    add x0, sp, #160
    mov w1, #O_WRONLY_CREAT_TRUNC
    bl _open
    tbnz w0, #31, 9f
    mov w23, w0

    mov w0, w23
    ldr x1, [x19, #BUF_DATA]
    ldr x2, [x19, #BUF_GS]
    bl Lwrite_all
    cbnz x0, 7f
    ldr x1, [x19, #BUF_DATA]
    ldr x3, [x19, #BUF_GE]
    add x1, x1, x3
    ldr x2, [x19, #BUF_CAP]
    sub x2, x2, x3
    mov w0, w23
    bl Lwrite_all
    cbnz x0, 7f
    mov w0, w23
    bl _close
    add x0, sp, #160
    mov x1, x20
    bl _rename
    cbnz w0, 6f
    ldr x0, [x19, #BUF_FLAGS]
    and x0, x0, #~BUF_DIRTY
    str x0, [x19, #BUF_FLAGS]
    mov x0, #0
    b 5f
7:  mov w0, w23
    bl _close
6:  add x0, sp, #160
    bl _unlink
9:  mov x0, #-1
5:  add sp, sp, #1184
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// int write_all(int fd, const void *p, size_t n)
    .p2align 2
Lwrite_all:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov w19, w0
    mov x20, x1
    mov x21, x2
1:  cbz x21, 2f
    mov w0, w19
    mov x1, x20
    mov x2, x21
    bl _write
    cmp x0, #0
    b.le 3f
    add x20, x20, x0
    sub x21, x21, x0
    b 1b
2:  mov x0, #0
    b 4f
3:  mov x0, #-1
4:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
