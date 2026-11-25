// YAML outline: every key and sequence item as a path with its line, and template detection

.include "macros.inc"
.include "yaml.inc"

.set OL_LINE, 0
.set OL_PATH, 8                // NUL-terminated, cut at OL_PATH_MAX
.set OL_SIZE, 128
.set OL_PATH_MAX, (OL_SIZE - OL_PATH)

    .section __TEXT,__cstring,cstring_literals
Ltpl_expr:  .asciz "{{"
Ltpl_stmt:  .asciz "{%"

    .zerofill __DATA,__bss,_av_ol_out,8,3
    .zerofill __DATA,__bss,_av_ol_max,8,3
    .zerofill __DATA,__bss,_av_ol_n,8,3
    .zerofill __DATA,__bss,_av_ol_path,(OL_PATH_MAX + 32),3

    .text
// int av_yaml_is_template(const char *src, size_t n): Helm/Jinja markers, such files are not
// plain YAML until rendered
FUNC_BEGIN _av_yaml_is_template
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    LADDR x2, Ltpl_expr
    mov x3, #2
    bl _memmem
    cbnz x0, 1f
    mov x0, x19
    mov x1, x20
    LADDR x2, Ltpl_stmt
    mov x3, #2
    bl _memmem
1:  cmp x0, #0
    cset w0, ne
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t av_outline(Node *root, Item *out, size_t max): one item per key and sequence item, in
// document order, documents after the first included; returns the count (at most max)
FUNC_BEGIN _av_outline
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    STRG x1, _av_ol_out, x9
    STRG x2, _av_ol_max, x9
    STRG xzr, _av_ol_n, x9
1:  cbz x19, 9f
    ldrb w9, [x19, #N_TYPE]
    cmp w9, #Y_MAP
    b.lo 2f
    mov x0, x19
    mov x1, #0
    bl Lwalk
2:  ldr x19, [x19, #N_NEXT]
    b 1b
9:  LDRG x0, _av_ol_n
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t append(size_t len, const char *s, size_t n): s after the path's first len bytes
    .p2align 2
Lappend:
    LADDR x9, _av_ol_path
1:  cbz x2, 2f
    cmp x0, #(OL_PATH_MAX - 1)
    b.hs 2f
    ldrb w10, [x1], #1
    strb w10, [x9, x0]
    add x0, x0, #1
    sub x2, x2, #1
    b 1b
2:  strb wzr, [x9, x0]
    ret

// void walk(Node *container, size_t len): children of a map or sequence under the path prefix
// of len bytes; recursion depth is bounded by the parser
    .p2align 2
Lwalk:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    ldrb w23, [x19, #N_TYPE]
    ldr x21, [x19, #N_PTR]
    mov x22, #0
1:  cbz x21, 9f
    mov x0, x20
    cmp w23, #Y_MAP
    b.ne 3f
    // map: "parent.key"
    cbz x20, 2f
    adr x1, Ldot
    mov x2, #1
    bl Lappend
2:  ldr x1, [x21, #N_KEY]
    ldr x2, [x21, #N_KEYLEN]
    bl Lappend
    b 5f
    // sequence: "parent[i]"
3:  adr x1, Lopen
    mov x2, #1
    bl Lappend
    mov x24, x0
    add x1, sp, #72
    mov x9, x22
    mov x10, #10
4:  udiv x11, x9, x10
    msub x12, x11, x10, x9
    add w12, w12, #'0'
    strb w12, [x1, #-1]!
    mov x9, x11
    cbnz x9, 4b
    add x2, sp, #72
    sub x2, x2, x1
    mov x0, x24
    bl Lappend
    adr x1, Lclose
    mov x2, #1
    bl Lappend
5:  mov x24, x0
    LDRG x9, _av_ol_n
    LDRG x10, _av_ol_max
    cmp x9, x10
    b.hs 9f
    add x10, x9, #1
    STRG x10, _av_ol_n, x11
    LDRG x10, _av_ol_out
    mov x11, #OL_SIZE
    madd x0, x9, x11, x10
    ldr w9, [x21, #N_LINE]
    str x9, [x0, #OL_LINE]
    add x0, x0, #OL_PATH
    LADDR x1, _av_ol_path
    mov x2, #OL_PATH_MAX
    bl _strlcpy
    ldrb w9, [x21, #N_TYPE]
    cmp w9, #Y_MAP
    b.lo 6f
    mov x0, x21
    mov x1, x24
    bl Lwalk
6:  ldr x21, [x21, #N_NEXT]
    add x22, x22, #1
    b 1b
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

Ldot:   .ascii "."
Lopen:  .ascii "["
Lclose: .ascii "]"
    .p2align 2
