// view-level editing: cursor, selection, movement, columns; no AppKit so it is unit-testable

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"

    .section __TEXT,__const
Lspaces:
    .ascii "                "

    // spaces per tab stop, set from config (1..16)
    .section __DATA,__data
    .globl _av_tab_width
    .p2align 3
_av_tab_width:
    .quad TAB_WIDTH

    // row start columns of the last av_wrap_locate
    .zerofill __DATA,__bss,_av_wrap_starts,(WRAP_MAX * 8),3
    .globl _av_wrap_starts

    .text
// size_t av_col_of(Buffer *b, size_t pos), visual column with tab stops
FUNC_BEGIN _av_col_of
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x19
    bl _av_buf_line_start
    mov x2, x0
    mov x3, #0
    BUF_GEOM x19
1:  cmp x2, x20
    b.hs 3f
    BUF_BYTE w4, x2
    add x2, x2, #1
    and w5, w4, #0xc0
    cmp w5, #0x80
    b.eq 1b
    cmp w4, #9
    b.ne 2f
    LDRG x14, _av_tab_width
    udiv x15, x3, x14
    madd x3, x15, x14, x14
    b 1b
2:  add x3, x3, #1
    b 1b
3:  mov x0, x3
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t av_pos_at_col(Buffer *b, size_t line, size_t col), clamps to line end
FUNC_BEGIN _av_pos_at_col
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _av_buf_line_start
    mov x22, x0
    mov x0, x19
    mov x1, x20
    bl _av_buf_line_end
    mov x5, x0
    mov x2, x22
    mov x3, #0
    BUF_GEOM x19
1:  cmp x2, x5
    b.hs 4f
    BUF_BYTE w4, x2
    add x6, x3, #1
    cmp w4, #9
    b.ne 2f
    LDRG x14, _av_tab_width
    udiv x15, x3, x14
    madd x6, x15, x14, x14
2:  cmp x6, x21
    b.hi 4f
    mov x3, x6
    add x2, x2, #1
3:  cmp x2, x5
    b.hs 1b
    BUF_BYTE w4, x2
    and w4, w4, #0xc0
    cmp w4, #0x80
    b.ne 1b
    add x2, x2, #1
    b 3b
4:  mov x0, x2
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// (start, end) av_view_sel(View *v)
FUNC_BEGIN _av_view_sel
    SEL_RANGE x0, x2, x3
    mov x0, x2
    mov x1, x3
    ret

