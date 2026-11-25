// main window, dark appearance and Catppuccin Mocha base background

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"
.include "theme.inc"

    CLASSREF NSWindow
    CLASSREF NSColor
    CLASSREF NSAppearance
    CLASSREF NSString

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
    SELDEF setContentView, "setContentView:"
    SELDEF makeFirstResponder, "makeFirstResponder:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"
    SELDEF setTitleWithFile, "setTitleWithRepresentedFilename:"
    SELDEF contentView, "contentView"
    SELDEF setDelegate, "setDelegate:"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"

    CFSTRDEF title, "Avenger"

    .zerofill __DATA,__bss,_av_window,8,3
    .globl _av_window

    .text
// void av_window_create(void): themed window whose content is the tab container
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
    // the app delegate also decides whether the window may close with unsaved tabs
    mov x0, x19
    LDRG x2, _av_delegate
    MSG setDelegate

    mov x0, x19
    bl Lwindow_style
    mov x0, x19
    mov x2, #1
    MSG setTitlebarTransparent

    mov x0, x19
    ldr d0, Lmin_w
    ldr d1, Lmin_h
    MSG setMinSize
    mov x0, x19
    bl _av_tabs_init
    mov x0, x19
    MSG center
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_window_show(void)
FUNC_BEGIN _av_window_show
    LDRG x0, _av_window
    mov x2, #0
    LSEL x1, makeKey
    b _objc_msgSend

    .p2align 3
Lwin_w:  .double 1100.0
Lwin_h:  .double 720.0
Lmin_w:  .double 400.0
Lmin_h:  .double 240.0

// void window_style(NSWindow *w): appearance and background from the loaded theme
    .text
    .p2align 2
Lwindow_style:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _av_theme_is_light
    cbz w0, 1f
    LEXTERN x2, _NSAppearanceNameAqua
    b 2f
1:  LEXTERN x2, _NSAppearanceNameDarkAqua
2:  CLS x0, NSAppearance
    MSG appearanceNamed
    mov x2, x0
    mov x0, x19
    MSG setAppearance
    LADDR x9, _av_theme
    ldp d0, d1, [x9, #T_BG]
    ldp d2, d3, [x9, #(T_BG + 16)]
    CLS x0, NSColor
    MSG srgb
    mov x2, x0
    mov x0, x19
    MSG setBackgroundColor
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_theme_apply(size_t idx): built-in flavor from the menu, session only
FUNC_BEGIN _av_theme_apply
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl _av_theme_load
    bl _av_config_forget_theme
    bl Ltheme_refresh
    ldp x29, x30, [sp], #16
    ret

// void av_config_apply(void): keys, font and theme from the loaded config
FUNC_BEGIN _av_config_apply
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x0, _av_cfg_prefix
    LDRG x1, _av_cfg_keys
    bl _av_keymap_configure
    LDRG x0, _av_cfg_font
    LDRD d0, _av_cfg_font_size
    bl _av_render_set_font
    LDRG x0, _av_cfg_theme
    bl _av_theme_index_of
    tbnz x0, #63, 1f
    bl _av_theme_load
    bl _av_config_forget_theme
    b 2f
    // not a built-in flavor: <config dir>/themes/<name>.yaml
1:  LDRG x0, _av_cfg_theme
    bl _av_config_theme_path
    bl _av_theme_load_file
    cbz x0, 2f
    mov x0, #THEME_DEFAULT
    bl _av_theme_load
2:  bl Ltheme_refresh
    ldp x29, x30, [sp], #16
    ret

// void av_config_reload_if_changed(void), beeps when the new config is invalid
FUNC_BEGIN _av_config_reload_if_changed
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl _av_config_changed
    cbz w0, 2f
    bl _av_config_load
    tbz x0, #63, 1f
    bl _NSBeep
1:  bl _av_config_apply
2:  ldp x29, x30, [sp], #16
    ret

// rebuild text attributes, sync the menu, restyle the window and redraw
    .p2align 2
Ltheme_refresh:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    bl _av_render_rebuild_attrs
    bl _av_app_theme_menu_sync
    LDRG x19, _av_window
    cbz x19, 1f
    mov x0, x19
    bl Lwindow_style
    // the font may have changed: tab bar height, then the active editor
    bl _av_tabs_layout
    bl _av_tabs_current_view
    cbz x0, 1f
    mov x2, #1
    MSG setNeedsDisplay
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
