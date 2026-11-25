// tabs: model, window content (tab bar + active view), actions, prefix keys, open/save panels

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"
.include "buffer.inc"
.include "doc.inc"
.include "theme.inc"
.include "keymap.inc"

.set MAX_TABS, 64
.set TAB_NSVIEW, 0
.set TAB_VIEW,   8
.set TAB_DOC,    16
.set TAB_KIND,   24
.set TAB_SIZE,   32
.set TAB_KIND_EDITOR, 1

.set NSModalResponseOK, 1
.set ALERT_FIRST,  1000
.set ALERT_SECOND, 1001
.set NSViewWidthSizable,  2
.set NSViewHeightSizable, 16
.set NSViewMinYMargin,    8
.set KEY_ESC_CODE, 53

// tab bar drawRect locals
.set TB_TITLE, 176
.set TB_FRAME, 448

    CLASSREF NSView
    CLASSREF NSString
    CLASSREF NSOpenPanel
    CLASSREF NSSavePanel
    CLASSREF NSAlert
    CLASSREF NSGraphicsContext

    SELDEF alloc, "alloc"
    SELDEF new, "new"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF setAutoresizingMask, "setAutoresizingMask:"
    SELDEF addSubview, "addSubview:"
    SELDEF removeFromSuperview, "removeFromSuperview"
    SELDEF setFrame, "setFrame:"
    SELDEF bounds, "bounds"
    SELDEF contentView, "contentView"
    SELDEF setContentView, "setContentView:"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF makeFirstResponder, "makeFirstResponder:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"
    SELDEF setTitle, "setTitle:"
    SELDEF setTitleWithFile, "setTitleWithRepresentedFilename:"
    SELDEF setRepresentedFilename, "setRepresentedFilename:"
    SELDEF setDocumentEdited, "setDocumentEdited:"
    SELDEF close, "close"
    SELDEF openPanel, "openPanel"
    SELDEF savePanel, "savePanel"
    SELDEF setAllowsMultiple, "setAllowsMultipleSelection:"
    SELDEF runModal, "runModal"
    SELDEF URLs, "URLs"
    SELDEF URL, "URL"
    SELDEF count, "count"
    SELDEF objectAtIndex, "objectAtIndex:"
    SELDEF path, "path"
    SELDEF UTF8String, "UTF8String"
    SELDEF setMessageText, "setMessageText:"
    SELDEF setInformativeText, "setInformativeText:"
    SELDEF addButton, "addButtonWithTitle:"
    SELDEF currentContext, "currentContext"
    SELDEF CGContext, "CGContext"
    SELDEF modifierFlags, "modifierFlags"
    SELDEF charsIgnoring, "charactersIgnoringModifiers"
    SELDEF keyCode, "keyCode"
    SELDEF locationInWindow, "locationInWindow"
    SELDEF convertPoint, "convertPoint:fromView:"
    SELDEF drawRect, "drawRect:"
    SELDEF mouseDown, "mouseDown:"
    SELDEF isOpaque, "isOpaque"

    CFSTRDEF untitled, "untitled"
    CFSTRDEF empty, ""
    CFSTRDEF askSave, "Save changes before closing?"
    CFSTRDEF bSave, "Save"
    CFSTRDEF bDontSave, "Don't Save"
    CFSTRDEF bCancel, "Cancel"
    CFSTRDEF unsaved, "You have unsaved changes."
    CFSTRDEF quitInfo, "Unsaved changes will be lost if you quit."
    CFSTRDEF bQuit, "Quit Anyway"

    .section __TEXT,__cstring,cstring_literals
Ltb_name:     .asciz "AvTabBar"
Lt_rect:      .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_obj:       .asciz "v@:@"
Lt_bool:      .asciz "c@:"
Ls_untitled:  .asciz "untitled"
Ls_ellipsis:  .asciz "\342\200\246"
Ls_dirty:     .asciz "\342\227\217"
Ls_close:     .asciz "\303\227"
Ls_plus:      .asciz "+"

    // config.yaml template written into a new config file
    .section __TEXT,__const
Lcfg_template:
    .incbin "config.example.yaml"
