// YAML subset parser: block maps/sequences, plain/quoted/block scalars, flow collections, comments
// recursive descent over the raw bytes; errors unwind straight back to av_yaml_parse
//
// internal parse functions share these registers and never save them:
// x19 ctx, x20 pos, x21 current line start, x22 line number (1-based), x23 end

.include "macros.inc"
.include "yaml.inc"

.set MAX_DEPTH, 200

    .section __TEXT,__cstring,cstring_literals
Le_none:   .asciz "no error"
Le_indent: .asciz "bad indentation"
Le_colon:  .asciz "expected a 'key: value' mapping entry"
Le_quote:  .asciz "unterminated quoted string"
Le_tab:    .asciz "tab character in indentation"
Le_dup:    .asciz "duplicate key"
Le_trail:  .asciz "unexpected content after value"
Le_flow:   .asciz "unterminated or malformed flow collection"
Le_nomem:  .asciz "out of memory"
Le_depth:  .asciz "nesting too deep"
Le_inline: .asciz "mapping values are not allowed on the same line"
Ls_true:   .asciz "true"
Ls_yes:    .asciz "yes"
Ls_on:     .asciz "on"
Ls_false:  .asciz "false"
Ls_no:     .asciz "no"
Ls_off:    .asciz "off"

    .section __DATA,__const
    .p2align 3
Lerr_msgs:
    .quad Le_none, Le_indent, Le_colon, Le_quote, Le_tab, Le_dup
    .quad Le_trail, Le_flow, Le_nomem, Le_depth, Le_inline

    .text
