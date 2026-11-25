// gap buffer with incremental line index and NEON newline scanning

.include "macros.inc"
.include "buffer.inc"

    .text
// int av_buf_init(Buffer *b, size_t cap), b must be zeroed
FUNC_BEGIN _av_buf_init
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x2, #BUF_MIN_CAP
    cmp x1, x2
    csel x20, x1, x2, hi
    mov x0, x20
    bl _av_pages_alloc
    cbz x0, 9f
    str x0, [x19, #BUF_DATA]
    str x20, [x19, #BUF_CAP]
    str xzr, [x19, #BUF_GS]
    str x20, [x19, #BUF_GE]
    mov x0, #(BUF_LINES_INIT * 8)
    bl _av_pages_alloc
    cbz x0, 9f
    str xzr, [x0]
    str x0, [x19, #BUF_LINES]
    mov x1, #1
    str x1, [x19, #BUF_NLINES]
    mov x1, #BUF_LINES_INIT
    str x1, [x19, #BUF_LCAP]
    str xzr, [x19, #BUF_FLAGS]
    mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_buf_free(Buffer *b)
FUNC_BEGIN _av_buf_free
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #BUF_DATA]
    ldr x1, [x19, #BUF_CAP]
    bl _av_pages_free
    ldr x0, [x19, #BUF_LINES]
    ldr x1, [x19, #BUF_LCAP]
    lsl x1, x1, #3
    bl _av_pages_free
    stp xzr, xzr, [x19]
    stp xzr, xzr, [x19, #16]
    stp xzr, xzr, [x19, #32]
    stp xzr, xzr, [x19, #48]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t av_buf_len(Buffer *b)
FUNC_BEGIN _av_buf_len
    ldr x1, [x0, #BUF_CAP]
    ldp x2, x3, [x0, #BUF_GS]
    sub x3, x3, x2
    sub x0, x1, x3
    ret

// size_t av_buf_line_count(Buffer *b)
FUNC_BEGIN _av_buf_line_count
    ldr x0, [x0, #BUF_NLINES]
    ret

// size_t av_buf_line_start(Buffer *b, size_t line)
FUNC_BEGIN _av_buf_line_start
    ldr x2, [x0, #BUF_LINES]
    ldr x0, [x2, x1, lsl #3]
    ret

// size_t av_buf_line_end(Buffer *b, size_t line), offset of the '\n' or len
FUNC_BEGIN _av_buf_line_end
    ldr x3, [x0, #BUF_NLINES]
    add x4, x1, #1
    cmp x4, x3
    b.hs _av_buf_len
    ldr x2, [x0, #BUF_LINES]
    ldr x0, [x2, x4, lsl #3]
    sub x0, x0, #1
    ret

// size_t av_buf_line_of(Buffer *b, size_t pos), binary search for last start <= pos
FUNC_BEGIN _av_buf_line_of
    ldr x2, [x0, #BUF_LINES]
    ldr x3, [x0, #BUF_NLINES]
    mov x4, #0
    sub x5, x3, #1
1:  cmp x4, x5
    b.hs 3f
    add x6, x4, x5
    add x6, x6, #1
    lsr x6, x6, #1
    ldr x7, [x2, x6, lsl #3]
    cmp x7, x1
    b.hi 2f
    mov x4, x6
    b 1b
2:  sub x5, x6, #1
    b 1b
3:  mov x0, x4
    ret

// uint8_t av_buf_byte_at(Buffer *b, size_t pos)
FUNC_BEGIN _av_buf_byte_at
    ldr x2, [x0, #BUF_DATA]
    ldp x3, x4, [x0, #BUF_GS]
    cmp x1, x3
    b.lo 1f
    sub x4, x4, x3
    add x1, x1, x4
1:  ldrb w0, [x2, x1]
    ret

// void av_buf_move_gap(Buffer *b, size_t pos)
FUNC_BEGIN _av_buf_move_gap
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x8, [x0, #BUF_DATA]
    ldp x9, x10, [x0, #BUF_GS]
    cmp x1, x9
    b.eq 3f
    b.hi 2f
    // gap moves left: text [pos, gs) slides to the end of the gap
    sub x2, x9, x1
    sub x10, x10, x2
    stp x1, x10, [x0, #BUF_GS]
    add x0, x8, x10
    add x1, x8, x1
    bl _memmove
    b 3f
    // gap moves right: text [ge, ge + n) slides to gs
2:  sub x2, x1, x9
    add x11, x10, x2
    stp x1, x11, [x0, #BUF_GS]
    add x0, x8, x9
    add x1, x8, x10
    bl _memmove
3:  ldp x29, x30, [sp], #16
    ret

// int av_buf_reserve(Buffer *b, size_t n), ensures gap >= n
FUNC_BEGIN _av_buf_reserve
    ldp x2, x3, [x0, #BUF_GS]
    sub x4, x3, x2
    cmp x4, x1
    b.lo 1f
    mov x0, #0
    ret
1:  stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    ldr x21, [x19, #BUF_CAP]
    mov x22, x2
    mov x23, x3
    // newcap = max(cap * 2, len + n + 64K)
    sub x0, x21, x4
    add x0, x0, x1
    add x0, x0, #0x10000
    lsl x2, x21, #1
    cmp x2, x0
    csel x24, x2, x0, hi
    mov x0, x24
    bl _av_pages_alloc
    cbz x0, 9f
    mov x25, x0
    ldr x1, [x19, #BUF_DATA]
    mov x2, x22
    bl _memcpy
    sub x26, x21, x23
    sub x0, x24, x26
    add x0, x25, x0
    ldr x1, [x19, #BUF_DATA]
    add x1, x1, x23
    mov x2, x26
    bl _memcpy
    ldr x0, [x19, #BUF_DATA]
    mov x1, x21
    bl _av_pages_free
    str x25, [x19, #BUF_DATA]
    str x24, [x19, #BUF_CAP]
    sub x0, x24, x26
    str x0, [x19, #BUF_GE]
    mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// int av_buf_lines_reserve(Buffer *b, size_t need), capacity in entries
FUNC_BEGIN _av_buf_lines_reserve
    ldr x2, [x0, #BUF_LCAP]
    cmp x2, x1
    b.lo 1f
    mov x0, #0
    ret
1:  stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x21, x2
    add x1, x1, #1024
    lsl x2, x2, #1
    cmp x2, x1
    csel x20, x2, x1, hi
    lsl x0, x20, #3
    bl _av_pages_alloc
    cbz x0, 9f
    mov x22, x0
    ldr x1, [x19, #BUF_LINES]
    ldr x2, [x19, #BUF_NLINES]
    lsl x2, x2, #3
    bl _memcpy
    ldr x0, [x19, #BUF_LINES]
    lsl x1, x21, #3
    bl _av_pages_free
    str x22, [x19, #BUF_LINES]
    str x20, [x19, #BUF_LCAP]
    mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_buf_insert(Buffer *b, size_t pos, const char *src, size_t n)
FUNC_BEGIN _av_buf_insert
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    cbz x22, 7f
    mov x1, x22
    bl _av_buf_reserve
    cbnz x0, 9f
    mov x0, x19
    mov x1, x20
    bl _av_buf_move_gap
    ldr x0, [x19, #BUF_DATA]
    ldr x1, [x19, #BUF_GS]
    add x0, x0, x1
    mov x1, x21
    mov x2, x22
    bl _memcpy
    ldr x1, [x19, #BUF_GS]
    add x1, x1, x22
    str x1, [x19, #BUF_GS]

    mov x0, x21
    mov x1, x22
    bl _av_count_newlines
    mov x24, x0
    mov x0, x19
    mov x1, x20
    bl _av_buf_line_of
    mov x23, x0
    cbz x24, 1f
    ldr x1, [x19, #BUF_NLINES]
    add x1, x1, x24
    mov x0, x19
    bl _av_buf_lines_reserve
    cbnz x0, 9f
    // open a hole of k entries after line L, then fill it with the new starts
    ldr x8, [x19, #BUF_LINES]
    ldr x9, [x19, #BUF_NLINES]
    add x10, x23, #1
    add x1, x8, x10, lsl #3
    add x0, x1, x24, lsl #3
    sub x2, x9, x10
    lsl x2, x2, #3
    bl _memmove
    ldr x8, [x19, #BUF_LINES]
    add x2, x8, x23, lsl #3
    add x2, x2, #8
    mov x0, x21
    mov x1, x22
    add x3, x20, #1
    bl _av_find_newlines
    ldr x9, [x19, #BUF_NLINES]
    add x9, x9, x24
    str x9, [x19, #BUF_NLINES]
    // lines after the inserted ones shift by n
1:  ldr x8, [x19, #BUF_LINES]
    ldr x9, [x19, #BUF_NLINES]
    add x10, x23, #1
    add x10, x10, x24
    add x0, x8, x10, lsl #3
    sub x1, x9, x10
    mov x2, x22
    bl _av_lines_shift
    ldr x0, [x19, #BUF_FLAGS]
    orr x0, x0, #BUF_DIRTY
    str x0, [x19, #BUF_FLAGS]
7:  mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_buf_delete(Buffer *b, size_t pos, size_t n), n clamped to len
FUNC_BEGIN _av_buf_delete
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _av_buf_len
    subs x1, x0, x20
    b.ls 8f
    cmp x21, x1
    csel x21, x1, x21, hi
    cbz x21, 8f
    // starts in (pos, pos + n] follow a deleted '\n' and go away
    mov x0, x19
    mov x1, x20
    bl _av_buf_line_of
    add x22, x0, #1
    mov x0, x19
    add x1, x20, x21
    bl _av_buf_line_of
    add x3, x0, #1
    cmp x22, x3
    b.eq 1f
    ldr x8, [x19, #BUF_LINES]
    ldr x9, [x19, #BUF_NLINES]
    sub x10, x3, x22
    sub x11, x9, x10
    str x11, [x19, #BUF_NLINES]
    add x0, x8, x22, lsl #3
    add x1, x8, x3, lsl #3
    sub x2, x9, x3
    lsl x2, x2, #3
    bl _memmove
1:  ldr x8, [x19, #BUF_LINES]
    ldr x9, [x19, #BUF_NLINES]
    add x0, x8, x22, lsl #3
    sub x1, x9, x22
    neg x2, x21
    bl _av_lines_shift
    mov x0, x19
    mov x1, x20
    bl _av_buf_move_gap
    ldr x1, [x19, #BUF_GE]
    add x1, x1, x21
    str x1, [x19, #BUF_GE]
    ldr x0, [x19, #BUF_FLAGS]
    orr x0, x0, #BUF_DIRTY
    str x0, [x19, #BUF_FLAGS]
8:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_buf_copy(Buffer *b, size_t pos, char *dst, size_t n), copies logical range out
FUNC_BEGIN _av_buf_copy
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x8, [x19, #BUF_DATA]
    ldr x9, [x19, #BUF_GS]
    cmp x20, x9
    b.hs 1f
    sub x2, x9, x20
    cmp x2, x22
    csel x23, x2, x22, lo
    mov x2, x23
    add x1, x8, x20
    mov x0, x21
    bl _memcpy
    add x21, x21, x23
    add x20, x20, x23
    sub x22, x22, x23
1:  cbz x22, 2f
    ldr x8, [x19, #BUF_DATA]
    ldp x9, x10, [x19, #BUF_GS]
    sub x10, x10, x9
    add x1, x20, x10
    add x1, x8, x1
    mov x0, x21
    mov x2, x22
    bl _memcpy
2:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// size_t av_utf8_next(Buffer *b, size_t pos), skips continuation bytes
FUNC_BEGIN _av_utf8_next
    ldr x8, [x0, #BUF_DATA]
    ldr x9, [x0, #BUF_CAP]
    ldp x10, x11, [x0, #BUF_GS]
    sub x12, x11, x10
    sub x9, x9, x12
    cmp x1, x9
    b.hs 3f
    add x1, x1, #1
1:  cmp x1, x9
    b.hs 2f
    add x13, x1, x12
    cmp x1, x10
    csel x13, x1, x13, lo
    ldrb w14, [x8, x13]
    and w14, w14, #0xc0
    cmp w14, #0x80
    b.ne 2f
    add x1, x1, #1
    b 1b
2:  mov x0, x1
    ret
3:  mov x0, x9
    ret

// size_t av_utf8_prev(Buffer *b, size_t pos)
FUNC_BEGIN _av_utf8_prev
    cbz x1, 2f
    ldr x8, [x0, #BUF_DATA]
    ldp x10, x11, [x0, #BUF_GS]
    sub x12, x11, x10
    sub x1, x1, #1
1:  cbz x1, 2f
    add x13, x1, x12
    cmp x1, x10
    csel x13, x1, x13, lo
    ldrb w14, [x8, x13]
    and w14, w14, #0xc0
    cmp w14, #0x80
    b.ne 2f
    sub x1, x1, #1
    b 1b
2:  mov x0, x1
    ret

// void av_lines_shift(size_t *p, size_t count, size_t delta), two entries per NEON op
FUNC_BEGIN _av_lines_shift
    dup v1.2d, x2
1:  cmp x1, #2
    b.lo 2f
    ldr q0, [x0]
    add v0.2d, v0.2d, v1.2d
    str q0, [x0], #16
    sub x1, x1, #2
    b 1b
2:  cbz x1, 3f
    ldr x3, [x0]
    add x3, x3, x2
    str x3, [x0]
3:  ret

// size_t av_count_newlines(const char *p, size_t n)
FUNC_BEGIN _av_count_newlines
    movi v31.16b, #10
    mov x2, #0
1:  cmp x1, #16
    b.lo 2f
    ldr q0, [x0], #16
    cmeq v0.16b, v0.16b, v31.16b
    ushr v0.16b, v0.16b, #7
    addv b0, v0.16b
    umov w3, v0.b[0]
    add x2, x2, x3
    sub x1, x1, #16
    b 1b
2:  cbz x1, 3f
    ldrb w3, [x0], #1
    cmp w3, #10
    cinc x2, x2, eq
    sub x1, x1, #1
    b 2b
3:  mov x0, x2
    ret

// void av_find_newlines(const char *p, size_t n, size_t *out, size_t base)
// writes base + i for each '\n' at index i, chunks without newlines are skipped
FUNC_BEGIN _av_find_newlines
    movi v31.16b, #10
    sub x3, x3, #1
    sub x3, x3, x0
1:  cmp x1, #16
    b.lo 3f
    ldr q0, [x0]
    cmeq v0.16b, v0.16b, v31.16b
    umaxv b1, v0.16b
    umov w5, v1.b[0]
    cbnz w5, 2f
    add x0, x0, #16
    sub x1, x1, #16
    b 1b
2:  mov x6, #16
    sub x1, x1, #16
4:  ldrb w5, [x0], #1
    cmp w5, #10
    b.ne 5f
    add x7, x0, x3
    str x7, [x2], #8
5:  subs x6, x6, #1
    b.ne 4b
    b 1b
3:  cbz x1, 6f
    ldrb w5, [x0], #1
    cmp w5, #10
    b.ne 7f
    add x7, x0, x3
    str x7, [x2], #8
7:  sub x1, x1, #1
    b 3b
6:  ret
