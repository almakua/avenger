// YAML parser: structure, scalars and error reporting

.include "macros.inc"
.include "yaml.inc"
.include "harness.inc"

// parse NUL-terminated doc at label into _tctx, x0 = root
.macro PARSE doc
    LADDR x0, \doc
    bl _strlen
    mov x2, x0
    LADDR x0, _tctx
    LADDR x1, \doc
    bl _av_yaml_parse
.endm

// x0 = node at path from root in x24, keys given as labels
.macro GET1 k1
    mov x0, x24
    LADDR x1, \k1
    bl _av_yaml_get
.endm

.macro GET2 k1, k2
    GET1 \k1
    LADDR x1, \k2
    bl _av_yaml_get
.endm

.macro TYPE_IS id, t
    ldrb w0, [x0, #N_TYPE]
    CHECK \id, \t
.endm

// x0 = 0 when the scalar node in x0 equals string label s
.macro STR_IS id, s
    bl _av_yaml_str
    cbz x0, 98f
    LADDR x1, \s
    bl _strcmp
    sxtw x0, w0
    b 99f
98: mov x0, #-1
99: CHECK \id, 0
.endm

.macro ERR_IS id, doc, code, line
    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE \doc
    CHECK \id, 0
    LADDR x9, _tctx
    ldr x0, [x9, #Y_ERR]
    CHECK (\id + 1), \code
    LADDR x9, _tctx
    ldr x0, [x9, #Y_ERRLINE]
    CHECK (\id + 2), \line
.endm

    .zerofill __DATA,__bss,_tctx,Y_SIZE,4
    .zerofill __DATA,__bss,_tol,(16 * 128),4

    .section __TEXT,__cstring,cstring_literals
Ldoc:
    .ascii "# comment\n"
    .ascii "---\n"
    .ascii "font: \"JetBrains Mono\"\n"
    .ascii "font_size: 15.5\n"
    .ascii "tab_width: 2\n"
    .ascii "theme: latte   # trailing comment\n"
    .ascii "empty:\n"
    .ascii "nested:\n"
    .ascii "  a: -12\n"
    .ascii "  b:\n"
    .ascii "    - x\n"
    .ascii "    - 'it''s'\n"
    .ascii "    - key: v\n"
    .ascii "      other: w\n"
    .ascii "  c: [1, two, \"3\"]\n"
    .ascii "  d: {k: v, n: 5}\n"
    .ascii "list:\n"
    .ascii "- 10\n"
    .ascii "- 20\n"
    .ascii "block: |\n"
    .ascii "  line one\n"
    .ascii "  line two\n"
    .ascii "after: ok\n"
    .ascii "url: http://example.com:8080/x\n"
    .ascii "esc: \"a\\tb\\u00e9\"\n"
    .ascii "anchor: &base\n"
    .ascii "  x: 1\n"
    .ascii "flag: Yes\n"
    .asciz "multi: [a,\n  b]\n"

Lol:
    .ascii "a:\n"
    .ascii "  b: 1\n"
    .ascii "  c:\n"
    .ascii "    - x\n"
    .ascii "    - k: v\n"
    .asciz "d: 2\n"
Lol_2:      .asciz "a.c[1].k"
Lol_tpl:    .asciz "image: {{ .Values.image }}\n"
Lol_plain:  .asciz "image: nginx\n"
Lk_font:      .asciz "font"
Lk_size:      .asciz "font_size"
Lk_tab:       .asciz "tab_width"
Lk_theme:     .asciz "theme"
Lk_empty:     .asciz "empty"
Lk_nested:    .asciz "nested"
Lk_a:         .asciz "a"
Lk_b:         .asciz "b"
Lk_c:         .asciz "c"
Lk_d:         .asciz "d"
Lk_n:         .asciz "n"
Lk_key:       .asciz "key"
Lk_other:     .asciz "other"
Lk_list:      .asciz "list"
Lk_block:     .asciz "block"
Lk_after:     .asciz "after"
Lk_url:       .asciz "url"
Lk_esc:       .asciz "esc"
Lk_anchor:    .asciz "anchor"
Lk_x:         .asciz "x"
Lk_flag:      .asciz "flag"
Lk_multi:     .asciz "multi"
Lk_missing:   .asciz "missing"

Lv_jb:        .asciz "JetBrains Mono"
Lv_latte:     .asciz "latte"
Lv_its:       .asciz "it's"
Lv_v:         .asciz "v"
Lv_w:         .asciz "w"
Lv_two:       .asciz "two"
Lv_ok:        .asciz "ok"
Lv_url:       .asciz "http://example.com:8080/x"
Lv_esc:       .asciz "a\tb\303\251"
Lv_b:         .asciz "b"

Ld_seq:       .asciz "- a\n- b\n"
Ld_keyseq:    .asciz "key:\n- a\n- b\nnext: 1\n"
Ld_empty:     .asciz "# only a comment\n"
Ld_multi:     .asciz "---\na: 1\n---\na: 2\nb: x\n...\n"
Ld_fold:      .asciz "desc: one\n  two\n   three\nrun:\n  - cmd --x\n    --y \"q\"\nnext: 1\n"
Lv_fold:      .asciz "one two three"
Lv_cmd:       .asciz "cmd --x --y \"q\""
Lk_desc:      .asciz "desc"
Lk_run:       .asciz "run"
Lk_next:      .asciz "next"
Le_indent:    .asciz "a: 1\n  b: 2\n"
Le_dup:       .asciz "a: 1\nb: 2\na: 3\n"
Le_quote:     .asciz "a: \"open\nb: 1\n"
Le_tab:       .asciz "a:\n\tb: 1\n"
Le_flow:      .asciz "a: [1, 2\n"
Le_colon:     .asciz "a: 1\njunk\n"
Le_inline:    .asciz "a: b: c\n"
Le_trail:     .asciz "a: \"x\" y\n"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x24, x25, [sp, #16]

    PARSE Ldoc
    mov x24, x0
    cmp x0, #0
    cset x0, ne
    CHECK 1, 1
    LADDR x9, _tctx
    ldr x0, [x9, #Y_ERR]
    CHECK 2, 0
    mov x0, x24
    TYPE_IS 3, Y_MAP

    GET1 Lk_font
    STR_IS 4, Lv_jb
    GET1 Lk_size
    fmov d0, #1.0
    bl _av_yaml_float
    fmov d1, #10.0
    fmul d0, d0, d1
    fcvtas x0, d0
    CHECK 5, 155
    GET1 Lk_tab
    mov x1, #4
    bl _av_yaml_int
    CHECK 6, 2
    GET1 Lk_theme
    STR_IS 7, Lv_latte
    GET1 Lk_empty
    TYPE_IS 8, Y_NULL
    GET1 Lk_missing
    CHECK 9, 0

    GET2 Lk_nested, Lk_a
    mov x1, #0
    bl _av_yaml_int
    CHECK 10, -12
    GET2 Lk_nested, Lk_b
    mov x25, x0
    ldr x0, [x25, #N_LEN]
    CHECK 11, 3
    mov x0, x25
    mov x1, #1
    bl _av_yaml_at
    STR_IS 12, Lv_its
    mov x0, x25
    mov x1, #2
    bl _av_yaml_at
    mov x25, x0
    TYPE_IS 13, Y_MAP
    mov x0, x25
    LADDR x1, Lk_key
    bl _av_yaml_get
    STR_IS 14, Lv_v
    mov x0, x25
    LADDR x1, Lk_other
    bl _av_yaml_get
    STR_IS 15, Lv_w

    GET2 Lk_nested, Lk_c
    mov x25, x0
    ldr x0, [x25, #N_LEN]
    CHECK 16, 3
    mov x0, x25
    mov x1, #1
    bl _av_yaml_at
    STR_IS 17, Lv_two
    GET2 Lk_nested, Lk_d
    LADDR x1, Lk_n
    bl _av_yaml_get
    mov x1, #0
    bl _av_yaml_int
    CHECK 18, 5

    GET1 Lk_list
    mov x25, x0
    ldr x0, [x25, #N_LEN]
    CHECK 19, 2
    mov x0, x25
    mov x1, #1
    bl _av_yaml_at
    mov x1, #0
    bl _av_yaml_int
    CHECK 20, 20

    GET1 Lk_block
    ldr x0, [x0, #N_LEN]
    CHECK 21, 22
    GET1 Lk_after
    STR_IS 22, Lv_ok
    GET1 Lk_url
    STR_IS 23, Lv_url
    GET1 Lk_esc
    STR_IS 24, Lv_esc
    GET2 Lk_anchor, Lk_x
    mov x1, #0
    bl _av_yaml_int
    CHECK 25, 1
    GET1 Lk_flag
    mov x1, #0
    bl _av_yaml_bool
    CHECK 26, 1
    GET1 Lk_multi
    mov x1, #1
    bl _av_yaml_at
    STR_IS 27, Lv_b
    // source line of a key, used to jump from the outline
    GET1 Lk_after
    ldr w0, [x0, #N_LINE]
    CHECK 28, 23

    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE Ld_seq
    mov x24, x0
    TYPE_IS 29, Y_SEQ
    ldr x0, [x24, #N_LEN]
    CHECK 30, 2

    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE Ld_keyseq
    mov x24, x0
    GET1 Lk_key
    ldr x0, [x0, #N_LEN]
    CHECK 31, 2
    LADDR x1, Lk_n
    GET1 Lk_key
    TYPE_IS 32, Y_SEQ

    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE Ld_empty
    TYPE_IS 33, Y_NULL

    // multiple documents chain through N_NEXT
    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE Ld_multi
    mov x24, x0
    GET1 Lk_a
    mov x1, #0
    bl _av_yaml_int
    CHECK 34, 1
    ldr x24, [x24, #N_NEXT]
    GET1 Lk_a
    mov x1, #0
    bl _av_yaml_int
    CHECK 35, 2
    ldr x0, [x24, #N_LEN]
    CHECK 36, 2

    // multi-line plain scalars fold into one line
    LADDR x0, _tctx
    bl _av_yaml_free
    PARSE Ld_fold
    mov x24, x0
    GET1 Lk_desc
    STR_IS 37, Lv_fold
    GET1 Lk_run
    mov x1, #0
    bl _av_yaml_at
    STR_IS 38, Lv_cmd
    GET1 Lk_next
    mov x1, #0
    bl _av_yaml_int
    CHECK 39, 1

    ERR_IS 40, Le_indent, YE_INDENT, 2
    ERR_IS 43, Le_dup, YE_DUP, 3
    ERR_IS 46, Le_quote, YE_QUOTE, 1
    ERR_IS 49, Le_tab, YE_TAB, 2
    ERR_IS 52, Le_flow, YE_FLOW, 2
    ERR_IS 55, Le_colon, YE_COLON, 2
    ERR_IS 58, Le_inline, YE_INLINE_MAP, 1
    ERR_IS 61, Le_trail, YE_TRAIL, 1

    LADDR x0, _tctx
    bl _av_yaml_free

    // outline paths and lines, template detection
    LADDR x0, Lol
    bl _strlen
    mov x2, x0
    LADDR x0, _tctx
    LADDR x1, Lol
    bl _av_yaml_parse
    LADDR x1, _tol
    mov x2, #16
    bl _av_outline
    CHECK 200, 7
    LADDR x9, _tol
    ldr x0, [x9, #(5 * 128)]
    CHECK 201, 5
    LADDR x0, _tol
    add x0, x0, #(5 * 128 + 8)
    LADDR x1, Lol_2
    bl _strcmp
    sxtw x0, w0
    CHECK 202, 0
    LADDR x9, _tol
    ldr x0, [x9, #(6 * 128)]
    CHECK 203, 6
    LADDR x9, _tol
    ldrb w0, [x9, #(3 * 128 + 8 + 3)]
    CHECK 204, '['
    LADDR x0, _tctx
    LADDR x1, _tol
    mov x2, #3
    LADDR x0, _tctx
    ldr x0, [x0, #Y_ROOT]
    bl _av_outline
    CHECK 205, 3
    LADDR x0, _tctx
    bl _av_yaml_free
    LADDR x0, Lol_tpl
    mov x1, #27
    bl _av_yaml_is_template
    CHECK 206, 1
    LADDR x0, Lol_plain
    mov x1, #13
    bl _av_yaml_is_template
    CHECK 207, 0
    bl Lsummary
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
