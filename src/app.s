// NSApplication bootstrap, app delegate class built at runtime and main menu

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"

    CLASSREF NSApplication
    CLASSREF NSObject
    CLASSREF NSMenu
    CLASSREF NSMenuItem

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
    SELDEF initItem, "initWithTitle:action:keyEquivalent:"
    SELDEF terminate, "terminate:"
    SELDEF hide, "hide:"
    SELDEF shouldTerminate, "applicationShouldTerminateAfterLastWindowClosed:"

    CFSTRDEF empty, ""
    CFSTRDEF quitTitle, "Quit Avenger"
    CFSTRDEF hideTitle, "Hide Avenger"
    CFSTRDEF keyQ, "q"
    CFSTRDEF keyH, "h"

    .section __TEXT,__cstring,cstring_literals
Ldelegate_name:
    .asciz "AvAppDelegate"
Ltypes_c_at_at:
    .asciz "c@:@"

    .zerofill __DATA,__bss,_av_app,8,3
    .globl _av_app

    .text
// void av_app_init(void)
FUNC_BEGIN _av_app_init
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    CLS x0, NSApplication
    MSG sharedApplication
    mov x19, x0
    STRG x19, _av_app, x8

    mov x0, x19
    mov x2, #NSApplicationActivationPolicyRegular
    MSG setActivationPolicy

    // delegate: NSObject subclass with a single method, no ivars
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
    bl _objc_registerClassPair
    mov x0, x20
    MSG new
    mov x2, x0
    mov x0, x19
    MSG setDelegate

    // menu bar -> app item -> app menu (hide, quit)
    CLS x0, NSMenu
    MSG new
    mov x20, x0
    CLS x0, NSMenuItem
    MSG new
    mov x21, x0
    mov x0, x20
    mov x2, x21
    MSG addItem
    CLS x0, NSMenu
    MSG new
    mov x22, x0

    CLS x0, NSMenuItem
    MSG alloc
    CFSTR x2, hideTitle
    LSEL x3, hide
    CFSTR x4, keyH
    MSG initItem
    mov x2, x0
    mov x0, x22
    MSG addItem

    CLS x0, NSMenuItem
    MSG alloc
    CFSTR x2, quitTitle
    LSEL x3, terminate
    CFSTR x4, keyQ
    MSG initItem
    mov x2, x0
    mov x0, x22
    MSG addItem

    mov x0, x21
    mov x2, x22
    MSG setSubmenu
    mov x0, x19
    mov x2, x20
    MSG setMainMenu

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
