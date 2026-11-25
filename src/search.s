// text search over the gap buffer (no gap move, so drawing can search too), replace all,
// fuzzy scoring for the command palette

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"

.set FIND_ICASE, 1             // ASCII letters match either case

    .text
// fold w reg to lower case when it is an ASCII capital, clobbers w17
.macro FOLD w
    sub w17, \w, #'A'
    cmp w17, #25
    b.hi 99f
    orr \w, \w, #0x20
99:
.endm

// int match_at(Buffer *b, size_t pos, const char *pat, size_t n, int flags): pat at pos
// caller guarantees pos + n <= len; clobbers x8..x17
    .p2align 2
Lmatch_at:
    BUF_GEOM x0
    mov x9, #0
1:  cmp x9, x3
    b.hs 8f
    add x14, x1, x9
    BUF_BYTE w15, x14
    ldrb w16, [x2, x9]
    add x9, x9, #1
    cmp w15, w16
    b.eq 1b
    tbz w4, #0, 9f
    FOLD w15
    FOLD w16
    cmp w15, w16
    b.eq 1b
9:  mov w0, #0
    ret
8:  mov w0, #1
    ret

// ssize_t av_buf_find(Buffer *b, size_t from, size_t end, const char *pat, size_t n, int flags)
// first match lying inside [from, end), -1 if none; exact matches use memmem on each side of
// the gap and check only the few starts that straddle it
FUNC_BEGIN _av_buf_find
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    cbz x23, 8f
    subs x9, x21, x20
    b.lo 8f
    cmp x9, x23
    b.lo 8f
    // last possible start
    sub x25, x21, x23
    tbnz x24, #0, 5f
    // before the gap
    ldr x10, [x19, #BUF_GS]
    cmp x10, x21
    csel x11, x10, x21, lo
    subs x2, x11, x20
    b.lo 2f
    cmp x2, x23
    b.lo 2f
    ldr x9, [x19, #BUF_DATA]
    add x0, x9, x20
    mov x1, x2
    mov x2, x22
    mov x3, x23
    bl _memmem
    cbz x0, 2f
    ldr x9, [x19, #BUF_DATA]
    sub x0, x0, x9
    b 9f
    // starts in (gs - n, gs) cross the gap
2:  ldr x10, [x19, #BUF_GS]
    sub x9, x10, x23
    add x9, x9, #1
    cmp x9, x20
    csel x9, x20, x9, lt
3:  cmp x9, x10
    b.ge 4f
    cmp x9, x25
    b.gt 8f
    stp x9, x10, [sp, #80]
    mov x0, x19
    mov x1, x9
    mov x2, x22
    mov x3, x23
    mov x4, x24
    bl Lmatch_at
    ldp x9, x10, [sp, #80]
    cbnz w0, 7f
    add x9, x9, #1
    b 3b
    // after the gap
4:  ldr x10, [x19, #BUF_GS]
    cmp x20, x10
    csel x11, x20, x10, hi
    subs x1, x21, x11
    b.lo 8f
    cmp x1, x23
    b.lo 8f
    ldr x9, [x19, #BUF_DATA]
    ldr x12, [x19, #BUF_GE]
    sub x12, x12, x10
    add x0, x9, x11
    add x0, x0, x12
    mov x2, x22
    mov x3, x23
    bl _memmem
    cbz x0, 8f
    ldr x9, [x19, #BUF_DATA]
    sub x0, x0, x9
    ldp x10, x12, [x19, #BUF_GS]
    sub x12, x12, x10
    sub x0, x0, x12
    b 9f
    // folding: every start, the first byte filters
5:  mov x9, x20
6:  cmp x9, x25
    b.hi 8f
    str x9, [sp, #80]
    mov x0, x19
    mov x1, x9
    mov x2, x22
    mov x3, x23
    mov x4, x24
    bl Lmatch_at
    ldr x9, [sp, #80]
    cbnz w0, 7f
    add x9, x9, #1
    b 6b
7:  mov x0, x9
    b 9f
8:  mov x0, #-1
9:  ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// ssize_t av_buf_find_back(Buffer *b, size_t before, const char *pat, size_t n, int flags)
// last match starting before before, -1 if none
FUNC_BEGIN _av_buf_find_back
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x21, x2
    mov x22, x3
    mov x23, x4
    cbz x22, 8f
    mov x24, x1
    bl _av_buf_len
    subs x9, x0, x22
    b.lo 8f
    sub x20, x24, #1
    cmp x20, x9
    csel x20, x9, x20, gt
1:  tbnz x20, #63, 8f
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    mov x4, x23
    bl Lmatch_at
    cbnz w0, 7f
    sub x20, x20, #1
    b 1b
7:  mov x0, x20
    b 9f
8:  mov x0, #-1
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// size_t av_buf_count(Buffer *b, size_t limit, const char *pat, size_t n, int flags)
// non-overlapping matches, scanning from the start, that begin before limit
FUNC_BEGIN _av_buf_count
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, #0
    mov x25, #0
    cbz x22, 9f
    bl _av_buf_len
    mov x9, x0
    str x9, [sp, #72]
1:  mov x0, x19
    mov x1, x25
    ldr x2, [sp, #72]
    mov x3, x21
    mov x4, x22
    mov x5, x23
    bl _av_buf_find
    tbnz x0, #63, 9f
    cmp x0, x20
    b.hs 9f
    add x24, x24, #1
    add x25, x0, x22
    b 1b
9:  mov x0, x24
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// size_t av_doc_replace_all(Doc *d, const char *pat, size_t n, const char *rep, size_t rn, int flags)
// one undo step for the whole batch, returns the number of replacements
FUNC_BEGIN _av_doc_replace_all
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, #0                // next search start
    mov x26, #0                // count
    cbz x21, 9f
1:  mov x0, x19
    bl _av_buf_len
    mov x2, x0
    mov x0, x19
    mov x1, x25
    mov x3, x20
    mov x4, x21
    mov x5, x24
    bl _av_buf_find
    tbnz x0, #63, 9f
    str x0, [sp, #80]
    // the first record starts the step, the rest join it
    cmp x26, #0
    mov x3, #EF_JOIN
    csel x3, xzr, x3, eq
    mov x1, x0
    mov x2, x21
    mov x0, x19
    bl _av_doc_delete
    mov x0, x19
    ldr x1, [sp, #80]
    mov x2, x22
    mov x3, x23
    mov x4, #EF_JOIN
    bl _av_doc_insert
    ldr x25, [sp, #80]
    add x25, x25, x23
    add x26, x26, #1
    b 1b
9:  mov x0, x26
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// long av_fuzzy_score(const char *query, const char *cand): -1 unless query is a subsequence
// of cand (ignoring ASCII case); higher is better, word starts and runs score extra
FUNC_BEGIN _av_fuzzy_score
    mov x2, #0                 // score
    mov x3, #-2                // index of the previous match
    mov x4, #0                 // cand index
    mov w5, #' '               // previous cand byte
1:  ldrb w6, [x0]
    cbz w6, 8f
    FOLD w6
2:  ldrb w7, [x1, x4]
    cbz w7, 7f
    mov w9, w7
    FOLD w9
    cmp w9, w6
    b.eq 3f
    mov w5, w7
    add x4, x4, #1
    b 2b
3:  add x2, x2, #1
    // after a separator or at the start
    mov w10, #'_'
    mov w11, #'-'
    mov w12, #'/'
    mov w13, #'.'
    cmp w5, #' '
    ccmp w5, w10, #4, ne
    ccmp w5, w11, #4, ne
    ccmp w5, w12, #4, ne
    ccmp w5, w13, #4, ne
    b.ne 4f
    add x2, x2, #8
4:  add x9, x3, #1
    cmp x9, x4
    b.ne 5f
    add x2, x2, #4
5:  mov x3, x4
    mov w5, w7
    add x4, x4, #1
    add x0, x0, #1
    b 1b
7:  mov x0, #-1
    ret
8:  mov x0, x2
    ret