Lcfg_template_end:

    .zerofill __DATA,__bss,_av_tabs,(MAX_TABS * 8),3
    .zerofill __DATA,__bss,_av_ntabs,8,3
    .zerofill __DATA,__bss,_av_container,8,3
    .zerofill __DATA,__bss,_av_tabbar,8,3
    .zerofill __DATA,__bss,_av_prefix_pending,8,3
    .globl _av_tabs
    .globl _av_ntabs
    .globl _av_container
    .section __DATA,__data
    .p2align 3
    .globl _av_tab_cur
_av_tab_cur:  .quad -1
_av_tab_last: .quad -1

// reg = Tab * at index ireg, clobbers x16
.macro TAB reg, ireg
    LADDR x16, _av_tabs
    ldr \reg, [x16, \ireg, lsl #3]
.endm

    .text
// ---- window content ----

// void av_tabs_init(NSWindow *w): container view with the tab bar on top
FUNC_BEGIN _av_tabs_init
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    MSG contentView
    MSG bounds
    stp d0, d1, [sp, #48]
    stp d2, d3, [sp, #64]
    CLS x0, NSView
    MSG alloc
    ldp d0, d1, [sp, #48]
    ldp d2, d3, [sp, #64]
    MSG initWithFrame
    mov x20, x0
    STRG x20, _av_container, x9
    mov x2, #(NSViewWidthSizable | NSViewHeightSizable)
    MSG setAutoresizingMask
    mov x0, x19
    mov x2, x20
    MSG setContentView

    CLS x0, NSView
    LADDR x1, Ltb_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x21, x0
    LSEL x1, drawRect
    adr x2, Ltb_draw
    LADDR x3, Lt_rect
    bl _class_addMethod
    mov x0, x21
    LSEL x1, mouseDown
    adr x2, Ltb_mouse
    LADDR x3, Lt_obj
    bl _class_addMethod
    mov x0, x21
    LSEL x1, isOpaque
    adr x2, Lyes
    LADDR x3, Lt_bool
    bl _class_addMethod
    mov x0, x21
    bl _objc_registerClassPair
    mov x0, x21
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x22, x0
    STRG x22, _av_tabbar, x9
    mov x2, #(NSViewWidthSizable | NSViewMinYMargin)
    MSG setAutoresizingMask
    mov x0, x20
    mov x2, x22
    MSG addSubview
    bl _av_tabs_layout
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

    .p2align 2
Lyes:
    mov w0, #1
    ret

// double bar_h(void), follows the editor font
    .p2align 2
Lbar_h:
    LDRD d0, _av_line_h
    fmov d1, #10.0
    fadd d0, d0, d1
    ret

// void av_tabs_layout(void): tab bar on top, active view below
FUNC_BEGIN _av_tabs_layout
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    str d10, [sp, #40]
    LDRG x19, _av_container
    cbz x19, 9f
    mov x0, x19
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    bl Lbar_h
    fmov d10, d0
    LDRG x0, _av_tabbar
    movi d0, #0
    fsub d1, d9, d10
    fmov d2, d8
    fmov d3, d10
    MSG setFrame
    bl _av_tabs_current_view
    cbz x0, 1f
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fsub d3, d9, d10
    MSG setFrame
1:  bl _av_tabbar_redraw
9:  ldr d10, [sp, #40]
    ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_tabbar_redraw(void)
FUNC_BEGIN _av_tabbar_redraw
    LDRG x0, _av_tabbar
    cbz x0, 1f
    mov x2, #1
    LSEL x1, setNeedsDisplay
    b _objc_msgSend
1:  ret

// NSView *av_tabs_current_view(void)
FUNC_BEGIN _av_tabs_current_view
    LDRG x9, _av_tab_cur
    LDRG x10, _av_ntabs
    mov x0, #0
    cmp x9, x10
    b.hs 1f
    TAB x0, x9
    ldr x0, [x0, #TAB_NSVIEW]
1:  ret

// Doc *av_tabs_current_doc(void)
FUNC_BEGIN _av_tabs_current_doc
    LDRG x9, _av_tab_cur
    LDRG x10, _av_ntabs
    mov x0, #0
    cmp x9, x10
    b.hs 1f
    TAB x0, x9
    ldr x0, [x0, #TAB_DOC]
1:  ret

// ---- tab lifecycle ----

// char *strdup_arena(const char *s)
    .p2align 2
Lstrdup:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    bl _strlen
    add x20, x0, #1
    mov x0, x20
    bl _av_arena_alloc
    mov x1, x19
    mov x2, x20
    bl _memcpy
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// long av_tab_find(const char *path), -1 if no tab has this file
FUNC_BEGIN _av_tab_find
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, #0
1:  LDRG x9, _av_ntabs
    cmp x20, x9
    b.hs 3f
    TAB x9, x20
    ldr x9, [x9, #TAB_DOC]
    ldr x0, [x9, #DOC_PATH]
    cbz x0, 2f
    mov x1, x19
    bl _strcmp
    cbz w0, 4f
2:  add x20, x20, #1
    b 1b
3:  mov x20, #-1
4:  mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// long av_tab_open(const char *path or NULL): focuses an existing tab for the same file
FUNC_BEGIN _av_tab_open
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    cbz x19, 1f
    bl _av_tab_find
    tbnz x0, #63, 1f
    mov x19, x0
    bl _av_tab_activate
    mov x0, x19
    b 9f
1:  LDRG x9, _av_ntabs
    cmp x9, #MAX_TABS
    b.hs 8f
    mov x0, #DOC_SIZE
    bl _av_arena_alloc
    mov x20, x0
    cbz x19, 2f
    mov x1, x19
    bl _av_doc_open
    b 3f
2:  bl _av_doc_init
3:  mov x0, x20
    bl _av_editor_create
    mov x21, x0
    mov x2, #(NSViewWidthSizable | NSViewHeightSizable)
    MSG setAutoresizingMask
    mov x0, #TAB_SIZE
    bl _av_arena_alloc
    mov x22, x0
    str x21, [x22, #TAB_NSVIEW]
    str x20, [x22, #TAB_DOC]
    mov x9, #TAB_KIND_EDITOR
    str x9, [x22, #TAB_KIND]
    mov x0, x21
    bl _av_editor_state
    str x0, [x22, #TAB_VIEW]
    LDRG x9, _av_ntabs
    LADDR x10, _av_tabs
    str x22, [x10, x9, lsl #3]
    add x19, x9, #1
    STRG x19, _av_ntabs, x10
    sub x19, x19, #1
    mov x0, x19
    bl _av_tab_activate
    mov x0, x19
    b 9f
8:  bl _NSBeep
    mov x0, #-1
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_tab_activate(size_t i)
FUNC_BEGIN _av_tab_activate
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    LDRG x9, _av_ntabs
    cmp x19, x9
    b.hs 9f
    LDRG x20, _av_tab_cur
    cmp x20, x19
    b.eq 2f
    // detach the previous view, it stays alive with its tab
    cmp x20, x9
    b.hs 1f
    TAB x10, x20
    ldr x0, [x10, #TAB_NSVIEW]
    MSG removeFromSuperview
    STRG x20, _av_tab_last, x9
1:  STRG x19, _av_tab_cur, x9
    TAB x10, x19
    ldr x2, [x10, #TAB_NSVIEW]
    LDRG x0, _av_container
    MSG addSubview
    bl _av_tabs_layout
2:  bl _av_tabs_current_view
    mov x2, x0
    LDRG x0, _av_window
    cbz x0, 3f
    MSG makeFirstResponder
3:  bl _av_tabs_update_window
    bl _av_tabbar_redraw
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_tabs_update_window(void): title, proxy icon and edited dot of the active tab
FUNC_BEGIN _av_tabs_update_window
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    LDRG x19, _av_window
    cbz x19, 9f
    bl _av_tabs_current_doc
    mov x20, x0
    cbz x20, 9f
    ldr x2, [x20, #DOC_PATH]
    cbz x2, 1f
    CLS x0, NSString
    MSG stringWithUTF8String
    mov x2, x0
    mov x0, x19
    MSG setTitleWithFile
    b 2f
1:  mov x0, x19
    CFSTR x2, untitled
    MSG setTitle
    mov x0, x19
    CFSTR x2, empty
    MSG setRepresentedFilename
2:  ldr x9, [x20, #BUF_FLAGS]
    and x2, x9, #BUF_DIRTY
    mov x0, x19
    MSG setDocumentEdited
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// long alert(NSString *msg, NSString *info, NSString *b1, NSString *b2, NSString *b3), modal response
    .p2align 2
Lalert:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x20, x0
    mov x21, x1
    mov x22, x2
    mov x23, x3
    mov x24, x4
    CLS x0, NSAlert
    MSG new
    mov x19, x0
    mov x2, x20
    MSG setMessageText
    cbz x21, 1f
    mov x0, x19
    mov x2, x21
    MSG setInformativeText
1:  mov x0, x19
    mov x2, x22
    MSG addButton
    cbz x23, 2f
    mov x0, x19
    mov x2, x23
    MSG addButton
2:  cbz x24, 3f
    mov x0, x19
    mov x2, x24
    MSG addButton
3:  mov x0, x19
    MSG runModal
    mov x20, x0
    mov x0, x19
    MSG release
    mov x0, x20
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// const char *display_name(Doc *d): file name or "untitled"
    .p2align 2
Ldisplay_name:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    ldr x19, [x0, #DOC_PATH]
    LADDR x0, Ls_untitled
    cbz x19, 1f
    mov x0, x19
    mov w1, #'/'
    bl _strrchr
    cmp x0, #0
    csinc x0, x19, x0, eq
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// const char *save_panel(void): chosen path (arena copy) or NULL
    .p2align 2
Lsave_panel:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    CLS x0, NSSavePanel
    MSG savePanel
    mov x19, x0
    MSG runModal
    cmp x0, #NSModalResponseOK
    mov x0, #0
    b.ne 1f
    mov x0, x19
    MSG URL
    MSG path
    MSG UTF8String
    bl Lstrdup
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_tab_save(size_t i): untitled tabs ask for a path first; 0 on success
FUNC_BEGIN _av_tab_save
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    LDRG x9, _av_ntabs
    cmp x0, x9
    b.hs 8f
    TAB x19, x0
    ldr x20, [x19, #TAB_DOC]
    ldr x21, [x20, #DOC_PATH]
    cbnz x21, 1f
    bl Lsave_panel
    cbz x0, 8f
    mov x21, x0
    str x21, [x20, #DOC_PATH]
    mov x0, x20
    bl _av_hl_detect
1:  mov x0, x20
    mov x1, x21
    bl _av_buf_save
    cbnz x0, 7f
    bl _av_config_reload_if_changed
    ldr x0, [x19, #TAB_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    bl _av_tabs_update_window
    bl _av_tabbar_redraw
    mov x0, #0
    b 9f
7:  bl _NSBeep
8:  mov x0, #-1
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_tab_close(size_t i): asks about unsaved changes; 1 closed, 0 cancelled
// closing the last tab closes the window (and the app)
FUNC_BEGIN _av_tab_close
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    LDRG x9, _av_ntabs
    cmp x19, x9
    b.hs Lc_cancel
    TAB x20, x19
    ldr x21, [x20, #TAB_DOC]
    ldr x9, [x21, #BUF_FLAGS]
    tbz x9, #0, 2f
    mov x0, x21
    bl Ldisplay_name
    mov x2, x0
    CLS x0, NSString
    MSG stringWithUTF8String
    mov x1, x0
    CFSTR x0, askSave
    CFSTR x2, bSave
    CFSTR x3, bDontSave
    CFSTR x4, bCancel
    bl Lalert
    cmp x0, #ALERT_SECOND
    b.eq 2f
    cmp x0, #ALERT_FIRST
    b.ne Lc_cancel
    mov x0, x19
    bl _av_tab_save
    cbnz x0, Lc_cancel
2:  ldr x0, [x20, #TAB_NSVIEW]
    MSG removeFromSuperview
    ldr x0, [x20, #TAB_NSVIEW]
    MSG release
    mov x0, x21
    bl _av_doc_free
    // remove slot i
    LDRG x22, _av_ntabs
    LADDR x10, _av_tabs
    mov x11, x19
3:  add x12, x11, #1
    cmp x12, x22
    b.hs 4f
    ldr x13, [x10, x12, lsl #3]
    str x13, [x10, x11, lsl #3]
    mov x11, x12
    b 3b
4:  sub x22, x22, #1
    STRG x22, _av_ntabs, x9
    // fix indices that pointed past i
    LDRG x23, _av_tab_cur
    cmp x23, x19
    mov x9, #-1
    sub x10, x23, #1
    csel x23, x9, x23, eq
    csel x23, x10, x23, gt
    STRG x23, _av_tab_cur, x9
    LDRG x24, _av_tab_last
    cmp x24, x19
    mov x9, #-1
    sub x10, x24, #1
    csel x24, x9, x24, eq
    csel x24, x10, x24, gt
    STRG x24, _av_tab_last, x9
    cbnz x22, 5f
    LDRG x0, _av_window
    MSG close
    b Lc_done
5:  tbz x23, #63, 6f
    // closed the active tab: previous tab if known, else the neighbour
    mov x0, x24
    tbz x0, #63, 51f
    sub x9, x22, #1
    cmp x19, x9
    csel x0, x9, x19, hi
51: bl _av_tab_activate
6:  bl _av_tabbar_redraw
Lc_done:
    mov x0, #1
    b 9f
Lc_cancel:
    mov x0, #0
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// int av_tabs_confirm_quit(void): 1 when nothing is dirty or the user accepts losing changes
FUNC_BEGIN _av_tabs_confirm_quit
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, #0
1:  LDRG x9, _av_ntabs
    cmp x19, x9
    b.hs 3f
    TAB x9, x19
    ldr x9, [x9, #TAB_DOC]
    ldr x9, [x9, #BUF_FLAGS]
    tbnz x9, #0, 2f
    add x19, x19, #1
    b 1b
2:  CFSTR x0, unsaved
    CFSTR x1, quitInfo
    CFSTR x2, bQuit
    CFSTR x3, bCancel
    mov x4, #0
    bl Lalert
    cmp x0, #ALERT_FIRST
    cset w0, eq
    b 4f
3:  mov w0, #1
4:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---- actions ----

// open panel; an untouched untitled tab is replaced by the opened files
    .p2align 2
Lopen_panel:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    CLS x0, NSOpenPanel
    MSG openPanel
    mov x19, x0
    mov x2, #1
    MSG setAllowsMultiple
    mov x0, x19
    MSG runModal
    cmp x0, #NSModalResponseOK
    b.ne 9f
    mov x23, #-1
    bl _av_tabs_current_doc
    cbz x0, 1f
    ldr x9, [x0, #DOC_PATH]
    cbnz x9, 1f
    ldr x9, [x0, #BUF_FLAGS]
    tbnz x9, #0, 1f
    bl _av_buf_len
    cbnz x0, 1f
    LDRG x23, _av_tab_cur
1:  mov x0, x19
    MSG URLs
    mov x20, x0
    MSG count
    mov x21, x0
    mov x22, #0
2:  cmp x22, x21
    b.hs 3f
    mov x0, x20
    mov x2, x22
    MSG objectAtIndex
    MSG path
    MSG UTF8String
    bl Lstrdup
    bl _av_tab_open
    add x22, x22, #1
    b 2b
3:  tbnz x23, #63, 9f
    LDRG x9, _av_ntabs
    cmp x9, #1
    b.ls 9f
    mov x0, x23
    bl _av_tab_close
9:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// open config.yaml in a tab; a missing file starts from the documented template
    .p2align 2
Lopen_config:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    sub sp, sp, #1040
    // mkdir -p <dir>: its parent (~/.config) first
    mov x0, sp
    LADDR x1, _av_cfg_dir
    bl _strcpy
    mov x0, sp
    mov w1, #'/'
    bl _strrchr
    cbz x0, 1f
    strb wzr, [x0]
    mov x0, sp
    mov w1, #0x1ed
    bl _mkdir
1:  LADDR x0, _av_cfg_dir
    mov w1, #0x1ed
    bl _mkdir
    LADDR x0, _av_cfg_path
    mov w1, #0
    bl _access
    mov x20, x0
    LADDR x0, _av_cfg_path
    bl _av_tab_open
    tbnz x0, #63, 9f
    cbz x20, 9f
    TAB x19, x0
    ldr x21, [x19, #TAB_DOC]
    mov x0, x21
    bl _av_buf_len
    cbnz x0, 9f
    mov x0, x21
    mov x1, #0
    LADDR x2, Lcfg_template
    LADDR x3, Lcfg_template_end
    sub x3, x3, x2
    mov x4, #0
    bl _av_doc_insert
    ldr x0, [x19, #TAB_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    bl _av_tabs_update_window
    bl _av_tabbar_redraw
9:  add sp, sp, #1040
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_action(size_t id)
FUNC_BEGIN _av_action
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    cmp x0, #A_COUNT
    b.hs La_out
    adr x9, La_table
    add x9, x9, x0, lsl #2
    br x9
La_table:
    b La_out
    b La_new
    b La_close
    b La_next
    b La_prev
    b La_last
    b La_open
    b La_config
    b La_save
    b La_theme
    .rept 9
    b La_tab
    .endr
La_new:
    mov x0, #0
    bl _av_tab_open
    b La_out
La_close:
    LDRG x0, _av_tab_cur
    bl _av_tab_close
    b La_out
La_next:
    LDRG x0, _av_tab_cur
    LDRG x9, _av_ntabs
    cbz x9, La_out
    add x0, x0, #1
    cmp x0, x9
    csel x0, x0, xzr, lo
    bl _av_tab_activate
    b La_out
La_prev:
    LDRG x0, _av_tab_cur
    LDRG x9, _av_ntabs
    cbz x9, La_out
    sub x10, x9, #1
    subs x0, x0, #1
    csel x0, x10, x0, lo
    bl _av_tab_activate
    b La_out
La_last:
    LDRG x0, _av_tab_last
    tbnz x0, #63, La_out
    bl _av_tab_activate
    b La_out
La_open:
    bl Lopen_panel
    b La_out
La_config:
    bl Lopen_config
    b La_out
La_save:
    LDRG x0, _av_tab_cur
    bl _av_tab_save
    b La_out
La_theme:
    LDRG x0, _av_theme_index
    add x0, x0, #1
    cmp x0, #THEME_COUNT
    csel x0, x0, xzr, lo
    bl _av_theme_apply
    b La_out
La_tab:
    sub x0, x19, #A_TAB_1
    bl _av_tab_activate
La_out:
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_keymap_handle(NSEvent *e): prefix key, the binding after it, and command+1..9
FUNC_BEGIN _av_keymap_handle
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    MSG modifierFlags
    and x20, x0, #MOD_ALL
    mov x0, x19
    MSG charsIgnoring
    MSG UTF8String
    cbz x0, 8f
    ldrb w9, [x0]
    cbz w9, 8f
    bl _av_utf8_decode
    mov x21, x0
    mov x0, x19
    MSG keyCode
    and w22, w0, #0xffff
    LDRG x9, _av_prefix_pending
    cbz x9, 2f
    STRG xzr, _av_prefix_pending, x9
    bl _av_tabbar_redraw
    cmp w22, #KEY_ESC_CODE
    b.eq 7f
    mov x0, x20
    mov x1, x21
    bl _av_keymap_lookup
    cbz x0, 1f
    bl _av_action
    b 7f
1:  bl _NSBeep
    b 7f
2:  and x9, x20, #MOD_CHORD
    LDRG x10, _av_prefix_mods
    and x10, x10, #MOD_CHORD
    cmp x9, x10
    b.ne 3f
    LDRG x10, _av_prefix_cp
    cmp x21, x10
    b.ne 3f
    mov x9, #1
    STRG x9, _av_prefix_pending, x10
    bl _av_tabbar_redraw
    b 7f
3:  and x9, x20, #MOD_CHORD
    cmp x9, #MOD_CMD
    b.ne 8f
    sub x0, x21, #'1'
    cmp x0, #8
    b.hi 8f
    bl _av_tab_activate
7:  mov w0, #1
    b 9f
8:  mov w0, #0
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---- tab bar view ----

// double tab_width(double bar_width), room kept for "+" and the prefix indicator
    .p2align 2
Ltab_width:
    LDRD d1, _av_adv
    fmov d2, #11.0
    fmul d2, d2, d1
    fsub d0, d0, d2
    LDRG x9, _av_ntabs
    mov x10, #1
    cmp x9, #1
    csel x9, x10, x9, lo
    ucvtf d1, x9
    fdiv d0, d0, d1
    mov x9, #220
    ucvtf d1, x9
    fmin d0, d0, d1
    mov x9, #100
    ucvtf d1, x9
    fmax d0, d0, d1
    ret

// (ptr, len) tab_title(size_t i, char *buf, size_t max_bytes): name, shortened with an ellipsis
    .p2align 2
Ltab_title:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x20, x1
    mov x21, x2
    TAB x9, x0
    ldr x0, [x9, #TAB_DOC]
    bl Ldisplay_name
    mov x19, x0
    bl _strlen
    mov x22, x0
    cmp x22, x21
    b.ls 3f
    // keep max-1 bytes on a UTF-8 boundary, then "…"
    sub x22, x21, #1
1:  cbz x22, 2f
    ldrb w9, [x19, x22]
    and w9, w9, #0xc0
    cmp w9, #0x80
    b.ne 2f
    sub x22, x22, #1
    b 1b
2:  mov x0, x20
    mov x1, x19
    mov x2, x22
    bl _memcpy
    add x0, x20, x22
    LADDR x1, Ls_ellipsis
    mov x2, #3
    bl _memcpy
    mov x0, x20
    add x1, x22, #3
    b 4f
3:  mov x0, x19
    mov x1, x22
4:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// draw text of NUL-terminated s at (d0, d1) with theme slot attrs in x2
    .p2align 2
Ldraw_cstr:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    mov x19, x0
    mov x20, x2
    fmov d8, d0
    fmov d9, d1
    bl _strlen
    mov x2, x0
    mov x1, x19
    LDRG x0, _av_tb_ctx
    mov x3, x20
    fmov d0, d8
    fmov d1, d9
    bl _av_draw_text
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .zerofill __DATA,__bss,_av_tb_ctx,8,3

// fill theme slot (offset in x0) over rect d0..d3
.macro TB_FILL slot
    LDRG x0, _av_tb_ctx
    LADDR x1, _av_theme
    add x1, x1, #\slot
    bl _av_fill
.endm

// drawRect: of the tab bar
// x19 self, x20 index, x21 count, x22 current; d8 W, d9 H, d10 tab width, d11 advance,
// d12 text baseline, d13 tab x
    .p2align 2
Ltb_draw:
    stp x29, x30, [sp, #-TB_FRAME]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    stp d10, d11, [sp, #64]
    stp d12, d13, [sp, #80]
    mov x19, x0
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    STRG x0, _av_tb_ctx, x9
    LGOT x1, _CGAffineTransformIdentity
    bl _CGContextSetTextMatrix
    mov x0, x19
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d9
    TB_FILL T_TABBAR
    fmov d0, d8
    bl Ltab_width
    fmov d10, d0
    LDRD d11, _av_adv
    LDRD d0, _av_line_h
    fsub d0, d9, d0
    fmov d1, #0.5
    fmul d0, d0, d1
    LDRD d1, _av_base_off
    fadd d12, d0, d1
    LDRG x21, _av_ntabs
    LDRG x22, _av_tab_cur
    mov x20, #0
1:  cmp x20, x21
    b.hs 5f
    ucvtf d13, x20
    fmul d13, d13, d10
    cmp x20, x22
    b.ne 2f
    fmov d0, d13
    movi d1, #0
    fmov d2, d10
    fmov d3, d9
    TB_FILL T_TAB_ACTIVE
    fmov d0, d13
    fmov d1, #2.0
    fsub d1, d9, d1
    fmov d2, d10
    fmov d3, #2.0
    TB_FILL T_ACCENT
    b 3f
    // thin separator between inactive tabs
2:  fadd d0, d13, d10
    fmov d1, #1.0
    fsub d0, d0, d1
    fmov d1, #0.25
    fmul d1, d9, d1
    fmov d2, #1.0
    fmov d3, #0.5
    fmul d3, d9, d3
    TB_FILL T_INDENT
    // title, at most (width - room for the marker) / advance bytes
3:  fmov d0, #4.0
    fmul d0, d0, d11
    fsub d0, d10, d0
    fdiv d0, d0, d11
    fcvtzu x2, d0
    cmp x2, #2
    mov x9, #2
    csel x2, x9, x2, lo
    mov x9, #250
    cmp x2, x9
    csel x2, x9, x2, hi
    mov x0, x20
    add x1, sp, #TB_TITLE
    bl Ltab_title
    mov x2, x1
    mov x1, x0
    LDRG x0, _av_tb_ctx
    ATTRS x3, T_TAB_TEXT
    cmp x20, x22
    b.ne 4f
    ATTRS x3, T_TAB_TEXT_ON
4:  fmov d0, d11
    fadd d0, d13, d0
    fmov d1, d12
    bl _av_draw_text
    // close marker, a dot while there are unsaved changes
    TAB x9, x20
    ldr x9, [x9, #TAB_DOC]
    ldr x9, [x9, #BUF_FLAGS]
    LADDR x0, Ls_close
    ATTRS x2, T_TAB_TEXT
    tbz x9, #0, 41f
    LADDR x0, Ls_dirty
    ATTRS x2, T_ACCENT
41: fadd d0, d13, d10
    fmov d1, #2.0
    fmul d1, d1, d11
    fsub d0, d0, d1
    fmov d1, d12
    bl Ldraw_cstr
    add x20, x20, #1
    b 1b
    // "+" after the last tab
5:  ucvtf d0, x21
    fmul d0, d0, d10
    fadd d0, d0, d11
    fmov d1, d12
    LADDR x0, Ls_plus
    ATTRS x2, T_TAB_TEXT
    bl Ldraw_cstr
    // waiting for the key after the prefix
    LDRG x9, _av_prefix_pending
    cbz x9, 9f
    LDRG x0, _av_cfg_prefix
    bl _strlen
    add x9, x0, #2
    ucvtf d0, x9
    fmul d2, d0, d11
    fsub d0, d8, d2
    fmov d13, d0
    fmov d1, #4.0
    fmov d3, #8.0
    fsub d3, d9, d3
    TB_FILL T_TAB_ACTIVE
    fadd d0, d13, d11
    fmov d1, d12
    LDRG x0, _av_cfg_prefix
    ATTRS x2, T_ACCENT
    bl Ldraw_cstr
9:  ldp d12, d13, [sp, #80]
    ldp d10, d11, [sp, #64]
    ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #TB_FRAME
    ret

// mouseDown: on the tab bar: select, close (marker area) or new tab ("+")
    .p2align 2
Ltb_mouse:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    stp d10, d11, [sp, #48]
    mov x19, x0
    mov x0, x2
    MSG locationInWindow
    mov x0, x19
    mov x2, #0
    MSG convertPoint
    fmov d8, d0
    mov x0, x19
    MSG bounds
    fmov d0, d2
    bl Ltab_width
    fmov d9, d0
    LDRD d11, _av_adv
    fdiv d0, d8, d9
    fcvtzu x20, d0
    LDRG x9, _av_ntabs
    cmp x20, x9
    b.hs 2f
    // within ~3 cells of the right edge of a tab: close it
    add x10, x20, #1
    ucvtf d0, x10
    fmul d0, d0, d9
    fmov d1, #3.0
    fmul d1, d1, d11
    fsub d0, d0, d1
    fcmp d8, d0
    mov x0, x20
    b.ge 1f
    bl _av_tab_activate
    b 9f
1:  bl _av_tab_close
    b 9f
2:  ucvtf d0, x9
    fmul d0, d0, d9
    fmov d1, #4.0
    fmul d1, d1, d11
    fadd d1, d0, d1
    fcmp d8, d1
    b.ge 9f
    mov x0, #0
    bl _av_tab_open
9:  ldp d10, d11, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
