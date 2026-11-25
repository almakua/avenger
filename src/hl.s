// syntax highlighting: per-line lexers producing color runs, plus a per-line start state cache
//
// lexers share these registers (saved once by av_hl_lex):
// x19 line bytes, x20 pos, x21 len, x22 runs (0 = only track state), x23 run count,
// x24 state, x25 language definition, x26 end of the last emitted run, x27/x28 lexer scratch

.include "macros.inc"
.include "buffer.inc"
.include "doc.inc"
.include "theme.inc"
.include "hl.inc"
.include "charclass.inc"

.set SL_TEXT,     T_TEXT / T_SLOT
.set SL_KEYWORD,  S_KEYWORD / T_SLOT
.set SL_STRING,   S_STRING / T_SLOT
.set SL_NUMBER,   S_NUMBER / T_SLOT
.set SL_COMMENT,  S_COMMENT / T_SLOT
.set SL_TYPE,     S_TYPE / T_SLOT
.set SL_FUNCTION, S_FUNCTION / T_SLOT
.set SL_OPERATOR, S_OPERATOR / T_SLOT
.set SL_PUNCT,    S_PUNCT / T_SLOT
.set SL_CONSTANT, S_CONSTANT / T_SLOT
.set SL_KEY,      S_KEY / T_SLOT
.set SL_LABEL,    S_LABEL / T_SLOT
.set SL_SPECIAL,  S_SPECIAL / T_SLOT
.set SL_ESCAPE,   S_ESCAPE / T_SLOT
.set SL_TAG,      S_TAG / T_SLOT
.set SL_HEADING,  S_HEADING / T_SLOT
.set SL_LINK,     S_LINK / T_SLOT

// word list: length-prefixed strings, 0-terminated
.macro WORDS list:vararg
    .irp w, \list
    .byte 2f - 1f
1:  .ascii "\w"
2:
    .endr
    .byte 0
.endm

// wd = byte at index xi, 0 past the end (line buffers have slack after len); wd may alias xi
.macro CH wd, xi
    cmp \xi, x21
    ldrb \wd, [x19, \xi]
    csel \wd, \wd, wzr, lo
.endm

// emit [s, e) with slot sl
.macro EMIT s, e, sl
    mov x0, \s
    mov x1, \e
    mov w2, #\sl
    bl Lemit
.endm

    .section __TEXT,__const
Lclass:
    CHARCLASS_TABLE

Lnone:        .byte 0
Lc_kw:        WORDS auto, break, case, const, continue, default, do, else, enum, extern, for, goto, if, inline, register, restrict, return, sizeof, static, struct, switch, typedef, union, volatile, while, class, namespace, template, typename, public, private, protected, new, delete, this, using, virtual, override, try, catch, throw, nullptr, constexpr, operator, friend
Lc_types:     WORDS void, char, short, int, long, float, double, signed, unsigned, bool, size_t, ssize_t, uint8_t, uint16_t, uint32_t, uint64_t, int8_t, int16_t, int32_t, int64_t, uintptr_t, intptr_t, ptrdiff_t, off_t, id, BOOL, SEL, Class, FILE, auto
Lc_consts:    WORDS NULL, true, false, nil, YES, NO, EOF
Lc_deftype:   WORDS struct, enum, union, class
Lpy_kw:       WORDS and, as, assert, async, await, break, class, continue, def, del, elif, else, except, finally, for, from, global, if, import, in, is, lambda, nonlocal, not, or, pass, raise, return, try, while, with, yield, match, case
Lpy_consts:   WORDS True, False, None, self, cls
Lpy_builtins: WORDS print, len, range, int, str, float, list, dict, set, tuple, open, isinstance, super, enumerate, zip, map, filter, sorted, type, object, Exception, bool, min, max, sum, any, all, repr, getattr, setattr, hasattr, bytes, iter, next
Lpy_deffn:    WORDS def
Lpy_deftype:  WORDS class
Lsh_kw:       WORDS if, then, else, elif, fi, for, while, until, do, done, case, esac, in, function, return, select, local, export, readonly, declare, set, unset, shift, exit, break, continue, source, alias
Lsh_builtins: WORDS echo, printf, cd, pwd, test, read, eval, exec, trap, wait, kill, true, false
Lsh_deffn:    WORDS function
Ljson_consts: WORDS true, false, null
Lyaml_consts: WORDS true, false, yes, no, on, off, null, True, False, Yes, No, On, Off, Null, TRUE, FALSE, YES, NO, ON, OFF, NULL
Lasm_regs:    WORDS sp, wsp, xzr, wzr, lr, fp, pc

Lpat_cclose:  .ascii "*/"
Lpat_tdq:     .ascii "\"\"\""
Lpat_tsq:     .ascii "'''"
Lpat_fence:   .ascii "```"
Lpat_tilde:   .ascii "~~~"
Lpat_dashes:  .ascii "---"
Lpat_dots:    .ascii "..."
Lpat_bold:    .ascii "**"
Lpat_ubold:   .ascii "__"
Lpat_http:    .ascii "http"

    .section __TEXT,__cstring,cstring_literals
Le_yaml:      .asciz "yaml"
Le_yml:       .asciz "yml"
Le_s:         .asciz "s"
Le_asm:       .asciz "asm"
Le_inc:       .asciz "inc"
Le_c:         .asciz "c"
Le_h:         .asciz "h"
Le_m:         .asciz "m"
Le_cc:        .asciz "cc"
Le_cpp:       .asciz "cpp"
Le_hpp:       .asciz "hpp"
Le_cxx:       .asciz "cxx"
Le_json:      .asciz "json"
Le_sh:        .asciz "sh"
Le_bash:      .asciz "bash"
Le_zsh:       .asciz "zsh"
Le_py:        .asciz "py"
Le_md:        .asciz "md"
Le_markdown:  .asciz "markdown"
Lb_make:      .asciz "Makefile"
Lb_gnumake:   .asciz "GNUmakefile"
Lb_docker:    .asciz "Dockerfile"
Lb_zshrc:     .asciz ".zshrc"
Lb_bashrc:    .asciz ".bashrc"
Lb_profile:   .asciz ".profile"
Ls_python:    .asciz "python"

    .section __DATA,__const
    .p2align 3
Ldef_none:   .quad 0, Lnone, Lnone, Lnone, Lnone, Lnone, Lnone, Lplain
Ldef_yaml:   .quad LF_STATEFUL, Lnone, Lnone, Lnone, Lnone, Lnone, Lnone, Lyaml
Ldef_asm:    .quad LF_STATEFUL, Lnone, Lnone, Lnone, Lnone, Lnone, Lnone, Lasm
Ldef_c:      .quad LF_STATEFUL | LF_CCOMMENT | LF_SQ | LF_FUNC | LF_PREPROC
             .quad Lc_kw, Lc_types, Lc_consts, Lnone, Lnone, Lc_deftype, 0
