// main window, dark appearance and Catppuccin Mocha base background

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"

    CLASSREF NSWindow
    CLASSREF NSColor
    CLASSREF NSAppearance

    SELDEF alloc, "alloc"
    SELDEF initWin, "initWithContentRect:styleMask:backing:defer:"
    SELDEF setReleasedWhenClosed, "setReleasedWhenClosed:"
    SELDEF setTitle, "setTitle:"
    SELDEF appearanceNamed, "appearanceNamed:"
    SELDEF setAppearance, "setAppearance:"
    SELDEF srgb, "colorWithSRGBRed:green:blue:alpha:"
    SELDEF setBackgroundColor, "setBackgroundColor:"
    SELDEF setTitlebarTransparent, "setTitlebarAppearsTransparent:"
    SELDEF setMinSize, "setContentMinSize:"
    SELDEF center, "center"
    SELDEF makeKey, "makeKeyAndOrderFront:"

    CFSTRDEF title, "Avenger"

    .zerofill __DATA,__bss,_av_window,8,3
    .globl _av_window

    .text
// void av_window_create(void)
FUNC_BEGIN _av_window_create
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]

    CLS x0, NSWindow
    MSG alloc
    movi d0, #0
    movi d1, #0
    ldr d2, Lwin_w
    ldr d3, Lwin_h
    mov x2, #AV_WINDOW_STYLE
    mov x3, #NSBackingStoreBuffered
    mov x4, #0
    MSG initWin
    mov x19, x0
    STRG x19, _av_window, x8

    mov x0, x19
    mov x2, #0
    MSG setReleasedWhenClosed
    mov x0, x19
    CFSTR x2, title
    MSG setTitle

    CLS x0, NSAppearance
    LEXTERN x2, _NSAppearanceNameDarkAqua
    MSG appearanceNamed
    mov x2, x0
    mov x0, x19
    MSG setAppearance

    // base #1e1e2e
    CLS x0, NSColor
    ldr d0, Lbase_r
    ldr d1, Lbase_r
    ldr d2, Lbase_b
    fmov d3, #1.0
    MSG srgb
    mov x2, x0
    mov x0, x19
    MSG setBackgroundColor
    mov x0, x19
    mov x2, #1
    MSG setTitlebarTransparent

    mov x0, x19
    ldr d0, Lmin_w
    ldr d1, Lmin_h
    MSG setMinSize
    mov x0, x19
    MSG center
    mov x0, x19
    mov x2, #0
    MSG makeKey

    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .p2align 3
Lwin_w:  .double 1100.0
Lwin_h:  .double 720.0
Lmin_w:  .double 400.0
Lmin_h:  .double 240.0
Lbase_r: .double 0.11764705882352941
Lbase_b: .double 0.1803921568627451
