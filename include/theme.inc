// theme color slots in _av_theme, each slot is 4 doubles (r, g, b, a)
// slot offset / 4 gives the index into _av_attrs (one CTFont attribute dict per slot)

.set T_SLOT, 32

// ui
.set T_BG,          0 * T_SLOT
.set T_GUTTER,      1 * T_SLOT
.set T_CURLINE,     2 * T_SLOT
.set T_SEL,         3 * T_SLOT
.set T_LINENR,      4 * T_SLOT
.set T_LINENR_CUR,  5 * T_SLOT
.set T_TEXT,        6 * T_SLOT
.set T_CURSOR,      7 * T_SLOT
.set T_TABBAR,      8 * T_SLOT
.set T_TAB_ACTIVE,  9 * T_SLOT
.set T_TAB_TEXT,    10 * T_SLOT
.set T_TAB_TEXT_ON, 11 * T_SLOT
.set T_ACCENT,      12 * T_SLOT
.set T_INDENT,      13 * T_SLOT
.set T_ERROR,       14 * T_SLOT
.set T_WARNING,     15 * T_SLOT

// syntax
.set S_KEYWORD,     16 * T_SLOT
.set S_STRING,      17 * T_SLOT
.set S_NUMBER,      18 * T_SLOT
.set S_COMMENT,     19 * T_SLOT
.set S_TYPE,        20 * T_SLOT
.set S_FUNCTION,    21 * T_SLOT
.set S_OPERATOR,    22 * T_SLOT
.set S_PUNCT,       23 * T_SLOT
.set S_CONSTANT,    24 * T_SLOT
.set S_KEY,         25 * T_SLOT
.set S_LABEL,       26 * T_SLOT
.set S_SPECIAL,     27 * T_SLOT
.set S_ESCAPE,      28 * T_SLOT
.set S_TAG,         29 * T_SLOT
.set S_HEADING,     30 * T_SLOT
.set S_LINK,        31 * T_SLOT

.set T_SLOTS, 32
.set T_SIZE,  T_SLOTS * T_SLOT

.set THEME_LATTE,     0
.set THEME_FRAPPE,    1
.set THEME_MACCHIATO, 2
.set THEME_MOCHA,     3
.set THEME_COUNT,     4
.set THEME_CUSTOM,    4
.set THEME_DEFAULT,   THEME_MOCHA

// reg = CFDictionaryRef text attributes for theme slot, clobbers nothing else
.macro ATTRS reg, slot
    adrp \reg, _av_attrs@PAGE
    add \reg, \reg, _av_attrs@PAGEOFF
    ldr \reg, [\reg, #(\slot / 4)]
.endm