// Node *av_yaml_parse(Yaml *ctx, const char *src, size_t n), NULL on error (see Y_ERR, Y_ERRLINE)
FUNC_BEGIN _av_yaml_parse
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x1
    mov x22, #1
    add x23, x1, x2
    str x1, [x19, #Y_SRC]
    stp xzr, xzr, [x19, #Y_ERR]
    str xzr, [x19, #Y_ROOT]
    str xzr, [x19, #Y_DEPTH]
    // arena is reserved generously, untouched pages cost nothing
    lsl x0, x2, #4
    add x0, x0, #0x10000
    str x0, [x19, #Y_CAP]
    bl _av_pages_alloc
    str x0, [x19, #Y_BASE]
    str xzr, [x19, #Y_USED]
    cbnz x0, 1f
    mov x0, #YE_NOMEM
    str x0, [x19, #Y_ERR]
    mov x0, #0
    b Lp_out
1:  mov x9, sp
    str x9, [x19, #Y_SP]
    bl Lpeek
    str xzr, [x19, #Y_DOCBRK]
    tbz x0, #63, 2f
    mov w0, #Y_NULL
    bl Lnew_node
    b 3f
2:  mov x1, x0
    mov x0, #0
    bl Lparse_node
3:  str x0, [x19, #Y_ROOT]
    mov x24, x0
    mov x25, x0
    // further documents only after a "---" marker
4:  bl Lpeek
    tbnz x0, #63, 5f
    ldr x9, [x19, #Y_DOCBRK]
    cbz x9, 6f
    str xzr, [x19, #Y_DOCBRK]
    mov x1, x0
    mov x0, #0
    bl Lparse_node
    str x0, [x25, #N_NEXT]
    mov x25, x0
    b 4b
6:  mov w0, #YE_TRAIL
    b Lerror
5:  mov x0, x24
Lp_out:
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
Lunwind:
    mov x0, #0
    b Lp_out

// error code in w0: record it and drop every nested frame
    .p2align 2
Lerror:
    mov w0, w0
    str x0, [x19, #Y_ERR]
    str x22, [x19, #Y_ERRLINE]
    ldr x9, [x19, #Y_SP]
    mov sp, x9
    b Lunwind

// void av_yaml_free(Yaml *ctx)
FUNC_BEGIN _av_yaml_free
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #Y_BASE]
    ldr x1, [x19, #Y_CAP]
    bl _av_pages_free
    str xzr, [x19, #Y_BASE]
    str xzr, [x19, #Y_ROOT]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// const char *av_yaml_error_msg(size_t code)
FUNC_BEGIN _av_yaml_error_msg
    cmp x0, #YE_COUNT
    csel x0, x0, xzr, lo
    LADDR x1, Lerr_msgs
    ldr x0, [x1, x0, lsl #3]
    ret

// ---- lexing helpers ----

// x0 = column of the next significant byte, -1 at EOF; skips blanks, comments and doc markers
    .p2align 2
Lpeek:
1:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #' '
    b.eq 2f
    cmp w9, #13
    b.eq 2f
    cmp w9, #9
    b.eq 5f
    cmp w9, #10
    b.eq 3f
    cmp w9, #'#'
    b.eq 4f
    cmp x20, x21
    b.ne 8f
    cmp w9, #'-'
    b.eq 6f
    cmp w9, #'.'
    b.ne 8f
    // "---" / "..." at column 0 followed by blank
6:  add x10, x20, #3
    cmp x10, x23
    b.hi 8f
    ldrb w11, [x20, #1]
    cmp w11, w9
    b.ne 8f
    ldrb w11, [x20, #2]
    cmp w11, w9
    b.ne 8f
    cmp x10, x23
    b.eq 11f
    ldrb w11, [x10]
    cmp w11, #' '
    b.eq 11f
    cmp w11, #10
    b.eq 11f
    cmp w11, #13
    b.eq 11f
8:  sub x0, x20, x21
    ret
2:  add x20, x20, #1
    b 1b
3:  add x20, x20, #1
    add x22, x22, #1
    mov x21, x20
    b 1b
4:  cmp x20, x23
    b.hs 1b
    ldrb w9, [x20]
    cmp w9, #10
    b.eq 1b
    add x20, x20, #1
    b 4b
    // a tab is fine after content but not inside indentation
5:  mov x10, x21
7:  cmp x10, x20
    b.hs 10f
    ldrb w11, [x10], #1
    cmp w11, #' '
    b.eq 7b
    cmp w11, #9
    b.eq 7b
    b 2b
10: mov w0, #YE_TAB
    b Lerror
11: mov x11, #1
    str x11, [x19, #Y_DOCBRK]
    b 4b
9:  mov x0, #-1
    ret

// skip spaces/tabs/CR on the current line
    .p2align 2
Lskip_ws:
1:  cmp x20, x23
    b.hs 2f
    ldrb w9, [x20]
    cmp w9, #' '
    b.eq 3f
    cmp w9, #9
    b.eq 3f
    cmp w9, #13
    b.ne 2f
3:  add x20, x20, #1
    b 1b
2:  ret

// skip anchors (&a) and tags (!t) in front of a value
    .p2align 2
Lskip_props:
1:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #'&'
    b.eq 2f
    cmp w9, #'!'
    b.ne 9f
2:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #' '
    b.eq 3f
    cmp w9, #9
    b.eq 3f
    cmp w9, #10
    b.eq 9f
    cmp w9, #13
    b.eq 3f
    add x20, x20, #1
    b 2b
3:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #' '
    b.eq 4f
    cmp w9, #9
    b.ne 1b
4:  add x20, x20, #1
    b 3b
9:  ret

// w0 = 1 at EOF, newline or comment
    .p2align 2
Lat_eol:
    mov w0, #1
    cmp x20, x23
    b.hs 1f
    ldrb w9, [x20]
    cmp w9, #10
    b.eq 1f
    cmp w9, #13
    b.eq 1f
    cmp w9, #'#'
    b.eq 1f
    mov w0, #0
1:  ret

// w0 = 1 if pos is a block sequence indicator "- "
    .p2align 2
Lseqish:
    mov w0, #0
    cmp x20, x23
    b.hs 2f
    ldrb w9, [x20]
    cmp w9, #'-'
    b.ne 2f
    add x10, x20, #1
    cmp x10, x23
    b.hs 1f
    ldrb w9, [x10]
    cmp w9, #' '
    b.eq 1f
    cmp w9, #9
    b.eq 1f
    cmp w9, #10
    b.eq 1f
    cmp w9, #13
    b.ne 2f
1:  mov w0, #1
2:  ret

// w0 = 1 if a byte at x10 ends a key, i.e. ':' followed by blank or EOF (x10 at the ':')
.macro COLON_ENDS_KEY yes
    add x11, x10, #1
    cmp x11, x23
    b.hs \yes
    ldrb w11, [x11]
    cmp w11, #' '
    b.eq \yes
    cmp w11, #9
    b.eq \yes
    cmp w11, #10
    b.eq \yes
    cmp w11, #13
    b.eq \yes
.endm

// w0 = 1 if the rest of the line starts with a mapping key, plain or quoted
    .p2align 2
Lis_key_line:
    mov x10, x20
    cmp x10, x23
    b.hs Lk_no
    ldrb w9, [x10]
    cmp w9, #'"'
    b.eq Lk_quoted
    cmp w9, #'\''
    b.eq Lk_quoted
1:  cmp x10, x23
    b.hs Lk_no
    ldrb w9, [x10]
    cmp w9, #10
    b.eq Lk_no
    cmp w9, #'#'
    b.ne 2f
    cmp x10, x20
    b.eq Lk_no
    ldurb w11, [x10, #-1]
    cmp w11, #' '
    b.eq Lk_no
    cmp w11, #9
    b.eq Lk_no
2:  cmp w9, #':'
    b.ne 3f
    COLON_ENDS_KEY Lk_yes
3:  add x10, x10, #1
    b 1b
Lk_quoted:
    mov w12, w9
    add x10, x10, #1
4:  cmp x10, x23
    b.hs Lk_no
    ldrb w9, [x10]
    cmp w9, #10
    b.eq Lk_no
    cmp w12, #'"'
    b.ne 5f
    cmp w9, #'\\'
    b.ne 5f
    add x10, x10, #2
    b 4b
5:  cmp w9, w12
    b.eq 6f
    add x10, x10, #1
    b 4b
6:  add x10, x10, #1
    cmp w12, #'\''
    b.ne 7f
    cmp x10, x23
    b.hs 7f
    ldrb w9, [x10]
    cmp w9, #'\''
    b.ne 7f
    add x10, x10, #1
    b 4b
7:  cmp x10, x23
    b.hs Lk_no
    ldrb w9, [x10]
    cmp w9, #' '
    b.ne 8f
    add x10, x10, #1
    b 7b
8:  cmp w9, #':'
    b.ne Lk_no
    COLON_ENDS_KEY Lk_yes
Lk_no:
    mov w0, #0
    ret
Lk_yes:
    mov w0, #1
    ret

// ---- allocation ----

// x0 = n bytes from the arena, 8-aligned and zeroed
    .p2align 2
Lalloc:
    add x0, x0, #7
    and x0, x0, #0xfffffffffffffff8
    ldr x9, [x19, #Y_USED]
    ldr x10, [x19, #Y_CAP]
    add x11, x9, x0
    cmp x11, x10
    b.hi 1f
    str x11, [x19, #Y_USED]
    ldr x10, [x19, #Y_BASE]
    add x0, x10, x9
    ret
1:  mov w0, #YE_NOMEM
    b Lerror

// x0 = new node of type w0 at the current line/position
    .p2align 2
Lnew_node:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov w12, w0
    mov x0, #NODE_SIZE
    bl Lalloc
    strb w12, [x0, #N_TYPE]
    str w22, [x0, #N_LINE]
    ldr x9, [x19, #Y_SRC]
    sub x9, x20, x9
    str x9, [x0, #N_OFF]
    ldp x29, x30, [sp], #16
    ret

// void append(Node *parent, Node *child)
    .p2align 2
Lappend:
    ldr x9, [x0, #N_TAIL]
    cbnz x9, 1f
    str x1, [x0, #N_PTR]
    b 2f
1:  str x1, [x9, #N_NEXT]
2:  str x1, [x0, #N_TAIL]
    ldr x9, [x0, #N_LEN]
    add x9, x9, #1
    str x9, [x0, #N_LEN]
    ret

// (str, len) copy_str(const char *src, size_t len), NUL-terminated copy in the arena
    .p2align 2
Lcopy_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    mov x24, x0
    mov x25, x1
    add x0, x1, #1
    bl Lalloc
    mov x1, x24
    mov x2, x25
    bl _memcpy
    strb wzr, [x0, x25]
    mov x1, x25
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Node *scalar(const char *src, size_t len)
    .p2align 2
Lscalar:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    str x26, [sp, #32]
    mov x24, x0
    mov x25, x1
    mov w0, #Y_SCALAR
    bl Lnew_node
    mov x26, x0
    ldr x9, [x19, #Y_SRC]
    sub x9, x24, x9
    str x9, [x26, #N_OFF]
    mov x0, x24
    mov x1, x25
    bl Lcopy_str
    stp x0, x1, [x26, #N_PTR]
    mov x0, x26
    ldr x26, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---- scalars ----

// x0 = end of the plain text on this line (at newline or " #"), trailing blanks trimmed
// leaves x20 at the newline/comment, x24 must hold the scalar start (lower bound for trimming)
    .p2align 2
Lplain_end:
1:  cmp x20, x23
    b.hs 2f
    ldrb w9, [x20]
    cmp w9, #10
    b.eq 2f
    cmp w9, #'#'
    b.ne 3f
    ldurb w10, [x20, #-1]
    cmp w10, #' '
    b.eq 2f
    cmp w10, #9
    b.eq 2f
3:  add x20, x20, #1
    b 1b
2:  mov x0, x20
4:  cmp x0, x24
    b.ls 5f
    ldurb w9, [x0, #-1]
    cmp w9, #' '
    b.eq 6f
    cmp w9, #9
    b.eq 6f
    cmp w9, #13
    b.ne 5f
6:  sub x0, x0, #1
    b 4b
5:  ret

// plain scalar; continuation lines indented at least x0 fold into it with single spaces
// x24 start, x25 end of the last piece, x26 min indent, x27 lookahead pos, x28 folded flag
// [sp+64] saved line start and line number for the lookahead
    .p2align 2
Lplain_line:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    str x28, [sp, #48]
    mov x26, x0
    mov x24, x20
    bl Lplain_end
    mov x25, x0
    mov x28, #0
1:  mov x27, x20
    stp x21, x22, [sp, #64]
    bl Lpeek
    tbnz x0, #63, 2f
    cmp x0, x26
    b.lt 2f
    ldr x9, [x19, #Y_DOCBRK]
    cbnz x9, 2f
    bl Lis_key_line
    cbnz w0, 2f
    bl Lseqish
    cbnz w0, 2f
    mov x27, x24
    mov x24, x20
    bl Lplain_end
    mov x24, x27
    mov x25, x0
    mov x28, #1
    b 1b
    // not a continuation: rewind to where the lookahead started
2:  mov x20, x27
    ldp x21, x22, [sp, #64]
    cbnz x28, 3f
    mov x0, x24
    sub x1, x25, x24
    bl Lscalar
    b 9f
    // folded copy: each line break plus indentation becomes one space
3:  mov x0, x24
    mov x1, #0
    bl Lscalar
    mov x27, x0
    sub x0, x25, x24
    add x0, x0, #1
    bl Lalloc
    str x0, [x27, #N_PTR]
    mov x12, x0
    mov x10, x24
4:  cmp x10, x25
    b.hs 8f
    ldrb w9, [x10], #1
    cmp w9, #10
    b.ne 7f
    // drop trailing blanks already written, then the next line's indentation
5:  ldr x11, [x27, #N_PTR]
    cmp x12, x11
    b.ls 6f
    ldurb w11, [x12, #-1]
    cmp w11, #' '
    b.eq 51f
    cmp w11, #9
    b.eq 51f
    cmp w11, #13
    b.ne 6f
51: sub x12, x12, #1
    b 5b
6:  cmp x10, x25
    b.hs 61f
    ldrb w11, [x10]
    cmp w11, #' '
    b.eq 62f
    cmp w11, #9
    b.eq 62f
    cmp w11, #10
    b.ne 61f
62: add x10, x10, #1
    b 6b
61: mov w9, #' '
7:  strb w9, [x12], #1
    b 4b
8:  strb wzr, [x12]
    ldr x9, [x27, #N_PTR]
    sub x9, x12, x9
    str x9, [x27, #N_LEN]
    mov x0, x27
9:  ldr x28, [sp, #48]
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// w14 = value of up to x13 hex digits at x20 (bounded by x26)
    .p2align 2
Lhexn:
    mov w14, #0
1:  cbz x13, 3f
    cmp x20, x26
    b.hs 3f
    ldrb w9, [x20]
    sub w10, w9, #'0'
    cmp w10, #9
    b.ls 2f
    orr w10, w9, #0x20
    sub w10, w10, #'a'
    cmp w10, #5
    b.hi 3f
    add w10, w10, #10
2:  add x20, x20, #1
    lsl w14, w14, #4
    add w14, w14, w10
    sub x13, x13, #1
    b 1b
3:  ret

// quoted scalar: '...' with '' escapes or "..." with backslash escapes, line breaks fold to a space
    .p2align 2
Lquoted:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    ldrb w24, [x20]
    add x20, x20, #1
    mov x25, x20
    // pass 1: find the closing quote
    mov x10, x20
1:  cmp x10, x23
    b.hs Lq_err
    ldrb w9, [x10]
    cmp w24, #'"'
    b.ne 2f
    cmp w9, #'\\'
    b.ne 2f
    add x10, x10, #2
    b 1b
2:  cmp w9, w24
    b.ne 3f
    cmp w24, #'\''
    b.ne 4f
    add x11, x10, #1
    cmp x11, x23
    b.hs 4f
    ldrb w11, [x11]
    cmp w11, #'\''
    b.ne 4f
    add x10, x10, #2
    b 1b
3:  add x10, x10, #1
    b 1b
4:  mov x26, x10
    mov w0, #Y_SCALAR
    bl Lnew_node
    mov x27, x0
    ldr x9, [x19, #Y_SRC]
    sub x9, x25, x9
    sub x9, x9, #1
    str x9, [x27, #N_OFF]
    mov w9, #NF_QUOTED
    strb w9, [x27, #N_FLAGS]
    // decoded text is never longer than the raw text
    sub x0, x26, x25
    add x0, x0, #1
    bl Lalloc
    str x0, [x27, #N_PTR]
    mov x12, x0
    // pass 2: decode
5:  cmp x20, x26
    b.hs 9f
    ldrb w9, [x20], #1
    cmp w9, #10
    b.ne 6f
    add x22, x22, #1
    mov x21, x20
    mov w9, #' '
    strb w9, [x12], #1
7:  cmp x20, x26
    b.hs 5b
    ldrb w10, [x20]
    cmp w10, #' '
    b.eq 71f
    cmp w10, #9
    b.ne 5b
71: add x20, x20, #1
    b 7b
6:  cmp w24, #'\''
    b.ne 61f
    cmp w9, #'\''
    b.ne 8f
    add x20, x20, #1
    b 8f
61: cmp w9, #'\\'
    b.ne 8f
    cmp x20, x26
    b.hs 8f
    ldrb w9, [x20], #1
    cmp w9, #'u'
    b.eq Lq_u
    cmp w9, #'x'
    b.eq Lq_x
    cmp w9, #'n'
    mov w10, #10
    csel w9, w10, w9, eq
    cmp w9, #'t'
    mov w10, #9
    csel w9, w10, w9, eq
    cmp w9, #'r'
    mov w10, #13
    csel w9, w10, w9, eq
    cmp w9, #'e'
    mov w10, #27
    csel w9, w10, w9, eq
    cmp w9, #'0'
    csel w9, wzr, w9, eq
8:  strb w9, [x12], #1
    b 5b
Lq_x:
    mov x13, #2
    bl Lhexn
    strb w14, [x12], #1
    b 5b
    // \uXXXX to UTF-8 (BMP)
Lq_u:
    mov x13, #4
    bl Lhexn
    cmp w14, #0x80
    b.hs 1f
    strb w14, [x12], #1
    b 5b
1:  cmp w14, #0x800
    b.hs 2f
    lsr w9, w14, #6
    orr w9, w9, #0xc0
    strb w9, [x12], #1
    and w9, w14, #0x3f
    orr w9, w9, #0x80
    strb w9, [x12], #1
    b 5b
2:  lsr w9, w14, #12
    orr w9, w9, #0xe0
    strb w9, [x12], #1
    ubfx w9, w14, #6, #6
    orr w9, w9, #0x80
    strb w9, [x12], #1
    and w9, w14, #0x3f
    orr w9, w9, #0x80
    strb w9, [x12], #1
    b 5b
9:  strb wzr, [x12]
    ldr x9, [x27, #N_PTR]
    sub x9, x12, x9
    str x9, [x27, #N_LEN]
    add x20, x26, #1
    mov x0, x27
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lq_err:
    mov w0, #YE_QUOTE
    b Lerror

// block scalar (| or >) whose lines are indented at least min (x0); stored as a raw source slice
    .p2align 2
Lblock_scalar:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    mov x24, x0
    mov w0, #Y_SCALAR
    bl Lnew_node
    mov x27, x0
    mov w9, #NF_RAW
    strb w9, [x27, #N_FLAGS]
    // rest of the header line (chomping/indent indicators, comment)
1:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #10
    b.eq 2f
    add x20, x20, #1
    b 1b
2:  add x20, x20, #1
    add x22, x22, #1
    mov x21, x20
    mov x25, x20
    mov x26, #-1
    // x20 at a line start: blank lines belong to the block, content needs indent >= block indent
3:  cmp x20, x23
    b.hs 8f
    mov x10, x20
4:  cmp x10, x23
    b.hs 8f
    ldrb w9, [x10]
    cmp w9, #' '
    b.ne 5f
    add x10, x10, #1
    b 4b
5:  sub x11, x10, x20
    cmp w9, #10
    b.eq 6f
    cmp w9, #13
    b.eq 6f
    tbz x26, #63, 51f
    mov x26, x11
    cmp x26, x24
    b.lt 8f
51: cmp x11, x26
    b.lt 8f
6:  mov x20, x10
7:  cmp x20, x23
    b.hs 8f
    ldrb w9, [x20], #1
    cmp w9, #10
    b.ne 7b
    add x22, x22, #1
    mov x21, x20
    b 3b
8:  str x25, [x27, #N_PTR]
    sub x9, x20, x25
    str x9, [x27, #N_LEN]
9:  mov x0, x27
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// nothing but blanks or a comment may follow a value on its line
    .p2align 2
Lexpect_eol:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lskip_ws
    bl Lat_eol
    cbz w0, 1f
    ldp x29, x30, [sp], #16
    ret
1:  mov w0, #YE_TRAIL
    b Lerror

// ---- flow collections ----

// skip blanks, line breaks and comments inside [] / {}
    .p2align 2
Lflow_ws:
1:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #' '
    b.eq 2f
    cmp w9, #9
    b.eq 2f
    cmp w9, #13
    b.eq 2f
    cmp w9, #10
    b.eq 3f
    cmp w9, #'#'
    b.ne 9f
4:  cmp x20, x23
    b.hs 9f
    ldrb w9, [x20]
    cmp w9, #10
    b.eq 1b
    add x20, x20, #1
    b 4b
2:  add x20, x20, #1
    b 1b
3:  add x20, x20, #1
    add x22, x22, #1
    mov x21, x20
    b 1b
9:  ret

// flow item: nested collection, quoted or plain scalar; w0 = 1 also stops plain text at ': '
    .p2align 2
Lflow_value:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    str x26, [sp, #32]
    mov w26, w0
    cmp x20, x23
    b.hs Lf_err
    ldrb w9, [x20]
    cmp w9, #'['
    b.eq 1f
    cmp w9, #'{'
    b.eq 1f
    cmp w9, #'"'
    b.eq 2f
    cmp w9, #'\''
    b.eq 2f
    mov x24, x20
3:  cmp x20, x23
    b.hs 5f
    ldrb w9, [x20]
    cmp w9, #','
    b.eq 5f
    cmp w9, #']'
    b.eq 5f
    cmp w9, #'}'
    b.eq 5f
    cmp w9, #10
    b.eq 5f
    cmp w9, #':'
    b.ne 4f
    cbz w26, 4f
    mov x10, x20
    COLON_ENDS_KEY 5f
    ldrb w11, [x10, #1]
    cmp w11, #','
    b.eq 5f
    cmp w11, #'}'
    b.eq 5f
    cmp w11, #']'
    b.eq 5f
4:  add x20, x20, #1
    b 3b
5:  mov x25, x20
6:  cmp x25, x24
    b.ls 7f
    ldurb w9, [x25, #-1]
    cmp w9, #' '
    b.eq 61f
    cmp w9, #9
    b.eq 61f
    cmp w9, #13
    b.ne 7f
61: sub x25, x25, #1
    b 6b
7:  mov x0, x24
    sub x1, x25, x24
    bl Lscalar
    b 8f
1:  bl Lparse_flow
    b 8f
2:  bl Lquoted
8:  ldr x26, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// [ ... ] or { ... }, may span lines
    .p2align 2
Lparse_flow:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    ldr x9, [x19, #Y_DEPTH]
    add x9, x9, #1
    str x9, [x19, #Y_DEPTH]
    cmp x9, #MAX_DEPTH
    b.hi Ldepth_err
    ldrb w9, [x20]
    mov w24, #Y_SEQ
    mov w25, #']'
    cmp w9, #'{'
    b.ne 1f
    mov w24, #Y_MAP
    mov w25, #'}'
1:  mov w0, w24
    bl Lnew_node
    mov x26, x0
    add x20, x20, #1
Lf_loop:
    bl Lflow_ws
    cmp x20, x23
    b.hs Lf_err
    ldrb w9, [x20]
    cmp w9, w25
    b.eq Lf_close
    cmp w24, #Y_MAP
    b.ne Lf_val
    mov w0, #1
    bl Lflow_value
    mov x27, x0
    bl Lflow_ws
    cmp x20, x23
    b.hs Lf_err
    ldrb w9, [x20]
    cmp w9, #':'
    b.ne 2f
    add x20, x20, #1
    bl Lflow_ws
    cmp x20, x23
    b.hs Lf_err
    ldrb w9, [x20]
    cmp w9, #','
    b.eq 2f
    cmp w9, w25
    b.eq 2f
    mov w0, #0
    bl Lflow_value
    b 3f
2:  mov w0, #Y_NULL
    bl Lnew_node
3:  ldp x9, x10, [x27, #N_PTR]
    stp x9, x10, [x0, #N_KEY]
    b Lf_add
Lf_val:
    mov w0, #0
    bl Lflow_value
Lf_add:
    mov x1, x0
    mov x0, x26
    bl Lappend
    bl Lflow_ws
    cmp x20, x23
    b.hs Lf_err
    ldrb w9, [x20]
    cmp w9, #','
    b.ne 4f
    add x20, x20, #1
    b Lf_loop
4:  cmp w9, w25
    b.eq Lf_loop
Lf_err:
    mov w0, #YE_FLOW
    b Lerror
Lf_close:
    add x20, x20, #1
    ldr x9, [x19, #Y_DEPTH]
    sub x9, x9, #1
    str x9, [x19, #Y_DEPTH]
    mov x0, x26
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---- block structure ----

// value that starts mid-line (after "key:" or "- "); x0 = min indent for block scalars
    .p2align 2
Lparse_inline:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    mov x24, x0
    ldrb w9, [x20]
    cmp w9, #'['
    b.eq 1f
    cmp w9, #'{'
    b.eq 1f
    cmp w9, #'|'
    b.eq 2f
    cmp w9, #'>'
    b.eq 2f
    cmp w9, #'"'
    b.eq 3f
    cmp w9, #'\''
    b.eq 3f
    bl Lis_key_line
    cbnz w0, 4f
    mov x0, x24
    bl Lplain_line
    b 9f
1:  bl Lparse_flow
    b 5f
3:  bl Lquoted
5:  mov x25, x0
    bl Lexpect_eol
    mov x0, x25
    b 9f
2:  mov x0, x24
    bl Lblock_scalar
9:  ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
4:  mov w0, #YE_INLINE_MAP
    b Lerror

// node starting at column x1, nested content must be indented at least x0
    .p2align 2
Lparse_node:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    ldr x9, [x19, #Y_DEPTH]
    add x9, x9, #1
    str x9, [x19, #Y_DEPTH]
    cmp x9, #MAX_DEPTH
    b.hi Ldepth_err
    mov x24, x0
    mov x25, x1
    bl Lseqish
    cbz w0, 1f
    mov x0, x25
    bl Lparse_seq
    b 9f
1:  ldrb w9, [x20]
    cmp w9, #'['
    b.eq 2f
    cmp w9, #'{'
    b.eq 2f
    cmp w9, #'|'
    b.eq 2f
    cmp w9, #'>'
    b.eq 2f
    bl Lis_key_line
    cbz w0, 2f
    mov x0, x25
    bl Lparse_map
    b 9f
2:  mov x0, x24
    bl Lparse_inline
9:  ldr x9, [x19, #Y_DEPTH]
    sub x9, x9, #1
    str x9, [x19, #Y_DEPTH]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
Ldepth_err:
    mov w0, #YE_DEPTH
    b Lerror

// block mapping whose keys sit at column x0
// x24 indent, x25 map, x26/x27 key text/len, x28 dup scan; [sp+56] key line, [sp+64] key offset
    .p2align 2
Lparse_map:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    str x28, [sp, #48]
    mov x24, x0
    mov w0, #Y_MAP
    bl Lnew_node
    mov x25, x0
Lm_loop:
    bl Lpeek
    tbnz x0, #63, Lm_done
    ldr x9, [x19, #Y_DOCBRK]
    cbnz x9, Lm_done
    cmp x0, x24
    b.lt Lm_done
    b.gt Lm_indent
    bl Lis_key_line
    cbz w0, Lm_nokey
    str x22, [sp, #56]
    ldr x9, [x19, #Y_SRC]
    sub x9, x20, x9
    str x9, [sp, #64]
    ldrb w9, [x20]
    cmp w9, #'"'
    b.eq 1f
    cmp w9, #'\''
    b.eq 1f
    // plain key up to the ':' that ends it
    mov x26, x20
2:  ldrb w9, [x20]
    cmp w9, #':'
    b.ne 3f
    mov x10, x20
    COLON_ENDS_KEY 4f
3:  add x20, x20, #1
    b 2b
4:  mov x27, x20
5:  cmp x27, x26
    b.ls 6f
    ldurb w9, [x27, #-1]
    cmp w9, #' '
    b.eq 51f
    cmp w9, #9
    b.ne 6f
51: sub x27, x27, #1
    b 5b
6:  mov x0, x26
    sub x1, x27, x26
    bl Lcopy_str
    mov x26, x0
    mov x27, x1
    b Lm_colon
1:  bl Lquoted
    ldp x26, x27, [x0, #N_PTR]
    bl Lskip_ws
Lm_colon:
    add x20, x20, #1
    ldr x28, [x25, #N_PTR]
7:  cbz x28, 8f
    ldr x9, [x28, #N_KEYLEN]
    cmp x9, x27
    b.ne 71f
    ldr x0, [x28, #N_KEY]
    mov x1, x26
    mov x2, x27
    bl _memcmp
    cbz w0, Lm_dup
71: ldr x28, [x28, #N_NEXT]
    b 7b
8:  bl Lskip_ws
    bl Lskip_props
    bl Lat_eol
    cbz w0, Lm_inline
    // value on the following lines: deeper node, or a sequence at the key's own indent
    bl Lpeek
    tbnz x0, #63, Lm_null
    cmp x0, x24
    b.gt 9f
    b.lt Lm_null
    bl Lseqish
    cbz w0, Lm_null
    mov x0, x24
    bl Lparse_seq
    b Lm_set
9:  mov x1, x0
    add x0, x24, #1
    bl Lparse_node
    b Lm_set
Lm_null:
    mov w0, #Y_NULL
    bl Lnew_node
    b Lm_set
Lm_inline:
    add x0, x24, #1
    bl Lparse_inline
Lm_set:
    stp x26, x27, [x0, #N_KEY]
    ldr x9, [sp, #56]
    str w9, [x0, #N_LINE]
    ldr x9, [sp, #64]
    str x9, [x0, #N_OFF]
    mov x1, x0
    mov x0, x25
    bl Lappend
    b Lm_loop
Lm_done:
    mov x0, x25
    ldr x28, [sp, #48]
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
Lm_indent:
    mov w0, #YE_INDENT
    b Lerror
Lm_nokey:
    mov w0, #YE_COLON
    b Lerror
Lm_dup:
    mov w0, #YE_DUP
    b Lerror

// block sequence whose "- " indicators sit at column x0
    .p2align 2
Lparse_seq:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x24, x25, [sp, #16]
    stp x26, x27, [sp, #32]
    mov x24, x0
    mov w0, #Y_SEQ
    bl Lnew_node
    mov x25, x0
Ls_loop:
    bl Lpeek
    tbnz x0, #63, Ls_done
    ldr x9, [x19, #Y_DOCBRK]
    cbnz x9, Ls_done
    cmp x0, x24
    b.lt Ls_done
    b.gt Lm_indent
    bl Lseqish
    cbz w0, Ls_done
    mov x26, x22
    ldr x9, [x19, #Y_SRC]
    sub x27, x20, x9
    add x20, x20, #1
    bl Lskip_ws
    bl Lskip_props
    bl Lat_eol
    cbz w0, 2f
    bl Lpeek
    tbnz x0, #63, 1f
    cmp x0, x24
    b.le 1f
    mov x1, x0
    add x0, x24, #1
    bl Lparse_node
    b 3f
1:  mov w0, #Y_NULL
    bl Lnew_node
    b 3f
    // item content on the same line: its column is its indent ("- key: v" opens a map there)
2:  bl Lpeek
    mov x1, x0
    bl Lparse_node
3:  str w26, [x0, #N_LINE]
    str x27, [x0, #N_OFF]
    mov x1, x0
    mov x0, x25
    bl Lappend
    b Ls_loop
Ls_done:
    mov x0, x25
    ldp x26, x27, [sp, #32]
    ldp x24, x25, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---- accessors (regular ABI) ----

// Node *av_yaml_get(Node *map, const char *key)
FUNC_BEGIN _av_yaml_get
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x21, #0
    cbz x0, 9f
    ldrb w9, [x0, #N_TYPE]
    cmp w9, #Y_MAP
    b.ne 9f
    ldr x19, [x0, #N_PTR]
    mov x20, x1
    mov x0, x1
    bl _strlen
    mov x22, x0
1:  cbz x19, 9f
    ldr x9, [x19, #N_KEYLEN]
    cmp x9, x22
    b.ne 2f
    ldr x0, [x19, #N_KEY]
    mov x1, x20
    mov x2, x22
    bl _memcmp
    cbnz w0, 2f
    mov x21, x19
    b 9f
2:  ldr x19, [x19, #N_NEXT]
    b 1b
9:  mov x0, x21
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Node *av_yaml_at(Node *seq_or_map, size_t i)
FUNC_BEGIN _av_yaml_at
    cbz x0, 2f
    ldrb w9, [x0, #N_TYPE]
    cmp w9, #Y_MAP
    b.lo 3f
    ldr x0, [x0, #N_PTR]
1:  cbz x0, 2f
    cbz x1, 2f
    ldr x0, [x0, #N_NEXT]
    sub x1, x1, #1
    b 1b
3:  mov x0, #0
2:  ret

// const char *av_yaml_str(Node *n), NULL unless a decoded scalar
FUNC_BEGIN _av_yaml_str
    cbz x0, 1f
    ldrb w9, [x0, #N_TYPE]
    cmp w9, #Y_SCALAR
    b.ne 2f
    ldrb w9, [x0, #N_FLAGS]
    tbnz w9, #1, 2f
    ldr x0, [x0, #N_PTR]
    ret
2:  mov x0, #0
1:  ret

// long av_yaml_int(Node *n, long dflt), decimal with optional sign
FUNC_BEGIN _av_yaml_int
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl _av_yaml_str
    cbz x0, 8f
    mov x2, #0
    mov x3, #0
    ldrb w4, [x0]
    cmp w4, #'-'
    b.ne 1f
    mov x3, #1
    add x0, x0, #1
1:  ldrb w4, [x0]
    cbz w4, 8f
    mov x5, #10
2:  ldrb w4, [x0], #1
    cbz w4, 3f
    sub w4, w4, #'0'
    cmp w4, #9
    b.hi 8f
    madd x2, x2, x5, x4
    b 2b
3:  cmp x3, #0
    cneg x19, x2, ne
8:  mov x0, x19
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// double av_yaml_float(Node *n, double dflt)
FUNC_BEGIN _av_yaml_float
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    str x19, [sp, #16]
    str d8, [sp, #24]
    fmov d8, d0
    bl _av_yaml_str
    cbz x0, 8f
    mov x19, x0
    add x1, sp, #32
    bl _strtod
    ldr x9, [sp, #32]
    cmp x9, x19
    b.eq 8f
    ldrb w9, [x9]
    cbnz w9, 8f
    fmov d8, d0
8:  fmov d0, d8
    ldr d8, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_yaml_bool(Node *n, int dflt), true/yes/on and false/no/off, any case
FUNC_BEGIN _av_yaml_bool
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x1
    bl _av_yaml_str
    cbz x0, 8f
    mov x20, x0
    LADDR x21, Lbool_words
    mov x22, #0
1:  cmp x22, #6
    b.hs 8f
    ldr x1, [x21, x22, lsl #3]
    mov x0, x20
    bl _strcasecmp
    cbz w0, 2f
    add x22, x22, #1
    b 1b
2:  cmp x22, #3
    cset x19, lo
8:  mov x0, x19
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .section __DATA,__const
    .p2align 3
Lbool_words:
    .quad Ls_true, Ls_yes, Ls_on, Ls_false, Ls_no, Ls_off
