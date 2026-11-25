// yamlcheck file...: validates YAML files with the editor's parser, exit 1 if any fails

.include "macros.inc"
.include "buffer.inc"
.include "yaml.inc"

    .zerofill __DATA,__bss,_ybuf,BUF_SIZE,4
    .zerofill __DATA,__bss,_yctx,Y_SIZE,4

    .section __TEXT,__cstring,cstring_literals
Lfmt_err:  .asciz "%s:%ld: %s\n"
Lfmt_open: .asciz "%s: cannot read\n"
Lfmt_ok:   .asciz "%s: ok\n"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, #1
    mov x22, #0
1:  cmp x21, x19
    b.hs 9f
    ldr x1, [x20, x21, lsl #3]
    LADDR x0, _ybuf
    bl _av_buf_load
    cbz x0, 2f
    sub sp, sp, #16
    ldr x9, [x20, x21, lsl #3]
    str x9, [sp]
    LADDR x0, Lfmt_open
    bl _printf
    add sp, sp, #16
    mov x22, #1
    b 5f
2:  LADDR x9, _ybuf
    ldr x1, [x9, #BUF_DATA]
    ldr x2, [x9, #BUF_GS]
    LADDR x0, _yctx
    bl _av_yaml_parse
    sub sp, sp, #32
    ldr x9, [x20, x21, lsl #3]
    str x9, [sp]
    cbnz x0, 3f
    mov x22, #1
    LADDR x9, _yctx
    ldr x10, [x9, #Y_ERRLINE]
    str x10, [sp, #8]
    ldr x0, [x9, #Y_ERR]
    bl _av_yaml_error_msg
    str x0, [sp, #16]
    LADDR x0, Lfmt_err
    bl _printf
    b 4f
3:  LADDR x0, Lfmt_ok
    bl _printf
4:  add sp, sp, #32
    LADDR x0, _yctx
    bl _av_yaml_free
    LADDR x0, _ybuf
    bl _av_buf_free
5:  add x21, x21, #1
    b 1b
9:  mov x0, x22
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
