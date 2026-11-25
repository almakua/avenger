// doc/undo and view editing tests

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"
.include "harness.inc"

.macro INS lit, n, merge
    LADDR x0, _tview
    LADDR x1, \lit
    mov x2, #\n
    mov x3, #\merge
    bl _av_view_insert
.endm

.macro MOVE cmd, ext
    LADDR x0, _tview
    mov x1, #\cmd
    mov x2, #\ext
    mov x3, #10
    bl _av_view_move
.endm

.macro VIEW_OP fn
    LADDR x0, _tview
    bl \fn
.endm

.macro SET_CUR pos
    LADDR x0, _tview
    mov x1, #\pos
    mov x2, #0
    bl _av_view_set_cursor
.endm

.macro CUR_IS id, expected
    LADDR x9, _tview
    ldr x0, [x9, #V_CUR]
    CHECK \id, \expected
.endm

.macro ANCHOR_IS id, expected
    LADDR x9, _tview
    ldr x0, [x9, #V_ANCHOR]
    CHECK \id, \expected
.endm

.macro VIEW2_IS id, cur, anchor
    LADDR x9, _tview2
    ldr x0, [x9, #V_CUR]
    CHECK \id, \cur
    LADDR x9, _tview2
    ldr x0, [x9, #V_ANCHOR]
    CHECK (\id + 1), \anchor
.endm

.macro ROWS id, line, width, rows, s1, s2
    LADDR x0, _tdoc3
    mov x1, #\line
    mov x2, #\width
    LADDR x3, _tstarts
    mov x4, #8
    bl _av_wrap_rows
    CHECK \id, \rows
    LADDR x9, _tstarts
    ldr x0, [x9, #8]
    CHECK (\id + 1), \s1
    LADDR x9, _tstarts
    ldr x0, [x9, #16]
    CHECK (\id + 2), \s2
.endm

// move view 3 one visual row, expect the cursor at pos
.macro VMOVE id, cmd, pos
    LADDR x0, _tview3
    mov x1, #\cmd
    mov x2, #0
    mov x3, #10
    bl _av_view_move
    LADDR x9, _tview3
    ldr x0, [x9, #V_CUR]
    CHECK \id, \pos
.endm

.macro LEN_IS id, expected
    CALL0 _av_buf_len, _tdoc
    CHECK \id, \expected
.endm

.macro COL_IS id, pos, expected
    CALL1 _av_col_of, _tdoc, \pos
    CHECK \id, \expected
.endm

.macro POS_AT id, line, col, expected
    LADDR x0, _tdoc
    mov x1, #\line
    mov x2, #\col
    bl _av_pos_at_col
    CHECK \id, \expected
.endm

    .zerofill __DATA,__bss,_tdoc,DOC_SIZE,4
    .zerofill __DATA,__bss,_tview,V_SIZE,4
    .zerofill __DATA,__bss,_tview2,V_SIZE,4
    .zerofill __DATA,__bss,_tdoc3,DOC_SIZE,4
    .zerofill __DATA,__bss,_tview3,V_SIZE,4
    .zerofill __DATA,__bss,_tstarts,64,3

    .section __TEXT,__cstring,cstring_literals
Ls_a:      .asciz "a"
Ls_b:      .asciz "b"
Ls_c:      .asciz "c"
Ls_sp:     .asciz " "
Ls_d:      .asciz "d"
Ls_X:      .asciz "X"
Ls_abc:    .asciz "abc"
Ls_abcd:   .asciz "abc d"
Ls_ab:     .asciz "ab"
Ls_key:    .asciz "  key:"
Ls_keynl:  .asciz "  key:\n  "
Ls_tabs:   .asciz "\tab\tc"
Ls_words:  .asciz "foo bar_baz\n  qux"
Ls_utf8:   .asciz "a\303\251"
Ls_wrap:   .asciz "aaa bbb ccc\nxy"
Ls_long:   .asciz "abcdefg"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    CALL0 _av_doc_init, _tdoc
    CHECK 1, 0
    LADDR x9, _tview
    LADDR x10, _tdoc
    str x10, [x9, #V_DOC]
    mov x10, #-1
    str x10, [x9, #V_PREFCOL]

    // typing merges into one undo step
    INS Ls_a, 1, 1
    INS Ls_b, 1, 1
    INS Ls_c, 1, 1
    LEN_IS 2, 3
    CHECK_TEXT 3, _tdoc, Ls_abc, 3
    VIEW_OP _av_view_undo
    LEN_IS 4, 0
    CUR_IS 5, 0
    VIEW_OP _av_view_redo
    LEN_IS 6, 3
    CUR_IS 7, 3

    // a word after a space starts a new step
    INS Ls_sp, 1, 1
    INS Ls_d, 1, 1
    LEN_IS 8, 5
    VIEW_OP _av_view_undo
    LEN_IS 9, 4
    VIEW_OP _av_view_undo
    LEN_IS 10, 0
    VIEW_OP _av_view_redo
    LEN_IS 11, 4
    VIEW_OP _av_view_redo
    LEN_IS 12, 5
    CUR_IS 13, 5

    // replacing a selection undoes in one step
    VIEW_OP _av_view_select_all
    INS Ls_X, 1, 1
    LEN_IS 14, 1
    VIEW_OP _av_view_undo
    LEN_IS 15, 5
    CHECK_TEXT 16, _tdoc, Ls_abcd, 5
    CUR_IS 17, 5

    // consecutive backspaces merge
    VIEW_OP _av_view_backspace
    VIEW_OP _av_view_backspace
    VIEW_OP _av_view_backspace
    CHECK_TEXT 18, _tdoc, Ls_ab, 2
    VIEW_OP _av_view_undo
    LEN_IS 19, 5
    CHECK_TEXT 20, _tdoc, Ls_abcd, 5

    // newline keeps indentation, tab goes to the next stop
    VIEW_OP _av_view_select_all
    INS Ls_key, 6, 0
    VIEW_OP _av_view_newline
    CHECK_TEXT 21, _tdoc, Ls_keynl, 9
    CALL0 _av_buf_line_count, _tdoc
    CHECK 22, 2
    CUR_IS 23, 9
    VIEW_OP _av_view_tab
    CUR_IS 24, 11
    COL_IS 25, 11, 4

    // tab-aware columns
    VIEW_OP _av_view_select_all
    INS Ls_tabs, 5, 0
    COL_IS 26, 1, 4
    COL_IS 27, 3, 6
    COL_IS 28, 4, 8
    POS_AT 29, 0, 5, 2
    POS_AT 30, 0, 6, 3
    POS_AT 31, 0, 7, 3
    POS_AT 32, 0, 99, 5

    // movement
    VIEW_OP _av_view_select_all
    INS Ls_words, 17, 0
    MOVE MV_TOP, 0
    CUR_IS 33, 0
    MOVE MV_WORD_RIGHT, 0
    CUR_IS 34, 3
    MOVE MV_WORD_RIGHT, 0
    CUR_IS 35, 11
    MOVE MV_WORD_RIGHT, 0
    CUR_IS 36, 12
    MOVE MV_TOP, 0
    MOVE MV_END, 0
    CUR_IS 37, 11
    MOVE MV_DOWN, 0
    CUR_IS 38, 17
    MOVE MV_UP, 0
    CUR_IS 39, 11
    SET_CUR 17
    MOVE MV_HOME, 0
    CUR_IS 40, 14
    MOVE MV_HOME, 0
    CUR_IS 41, 12
    SET_CUR 11
    MOVE MV_WORD_LEFT, 0
    CUR_IS 42, 4
    MOVE MV_WORD_LEFT, 0
    CUR_IS 43, 0

    // shift extends, plain move collapses
    MOVE MV_RIGHT, 1
    MOVE MV_RIGHT, 1
    VIEW_OP _av_view_sel
    stp x0, x1, [sp, #-16]!
    CHECK 44, 0
    ldp x0, x1, [sp], #16
    mov x0, x1
    CHECK 45, 2
    MOVE MV_RIGHT, 0
    CUR_IS 46, 2
    ANCHOR_IS 54, 2

    // word and line selection
    CALL1 _av_view_select_word, _tview, 6
    ANCHOR_IS 47, 4
    CUR_IS 48, 11
    CALL1 _av_view_select_line, _tview, 13
    ANCHOR_IS 49, 12
    CUR_IS 50, 17

    // forward delete and utf8 backspace
    SET_CUR 0
    VIEW_OP _av_view_delete_fwd
    LEN_IS 51, 16
    CALL1 _av_buf_byte_at, _tdoc, 0
    CHECK 52, 'o'
    VIEW_OP _av_view_select_all
    INS Ls_utf8, 3, 0
    VIEW_OP _av_view_backspace
    LEN_IS 53, 1

    // a second view on the same doc follows edits made through the first
    LADDR x0, _tdoc
    LADDR x1, _tview
    bl _av_doc_attach
    LADDR x0, _tdoc
    LADDR x1, _tview2
    bl _av_doc_attach
    LADDR x9, _tview2
    LADDR x10, _tdoc
    str x10, [x9, #V_DOC]
    VIEW_OP _av_view_select_all
    INS Ls_abcd, 5, 0
    LADDR x9, _tview2
    mov x10, #4
    mov x11, #2
    stp x10, x11, [x9, #V_CUR]
    SET_CUR 0
    INS Ls_X, 1, 0
    VIEW2_IS 60, 5, 3
    // deleting "abc" from "Xabc d"
    SET_CUR 4
    LADDR x0, _tview
    mov x1, #1
    mov x2, #1
    bl _av_view_set_cursor
    VIEW_OP _av_view_backspace
    VIEW2_IS 62, 2, 1
    VIEW_OP _av_view_undo
    VIEW2_IS 64, 5, 1
    VIEW_OP _av_view_redo
    VIEW2_IS 66, 2, 1
    CUR_IS 68, 1
    LADDR x0, _tdoc
    LADDR x1, _tview2
    bl _av_doc_detach
    CHECK 69, 1
    LADDR x0, _tdoc
    LADDR x1, _tview2
    bl _av_doc_detach
    CHECK 70, 1
    LADDR x0, _tdoc
    LADDR x1, _tview
    bl _av_doc_detach
    CHECK 71, 0

    // wrapping after blanks, mid word when a word does not fit
    CALL0 _av_doc_init, _tdoc3
    LADDR x0, _tdoc3
    mov x1, #0
    LADDR x2, Ls_wrap
    mov x3, #14
    mov x4, #0
    bl _av_doc_insert
    ROWS 80, 0, 8, 2, 8, 0
    ROWS 83, 0, 5, 3, 4, 8
    ROWS 86, 1, 5, 1, 4, 8
    LADDR x0, _tdoc3
    mov x1, #0
    mov x2, #0
    mov x3, #0
    mov x4, #0
    bl _av_wrap_rows
    CHECK 89, 1
    // up and down move by visual rows
    LADDR x9, _tview3
    LADDR x10, _tdoc3
    str x10, [x9, #V_DOC]
    mov x10, #5
    str x10, [x9, #V_WRAP]
    mov x10, #1
    stp x10, x10, [x9, #V_CUR]
    mov x10, #-1
    str x10, [x9, #V_PREFCOL]
    VMOVE 90, MV_DOWN, 5
    VMOVE 91, MV_DOWN, 9
    VMOVE 92, MV_DOWN, 13
    VMOVE 93, MV_DOWN, 14
    LADDR x0, _tview3
    mov x1, #13
    mov x2, #0
    bl _av_view_set_cursor
    VMOVE 94, MV_UP, 9
    VMOVE 95, MV_UP, 5
    VMOVE 96, MV_UP, 1
    VMOVE 97, MV_UP, 0
    // a long word is cut every width columns
    LADDR x0, _tdoc3
    mov x1, #0
    mov x2, #14
    mov x3, #0
    bl _av_doc_delete
    LADDR x0, _tdoc3
    mov x1, #0
    LADDR x2, Ls_long
    mov x3, #7
    mov x4, #0
    bl _av_doc_insert
    ROWS 98, 0, 3, 3, 3, 6

    bl Lsummary
    ldp x29, x30, [sp], #16
    ret