// void av_view_set_cursor(View *v, size_t pos, int extend)
FUNC_BEGIN _av_view_set_cursor
    str x1, [x0, #V_CUR]
    cbnz x2, 1f
    str x1, [x0, #V_ANCHOR]
1:  mov x1, #-1
    str x1, [x0, #V_PREFCOL]
    ret

// int av_view_delete_sel(View *v, int flags), 1 if something was deleted
FUNC_BEGIN _av_view_delete_sel
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    SEL_RANGE x19, x21, x22
    cmp x21, x22
    b.eq 7f
    ldr x0, [x19, #V_DOC]
    mov x1, x21
    sub x2, x22, x21
    mov x3, x20
    bl _av_doc_delete
    stp x21, x21, [x19, #V_CUR]
    mov x0, #1
    b 8f
7:  mov x0, #0
8:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_insert(View *v, const char *src, size_t n, int merge)
// replacing a selection is a single undo step (delete + joined insert)
FUNC_BEGIN _av_view_insert
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x1, #0
    bl _av_view_delete_sel
    mov x4, #EF_JOIN
    cbnz x0, 1f
    cmp x22, #0
    mov x4, #EF_MERGE
    csel x4, x4, xzr, ne
1:  ldr x0, [x19, #V_DOC]
    ldr x1, [x19, #V_CUR]
    mov x2, x20
    mov x3, x21
    bl _av_doc_insert
    ldr x1, [x19, #V_CUR]
    add x1, x1, x21
    stp x1, x1, [x19, #V_CUR]
    mov x0, #-1
    str x0, [x19, #V_PREFCOL]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_backspace(View *v)
FUNC_BEGIN _av_view_backspace
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x1, #0
    bl _av_view_delete_sel
    cbnz x0, 8f
    ldr x20, [x19, #V_CUR]
    cbz x20, 8f
    ldr x0, [x19, #V_DOC]
    mov x1, x20
    bl _av_utf8_prev
    mov x21, x0
    ldr x0, [x19, #V_DOC]
    mov x1, x21
    sub x2, x20, x21
    mov x3, #EF_MERGE
    bl _av_doc_delete
    stp x21, x21, [x19, #V_CUR]
8:  mov x0, #-1
    str x0, [x19, #V_PREFCOL]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_delete_fwd(View *v)
FUNC_BEGIN _av_view_delete_fwd
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x1, #0
    bl _av_view_delete_sel
    cbnz x0, 8f
    ldr x20, [x19, #V_CUR]
    ldr x0, [x19, #V_DOC]
    mov x1, x20
    bl _av_utf8_next
    mov x21, x0
    cmp x21, x20
    b.ls 8f
    ldr x0, [x19, #V_DOC]
    mov x1, x20
    sub x2, x21, x20
    mov x3, #EF_MERGE
    bl _av_doc_delete
8:  mov x0, #-1
    str x0, [x19, #V_PREFCOL]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_newline(View *v), keeps the leading whitespace of the current line
FUNC_BEGIN _av_view_newline
    stp x29, x30, [sp, #-304]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x20, [x19, #V_DOC]
    ldr x1, [x19, #V_CUR]
    mov x0, x20
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x20
    bl _av_buf_line_start
    mov x2, x0
    ldr x5, [x19, #V_CUR]
    add x6, sp, #48
    mov w4, #10
    strb w4, [x6], #1
    mov x7, #1
    BUF_GEOM x20
1:  cmp x2, x5
    b.hs 2f
    cmp x7, #255
    b.hs 2f
    BUF_BYTE w4, x2
    cmp w4, #' '
    b.eq 3f
    cmp w4, #9
    b.ne 2f
3:  strb w4, [x6], #1
    add x7, x7, #1
    add x2, x2, #1
    b 1b
2:  mov x0, x19
    add x1, sp, #48
    mov x2, x7
    mov x3, #0
    bl _av_view_insert
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #304
    ret

// void av_view_tab(View *v), soft tab up to the next stop
FUNC_BEGIN _av_view_tab
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #V_DOC]
    ldr x1, [x19, #V_CUR]
    bl _av_col_of
    LDRG x14, _av_tab_width
    udiv x15, x0, x14
    msub x1, x15, x14, x0
    sub x2, x14, x1
    mov x0, x19
    LADDR x1, Lspaces
    mov x3, #1
    bl _av_view_insert
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// character class for word motion: 0 blank, 1 word, 2 punctuation, 3 newline
// in w0, out w0, clobbers w14 only
    .p2align 2
Lclass:
    cmp w0, #' '
    b.eq 1f
    cmp w0, #9
    b.eq 1f
    cmp w0, #10
    b.eq 4f
    cmp w0, #0x80
    b.hs 2f
    cmp w0, #'_'
    b.eq 2f
    sub w14, w0, #'0'
    cmp w14, #9
    b.ls 2f
    orr w14, w0, #0x20
    sub w14, w14, #'a'
    cmp w14, #25
    b.ls 2f
    mov w0, #2
    ret
1:  mov w0, #0
    ret
2:  mov w0, #1
    ret
4:  mov w0, #3
    ret

// void av_view_move(View *v, int cmd, int extend, size_t page_lines)
FUNC_BEGIN _av_view_move
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    ldr x23, [x19, #V_DOC]
    ldr x24, [x19, #V_CUR]
    cmp x20, #MV_COUNT
    b.hs Lmv_out
    adr x9, Lmv_table
    add x9, x9, x20, lsl #2
    br x9
Lmv_table:
    b Lmv_left
    b Lmv_right
    b Lmv_up
    b Lmv_down
    b Lmv_home
    b Lmv_end
    b Lmv_top
    b Lmv_bottom
    b Lmv_pgup
    b Lmv_pgdn
    b Lmv_wleft
    b Lmv_wright

    // without shift an active selection collapses to its edge
Lmv_left:
    cbnz x21, 1f
    SEL_RANGE x19, x25, x26
    cmp x25, x26
    b.eq 1f
    mov x24, x25
    b Lmv_done
1:  mov x0, x23
    mov x1, x24
    bl _av_utf8_prev
    mov x24, x0
    b Lmv_done

Lmv_right:
    cbnz x21, 1f
    SEL_RANGE x19, x25, x26
    cmp x25, x26
    b.eq 1f
    mov x24, x26
    b Lmv_done
1:  mov x0, x23
    mov x1, x24
    bl _av_utf8_next
    mov x24, x0
    b Lmv_done

Lmv_up:
    mov x25, #-1
    b Lmv_vert
Lmv_down:
    mov x25, #1
    b Lmv_vert
Lmv_pgup:
    neg x25, x22
    b Lmv_vert
Lmv_pgdn:
    mov x25, x22

Lmv_vert:
    mov x0, x19
    mov x1, x25
    bl Lvert
    mov x24, x0
    b Lmv_keep

    // smart home: first non-blank, then column 0
Lmv_home:
    mov x0, x23
    mov x1, x24
    bl _av_buf_line_of
    mov x25, x0
    mov x0, x23
    mov x1, x25
    bl _av_buf_line_start
    mov x26, x0
    mov x0, x23
    mov x1, x25
    bl _av_buf_line_end
    mov x5, x0
    mov x2, x26
    BUF_GEOM x23
1:  cmp x2, x5
    b.hs 2f
    BUF_BYTE w4, x2
    cmp w4, #' '
    b.eq 3f
    cmp w4, #9
    b.ne 2f
3:  add x2, x2, #1
    b 1b
2:  cmp x2, x24
    csel x24, x26, x2, eq
    b Lmv_done

Lmv_end:
    mov x0, x23
    mov x1, x24
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x23
    bl _av_buf_line_end
    mov x24, x0
    b Lmv_done

Lmv_top:
    mov x24, #0
    b Lmv_done

Lmv_bottom:
    mov x0, x23
    bl _av_buf_len
    mov x24, x0
    b Lmv_done

Lmv_wright:
    mov x0, x23
    bl _av_buf_len
    mov x25, x0
    BUF_GEOM x23
    mov x2, x24
1:  cmp x2, x25
    b.hs 9f
    BUF_BYTE w0, x2
    cmp w0, #' '
    b.eq 2f
    cmp w0, #9
    b.ne 3f
2:  add x2, x2, #1
    b 1b
3:  cmp w0, #10
    b.ne 4f
    add x2, x2, #1
    b 9f
4:  bl Lclass
    mov w6, w0
5:  add x2, x2, #1
    cmp x2, x25
    b.hs 9f
    BUF_BYTE w0, x2
    bl Lclass
    cmp w0, w6
    b.eq 5b
9:  mov x24, x2
    b Lmv_done

Lmv_wleft:
    BUF_GEOM x23
    mov x2, x24
1:  cbz x2, 9f
    sub x3, x2, #1
    BUF_BYTE w0, x3
    cmp w0, #' '
    b.eq 2f
    cmp w0, #9
    b.ne 3f
2:  mov x2, x3
    b 1b
3:  cmp w0, #10
    b.ne 4f
    mov x2, x3
    b 9f
4:  bl Lclass
    mov w6, w0
5:  sub x2, x2, #1
    cbz x2, 9f
    sub x3, x2, #1
    BUF_BYTE w0, x3
    bl Lclass
    cmp w0, w6
    b.eq 5b
9:  mov x24, x2

Lmv_done:
    mov x0, #-1
    str x0, [x19, #V_PREFCOL]
Lmv_keep:
    str x24, [x19, #V_CUR]
    cbnz x21, Lmv_out
    str x24, [x19, #V_ANCHOR]
Lmv_out:
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// void av_view_select_word(View *v, size_t pos)
FUNC_BEGIN _av_view_select_word
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #V_DOC]
    mov x0, x21
    bl _av_buf_len
    mov x22, x0
    mov x2, x20
    mov x3, x20
    cmp x20, x22
    b.hs 3f
    BUF_GEOM x21
    BUF_BYTE w0, x20
    bl Lclass
    mov w6, w0
1:  cbz x2, 2f
    sub x4, x2, #1
    BUF_BYTE w0, x4
    bl Lclass
    cmp w0, w6
    b.ne 2f
    mov x2, x4
    b 1b
2:  add x3, x3, #1
    cmp x3, x22
    b.hs 3f
    BUF_BYTE w0, x3
    bl Lclass
    cmp w0, w6
    b.eq 2b
3:  str x2, [x19, #V_ANCHOR]
    str x3, [x19, #V_CUR]
    mov x0, #-1
    str x0, [x19, #V_PREFCOL]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_select_line(View *v, size_t pos), includes the trailing newline
FUNC_BEGIN _av_view_select_line
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    ldr x20, [x19, #V_DOC]
    mov x0, x20
    bl _av_buf_line_of
    mov x21, x0
    mov x0, x20
    mov x1, x21
    bl _av_buf_line_start
    str x0, [x19, #V_ANCHOR]
    add x1, x21, #1
    ldr x9, [x20, #BUF_NLINES]
    cmp x1, x9
    b.hs 1f
    mov x0, x20
    bl _av_buf_line_start
    b 2f
1:  mov x0, x20
    bl _av_buf_len
2:  str x0, [x19, #V_CUR]
    mov x0, #-1
    str x0, [x19, #V_PREFCOL]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_view_select_all(View *v)
FUNC_BEGIN _av_view_select_all
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #V_DOC]
    bl _av_buf_len
    str x0, [x19, #V_CUR]
    str xzr, [x19, #V_ANCHOR]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_view_undo(View *v) / av_view_redo(View *v)
FUNC_BEGIN _av_view_undo
    LADDR x9, _av_doc_undo
    b Lview_history
FUNC_BEGIN _av_view_redo
    LADDR x9, _av_doc_redo
Lview_history:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #V_DOC]
    blr x9
    tbnz x0, #63, 1f
    stp x0, x0, [x19, #V_CUR]
    mov x0, #-1
    str x0, [x19, #V_PREFCOL]
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t av_wrap_rows(Buffer *b, size_t line, size_t width, size_t *starts, size_t max)
// visual rows of a line wrapped at width columns (0: no wrap), breaking after blanks when a
// word fits, else mid word; starts[] gets the first column of each row (at most max)
FUNC_BEGIN _av_wrap_rows
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    mov x24, x1
    mov x20, x2
    mov x21, x3
    mov x22, x4
    mov x23, #1
    cbz x22, 1f
    str xzr, [x21]
1:  cbz x20, 9f
    mov x0, x19
    mov x1, x24
    bl _av_buf_line_end
    mov x27, x0
    mov x0, x19
    mov x1, x24
    bl _av_buf_line_start
    mov x2, x0                 // byte position
    mov x3, #0                 // column
    mov x25, #0                // row start column
    mov x26, #0                // column after the last blank
    BUF_GEOM x19
2:  cmp x2, x27
    b.hs 9f
    BUF_BYTE w4, x2
    and w5, w4, #0xc0
    cmp w5, #0x80
    b.ne 3f
    add x2, x2, #1
    b 2b
    // x6 width of this character
3:  mov x6, #1
    cmp w4, #9
    b.ne 4f
    LDRG x14, _av_tab_width
    udiv x15, x3, x14
    madd x6, x15, x14, x14
    sub x6, x6, x3
4:  add x7, x3, x6
    add x9, x25, x20
    cmp x7, x9
    b.ls 7f
    // overflow: a blank hangs at the row end, else back to the last blank or cut here
    cmp w4, #' '
    b.ne 5f
    mov x9, x7
    b 6f
5:  cmp x26, x25
    csel x9, x26, x3, hi
    cmp x9, x25
    csel x9, x7, x9, ls
6:  cmp x23, x22
    b.hs 61f
    str x9, [x21, x23, lsl #3]
61: add x23, x23, #1
    mov x25, x9
    mov x26, x9
    // the character already went to the previous row, or is placed again in the new one
    cmp x9, x3
    b.hi 8f
    b 2b
7:  cmp w4, #' '
    ccmp w4, #9, #4, ne
    csel x26, x7, x26, eq
8:  mov x3, x7
    add x2, x2, #1
    b 2b
9:  mov x0, x23
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// size_t av_wrap_row_of(const size_t *starts, size_t rows, size_t col): row holding col
FUNC_BEGIN _av_wrap_row_of
    mov x9, #WRAP_MAX
    cmp x1, x9
    csel x1, x9, x1, hi
    mov x3, #0
1:  add x4, x3, #1
    cmp x4, x1
    b.hs 2f
    ldr x5, [x0, x4, lsl #3]
    cmp x5, x2
    b.hi 2f
    mov x3, x4
    b 1b
2:  mov x0, x3
    ret

// (row, rows) av_wrap_locate(Buffer *b, size_t pos, size_t width): visual row of pos inside its
// line and the line's row count; row starts are left in av_wrap_starts
FUNC_BEGIN _av_wrap_locate
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _av_col_of
    mov x22, x0
    mov x0, x19
    mov x1, x20
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x19
    mov x2, x21
    LADDR x3, _av_wrap_starts
    mov x4, #WRAP_MAX
    bl _av_wrap_rows
    mov x21, x0
    mov x1, x0
    LADDR x0, _av_wrap_starts
    mov x2, x22
    bl _av_wrap_row_of
    mov x1, x21
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// size_t vert(View *v, long delta): delta visual rows down (or up), the preferred column is
// kept relative to the row start; past either end of the buffer clamps to it
    .p2align 2
Lvert:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #V_DOC]
    ldr x22, [x19, #V_WRAP]
    mov x0, x21
    ldr x1, [x19, #V_CUR]
    mov x2, x22
    bl _av_wrap_locate
    mov x25, x0
    mov x24, x1
    mov x0, x21
    ldr x1, [x19, #V_CUR]
    bl _av_buf_line_of
    mov x23, x0
    ldr x9, [x19, #V_PREFCOL]
    tbz x9, #63, 1f
    mov x0, x21
    ldr x1, [x19, #V_CUR]
    bl _av_col_of
    LADDR x10, _av_wrap_starts
    ldr x10, [x10, x25, lsl #3]
    sub x9, x0, x10
    str x9, [x19, #V_PREFCOL]
1:  cbz x20, 6f
    tbnz x20, #63, 3f
    // down
    add x9, x25, #1
    cmp x9, x24
    b.hs 2f
    mov x25, x9
    sub x20, x20, #1
    b 1b
2:  add x9, x23, #1
    ldr x10, [x21, #BUF_NLINES]
    cmp x9, x10
    b.hs 8f
    mov x23, x9
    mov x25, #0
    bl Lvert_rows
    sub x20, x20, #1
    b 1b
    // up
3:  cbz x25, 4f
    sub x25, x25, #1
    add x20, x20, #1
    b 1b
4:  cbz x23, 7f
    sub x23, x23, #1
    bl Lvert_rows
    sub x25, x24, #1
    mov x9, #(WRAP_MAX - 1)
    cmp x25, x9
    csel x25, x9, x25, hi
    add x20, x20, #1
    b 1b
    // column in the target row, not past its end
6:  LADDR x10, _av_wrap_starts
    ldr x2, [x10, x25, lsl #3]
    ldr x9, [x19, #V_PREFCOL]
    add x2, x2, x9
    add x11, x25, #1
    cmp x11, x24
    b.hs 61f
    cmp x11, #WRAP_MAX
    b.hs 61f
    ldr x12, [x10, x11, lsl #3]
    sub x12, x12, #1
    cmp x2, x12
    csel x2, x12, x2, hi
61: mov x0, x21
    mov x1, x23
    bl _av_pos_at_col
    b 9f
7:  mov x0, #0
    b 9f
8:  mov x0, x21
    bl _av_buf_len
9:  ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// rows of line x23 into x24, starts in av_wrap_starts; helper of vert, uses its registers
    .p2align 2
Lvert_rows:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x21
    mov x1, x23
    mov x2, x22
    LADDR x3, _av_wrap_starts
    mov x4, #WRAP_MAX
    bl _av_wrap_rows
    mov x24, x0
    ldp x29, x30, [sp], #16
    ret