Ldef_json:   .quad LF_JSONKEY, Lnone, Lnone, Ljson_consts, Lnone, Lnone, Lnone, 0
Ldef_shell:  .quad LF_HASH | LF_SQ | LF_BT | LF_SHELL
             .quad Lsh_kw, Lnone, Lnone, Lsh_builtins, Lsh_deffn, Lnone, 0
Ldef_python: .quad LF_STATEFUL | LF_HASH | LF_SQ | LF_TRIPLE | LF_FUNC | LF_DECOR
             .quad Lpy_kw, Lnone, Lpy_consts, Lpy_builtins, Lpy_deffn, Lpy_deftype, 0
Ldef_md:     .quad LF_STATEFUL, Lnone, Lnone, Lnone, Lnone, Lnone, Lnone, Lmd
Llangs:
    .quad Ldef_none, Ldef_yaml, Ldef_asm, Ldef_c, Ldef_json, Ldef_shell, Ldef_python, Ldef_md

    // extension or file name -> language
Lexts:
    .quad Le_yaml, LANG_YAML, Le_yml, LANG_YAML
    .quad Le_s, LANG_ASM, Le_asm, LANG_ASM, Le_inc, LANG_ASM
    .quad Le_c, LANG_C, Le_h, LANG_C, Le_m, LANG_C, Le_cc, LANG_C, Le_cpp, LANG_C, Le_hpp, LANG_C, Le_cxx, LANG_C
    .quad Le_json, LANG_JSON
    .quad Le_sh, LANG_SHELL, Le_bash, LANG_SHELL, Le_zsh, LANG_SHELL
    .quad Le_py, LANG_PYTHON
    .quad Le_md, LANG_MARKDOWN, Le_markdown, LANG_MARKDOWN
Lexts_end:
Lnames:
    .quad Lb_make, LANG_SHELL, Lb_gnumake, LANG_SHELL, Lb_docker, LANG_SHELL
    .quad Lb_zshrc, LANG_SHELL, Lb_bashrc, LANG_SHELL, Lb_profile, LANG_SHELL
Lnames_end:

    .zerofill __DATA,__bss,_av_runs,(MAX_RUNS * RUN_SIZE),4
    .zerofill __DATA,__bss,_av_hl_line,(HL_LINE_MAX + 32),4
    .globl _av_runs

    .text
