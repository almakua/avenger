// NSApplication bootstrap, app delegate class built at runtime and main menu

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"
.include "theme.inc"

    CLASSREF NSApplication
    CLASSREF NSObject
    CLASSREF NSMenu
    CLASSREF NSMenuItem
    CLASSREF NSString

    SELDEF sharedApplication, "sharedApplication"
    SELDEF setActivationPolicy, "setActivationPolicy:"
    SELDEF setDelegate, "setDelegate:"
    SELDEF setMainMenu, "setMainMenu:"
    SELDEF activate, "activateIgnoringOtherApps:"
    SELDEF run, "run"
    SELDEF new, "new"
    SELDEF alloc, "alloc"
    SELDEF addItem, "addItem:"
    SELDEF setSubmenu, "setSubmenu:"
    SELDEF initMenu, "initWithTitle:"
    SELDEF initItem, "initWithTitle:action:keyEquivalent:"
    SELDEF shouldTerminate, "applicationShouldTerminateAfterLastWindowClosed:"

    // menu actions, resolved through the responder chain
    SELDEF terminate, "terminate:"
    SELDEF hide, "hide:"
    SELDEF saveDocument, "saveDocument:"
    SELDEF undo, "undo:"
    SELDEF redo, "redo:"
    SELDEF cut, "cut:"
    SELDEF copy, "copy:"
    SELDEF paste, "paste:"
    SELDEF selectAll, "selectAll:"
    SELDEF selectTheme, "selectTheme:"
    SELDEF nextTheme, "nextTheme:"
    SELDEF didBecomeActive, "applicationDidBecomeActive:"
    SELDEF tag, "tag"
    SELDEF setTag, "setTag:"
    SELDEF setState, "setState:"
    SELDEF setKeyMask, "setKeyEquivalentModifierMask:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"

    CFSTRDEF empty, ""
    CFSTRDEF tApp, "Avenger"
    CFSTRDEF tHide, "Hide Avenger"
    CFSTRDEF tQuit, "Quit Avenger"
    CFSTRDEF tFile, "File"
    CFSTRDEF tSave, "Save"
    CFSTRDEF tEdit, "Edit"
    CFSTRDEF tUndo, "Undo"
    CFSTRDEF tRedo, "Redo"
    CFSTRDEF tCut, "Cut"
    CFSTRDEF tCopy, "Copy"
    CFSTRDEF tPaste, "Paste"
    CFSTRDEF tSelectAll, "Select All"
    CFSTRDEF tView, "View"
    CFSTRDEF tTheme, "Theme"
    CFSTRDEF tNextTheme, "Next Theme"
    CFSTRDEF kT, "t"
    CFSTRDEF kH, "h"
    CFSTRDEF kQ, "q"
    CFSTRDEF kS, "s"
    CFSTRDEF kZ, "z"
    CFSTRDEF kShiftZ, "Z"
    CFSTRDEF kX, "x"
    CFSTRDEF kC, "c"
    CFSTRDEF kV, "v"
    CFSTRDEF kA, "a"

    .section __TEXT,__cstring,cstring_literals
Ldelegate_name:
    .asciz "AvAppDelegate"
Ltypes_c_at_at:
    .asciz "c@:@"
Ltypes_v_at_at:
    .asciz "v@:@"

    .zerofill __DATA,__bss,_av_app,8,3
    .zerofill __DATA,__bss,_av_theme_items,(THEME_COUNT * 8),3
    .globl _av_app

// ITEM menu_reg, title, action, key
.macro ITEM menu, title, action, key
    mov x0, \menu
    CFSTR x1, \title
    LSEL x2, \action
    CFSTR x3, \key
    bl Ladd_item
.endm

    .text
