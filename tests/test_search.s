// search: exact and folded matches across the gap, backwards, counting, replace all, fuzzy

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"
.include "harness.inc"

// FIND id, from, end, pattern, flags, expected
.macro FIND id, from, end, pat, flags, want
    LADDR x0, _tdoc
    mov x1, #\from
    mov x2, #\end
    LADDR x3, \pat
    mov x4, #3
    mov x5, #\flags
    bl _av_buf_find
    CHECK \id, \want
.endm

.macro BACK id, before, flags, want
    LADDR x0, _tdoc
    mov x1, #\before
    LADDR x2, Ls_foo
    mov x3, #3
    mov x4, #\flags
    bl _av_buf_find_back
    CHECK \id, \want
.endm

.macro COUNT id, limit, flags, want
    LADDR x0, _tdoc
    mov x1, #\limit
    LADDR x2, Ls_foo
    mov x3, #3
    mov x4, #\flags
    bl _av_buf_count
    CHECK \id, \want
.endm

.macro GAP pos
    LADDR x0, _tdoc
    mov x1, #\pos
    bl _av_buf_move_gap
.endm

.macro FUZZY id, q, c, want
    LADDR x0, \q
    LADDR x1, \c
    bl _av_fuzzy_score
    CHECK \id, \want
.endm

    .zerofill __DATA,__bss,_tdoc,DOC_SIZE,4

    .section __TEXT,__cstring,cstring_literals
Ls_text:   .asciz "foo bar Foo baz foo\nbarfoo"
Ls_after:  .asciz "X bar Foo baz X\nbarX"
Ls_foo:    .asciz "foo"
Ls_bar:    .asciz "bar"
Ls_X:      .asciz "X"
Ls_sr:     .asciz "sr"
Ls_op:     .asciz "OP"
Ls_xyz:    .asciz "xyz"
Ls_empty:  .asciz ""
Ls_split:  .asciz "split_right"
Ls_open:   .asciz "open"
Ls_save:   .asciz "save"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    CALL0 _av_doc_init, _tdoc
    LADDR x0, _tdoc
    mov x1, #0
    LADDR x2, Ls_text
    mov x3, #26
    mov x4, #0
    bl _av_doc_insert

    // gap at the end, then inside the second "foo", then before everything
    GAP 26
    FIND 1, 0, 26, Ls_foo, 0, 0
    FIND 2, 1, 26, Ls_foo, 0, 16
    FIND 3, 17, 26, Ls_foo, 0, 23
    FIND 4, 1, 26, Ls_foo, 1, 8
    FIND 5, 1, 18, Ls_foo, 0, -1
    FIND 6, 24, 26, Ls_foo, 0, -1
    GAP 17
    FIND 7, 1, 26, Ls_foo, 0, 16
    FIND 8, 17, 26, Ls_foo, 0, 23
    FIND 9, 9, 26, Ls_foo, 1, 16
    FIND 10, 4, 26, Ls_bar, 0, 4
    FIND 11, 5, 26, Ls_bar, 0, 20
    GAP 0
    FIND 12, 1, 26, Ls_foo, 0, 16
    FIND 13, 0, 3, Ls_foo, 0, 0
    GAP 18

    BACK 20, 16, 0, 0
    BACK 21, 16, 1, 8
    BACK 22, 26, 0, 23
    BACK 23, 0, 0, -1
    COUNT 30, 26, 0, 3
    COUNT 31, 26, 1, 4
    COUNT 32, 16, 0, 1
    COUNT 33, 17, 0, 2

    // replace all is one undo step
    LADDR x0, _tdoc
    LADDR x1, Ls_foo
    mov x2, #3
    LADDR x3, Ls_X
    mov x4, #1
    mov x5, #0
    bl _av_doc_replace_all
    CHECK 40, 3
    CALL0 _av_buf_len, _tdoc
    CHECK 41, 20
    CHECK_TEXT 42, _tdoc, Ls_after, 20
    CALL0 _av_doc_undo, _tdoc
    CALL0 _av_buf_len, _tdoc
    CHECK 43, 26
    CHECK_TEXT 44, _tdoc, Ls_text, 26

    FUZZY 50, Ls_sr, Ls_split, 18
    FUZZY 51, Ls_op, Ls_open, 14
    FUZZY 52, Ls_xyz, Ls_save, -1
    FUZZY 53, Ls_empty, Ls_save, 0
    FUZZY 54, Ls_sr, Ls_save, -1

    bl Lsummary
    ldp x29, x30, [sp], #16
    ret
