// document: buffer plus linear undo log, consecutive typing and deleting merge into one record

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"

.set UNDO_INIT, 0x10000

    .text
// int av_doc_init(Doc *d), d must be zeroed
FUNC_BEGIN _av_doc_init
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x1, #0
    bl _av_buf_init
    cbnz x0, 1f
    mov x0, x19
    bl Lundo_init
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_doc_open(Doc *d, const char *path), a missing file opens empty and is created on save
FUNC_BEGIN _av_doc_open
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    str x20, [x19, #DOC_PATH]
    bl _av_buf_load
    cbz x0, 1f
    mov x0, x19
    mov x1, #0
    bl _av_buf_init
    cbnz x0, 2f
1:  mov x0, x19
    bl Lundo_init
    mov x20, x0
    mov x0, x19
    bl _av_hl_detect
    mov x0, x20
2:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .p2align 2
Lundo_init:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x0, #UNDO_INIT
    bl _av_pages_alloc
    cbz x0, 9f
    str x0, [x19, #DOC_U_DATA]
    mov x1, #UNDO_INIT
    str x1, [x19, #DOC_U_CAP]
    stp xzr, xzr, [x19, #DOC_U_LEN]
    mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int undo_reserve(Doc *d, size_t n), room for n bytes after u_pos
    .p2align 2
Lundo_reserve:
    ldr x2, [x0, #DOC_U_CAP]
    ldr x3, [x0, #DOC_U_POS]
    sub x4, x2, x3
    cmp x4, x1
    b.lo 1f
    mov x0, #0
    ret
1:  stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    add x1, x3, x1
    add x1, x1, #UNDO_INIT
    lsl x4, x2, #1
    cmp x4, x1
    csel x20, x4, x1, hi
    ldr x0, [x19, #DOC_U_DATA]
    mov x1, x3
    mov x3, x20
    bl _av_pages_grow
    cbz x0, 9f
    str x0, [x19, #DOC_U_DATA]
    str x20, [x19, #DOC_U_CAP]
    mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// x24 = last record of doc x19 if its type is w1, else 0; clobbers x9..x13
.macro LAST_RECORD type
    mov x24, #0
    ldr x9, [x19, #DOC_U_POS]
    cbz x9, 99f
    ldr x10, [x19, #DOC_U_DATA]
    add x11, x10, x9
    ldur x12, [x11, #-8]
    sub x11, x11, x12
    ldr w13, [x11, #UR_TYPE]
    cmp w13, #\type
    b.ne 99f
    mov x24, x11
99:
.endm

// rewrite footer of record x24 after its len changed, advance u_pos/u_len by x21
.macro FINISH_GROW n
    ldr x15, [x24, #UR_LEN]
    add x15, x15, \n
    str x15, [x24, #UR_LEN]
    add x0, x24, #UR_TEXT
    add x1, x15, #UR_OVERHEAD
    str x1, [x0, x15]
    ldr x9, [x19, #DOC_U_POS]
    add x9, x9, \n
    stp x9, x9, [x19, #DOC_U_LEN]
.endm

// int av_doc_insert(Doc *d, size_t pos, const char *src, size_t n, int flags)
FUNC_BEGIN _av_doc_insert
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    cbz x22, 7f
    // a new edit drops the redo tail
    ldr x0, [x19, #DOC_U_POS]
    str x0, [x19, #DOC_U_LEN]

    tbz x23, #1, 2f
    ldrb w0, [x21]
    cmp w0, #10
    b.eq 2f
    LAST_RECORD UR_INSERT
    cbz x24, 2f
    ldp x14, x15, [x24, #UR_POS]
    add x16, x14, x15
    cmp x16, x20
    b.ne 2f
    // word granularity: a non-space after a space starts a new record
    add x17, x24, #UR_TEXT
    add x17, x17, x15
    ldurb w16, [x17, #-1]
    cmp w16, #' '
    b.ne 1f
    ldrb w0, [x21]
    cmp w0, #' '
    b.ne 2f
1:  ldr x10, [x19, #DOC_U_DATA]
    sub x24, x24, x10
    mov x0, x19
    mov x1, x22
    bl Lundo_reserve
    cbnz x0, 9f
    ldr x10, [x19, #DOC_U_DATA]
    add x24, x10, x24
    ldr x15, [x24, #UR_LEN]
    add x0, x24, #UR_TEXT
    add x0, x0, x15
    mov x1, x21
    mov x2, x22
    bl _memcpy
    FINISH_GROW x22
    b 6f

2:  mov x0, x19
    add x1, x22, #UR_OVERHEAD
    bl Lundo_reserve
    cbnz x0, 9f
    ldr x10, [x19, #DOC_U_DATA]
    ldr x9, [x19, #DOC_U_POS]
    add x24, x10, x9
    mov w0, #UR_INSERT
    and w1, w23, #EF_JOIN
    stp w0, w1, [x24, #UR_TYPE]
    stp x20, x22, [x24, #UR_POS]
    add x0, x24, #UR_TEXT
    mov x1, x21
    mov x2, x22
    bl _memcpy
    add x0, x24, #UR_TEXT
    add x1, x22, #UR_OVERHEAD
    str x1, [x0, x22]
    ldr x9, [x19, #DOC_U_POS]
    add x9, x9, x1
    stp x9, x9, [x19, #DOC_U_LEN]

6:  mov x0, x19
    mov x1, x20
    bl _av_hl_invalidate
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x3, x22
    bl _av_buf_insert
    b 8f
7:  mov x0, #0
    b 8f
9:  mov x0, #-1
8:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_doc_delete(Doc *d, size_t pos, size_t n, int flags)
FUNC_BEGIN _av_doc_delete
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x23, x3
    bl _av_buf_len
    subs x1, x0, x20
    b.ls 8f
    cmp x21, x1
    csel x21, x1, x21, hi
    cbz x21, 8f
    ldr x0, [x19, #DOC_U_POS]
    str x0, [x19, #DOC_U_LEN]

    tbz x23, #1, 3f
    LAST_RECORD UR_DELETE
    cbz x24, 3f
    ldr x14, [x24, #UR_POS]
    add x16, x20, x21
    cmp x16, x14
    b.eq 1f
    cmp x20, x14
    b.eq 2f
    b 3f

    // backspace: deleted text goes in front of the record text
1:  ldr x10, [x19, #DOC_U_DATA]
    sub x24, x24, x10
    mov x0, x19
    mov x1, x21
    bl Lundo_reserve
    cbnz x0, 8f
    ldr x10, [x19, #DOC_U_DATA]
    add x24, x10, x24
    add x1, x24, #UR_TEXT
    add x0, x1, x21
    ldr x2, [x24, #UR_LEN]
    add x2, x2, #8
    bl _memmove
    mov x0, x19
    mov x1, x20
    add x2, x24, #UR_TEXT
    mov x3, x21
    bl _av_buf_copy
    str x20, [x24, #UR_POS]
    FINISH_GROW x21
    b 6f

    // forward delete: deleted text goes after the record text
2:  ldr x10, [x19, #DOC_U_DATA]
    sub x24, x24, x10
    mov x0, x19
    mov x1, x21
    bl Lundo_reserve
    cbnz x0, 8f
    ldr x10, [x19, #DOC_U_DATA]
    add x24, x10, x24
    mov x0, x19
    mov x1, x20
    add x2, x24, #UR_TEXT
    ldr x3, [x24, #UR_LEN]
    add x2, x2, x3
    mov x3, x21
    bl _av_buf_copy
    FINISH_GROW x21
    b 6f

3:  mov x0, x19
    add x1, x21, #UR_OVERHEAD
    bl Lundo_reserve
    cbnz x0, 8f
    ldr x10, [x19, #DOC_U_DATA]
    ldr x9, [x19, #DOC_U_POS]
    add x24, x10, x9
    mov w0, #UR_DELETE
    and w1, w23, #EF_JOIN
    stp w0, w1, [x24, #UR_TYPE]
    stp x20, x21, [x24, #UR_POS]
    mov x0, x19
    mov x1, x20
    add x2, x24, #UR_TEXT
    mov x3, x21
    bl _av_buf_copy
    add x0, x24, #UR_TEXT
    add x1, x21, #UR_OVERHEAD
    str x1, [x0, x21]
    ldr x9, [x19, #DOC_U_POS]
    add x9, x9, x1
    stp x9, x9, [x19, #DOC_U_LEN]

6:  mov x0, x19
    mov x1, x20
    bl _av_hl_invalidate
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl _av_buf_delete
8:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ssize_t av_doc_undo(Doc *d), new cursor or -1 when nothing to undo
FUNC_BEGIN _av_doc_undo
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, #-1
1:  ldr x9, [x19, #DOC_U_POS]
    cbz x9, 8f
    ldr x10, [x19, #DOC_U_DATA]
    add x11, x10, x9
    ldur x12, [x11, #-8]
    sub x21, x11, x12
    sub x9, x9, x12
    str x9, [x19, #DOC_U_POS]
    ldr x1, [x21, #UR_POS]
    mov x0, x19
    bl _av_hl_invalidate
    ldr w13, [x21, #UR_TYPE]
    ldp x1, x2, [x21, #UR_POS]
    cmp w13, #UR_INSERT
    b.ne 2f
    mov x20, x1
    mov x0, x19
    bl _av_buf_delete
    b 3f
2:  add x20, x1, x2
    mov x3, x2
    add x2, x21, #UR_TEXT
    mov x0, x19
    bl _av_buf_insert
3:  ldr w13, [x21, #UR_FLAGS]
    tbnz w13, #0, 1b
8:  mov x0, x20
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ssize_t av_doc_redo(Doc *d), new cursor or -1 when nothing to redo
FUNC_BEGIN _av_doc_redo
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, #-1
1:  ldr x9, [x19, #DOC_U_POS]
    ldr x14, [x19, #DOC_U_LEN]
    cmp x9, x14
    b.hs 8f
    ldr x10, [x19, #DOC_U_DATA]
    add x21, x10, x9
    ldp x1, x2, [x21, #UR_POS]
    add x12, x2, #UR_OVERHEAD
    add x9, x9, x12
    str x9, [x19, #DOC_U_POS]
    ldr x1, [x21, #UR_POS]
    mov x0, x19
    bl _av_hl_invalidate
    ldp x1, x2, [x21, #UR_POS]
    ldr w13, [x21, #UR_TYPE]
    cmp w13, #UR_INSERT
    b.ne 2f
    add x20, x1, x2
    mov x3, x2
    add x2, x21, #UR_TEXT
    mov x0, x19
    bl _av_buf_insert
    b 3f
2:  mov x20, x1
    mov x0, x19
    bl _av_buf_delete
    // keep going while the next record is joined to this one
3:  ldr x9, [x19, #DOC_U_POS]
    ldr x14, [x19, #DOC_U_LEN]
    cmp x9, x14
    b.hs 8f
    ldr x10, [x19, #DOC_U_DATA]
    add x11, x10, x9
    ldr w13, [x11, #UR_FLAGS]
    tbnz w13, #0, 1b
8:  mov x0, x20
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