// (state, nruns) av_hl_lex(lang, const char *p, size_t n, state, Run *runs or NULL)
FUNC_BEGIN _av_hl_lex
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    cmp x0, #LANG_COUNT
    csel x0, x0, xzr, lo
    LADDR x9, Llangs
    ldr x25, [x9, x0, lsl #3]
    mov x19, x1
    mov x20, #0
    mov x21, x2
    mov x22, x4
    mov x23, #0
    mov x24, x3
    mov x26, #0
    mov x27, #0
    ldr x9, [x25, #LD_LEXER]
    cbnz x9, 1f
    LADDR x9, Lgeneric
1:  blr x9
    // whatever is left uncolored is plain text
    EMIT x21, x21, SL_TEXT
    mov x0, x24
    mov x1, x23
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// ---- shared lexer helpers (leaf, x0..x17 only) ----

// append run [xs, e) slot sl (ws = 32-bit view of xs), merging with the previous run
// when contiguous and same color
.macro PUSH xs, ws, e, sl
    cbz x23, 91f
    add x6, x22, x23, lsl #3
    ldurh w7, [x6, #(RUN_SLOT - RUN_SIZE)]
    cmp w7, \sl
    b.ne 91f
    ldur w7, [x6, #(RUN_START - RUN_SIZE)]
    ldurh w8, [x6, #(RUN_LEN - RUN_SIZE)]
    add x8, x7, x8
    cmp x8, \xs
    b.ne 91f
    sub x8, \e, x7
    sturh w8, [x6, #(RUN_LEN - RUN_SIZE)]
    b 92f
91: cmp x23, #MAX_RUNS
    b.hs 93f
    add x6, x22, x23, lsl #3
    str \ws, [x6, #RUN_START]
    sub x8, \e, \xs
    strh w8, [x6, #RUN_LEN]
    strh \sl, [x6, #RUN_SLOT]
    add x23, x23, #1
    b 92f
    // out of runs: stretch the last one
93: add x6, x22, x23, lsl #3
    ldur w7, [x6, #(RUN_START - RUN_SIZE)]
    sub x8, \e, x7
    sturh w8, [x6, #(RUN_LEN - RUN_SIZE)]
92:
.endm

// emit run [x0, x1) slot w2, the gap since the previous run becomes plain text
    .p2align 2
Lemit:
    cbz x22, 9f
    cmp x0, x26
    b.ls 1f
    mov w5, #SL_TEXT
    PUSH x26, w26, x0, w5
    mov x26, x0
1:  cmp x1, x0
    b.ls 8f
    PUSH x0, w0, x1, w2
8:  cmp x1, x26
    csel x26, x1, x26, hi
9:  ret

// x0 = first index >= x0 whose class has none of the bits in w1
    .p2align 2
Lscan:
    LADDR x10, Lclass
1:  cmp x0, x21
    b.hs 2f
    ldrb w9, [x19, x0]
    ldrb w9, [x10, x9]
    tst w9, w1
    b.eq 2f
    add x0, x0, #1
    b 1b
2:  ret

// x0 = first non-blank index >= x0
    .p2align 2
Lskip_sp:
    mov w1, #C_SPACE
    b Lscan

// x14 = end of a number token starting at x0 (identifier chars and dots)
    .p2align 2
Lscan_number:
    LADDR x10, Lclass
1:  cmp x0, x21
    b.hs 2f
    ldrb w9, [x19, x0]
    cmp w9, #'.'
    b.eq 3f
    ldrb w11, [x10, x9]
    tst w11, #C_IDENT
    b.eq 2f
3:  add x0, x0, #1
    b 1b
2:  mov x14, x0
    ret

// w0 = 1 if bytes [x1, x1 + x2) of the line are in word list x0
    .p2align 2
Lword_in:
1:  ldrb w9, [x0]
    cbz w9, 4f
    cmp x9, x2
    b.ne 3f
    mov x10, #0
2:  cmp x10, x2
    b.hs 5f
    add x11, x0, #1
    ldrb w12, [x11, x10]
    add x13, x19, x1
    ldrb w13, [x13, x10]
    cmp w12, w13
    b.ne 3f
    add x10, x10, #1
    b 2b
3:  add x0, x0, x9
    add x0, x0, #1
    b 1b
4:  mov w0, #0
    ret
5:  mov w0, #1
    ret

// x0 = index after the first occurrence of pattern x1 (x2 bytes) at or after x0, -1 if none
    .p2align 2
Lfind_seq:
1:  add x9, x0, x2
    cmp x9, x21
    b.hi 4f
    mov x10, #0
2:  cmp x10, x2
    b.hs 3f
    ldrb w11, [x1, x10]
    add x12, x0, x10
    ldrb w12, [x19, x12]
    cmp w11, w12
    b.ne 5f
    add x10, x10, #1
    b 2b
5:  add x0, x0, #1
    b 1b
3:  add x0, x0, x2
    ret
4:  mov x0, #-1
    ret

// x0 = index of byte w1 at or after x0, -1 if none
    .p2align 2
Lfind_char:
1:  cmp x0, x21
    b.hs 2f
    ldrb w9, [x19, x0]
    cmp w9, w1
    b.eq 3f
    add x0, x0, #1
    b 1b
2:  mov x0, #-1
3:  ret

// w0 = 1 if pattern x1 (x2 bytes) occurs exactly at x0
    .p2align 2
Lmatch_at:
    add x9, x0, x2
    cmp x9, x21
    b.hi 2f
    mov x10, #0
1:  cmp x10, x2
    b.hs 3f
    ldrb w11, [x1, x10]
    add x12, x0, x10
    ldrb w12, [x19, x12]
    cmp w11, w12
    b.ne 2f
    add x10, x10, #1
    b 1b
2:  mov w0, #0
    ret
3:  mov w0, #1
    ret

// x0 = index after the string opened by quote w1 at x0; w2 = 1 honours backslash escapes
    .p2align 2
Lstring_end:
    add x0, x0, #1
1:  cmp x0, x21
    b.hs 9f
    ldrb w9, [x19, x0]
    cbz w2, 2f
    cmp w9, #'\\'
    b.ne 2f
    add x0, x0, #2
    b 1b
2:  add x0, x0, #1
    cmp w9, w1
    b.ne 1b
    ret
9:  mov x0, x21
    ret

// w0 = 1 if the byte before x0 is blank (or x0 is the line start)
    .p2align 2
Lblank_before:
    cbz x0, 2f
    sub x9, x0, #1
    ldrb w9, [x19, x9]
    LADDR x10, Lclass
    ldrb w9, [x10, x9]
    and w0, w9, #C_SPACE
    lsr w0, w0, #5
    ret
2:  mov w0, #1
    ret

// ---- lexers ----

    .p2align 2
Lplain:
    ret

// table-driven lexer for C-like, JSON, shell and Python; x27 = 1/2 when the next identifier
// names a function/type, x28 = language flags
    .p2align 2
Lgeneric:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x28, [x25, #LD_FLAGS]
    cbz x24, Lg_loop
    // construct left open by the previous line: comment, or triple-quoted string
    LADDR x1, Lpat_cclose
    mov x2, #2
    mov x27, #SL_COMMENT
    tbz x28, #5, 1f
    LADDR x1, Lpat_tdq
    cmp x24, #1
    b.eq 2f
    LADDR x1, Lpat_tsq
2:  mov x2, #3
    mov x27, #SL_STRING
1:  mov x0, #0
    bl Lfind_seq
    tbnz x0, #63, 3f
    mov x1, x0
    mov x0, #0
    mov w2, w27
    bl Lemit
    mov x20, x1
    mov x24, #0
    mov x27, #0
    b Lg_loop
3:  mov x0, #0
    mov x1, x21
    mov w2, w27
    bl Lemit
    b Lg_done

Lg_loop:
    cmp x20, x21
    b.hs Lg_done
    ldrb w9, [x19, x20]
    LADDR x10, Lclass
    ldrb w10, [x10, x9]
    tst w10, #C_SPACE
    b.eq 1f
    add x20, x20, #1
    b Lg_loop
1:  cmp w9, #'#'
    b.ne 3f
    tbz x28, #10, 2f
    // preprocessor directive when only blanks precede it
    mov x0, #0
    bl Lskip_sp
    cmp x0, x20
    b.ne 2f
    add x0, x20, #1
    mov w1, #C_IDENT
    bl Lscan
    mov x14, x0
    EMIT x20, x14, SL_KEYWORD
    mov x20, x14
    b Lg_loop
2:  tbz x28, #2, 3f
    mov x0, x20
    bl Lblank_before
    cbz w0, Lg_other
    EMIT x20, x21, SL_COMMENT
    b Lg_done
3:  ldrb w9, [x19, x20]
    cmp w9, #'/'
    b.ne 5f
    tbz x28, #1, 5f
    add x11, x20, #1
    CH w11, x11
    cmp w11, #'/'
    b.ne 4f
    EMIT x20, x21, SL_COMMENT
    b Lg_done
4:  cmp w11, #'*'
    b.ne 5f
    add x0, x20, #2
    LADDR x1, Lpat_cclose
    mov x2, #2
    bl Lfind_seq
    tbnz x0, #63, 41f
    mov x14, x0
    EMIT x20, x14, SL_COMMENT
    mov x20, x14
    b Lg_loop
41: EMIT x20, x21, SL_COMMENT
    mov x24, #1
    b Lg_done

5:  cmp w9, #'"'
    b.eq 6f
    cmp w9, #'\''
    b.ne 51f
    tbnz x28, #3, 6f
51: cmp w9, #'`'
    b.ne 7f
    tbz x28, #4, 7f
6:  tbz x28, #5, 61f
    add x11, x20, #1
    CH w11, x11
    cmp w11, w9
    b.ne 61f
    add x11, x20, #2
    CH w11, x11
    cmp w11, w9
    b.ne 61f
    // triple-quoted string, state 1 for """ and 2 for '''
    mov x13, #1
    LADDR x1, Lpat_tdq
    cmp w9, #'"'
    b.eq 62f
    mov x13, #2
    LADDR x1, Lpat_tsq
62: add x0, x20, #3
    mov x2, #3
    bl Lfind_seq
    tbnz x0, #63, 63f
    mov x14, x0
    EMIT x20, x14, SL_STRING
    mov x20, x14
    b Lg_loop
63: mov x24, x13
    EMIT x20, x21, SL_STRING
    b Lg_done
61: mov x0, x20
    mov w1, w9
    mov w2, #1
    bl Lstring_end
    mov x14, x0
    mov w15, #SL_STRING
    tbz x28, #7, 64f
    bl Lskip_sp
    CH w11, x0
    cmp w11, #':'
    mov w11, #SL_KEY
    csel w15, w11, w15, eq
64: mov x0, x20
    mov x1, x14
    mov w2, w15
    bl Lemit
    mov x20, x14
    b Lg_loop

    // $VAR, ${...}, $1, $@ ...
7:  cmp w9, #'$'
    b.ne 8f
    tbz x28, #8, 8f
    add x11, x20, #1
    CH w11, x11
    cmp w11, #'{'
    b.ne 71f
    add x0, x20, #2
    mov w1, #'}'
    bl Lfind_char
    add x14, x0, #1
    cmp x0, #0
    csel x14, x21, x14, lt
    b 72f
71: add x0, x20, #1
    mov w1, #C_IDENT
    bl Lscan
    mov x14, x0
    add x12, x20, #1
    cmp x14, x12
    b.ne 72f
    add x14, x20, #2
    cmp x14, x21
    csel x14, x21, x14, hi
72: EMIT x20, x14, SL_SPECIAL
    mov x20, x14
    b Lg_loop

8:  cmp w9, #'@'
    b.ne 9f
    tbz x28, #9, 9f
    add x0, x20, #1
    mov w1, #C_IDENT
    bl Lscan
    mov x14, x0
    EMIT x20, x14, SL_SPECIAL
    mov x20, x14
    b Lg_loop

9:  ldrb w9, [x19, x20]
    LADDR x10, Lclass
    ldrb w10, [x10, x9]
    tst w10, #C_DIGIT
    b.ne 91f
    cmp w9, #'.'
    b.ne 92f
    add x11, x20, #1
    CH w11, x11
    LADDR x12, Lclass
    ldrb w11, [x12, x11]
    tst w11, #C_DIGIT
    b.eq 92f
91: mov x0, x20
    bl Lscan_number
    EMIT x20, x14, SL_NUMBER
    mov x20, x14
    b Lg_loop
92: tst w10, #C_START
    b.eq 93f
    bl Lident
    b Lg_loop
93: tst w10, #C_OP
    b.eq 94f
    add x14, x20, #1
    EMIT x20, x14, SL_OPERATOR
    mov x20, x14
    b Lg_loop
94: tst w10, #C_PUNCT
    b.eq Lg_other
    add x14, x20, #1
    EMIT x20, x14, SL_PUNCT
    mov x20, x14
    b Lg_loop
Lg_other:
    add x20, x20, #1
    b Lg_loop
Lg_done:
    ldp x29, x30, [sp], #16
    ret

// identifier at x20 for the generic lexer: word lists, then definition names and calls
    .p2align 2
Lident:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add x0, x20, #1
    mov w1, #C_IDENT
    bl Lscan
    mov x14, x0
    sub x15, x14, x20
    ldr x0, [x25, #LD_KEYWORDS]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    cbz w0, 1f
    mov x27, #0
    ldr x0, [x25, #LD_DEFFN]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    cbz w0, 11f
    mov x27, #1
11: ldr x0, [x25, #LD_DEFTYPE]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    cbz w0, 12f
    mov x27, #2
12: mov w2, #SL_KEYWORD
    b 8f
1:  ldr x0, [x25, #LD_TYPES]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    mov w2, #SL_TYPE
    cbnz w0, 7f
    ldr x0, [x25, #LD_CONSTS]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    mov w2, #SL_CONSTANT
    cbnz w0, 7f
    ldr x0, [x25, #LD_BUILTINS]
    mov x1, x20
    mov x2, x15
    bl Lword_in
    mov w2, #SL_SPECIAL
    cbnz w0, 7f
    cmp x27, #1
    mov w2, #SL_FUNCTION
    b.eq 7f
    cmp x27, #2
    mov w2, #SL_TYPE
    b.eq 7f
    tbz x28, #6, 6f
    mov x0, x14
    bl Lskip_sp
    CH w9, x0
    cmp w9, #'('
    mov w2, #SL_FUNCTION
    b.eq 7f
6:  mov x27, #0
    mov x20, x14
    ldp x29, x30, [sp], #16
    ret
7:  mov x27, #0
8:  mov x0, x20
    mov x1, x14
    bl Lemit
    mov x20, x14
    ldp x29, x30, [sp], #16
    ret

// ---- YAML ----
// state: 0, or 1 + indent of the line that opened a block scalar (| or >)

// x0 = index of the ':' ending a mapping key that starts at x20, -1 if this is not a key
    .p2align 2
Ly_keyend:
    mov x0, x20
    ldrb w9, [x19, x0]
    cmp w9, #'['
    b.eq 9f
    cmp w9, #'{'
    b.eq 9f
    cmp w9, #'"'
    b.eq 5f
    cmp w9, #'\''
    b.eq 5f
1:  cmp x0, x21
    b.hs 9f
    ldrb w9, [x19, x0]
    cmp w9, #'#'
    b.ne 2f
    cmp x0, x20
    b.eq 9f
    sub x10, x0, #1
    ldrb w10, [x19, x10]
    cmp w10, #' '
    b.eq 9f
2:  cmp w9, #':'
    b.ne 3f
    add x10, x0, #1
    cmp x10, x21
    b.hs 4f
    ldrb w10, [x19, x10]
    cmp w10, #' '
    b.eq 4f
    cmp w10, #9
    b.eq 4f
3:  add x0, x0, #1
    b 1b
4:  ret
    // quoted key: the closing quote, blanks, then ':'
5:  mov w11, w9
    add x0, x0, #1
6:  cmp x0, x21
    b.hs 9f
    ldrb w9, [x19, x0]
    add x0, x0, #1
    cmp w11, #'"'
    b.ne 7f
    cmp w9, #'\\'
    b.ne 7f
    add x0, x0, #1
    b 6b
7:  cmp w9, w11
    b.ne 6b
8:  cmp x0, x21
    b.hs 9f
    ldrb w9, [x19, x0]
    cmp w9, #' '
    b.ne 81f
    add x0, x0, #1
    b 8b
81: cmp w9, #':'
    b.eq 4b
9:  mov x0, #-1
    ret

// w2 = slot of plain scalar [x20, x15): constant, number or string
    .p2align 2
Ly_classify:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub x2, x15, x20
    cbz x2, 8f
    ldrb w9, [x19, x20]
    cmp x2, #1
    b.ne 1f
    cmp w9, #'~'
    b.eq 7f
1:  LADDR x0, Lyaml_consts
    mov x1, x20
    bl Lword_in
    cbnz w0, 7f
    // number: optional sign, a digit (or .digit) first, then digits/letters/dots/underscores
    mov x10, x20
    ldrb w9, [x19, x10]
    cmp w9, #'-'
    b.eq 2f
    cmp w9, #'+'
    b.ne 3f
2:  add x10, x10, #1
3:  cmp x10, x15
    b.hs 6f
    ldrb w9, [x19, x10]
    cmp w9, #'.'
    b.ne 4f
    add x10, x10, #1
    cmp x10, x15
    b.hs 6f
    ldrb w9, [x19, x10]
4:  sub w9, w9, #'0'
    cmp w9, #9
    b.hi 6f
    LADDR x11, Lclass
5:  cmp x10, x15
    b.hs 9f
    ldrb w9, [x19, x10]
    add x10, x10, #1
    cmp w9, #'.'
    b.eq 5b
    cmp w9, #':'
    b.eq 5b
    ldrb w12, [x11, x9]
    tst w12, #C_IDENT
    b.ne 5b
6:  mov w2, #SL_STRING
    b 10f
7:  mov w2, #SL_CONSTANT
    b 10f
8:  mov w2, #SL_TEXT
    b 10f
9:  mov w2, #SL_NUMBER
10: ldp x29, x30, [sp], #16
    ret

// x14 = end of a plain scalar at x20 (EOL or " #"), x15 = end with trailing blanks trimmed
// w1 = 1 also stops at flow indicators and ": "
    .p2align 2
Ly_plain_end:
    mov x14, x20
1:  cmp x14, x21
    b.hs 4f
    ldrb w9, [x19, x14]
    cmp w9, #'#'
    b.ne 2f
    cmp x14, x20
    b.eq 2f
    sub x10, x14, #1
    ldrb w10, [x19, x10]
    cmp w10, #' '
    b.eq 4f
2:  cbz w1, 3f
    cmp w9, #','
    b.eq 4f
    cmp w9, #']'
    b.eq 4f
    cmp w9, #'}'
    b.eq 4f
    cmp w9, #'['
    b.eq 4f
    cmp w9, #'{'
    b.eq 4f
    cmp w9, #':'
    b.ne 3f
    add x10, x14, #1
    CH w10, x10
    cmp w10, #' '
    b.eq 4f
    cbz w10, 4f
3:  add x14, x14, #1
    b 1b
4:  mov x15, x14
5:  cmp x15, x20
    b.ls 6f
    sub x10, x15, #1
    ldrb w10, [x19, x10]
    cmp w10, #' '
    b.eq 51f
    cmp w10, #9
    b.ne 6f
51: sub x15, x15, #1
    b 5b
6:  ret

// x28 = indentation of the line
    .p2align 2
Lyaml:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, #0
    bl Lskip_sp
    mov x28, x0
    cbz x24, Ly_normal
    // inside a block scalar: blank lines and deeper lines belong to it
    cmp x28, x21
    b.hs Ly_done
    cmp x28, x24
    b.lo 1f
    EMIT x28, x21, SL_STRING
    b Ly_done
1:  mov x24, #0
Ly_normal:
    mov x20, x28
    cbnz x28, Ly_item
    mov x0, #0
    LADDR x1, Lpat_dashes
    mov x2, #3
    bl Lmatch_at
    cbnz w0, 2f
    mov x0, #0
    LADDR x1, Lpat_dots
    mov x2, #3
    bl Lmatch_at
    cbz w0, Ly_item
2:  mov x11, #3
    CH w11, x11
    cmp w11, #' '
    b.eq 3f
    cbnz w11, Ly_item
3:  mov x14, #3
    EMIT xzr, x14, SL_PUNCT
    mov x20, #3
Ly_item:
    mov x0, x20
    bl Lskip_sp
    mov x20, x0
    cmp x20, x21
    b.hs Ly_done
    ldrb w9, [x19, x20]
    cmp w9, #'#'
    b.eq Ly_comment
    cmp w9, #'-'
    b.ne Ly_key
    add x11, x20, #1
    CH w11, x11
    cmp w11, #' '
    b.eq 4f
    cmp w11, #9
    b.eq 4f
    cbnz w11, Ly_key
4:  add x14, x20, #1
    EMIT x20, x14, SL_PUNCT
    mov x20, x14
    b Ly_item
Ly_key:
    bl Ly_keyend
    tbnz x0, #63, Ly_value
    mov x14, x0
    EMIT x20, x14, SL_KEY
    add x15, x14, #1
    EMIT x14, x15, SL_PUNCT
    mov x20, x15
Ly_value:
    mov x0, x20
    bl Lskip_sp
    mov x20, x0
    cmp x20, x21
    b.hs Ly_done
    ldrb w9, [x19, x20]
    cmp w9, #'#'
    b.eq Ly_comment
    cmp w9, #'&'
    b.eq 5f
    cmp w9, #'*'
    b.eq 5f
    cmp w9, #'!'
    b.ne 6f
    // anchor, alias or tag up to the next blank
5:  add x14, x20, #1
51: cmp x14, x21
    b.hs 52f
    ldrb w9, [x19, x14]
    cmp w9, #' '
    b.eq 52f
    cmp w9, #9
    b.eq 52f
    add x14, x14, #1
    b 51b
52: EMIT x20, x14, SL_TAG
    mov x20, x14
    b Ly_value
6:  cmp w9, #'|'
    b.eq 7f
    cmp w9, #'>'
    b.ne 8f
    // block scalar header; following deeper lines are its content
7:  add x14, x20, #1
71: cmp x14, x21
    b.hs 72f
    ldrb w9, [x19, x14]
    cmp w9, #' '
    b.eq 72f
    cmp w9, #'#'
    b.eq 72f
    add x14, x14, #1
    b 71b
72: EMIT x20, x14, SL_OPERATOR
    add x24, x28, #1
    mov x9, #255
    cmp x24, x9
    csel x24, x9, x24, hi
    mov x20, x14
    b Ly_value
8:  cmp w9, #'"'
    b.eq 81f
    cmp w9, #'\''
    b.ne 82f
81: mov x0, x20
    mov w1, w9
    cmp w9, #'"'
    cset w2, eq
    bl Lstring_end
    mov x14, x0
    EMIT x20, x14, SL_STRING
    mov x20, x14
    b Ly_value
82: cmp w9, #'['
    b.eq Ly_flow
    cmp w9, #'{'
    b.eq Ly_flow
    mov w1, #0
    bl Ly_plain_end
    bl Ly_classify
    mov x0, x20
    mov x1, x15
    bl Lemit
    mov x20, x14
    b Ly_value
Ly_comment:
    EMIT x20, x21, SL_COMMENT
Ly_done:
    ldp x29, x30, [sp], #16
    ret

// flow collection: indicators, quoted and plain scalars, "key:" pairs
Ly_flow:
    cmp x20, x21
    b.hs Ly_done
    ldrb w9, [x19, x20]
    cmp w9, #' '
    b.eq 1f
    cmp w9, #9
    b.ne 2f
1:  add x20, x20, #1
    b Ly_flow
2:  cmp w9, #'#'
    b.ne 3f
    mov x0, x20
    bl Lblank_before
    cbnz w0, Ly_comment
3:  cmp w9, #','
    b.eq 4f
    cmp w9, #'['
    b.eq 4f
    cmp w9, #']'
    b.eq 4f
    cmp w9, #'{'
    b.eq 4f
    cmp w9, #'}'
    b.eq 4f
    cmp w9, #':'
    b.ne 5f
4:  add x14, x20, #1
    EMIT x20, x14, SL_PUNCT
    mov x20, x14
    b Ly_flow
5:  cmp w9, #'"'
    b.eq 51f
    cmp w9, #'\''
    b.ne 6f
51: mov x0, x20
    mov w1, w9
    cmp w9, #'"'
    cset w2, eq
    bl Lstring_end
    mov x14, x0
    mov x15, x0
    mov w2, #SL_STRING
    b 7f
6:  mov w1, #1
    bl Ly_plain_end
    bl Ly_classify
    // anything followed by ':' is a key
7:  mov w27, w2
    mov x0, x14
    bl Lskip_sp
    CH w9, x0
    cmp w9, #':'
    mov w9, #SL_KEY
    csel w2, w9, w27, eq
    mov x0, x20
    mov x1, x15
    bl Lemit
    cmp x14, x20
    b.hi 8f
    add x14, x20, #1
8:  mov x20, x14
    b Ly_flow

// ---- Markdown ----
// state 1 inside a fenced code block

    .p2align 2
Lmd:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, #0
    bl Lskip_sp
    mov x28, x0
    mov x27, #0
    LADDR x1, Lpat_fence
    mov x2, #3
    bl Lmatch_at
    cbnz w0, 1f
    mov x0, x28
    LADDR x1, Lpat_tilde
    mov x2, #3
    bl Lmatch_at
1:  cbz x24, 2f
    cbz w0, 11f
    mov x24, #0
    EMIT xzr, x21, SL_PUNCT
    b Lmd_done
11: EMIT xzr, x21, SL_STRING
    b Lmd_done
2:  cbz w0, 3f
    mov x24, #1
    EMIT xzr, x21, SL_PUNCT
    b Lmd_done
3:  cmp x28, x21
    b.hs Lmd_done
    ldrb w9, [x19, x28]
    cmp w9, #'#'
    b.ne 4f
    // heading: 1-6 '#' then a blank or the end
    mov x10, x28
31: ldrb w11, [x19, x10]
    cmp x10, x21
    b.hs 32f
    cmp w11, #'#'
    b.ne 32f
    add x10, x10, #1
    b 31b
32: sub x11, x10, x28
    cmp x11, #6
    b.hi Lmd_inline_start
    CH w11, x10
    cmp w11, #' '
    b.eq 33f
    cbnz w11, Lmd_inline_start
33: EMIT x28, x21, SL_HEADING
    b Lmd_done
4:  cmp w9, #'>'
    b.ne 5f
    EMIT x28, x21, SL_COMMENT
    b Lmd_done
5:  cmp w9, #'-'
    b.eq 51f
    cmp w9, #'*'
    b.eq 51f
    cmp w9, #'_'
    b.ne 6f
    // thematic break: three or more of the same mark, blanks allowed
51: mov x10, x28
    mov x11, #0
52: cmp x10, x21
    b.hs 54f
    ldrb w12, [x19, x10]
    add x10, x10, #1
    cmp w12, #' '
    b.eq 52b
    cmp w12, w9
    b.ne 6f
    add x11, x11, #1
    b 52b
54: cmp x11, #3
    b.lo 6f
    EMIT x28, x21, SL_PUNCT
    b Lmd_done
    // list markers
6:  cmp w9, #'-'
    b.eq 61f
    cmp w9, #'*'
    b.eq 61f
    cmp w9, #'+'
    b.ne 62f
61: add x11, x28, #1
    CH w11, x11
    cmp w11, #' '
    b.ne Lmd_inline_start
    add x14, x28, #1
    EMIT x28, x14, SL_OPERATOR
    mov x20, x14
    b Lmd_inline
62: mov x10, x28
63: ldrb w11, [x19, x10]
    cmp x10, x21
    b.hs Lmd_inline_start
    sub w12, w11, #'0'
    cmp w12, #9
    b.hi 64f
    add x10, x10, #1
    b 63b
64: cmp x10, x28
    b.eq Lmd_inline_start
    cmp w11, #'.'
    b.eq 65f
    cmp w11, #')'
    b.ne Lmd_inline_start
65: add x14, x10, #1
    EMIT x28, x14, SL_OPERATOR
    mov x20, x14
    b Lmd_inline
Lmd_inline_start:
    mov x20, x28
Lmd_inline:
    cmp x20, x21
    b.hs Lmd_done
    ldrb w9, [x19, x20]
    cmp w9, #'`'
    b.ne 2f
    add x0, x20, #1
    mov w1, #'`'
    bl Lfind_char
    tbnz x0, #63, Lmd_next
    add x14, x0, #1
    EMIT x20, x14, SL_STRING
    mov x20, x14
    b Lmd_inline
2:  cmp w9, #'*'
    b.eq 3f
    cmp w9, #'_'
    b.ne 5f
    // '_' inside a word (snake_case) is not emphasis
    cbz x20, 3f
    sub x10, x20, #1
    ldrb w10, [x19, x10]
    LADDR x11, Lclass
    ldrb w10, [x11, x10]
    tst w10, #C_IDENT
    b.ne Lmd_next
3:  add x11, x20, #1
    CH w11, x11
    cmp w11, w9
    b.ne 4f
    // **strong** / __strong__
    LADDR x1, Lpat_bold
    cmp w9, #'*'
    b.eq 31f
    LADDR x1, Lpat_ubold
31: add x0, x20, #2
    mov x2, #2
    bl Lfind_seq
    tbnz x0, #63, Lmd_next
    mov x14, x0
    EMIT x20, x14, SL_SPECIAL
    mov x20, x14
    b Lmd_inline
    // *emphasis* / _emphasis_, not when followed by a blank
4:  cmp w11, #' '
    b.eq Lmd_next
    cbz w11, Lmd_next
    add x0, x20, #1
    mov w1, w9
    bl Lfind_char
    tbnz x0, #63, Lmd_next
    add x14, x0, #1
    EMIT x20, x14, SL_ESCAPE
    mov x20, x14
    b Lmd_inline
    // [text](url)
5:  cmp w9, #'['
    b.ne 6f
    add x0, x20, #1
    mov w1, #']'
    bl Lfind_char
    tbnz x0, #63, Lmd_next
    add x15, x0, #1
    CH w9, x15
    cmp w9, #'('
    b.ne Lmd_next
    mov x0, x15
    mov w1, #')'
    bl Lfind_char
    tbnz x0, #63, Lmd_next
    add x14, x0, #1
    EMIT x20, x15, SL_LINK
    EMIT x15, x14, SL_TAG
    mov x20, x14
    b Lmd_inline
    // <http...>
6:  cmp w9, #'<'
    b.ne Lmd_next
    add x0, x20, #1
    LADDR x1, Lpat_http
    mov x2, #4
    bl Lmatch_at
    cbz w0, Lmd_next
    add x0, x20, #1
    mov w1, #'>'
    bl Lfind_char
    tbnz x0, #63, Lmd_next
    add x14, x0, #1
    EMIT x20, x14, SL_TAG
    mov x20, x14
    b Lmd_inline
Lmd_next:
    add x20, x20, #1
    b Lmd_inline
Lmd_done:
    ldp x29, x30, [sp], #16
    ret

// ---- ARM64 assembly ----
// state 1 inside /* */; x27 = words seen in the current statement

// x0 = end of an assembler identifier at x0 ($ allowed, '.' too when w1 = 1)
    .p2align 2
La_ident_end:
    LADDR x10, Lclass
1:  cmp x0, x21
    b.hs 3f
    ldrb w9, [x19, x0]
    cmp w9, #'$'
    b.eq 2f
    cmp w9, #'.'
    b.ne 11f
    cbnz w1, 2f
    b 3f
11: ldrb w11, [x10, x9]
    tst w11, #C_IDENT
    b.eq 3f
2:  add x0, x0, #1
    b 1b
3:  ret

// w0 = 1 if [x20, x14) is a register name
    .p2align 2
La_is_reg:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub x2, x14, x20
    cmp x2, #2
    b.lo 8f
    cmp x2, #3
    b.hi 8f
    ldrb w9, [x19, x20]
    orr w9, w9, #0x20
    cmp w9, #'x'
    b.eq 1f
    cmp w9, #'w'
    b.eq 1f
    cmp w9, #'v'
    b.eq 1f
    cmp w9, #'q'
    b.eq 1f
    cmp w9, #'d'
    b.eq 1f
    cmp w9, #'s'
    b.eq 1f
    cmp w9, #'h'
    b.eq 1f
    cmp w9, #'b'
    b.ne 5f
    // letter + register number 0..31
1:  mov x10, x20
    add x10, x10, #1
    mov x11, #0
2:  cmp x10, x14
    b.hs 3f
    ldrb w9, [x19, x10]
    sub w9, w9, #'0'
    cmp w9, #9
    b.hi 5f
    mov x12, #10
    madd x11, x11, x12, x9
    add x10, x10, #1
    b 2b
3:  cmp x11, #31
    b.hi 5f
    mov w0, #1
    b 9f
5:  LADDR x0, Lasm_regs
    mov x1, x20
    bl Lword_in
    b 9f
8:  mov w0, #0
9:  ldp x29, x30, [sp], #16
    ret

    .p2align 2
Lasm:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x27, #0
    cbz x24, La_loop
    mov x0, #0
    LADDR x1, Lpat_cclose
    mov x2, #2
    bl Lfind_seq
    tbnz x0, #63, 1f
    mov x14, x0
    EMIT xzr, x14, SL_COMMENT
    mov x20, x14
    mov x24, #0
    b La_loop
1:  EMIT xzr, x21, SL_COMMENT
    b La_done

La_loop:
    cmp x20, x21
    b.hs La_done
    ldrb w9, [x19, x20]
    LADDR x10, Lclass
    ldrb w10, [x10, x9]
    tst w10, #C_SPACE
    b.eq 1f
    add x20, x20, #1
    b La_loop
1:  cmp w9, #';'
    b.eq La_comment
    cmp w9, #'/'
    b.ne 3f
    add x11, x20, #1
    CH w11, x11
    cmp w11, #'/'
    b.eq La_comment
    cmp w11, #'*'
    b.ne La_op
    add x0, x20, #2
    LADDR x1, Lpat_cclose
    mov x2, #2
    bl Lfind_seq
    tbnz x0, #63, 2f
    mov x14, x0
    EMIT x20, x14, SL_COMMENT
    mov x20, x14
    b La_loop
2:  EMIT x20, x21, SL_COMMENT
    mov x24, #1
    b La_done
3:  cmp w9, #'#'
    b.ne 4f
    // #directive at statement start, otherwise an immediate marker
    cbnz x27, 31f
    mov x0, #0
    bl Lskip_sp
    cmp x0, x20
    b.ne 31f
    add x11, x20, #1
    CH w11, x11
    orr w11, w11, #0x20
    sub w11, w11, #'a'
    cmp w11, #25
    b.hi 31f
    add x0, x20, #1
    mov w1, #0
    bl La_ident_end
    mov x14, x0
    EMIT x20, x14, SL_KEYWORD
    mov x20, x14
    mov x27, #1
    b La_loop
31: add x14, x20, #1
    EMIT x20, x14, SL_NUMBER
    mov x20, x14
    b La_loop
4:  cmp w9, #'"'
    b.ne 5f
    mov x0, x20
    mov w1, w9
    mov w2, #1
    bl Lstring_end
    mov x14, x0
    EMIT x20, x14, SL_STRING
    mov x20, x14
    b La_loop
    // 'c' or '\c'
5:  cmp w9, #'\''
    b.ne 6f
    add x14, x20, #1
    add x11, x20, #1
    CH w11, x11
    cmp w11, #'\\'
    cinc x14, x14, eq
    add x14, x14, #1
    CH w11, x14
    cmp w11, #'\''
    b.ne 51f
    add x14, x14, #1
    EMIT x20, x14, SL_STRING
    mov x20, x14
    b La_loop
51: add x14, x20, #1
    EMIT x20, x14, SL_PUNCT
    mov x20, x14
    b La_loop
    // \macro_arg and @relocation
6:  cmp w9, #'\\'
    b.ne 7f
    add x0, x20, #1
    mov w1, #0
    bl La_ident_end
    mov x14, x0
    EMIT x20, x14, SL_SPECIAL
    mov x20, x14
    b La_loop
7:  cmp w9, #'@'
    b.ne 8f
    add x0, x20, #1
    mov w1, #0
    bl La_ident_end
    mov x14, x0
    EMIT x20, x14, SL_TYPE
    mov x20, x14
    b La_loop
8:  tst w10, #C_DIGIT
    b.eq 9f
    mov x0, x20
    bl Lscan_number
    // "1:" defines a local label, "1f"/"1b" refer to one
    CH w11, x14
    cmp w11, #':'
    b.ne 81f
    cbnz x27, 81f
    add x14, x14, #1
    EMIT x20, x14, SL_LABEL
    mov x20, x14
    b La_loop
81: sub x11, x14, #1
    ldrb w11, [x19, x11]
    cmp w11, #'f'
    b.eq 82f
    cmp w11, #'b'
    b.ne 83f
82: sub x12, x14, x20
    cmp x12, #2
    b.lo 83f
    ldrb w12, [x19, x20]
    cmp w12, #'0'
    b.eq 83f
    EMIT x20, x14, SL_LABEL
    mov x20, x14
    b La_loop
83: EMIT x20, x14, SL_NUMBER
    mov x20, x14
    b La_loop
9:  cmp w9, #'.'
    b.eq 91f
    cmp w9, #'$'
    b.eq 91f
    tst w10, #C_START
    b.eq La_op
91: mov x0, x20
    cmp x27, #0
    cset w1, eq
    bl La_ident_end
    add x14, x20, #1
    cmp x0, x14
    csel x14, x0, x14, hi
    CH w11, x14
    cmp w11, #':'
    b.ne 92f
    cbnz x27, 92f
    add x14, x14, #1
    EMIT x20, x14, SL_LABEL
    mov x20, x14
    b La_loop
    // first word: directive or mnemonic (macros included)
92: cbnz x27, 93f
    mov x27, #1
    ldrb w11, [x19, x20]
    cmp w11, #'.'
    mov w2, #SL_FUNCTION
    mov w11, #SL_KEYWORD
    csel w2, w11, w2, eq
    mov x0, x20
    mov x1, x14
    bl Lemit
    mov x20, x14
    b La_loop
93: bl La_is_reg
    cbz w0, 94f
    EMIT x20, x14, SL_SPECIAL
94: mov x20, x14
    b La_loop
La_op:
    ldrb w9, [x19, x20]
    LADDR x10, Lclass
    ldrb w10, [x10, x9]
    add x14, x20, #1
    tst w10, #C_OP
    b.eq 1f
    EMIT x20, x14, SL_OPERATOR
    mov x20, x14
    b La_loop
1:  tst w10, #C_PUNCT
    b.eq 2f
    EMIT x20, x14, SL_PUNCT
2:  mov x20, x14
    b La_loop
La_comment:
    EMIT x20, x21, SL_COMMENT
La_done:
    ldp x29, x30, [sp], #16
    ret

// ---- language detection and per-line state cache (regular ABI) ----

// size_t av_hl_lang_for_path(const char *path)
FUNC_BEGIN _av_hl_lang_for_path
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x22, #LANG_NONE
    cbz x0, 9f
    mov x19, x0
    mov w1, #'/'
    bl _strrchr
    cmp x0, #0
    csinc x19, x19, x0, eq
    LADDR x20, Lnames
    LADDR x21, Lnames_end
1:  cmp x20, x21
    b.hs 2f
    ldr x0, [x20]
    mov x1, x19
    bl _strcasecmp
    cbz w0, 5f
    add x20, x20, #16
    b 1b
2:  mov x0, x19
    mov w1, #'.'
    bl _strrchr
    cbz x0, 9f
    add x19, x0, #1
    LADDR x20, Lexts
    LADDR x21, Lexts_end
3:  cmp x20, x21
    b.hs 9f
    ldr x0, [x20]
    mov x1, x19
    bl _strcasecmp
    cbz w0, 5f
    add x20, x20, #16
    b 3b
5:  ldr x22, [x20, #8]
9:  mov x0, x22
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_hl_detect(Doc *d): language from the path, else from a #! line
FUNC_BEGIN _av_hl_detect
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #DOC_PATH]
    bl _av_hl_lang_for_path
    mov x20, x0
    cbnz x20, 8f
    mov x0, x19
    bl _av_buf_len
    cmp x0, #2
    b.lo 8f
    mov x0, x19
    mov x1, #0
    bl _av_buf_line_end
    mov x3, #255
    cmp x0, x3
    csel x3, x0, x3, lo
    mov x0, x19
    mov x1, #0
    LADDR x2, _av_hl_line
    bl _av_buf_copy
    LADDR x0, _av_hl_line
    ldrh w9, [x0]
    mov w10, #0x2123
    cmp w9, w10
    b.ne 8f
    mov x0, x19
    mov x1, #0
    bl _av_buf_line_end
    mov x3, #255
    cmp x0, x3
    csel x3, x0, x3, lo
    LADDR x0, _av_hl_line
    strb wzr, [x0, x3]
    LADDR x1, Ls_python
    bl _strstr
    mov x20, #LANG_SHELL
    cbz x0, 8f
    mov x20, #LANG_PYTHON
8:  str x20, [x19, #DOC_LANG]
    str xzr, [x19, #DOC_HL_VALID]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_hl_invalidate(Doc *d, size_t pos): states after the line of pos must be recomputed
FUNC_BEGIN _av_hl_invalidate
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _av_buf_line_of
    ldr x9, [x19, #DOC_HL_VALID]
    cmp x0, x9
    b.hs 1f
    str x0, [x19, #DOC_HL_VALID]
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// u8 av_hl_state_at(Doc *d, size_t line): lexer state at the start of line, computed lazily
FUNC_BEGIN _av_hl_state_at
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x0, #0
    cbz x20, 9f
    ldr x21, [x19, #DOC_LANG]
    cmp x21, #LANG_COUNT
    b.hs 9f
    LADDR x9, Llangs
    ldr x9, [x9, x21, lsl #3]
    ldr x9, [x9, #LD_FLAGS]
    tbz x9, #0, 9f
    // one state byte per line, grown with the document
    ldr x9, [x19, #DOC_HL_CAP]
    ldr x10, [x19, #BUF_NLINES]
    add x10, x10, #1
    cmp x9, x10
    b.hs 1f
    add x3, x10, #4096
    lsl x11, x9, #1
    cmp x11, x3
    csel x22, x11, x3, hi
    ldr x0, [x19, #DOC_HL_STATES]
    mov x1, x9
    mov x2, x9
    mov x3, x22
    bl _av_pages_grow
    mov x9, x0
    mov x0, #0
    cbz x9, 9f
    str x9, [x19, #DOC_HL_STATES]
    str x22, [x19, #DOC_HL_CAP]
1:  ldr x22, [x19, #DOC_HL_VALID]
    cmp x20, x22
    b.ls 8f
    // lex the missing lines in state-only mode
2:  cmp x22, x20
    b.hs 7f
    mov x0, x19
    mov x1, x22
    bl _av_buf_line_start
    mov x23, x0
    mov x0, x19
    mov x1, x22
    bl _av_buf_line_end
    sub x24, x0, x23
    mov x9, #HL_LINE_MAX
    cmp x24, x9
    csel x24, x9, x24, hi
    mov x0, x19
    mov x1, x23
    LADDR x2, _av_hl_line
    mov x3, x24
    bl _av_buf_copy
    ldr x9, [x19, #DOC_HL_STATES]
    ldrb w3, [x9, x22]
    mov x0, x21
    LADDR x1, _av_hl_line
    mov x2, x24
    mov x4, #0
    bl _av_hl_lex
    ldr x9, [x19, #DOC_HL_STATES]
    add x22, x22, #1
    strb w0, [x9, x22]
    b 2b
7:  str x20, [x19, #DOC_HL_VALID]
8:  ldr x9, [x19, #DOC_HL_STATES]
    ldrb w0, [x9, x20]
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
