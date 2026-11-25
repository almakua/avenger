// entry point: avenger [file]

.include "macros.inc"
.include "doc.inc"
.include "theme.inc"

    .section __TEXT,__cstring,cstring_literals
Lsnap_env:
    .asciz "AV_SNAPSHOT"
Ltype_env:
    .asciz "AV_TYPE"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    bl _av_app_init
    bl _av_render_init
    bl _av_editor_class_init
    bl _av_config_load
    bl _av_config_apply

    mov x0, #DOC_SIZE
    bl _av_arena_alloc
    mov x21, x0
    mov x22, #0
    cmp x19, #2
    b.lt 1f
    ldr x22, [x20, #8]
    mov x0, x21
    mov x1, x22
    bl _av_doc_open
    b 2f
1:  mov x0, x21
    bl _av_doc_init

2:  mov x0, x21
    bl _av_editor_create
    mov x19, x0
    mov x1, x22
    bl _av_window_create
    // dev hooks: AV_TYPE feeds synthetic keys, AV_SNAPSHOT=out.png renders a frame and exits
    LADDR x0, Ltype_env
    bl _getenv
    cbz x0, 4f
    mov x1, x0
    mov x0, x19
    bl _av_snapshot_type
4:  LADDR x0, Lsnap_env
    bl _getenv
    cbz x0, 3f
    mov x1, x0
    mov x0, x19
    bl _av_snapshot
    bl _exit
3:  bl _av_app_run
    mov w0, #0
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    // marks the image as containing objc metadata so selrefs get fixed up
    .section __DATA,__objc_imageinfo,regular,no_dead_strip
    .p2align 2
    .long 0, 64