// void av_app_init(void)
FUNC_BEGIN _av_app_init
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]

    CLS x0, NSApplication
    MSG sharedApplication
    mov x19, x0
    STRG x19, _av_app, x8

    mov x0, x19
    mov x2, #NSApplicationActivationPolicyRegular
    MSG setActivationPolicy

    // delegate: NSObject subclass, also the responder-chain target for app-wide actions
    CLS x0, NSObject
    LADDR x1, Ldelegate_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x20, x0
    LSEL x1, shouldTerminate
    adr x2, _av_should_terminate
    LADDR x3, Ltypes_c_at_at
    bl _class_addMethod
    mov x0, x20
    LSEL x1, selectTheme
    adr x2, Lselect_theme
    LADDR x3, Ltypes_v_at_at
    bl _class_addMethod
    mov x0, x20
    LSEL x1, nextTheme
    adr x2, Lnext_theme
    LADDR x3, Ltypes_v_at_at
    bl _class_addMethod
    mov x0, x20
    LSEL x1, didBecomeActive
    adr x2, Ldid_become_active
    LADDR x3, Ltypes_v_at_at
    bl _class_addMethod
    mov x0, x20
    bl _objc_registerClassPair
    mov x0, x20
    MSG new
    mov x2, x0
    mov x0, x19
    MSG setDelegate

    CLS x0, NSMenu
    MSG new
    mov x20, x0

    mov x0, x20
    CFSTR x1, tApp
    bl Ladd_menu
    mov x21, x0
    ITEM x21, tHide, hide, kH
    ITEM x21, tQuit, terminate, kQ

    mov x0, x20
    CFSTR x1, tFile
    bl Ladd_menu
    mov x21, x0
    ITEM x21, tSave, saveDocument, kS

    mov x0, x20
    CFSTR x1, tEdit
    bl Ladd_menu
    mov x21, x0
    ITEM x21, tUndo, undo, kZ
    ITEM x21, tRedo, redo, kShiftZ
    ITEM x21, tCut, cut, kX
    ITEM x21, tCopy, copy, kC
    ITEM x21, tPaste, paste, kV
    ITEM x21, tSelectAll, selectAll, kA

    // View > Theme > one item per flavor, tag = theme index
    mov x0, x20
    CFSTR x1, tView
    bl Ladd_menu
    mov x21, x0
    CFSTR x1, tTheme
    bl Ladd_menu
    mov x22, x0
    mov x23, #0
1:  mov x0, x23
    bl _av_theme_name
    mov x2, x0
    CLS x0, NSString
    MSG stringWithUTF8String
    mov x1, x0
    mov x0, x22
    LSEL x2, selectTheme
    CFSTR x3, empty
    bl Ladd_item
    LADDR x9, _av_theme_items
    str x0, [x9, x23, lsl #3]
    mov x2, x23
    MSG setTag
    add x23, x23, #1
    cmp x23, #THEME_COUNT
    b.lo 1b
    ITEM x21, tNextTheme, nextTheme, kT
    mov x2, #(NSEventModifierFlagCommand | NSEventModifierFlagOption)
    MSG setKeyMask

    mov x0, x19
    mov x2, x20
    MSG setMainMenu

    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_app_theme_menu_sync(void), check mark on the active flavor
FUNC_BEGIN _av_app_theme_menu_sync
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, #0
1:  LADDR x9, _av_theme_items
    ldr x0, [x9, x19, lsl #3]
    cbz x0, 2f
    LDRG x10, _av_theme_index
    cmp x10, x19
    cset x2, eq
    MSG setState
2:  add x19, x19, #1
    cmp x19, #THEME_COUNT
    b.lo 1b
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// selectTheme:(NSMenuItem *)sender
    .p2align 2
Lselect_theme:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x2
    MSG tag
    bl _av_theme_apply
    ldp x29, x30, [sp], #16
    ret

// applicationDidBecomeActive:, picks up config edits made in other editors
    .p2align 2
Ldid_become_active:
    b _av_config_reload_if_changed

// nextTheme:(id)sender, cycles through the flavors
    .p2align 2
Lnext_theme:
    LDRG x0, _av_theme_index
    add x0, x0, #1
    cmp x0, #THEME_COUNT
    csel x0, x0, xzr, lo
    b _av_theme_apply

// NSMenu *add_menu(NSMenu *bar, NSString *title)
    .p2align 2
Ladd_menu:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    CLS x0, NSMenu
    MSG alloc
    mov x2, x20
    MSG initMenu
    mov x21, x0
    CLS x0, NSMenuItem
    MSG new
    mov x22, x0
    mov x2, x21
    MSG setSubmenu
    mov x0, x19
    mov x2, x22
    MSG addItem
    mov x0, x21
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// NSMenuItem *add_item(NSMenu *menu, NSString *title, SEL action, NSString *key)
    .p2align 2
Ladd_item:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    CLS x0, NSMenuItem
    MSG alloc
    mov x2, x20
    mov x3, x21
    mov x4, x22
    MSG initItem
    mov x20, x0
    mov x2, x0
    mov x0, x19
    MSG addItem
    mov x0, x20
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_app_run(void), never returns in practice
FUNC_BEGIN _av_app_run
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x0, _av_app
    mov x2, #1
    MSG activate
    LDRG x0, _av_app
    MSG run
    ldp x29, x30, [sp], #16
    ret

// BOOL applicationShouldTerminateAfterLastWindowClosed:(id)sender
    .p2align 2
_av_should_terminate:
    mov w0, #1
    ret
