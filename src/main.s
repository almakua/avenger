// entry point: avenger [file]

.include "macros.inc"
.include "doc.inc"
.include "theme.inc"

.set CLOCK_UPTIME_RAW, 8

    .section __TEXT,__cstring,cstring_literals
Lsnap_env:
    .asciz "AV_SNAPSHOT"
Ltype_env:
    .asciz "AV_TYPE"
Lbench_env:
    .asciz "AV_BENCH"

    .zerofill __DATA,__bss,_av_t0,8,3
    .globl _av_t0

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    // start time for AV_BENCH
    mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    STRG x0, _av_t0, x9
    bl _av_app_init
    bl _av_render_init
    bl _av_editor_class_init
    bl _av_term_class_init
    bl _av_config_load
    bl _av_config_apply

    // one tab per file argument, or an untitled one
2:  bl _av_window_create
    mov x21, #1
4:  cmp x21, x19
    b.hs 5f
    ldr x0, [x20, x21, lsl #3]
    bl _av_tab_open
    add x21, x21, #1
    b 4b
5:  LDRG x9, _av_ntabs
    cbnz x9, 6f
    mov x0, #0
    bl _av_tab_open
6:  bl _av_window_show
    // dev hooks: AV_TYPE feeds synthetic keys, AV_SNAPSHOT=out.png renders a frame and exits
    LADDR x0, Ltype_env
    bl _getenv
    cbz x0, 7f
    mov x1, x0
    bl _av_tabs_current_view
    bl _av_snapshot_type
7:  LADDR x0, Lbench_env
    bl _getenv
    cbz x0, 71f
    bl _atol
    bl _av_bench
71: LADDR x0, Lsnap_env
    bl _getenv
    cbz x0, 3f
    mov x1, x0
    LDRG x0, _av_container
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
