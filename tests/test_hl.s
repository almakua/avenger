// lexers: color of selected bytes, multi-line states, language detection, state cache

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"
.include "theme.inc"
.include "hl.inc"
.include "harness.inc"

.macro LEX lang, lit, state
    LADDR x0, \lit
    bl _strlen
    mov x2, x0
    mov x0, #\lang
    LADDR x1, \lit
    mov x3, #\state
    LADDR x4, _av_runs
    bl _av_hl_lex
    STRG x0, _tstate, x9
    STRG x1, _tn, x9
.endm

// byte idx of the last lexed line has color slot
.macro SLOT_AT id, idx, slot
    mov x0, #\idx
    bl Lslot_at
    CHECK \id, (\slot / T_SLOT)
.endm

.macro STATE_IS id, v
    LDRG x0, _tstate
    CHECK \id, \v
.endm

.macro LANG_OF id, lit, lang
    LADDR x0, \lit
    bl _av_hl_lang_for_path
    CHECK \id, \lang
.endm

    .zerofill __DATA,__bss,_tstate,8,3
    .zerofill __DATA,__bss,_tn,8,3
    .zerofill __DATA,__bss,_tdoc,DOC_SIZE,4

    .section __TEXT,__cstring,cstring_literals
Lc1:   .asciz "int main(void) { return 0; } // hi"
Lc2:   .asciz "#include <stdio.h>"
Lc3:   .asciz "a /* b"
Lc4:   .asciz "c */ d"
Lc5:   .asciz "struct foo x;"
Ly1:   .asciz "  name: \"x\" # c"
Ly2:   .asciz "- true"
Ly3:   .asciz "port: 8080"
Ly4:   .asciz "url: http://a.b"
Ly5:   .asciz "run: |"
Ly6:   .asciz "  echo hi"
Ly7:   .asciz "next: 1"
Ly8:   .asciz "x: &a [1, \"s\", k: v]"
Ly9:   .asciz "---"
Lj1:   .asciz "{\"a\": \"b\", \"n\": 1}"
Lp1:   .asciz "def foo(x):"
Lp2:   .asciz "class Bar:"
Lp3:   .asciz "s = \"\"\"doc"
Lp4:   .asciz "end\"\"\" + 1"
Lp5:   .asciz "@app.route"
Lp6:   .asciz "print(len(x))"
Ls1:   .asciz "echo $HOME # c"
Ls2:   .asciz "if [ -f x ]; then"
Ls3:   .asciz "a#b"
La1:   .asciz "loop: ldr x0, [x1, #8] // c"
La2:   .asciz ".section __TEXT"
La3:   .asciz "    b.eq 1f"
La4:   .asciz "1:  ret"
La5:   .asciz "    adrp x9, sym@PAGE"
La6:   .asciz "mov w0, #'M'"
La7:   .asciz "/* a"
La8:   .asciz "b */ nop"
La9:   .asciz "    ldr x1, .Lfoo"
Lm1:   .asciz "# Title"
Lm2:   .asciz "Some `code` and **bold** [l](u)"
Lm3:   .asciz "```yaml"
Lm4:   .asciz "x: 1"
Lm5:   .asciz "```"
Lm6:   .asciz "- item"
Lm7:   .asciz "snake_case_name"
Lf1:   .asciz "a/b.yml"
Lf2:   .asciz "x.S"
Lf3:   .asciz "dir/Makefile"
Lf4:   .asciz "x.txt"
Lf5:   .asciz "README.md"
Lf6:   .asciz "/tmp/conf.JSON"
Ldoc:  .asciz "a\n/* x\ny\n*/ z\nw\n"
Lslashes: .asciz "//"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // C
    LEX LANG_C, Lc1, 0
    SLOT_AT 1, 0, S_TYPE
    SLOT_AT 2, 3, T_TEXT
    SLOT_AT 3, 4, S_FUNCTION
    SLOT_AT 4, 8, S_PUNCT
    SLOT_AT 5, 9, S_TYPE
    SLOT_AT 6, 15, S_PUNCT
    SLOT_AT 7, 17, S_KEYWORD
    SLOT_AT 8, 24, S_NUMBER
    SLOT_AT 9, 29, S_COMMENT
    STATE_IS 10, 0
    LEX LANG_C, Lc2, 0
    SLOT_AT 11, 0, S_KEYWORD
    LEX LANG_C, Lc3, 0
    SLOT_AT 12, 2, S_COMMENT
    STATE_IS 13, 1
    LEX LANG_C, Lc4, 1
    SLOT_AT 14, 0, S_COMMENT
    SLOT_AT 15, 5, T_TEXT
    STATE_IS 16, 0
    LEX LANG_C, Lc5, 0
    SLOT_AT 17, 7, S_TYPE

    // YAML
    LEX LANG_YAML, Ly1, 0
    SLOT_AT 20, 2, S_KEY
    SLOT_AT 21, 6, S_PUNCT
    SLOT_AT 22, 8, S_STRING
    SLOT_AT 23, 12, S_COMMENT
    LEX LANG_YAML, Ly2, 0
    SLOT_AT 24, 0, S_PUNCT
    SLOT_AT 25, 2, S_CONSTANT
    LEX LANG_YAML, Ly3, 0
    SLOT_AT 26, 6, S_NUMBER
    LEX LANG_YAML, Ly4, 0
    SLOT_AT 27, 5, S_STRING
    LEX LANG_YAML, Ly5, 0
    SLOT_AT 28, 5, S_OPERATOR
    STATE_IS 29, 1
    LEX LANG_YAML, Ly6, 1
    SLOT_AT 30, 2, S_STRING
    STATE_IS 31, 1
    LEX LANG_YAML, Ly7, 1
    SLOT_AT 32, 0, S_KEY
    STATE_IS 33, 0
    LEX LANG_YAML, Ly8, 0
    SLOT_AT 34, 3, S_TAG
    SLOT_AT 35, 6, S_PUNCT
    SLOT_AT 36, 7, S_NUMBER
    SLOT_AT 37, 10, S_STRING
    SLOT_AT 38, 15, S_KEY
    LEX LANG_YAML, Ly9, 0
    SLOT_AT 39, 1, S_PUNCT

    // JSON
    LEX LANG_JSON, Lj1, 0
    SLOT_AT 40, 1, S_KEY
    SLOT_AT 41, 6, S_STRING
    SLOT_AT 42, 16, S_NUMBER

    // Python
    LEX LANG_PYTHON, Lp1, 0
    SLOT_AT 50, 0, S_KEYWORD
    SLOT_AT 51, 4, S_FUNCTION
    LEX LANG_PYTHON, Lp2, 0
    SLOT_AT 52, 6, S_TYPE
    LEX LANG_PYTHON, Lp3, 0
    SLOT_AT 53, 4, S_STRING
    STATE_IS 54, 1
    LEX LANG_PYTHON, Lp4, 1
    SLOT_AT 55, 0, S_STRING
    SLOT_AT 56, 7, S_OPERATOR
    SLOT_AT 57, 9, S_NUMBER
    STATE_IS 58, 0
    LEX LANG_PYTHON, Lp5, 0
    SLOT_AT 59, 0, S_SPECIAL
    LEX LANG_PYTHON, Lp6, 0
    SLOT_AT 60, 0, S_SPECIAL

    // shell
    LEX LANG_SHELL, Ls1, 0
    SLOT_AT 61, 0, S_SPECIAL
    SLOT_AT 62, 5, S_SPECIAL
    SLOT_AT 63, 11, S_COMMENT
    LEX LANG_SHELL, Ls2, 0
    SLOT_AT 64, 0, S_KEYWORD
    SLOT_AT 65, 13, S_KEYWORD
    LEX LANG_SHELL, Ls3, 0
    SLOT_AT 66, 1, T_TEXT

    // ARM64 assembly
    LEX LANG_ASM, La1, 0
    SLOT_AT 70, 0, S_LABEL
    SLOT_AT 71, 6, S_FUNCTION
    SLOT_AT 72, 10, S_SPECIAL
    SLOT_AT 73, 15, S_SPECIAL
    SLOT_AT 74, 19, S_NUMBER
    SLOT_AT 75, 20, S_NUMBER
    SLOT_AT 76, 23, S_COMMENT
    LEX LANG_ASM, La2, 0
    SLOT_AT 77, 0, S_KEYWORD
    LEX LANG_ASM, La3, 0
    SLOT_AT 78, 4, S_FUNCTION
    SLOT_AT 79, 9, S_LABEL
    LEX LANG_ASM, La4, 0
    SLOT_AT 80, 0, S_LABEL
    SLOT_AT 81, 4, S_FUNCTION
    LEX LANG_ASM, La5, 0
    SLOT_AT 82, 9, S_SPECIAL
    SLOT_AT 83, 13, T_TEXT
    SLOT_AT 84, 16, S_TYPE
    LEX LANG_ASM, La6, 0
    SLOT_AT 85, 9, S_STRING
    LEX LANG_ASM, La7, 0
    STATE_IS 86, 1
    LEX LANG_ASM, La8, 1
    SLOT_AT 87, 0, S_COMMENT
    SLOT_AT 88, 5, S_FUNCTION
    STATE_IS 89, 0
    LEX LANG_ASM, La9, 0
    SLOT_AT 90, 13, T_TEXT

    // Markdown
    LEX LANG_MARKDOWN, Lm1, 0
    SLOT_AT 100, 2, S_HEADING
    LEX LANG_MARKDOWN, Lm2, 0
    SLOT_AT 101, 5, S_STRING
    SLOT_AT 102, 16, S_SPECIAL
    SLOT_AT 103, 25, S_LINK
    SLOT_AT 104, 28, S_TAG
    SLOT_AT 105, 0, T_TEXT
    LEX LANG_MARKDOWN, Lm3, 0
    SLOT_AT 106, 0, S_PUNCT
    STATE_IS 107, 1
    LEX LANG_MARKDOWN, Lm4, 1
    SLOT_AT 108, 0, S_STRING
    LEX LANG_MARKDOWN, Lm5, 1
    STATE_IS 109, 0
    LEX LANG_MARKDOWN, Lm6, 0
    SLOT_AT 110, 0, S_OPERATOR
    LEX LANG_MARKDOWN, Lm7, 0
    SLOT_AT 111, 5, T_TEXT

    // detection
    LANG_OF 120, Lf1, LANG_YAML
    LANG_OF 121, Lf2, LANG_ASM
    LANG_OF 122, Lf3, LANG_SHELL
    LANG_OF 123, Lf4, LANG_NONE
    LANG_OF 124, Lf5, LANG_MARKDOWN
    LANG_OF 125, Lf6, LANG_JSON
    mov x0, #0
    bl _av_hl_lang_for_path
    CHECK 126, LANG_NONE

    // state cache follows edits
    CALL0 _av_doc_init, _tdoc
    LADDR x9, _tdoc
    mov x10, #LANG_C
    str x10, [x9, #DOC_LANG]
    LADDR x0, _tdoc
    mov x1, #0
    LADDR x2, Ldoc
    mov x3, #15
    mov x4, #0
    bl _av_doc_insert
    CALL1 _av_hl_state_at, _tdoc, 2
    CHECK 130, 1
    CALL1 _av_hl_state_at, _tdoc, 3
    CHECK 131, 1
    CALL1 _av_hl_state_at, _tdoc, 4
    CHECK 132, 0
    LADDR x0, _tdoc
    mov x1, #2
    LADDR x2, Lslashes
    mov x3, #2
    mov x4, #0
    bl _av_doc_insert
    CALL1 _av_hl_state_at, _tdoc, 2
    CHECK 133, 0
    CALL1 _av_hl_state_at, _tdoc, 4
    CHECK 134, 0
    // undo restores the open comment
    CALL0 _av_doc_undo, _tdoc
    CALL1 _av_hl_state_at, _tdoc, 3
    CHECK 135, 1

    bl Lsummary
    ldp x29, x30, [sp], #16
    ret

// x0 = slot index of the run covering byte x0, -1 if no run covers it
    .p2align 2
Lslot_at:
    LDRG x9, _tn
    LADDR x10, _av_runs
1:  cbz x9, 3f
    ldr w11, [x10, #RUN_START]
    ldrh w12, [x10, #RUN_LEN]
    add x12, x11, x12
    cmp x0, x11
    b.lo 2f
    cmp x0, x12
    b.hs 2f
    ldrh w0, [x10, #RUN_SLOT]
    ret
2:  add x10, x10, #RUN_SIZE
    sub x9, x9, #1
    b 1b
3:  mov x0, #-1
    ret
