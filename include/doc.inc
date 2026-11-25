// Doc: buffer + undo log; View: cursor, selection and scroll over a Doc

.set DOC_BUF,    0
.set DOC_PATH,   64
.set DOC_U_DATA, 72
.set DOC_U_CAP,  80
.set DOC_U_LEN,  88
.set DOC_U_POS,  96
.set DOC_SIZE,   128

// undo record: [type u32][flags u32][pos u64][len u64][text][size u64]
// trailing size lets undo walk records backwards, fields may be unaligned
.set UR_TYPE,     0
.set UR_FLAGS,    4
.set UR_POS,      8
.set UR_LEN,      16
.set UR_TEXT,     24
.set UR_OVERHEAD, 32
.set UR_INSERT,   1
.set UR_DELETE,   2
.set UF_JOINED,   1

// flags for av_doc_insert/delete
.set EF_JOIN,  1
.set EF_MERGE, 2

.set V_DOC,     0
.set V_CUR,     8
.set V_ANCHOR,  16
.set V_SCROLLY, 24
.set V_SCROLLX, 32
.set V_PREFCOL, 40
.set V_NSVIEW,  48
.set V_SIZE,    64

// default tab stop width, the live value is _av_tab_width
.set TAB_WIDTH, 4

// movement commands for av_view_move
.set MV_LEFT,       0
.set MV_RIGHT,      1
.set MV_UP,         2
.set MV_DOWN,       3
.set MV_HOME,       4
.set MV_END,        5
.set MV_TOP,        6
.set MV_BOTTOM,     7
.set MV_PAGE_UP,    8
.set MV_PAGE_DOWN,  9
.set MV_WORD_LEFT,  10
.set MV_WORD_RIGHT, 11
.set MV_COUNT,      12

// rs/re = ordered selection of view st, clobbers x9 x10
.macro SEL_RANGE st, rs, re
    ldp x9, x10, [\st, #V_CUR]
    cmp x9, x10
    csel \rs, x9, x10, lo
    csel \re, x10, x9, lo
.endm
