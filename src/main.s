// entry point, keeps main tiny so startup work lives in app.s

.include "macros.inc"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl _av_app_init
    bl _av_window_create
    bl _av_app_run
    mov w0, #0
    ldp x29, x30, [sp], #16
    ret

    // marks the image as containing objc metadata so selrefs get fixed up
    .section __DATA,__objc_imageinfo,regular,no_dead_strip
    .p2align 2
    .long 0, 64
