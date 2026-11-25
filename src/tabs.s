// tabs: model (one pane tree per tab), window content (tab bar + panes), actions, prefix keys,
// open/save panels

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"
.include "buffer.inc"
.include "doc.inc"
.include "theme.inc"
.include "keymap.inc"
.include "pane.inc"

.set MAX_TABS, 64
.set TAB_ROOT,  0
.set TAB_FOCUS, 8              // leaf with the keyboard focus
.set TAB_ZOOM,  16             // the focused leaf fills the tab
.set TAB_SIZE,  32

.set NSModalResponseOK, 1
.set ALERT_FIRST,  1000
.set ALERT_SECOND, 1001
.set NSViewWidthSizable,  2
.set NSViewHeightSizable, 16
.set KEY_ESC_CODE, 53
.set DIVIDER_SLOP, 3           // points around a divider that still grab it
.set NSWindowBelow, -1

// tab bar drawRect locals
.set TB_TITLE, 176
.set TB_FRAME, 448

    CLASSREF NSView
    CLASSREF NSString
    CLASSREF NSOpenPanel
    CLASSREF NSSavePanel
    CLASSREF NSAlert
    CLASSREF NSGraphicsContext
    CLASSREF NSCursor

    SELDEF alloc, "alloc"
    SELDEF new, "new"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF setAutoresizingMask, "setAutoresizingMask:"
    SELDEF addSubview, "addSubview:"
    SELDEF addSubviewBelow, "addSubview:positioned:relativeTo:"
    SELDEF removeFromSuperview, "removeFromSuperview"
    SELDEF superview, "superview"
    SELDEF setFrame, "setFrame:"
    SELDEF bounds, "bounds"
    SELDEF contentView, "contentView"
    SELDEF setContentView, "setContentView:"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF makeFirstResponder, "makeFirstResponder:"
    SELDEF invalidateCursorRects, "invalidateCursorRectsForView:"
    SELDEF addCursorRect, "addCursorRect:cursor:"
    SELDEF resizeLeftRight, "resizeLeftRightCursor"
    SELDEF resizeUpDown, "resizeUpDownCursor"
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
    SELDEF mouseDragged, "mouseDragged:"
    SELDEF mouseUp, "mouseUp:"
    SELDEF isOpaque, "isOpaque"
    SELDEF isFlipped, "isFlipped"
    SELDEF hitTest, "hitTest:"
    SELDEF resizeSubviews, "resizeSubviewsWithOldSize:"
    SELDEF resetCursorRects, "resetCursorRects"

    CFSTRDEF untitled, "untitled"
    CFSTRDEF empty, ""
    CFSTRDEF askSave, "Save changes before closing?"
    CFSTRDEF bSave, "Save"
    CFSTRDEF bDontSave, "Don't Save"
    CFSTRDEF bCancel, "Cancel"
    CFSTRDEF unsaved, "You have unsaved changes."
    CFSTRDEF quitInfo, "Unsaved changes will be lost if you quit."
    CFSTRDEF bQuit, "Quit Anyway"
    CFSTRDEF askKill, "Terminate the running process?"
    CFSTRDEF bTerminate, "Terminate"
    CFSTRDEF running, "Processes are still running in terminal tabs."
    CFSTRDEF runningInfo, "They will be terminated if you quit."

    .section __TEXT,__cstring,cstring_literals
Ltb_name:     .asciz "AvTabBar"
Lpn_name:     .asciz "AvPanes"
Lt_rect:      .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_size:      .asciz "v@:{CGSize=dd}"
Lt_hit:       .asciz "@@:{CGPoint=dd}"
Lt_obj:       .asciz "v@:@"
Lt_void:      .asciz "v@:"
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

    // selector slot, IMP, type encoding
    .section __DATA,__const
    .p2align 3
Ltb_methods:
    .quad Lsr_drawRect, Ltb_draw, Lt_rect
    .quad Lsr_mouseDown, Ltb_mouse, Lt_obj
    .quad Lsr_isOpaque, Lyes, Lt_bool
Ltb_methods_end:
Lpn_methods:
    .quad Lsr_isFlipped, Lyes, Lt_bool
    .quad Lsr_drawRect, Lpn_draw, Lt_rect
    .quad Lsr_resizeSubviews, Lpn_resize, Lt_size
    .quad Lsr_hitTest, Lpn_hit, Lt_hit
    .quad Lsr_mouseDown, Lpn_mdown, Lt_obj
    .quad Lsr_mouseDragged, Lpn_mdrag, Lt_obj
    .quad Lsr_mouseUp, Lpn_mup, Lt_obj
    .quad Lsr_resetCursorRects, Lpn_cursors, Lt_void
Lpn_methods_end:

    .zerofill __DATA,__bss,_av_tabs,(MAX_TABS * 8),3
    .zerofill __DATA,__bss,_av_ntabs,8,3
    .zerofill __DATA,__bss,_av_container,8,3
    .zerofill __DATA,__bss,_av_tabbar,8,3
    .zerofill __DATA,__bss,_av_prefix_pending,8,3
    .zerofill __DATA,__bss,_av_focus_view,8,3
    .zerofill __DATA,__bss,_av_drag_split,8,3
    .globl _av_tabs
    .globl _av_ntabs
    .globl _av_container
    .globl _av_focus_view
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

// Class make_class(const char *name, const void *methods, const void *end): NSView subclass
    .p2align 2
Lmake_class:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x9, x0
    mov x20, x1
    mov x21, x2
    CLS x0, NSView
    mov x1, x9
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
1:  cmp x20, x21
    b.hs 2f
    ldp x9, x2, [x20]
    ldr x3, [x20, #16]
    ldr x1, [x9]
    mov x0, x19
    bl _class_addMethod
    add x20, x20, #24
    b 1b
2:  mov x0, x19
    bl _objc_registerClassPair
    mov x0, x19
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_tabs_init(NSWindow *w): flipped container with the tab bar on top and the panes below
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
    LADDR x0, Lpn_name
    LADDR x1, Lpn_methods
    LADDR x2, Lpn_methods_end
    bl Lmake_class
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
    LADDR x0, Ltb_name
    LADDR x1, Ltb_methods
    LADDR x2, Ltb_methods_end
    bl Lmake_class
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x22, x0
    STRG x22, _av_tabbar, x9
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

// Tab *cur_tab(void), NULL before the first tab
    .p2align 2
Lcur_tab:
    LDRG x9, _av_tab_cur
    LDRG x10, _av_ntabs
    mov x0, #0
    cmp x9, x10
    b.hs 1f
    TAB x0, x9
1:  ret

// Pane *vis_first(Tab *t) / vis_next(Tab *t, Pane *leaf): leaves on screen, only the focused one
// while zoomed
    .p2align 2
Lvis_first:
    ldr x9, [x0, #TAB_ZOOM]
    cbz x9, 1f
    ldr x0, [x0, #TAB_FOCUS]
    ret
1:  ldr x0, [x0, #TAB_ROOT]
    b _av_pane_first

    .p2align 2
Lvis_next:
    ldr x9, [x0, #TAB_ZOOM]
    mov x0, x1
    cbnz x9, 1f
    b _av_pane_after
1:  mov x0, #0
    ret

// void mount(Tab *t): visible panes of t into the container
    .p2align 2
Lmount:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    bl Lvis_first
    mov x20, x0
1:  cbz x20, 9f
    // re-adding a subview would drop the first responder
    ldr x0, [x20, #P_NSVIEW]
    MSG superview
    LDRG x9, _av_container
    cmp x0, x9
    b.eq 2f
    // panes stay under the palette and the find bar
    mov x0, x9
    ldr x2, [x20, #P_NSVIEW]
    mov x3, #NSWindowBelow
    mov x4, #0
    MSG addSubviewBelow
2:  mov x0, x19
    mov x1, x20
    bl Lvis_next
    mov x20, x0
    b 1b
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void unmount(Tab *t, Pane *keep): panes of t out of the container except keep (may be NULL)
    .p2align 2
Lunmount:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x21, x1
    ldr x0, [x19, #TAB_ROOT]
    cbz x0, 9f
    bl _av_pane_first
    mov x20, x0
1:  cbz x20, 9f
    cmp x20, x21
    b.eq 2f
    ldr x0, [x20, #P_NSVIEW]
    MSG removeFromSuperview
2:  mov x0, x20
    bl _av_pane_after
    mov x20, x0
    b 1b
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void unzoom(Tab *t): back to all panes
    .p2align 2
Lunzoom:
    ldr x9, [x0, #TAB_ZOOM]
    cbz x9, 1f
    str xzr, [x0, #TAB_ZOOM]
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl Lcur_tab
    cmp x0, x19
    b.ne 2f
    mov x0, x19
    bl Lmount
    bl _av_tabs_layout
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
1:  ret

// focus follows the active tab's focused pane: first responder, window title, tab bar
    .p2align 2
Lsync_focus:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lcur_tab
    cbz x0, 1f
    ldr x0, [x0, #TAB_FOCUS]
    cbz x0, 1f
    ldr x0, [x0, #P_NSVIEW]
1:  STRG x0, _av_focus_view, x9
    mov x2, x0
    LDRG x0, _av_window
    cbz x0, 2f
    cbz x2, 2f
    MSG makeFirstResponder
2:  bl _av_tabs_update_window
    bl _av_tabbar_redraw
    ldp x29, x30, [sp], #16
    ret

// void av_tabs_refocus(void): keyboard back to the focused pane (after the palette or find bar)
FUNC_BEGIN _av_tabs_refocus
    b Lsync_focus

// const char *av_tab_name(size_t i): name of the focused pane of tab i
FUNC_BEGIN _av_tab_name
    TAB x0, x0
    b Ltab_name

// void set_focus(Tab *t, Pane *leaf): both panes redraw their cursor
    .p2align 2
Lset_focus:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    ldr x0, [x19, #TAB_FOCUS]
    str x20, [x19, #TAB_FOCUS]
    cbz x0, 1f
    cmp x0, x20
    b.eq 1f
    ldr x0, [x0, #P_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
1:  bl Lcur_tab
    cmp x0, x19
    b.ne 9f
    ldr x0, [x20, #P_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    bl Lsync_focus
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void set_focus_any(Tab *t, Pane *leaf): also leaves a zoom that hides leaf
    .p2align 2
Lset_focus_any:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    ldr x9, [x19, #TAB_FOCUS]
    cmp x9, x20
    b.eq 1f
    bl Lunzoom
1:  mov x0, x19
    mov x1, x20
    bl Lset_focus
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_tabs_focus_view(NSView *v): a click moved the focus to the pane showing v
FUNC_BEGIN _av_tabs_focus_view
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x21, x0
    bl Lcur_tab
    cbz x0, 9f
    mov x19, x0
    ldr x0, [x19, #TAB_ROOT]
    bl _av_pane_first
    mov x20, x0
1:  cbz x20, 9f
    ldr x9, [x20, #P_NSVIEW]
    cmp x9, x21
    b.eq 2f
    mov x0, x20
    bl _av_pane_after
    mov x20, x0
    b 1b
2:  ldr x9, [x19, #TAB_FOCUS]
    cmp x9, x20
    b.eq 9f
    mov x0, x19
    mov x1, x20
    bl Lset_focus
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_tabs_layout(void): tab bar on top, the active tab's visible panes below
FUNC_BEGIN _av_tabs_layout
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    str d10, [sp, #48]
    LDRG x0, _av_container
    cbz x0, 9f
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    bl Lbar_h
    fmov d10, d0
    LDRG x0, _av_tabbar
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d10
    MSG setFrame
    bl Lcur_tab
    cbz x0, 8f
    mov x19, x0
    ldr x0, [x19, #TAB_ROOT]
    ldr x9, [x19, #TAB_ZOOM]
    cbz x9, 1f
    ldr x0, [x19, #TAB_FOCUS]
1:  movi d0, #0
    fmov d1, d10
    fmov d2, d8
    fsub d3, d9, d10
    bl _av_pane_layout
    bl _av_findbar_hide
    mov x0, x19
    bl Lvis_first
    mov x20, x0
2:  cbz x20, 8f
    // the find bar takes the bottom of its pane
    ldr x0, [x20, #P_NSVIEW]
    ldp d0, d1, [x20, #P_X]
    ldp d2, d3, [x20, #P_W]
    bl _av_findbar_fit
    ldr x0, [x20, #P_NSVIEW]
    MSG setFrame
    ldr x0, [x20, #P_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    mov x0, x19
    mov x1, x20
    bl Lvis_next
    mov x20, x0
    b 2b
8:  LDRG x0, _av_container
    mov x2, #1
    MSG setNeedsDisplay
    LDRG x0, _av_window
    cbz x0, 81f
    LDRG x2, _av_container
    MSG invalidateCursorRects
81: bl _av_palette_layout
    bl _av_tabbar_redraw
9:  ldr d10, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
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

// NSView *av_tabs_current_view(void): the focused pane
FUNC_BEGIN _av_tabs_current_view
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lcur_tab
    cbz x0, 1f
    ldr x0, [x0, #TAB_FOCUS]
    ldr x0, [x0, #P_NSVIEW]
1:  ldp x29, x30, [sp], #16
    ret

// Doc *av_tabs_current_doc(void): doc of the focused pane, NULL for terminals
FUNC_BEGIN _av_tabs_current_doc
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lcur_tab
    cbz x0, 1f
    ldr x0, [x0, #TAB_FOCUS]
    ldr x0, [x0, #P_DOC]
1:  ldp x29, x30, [sp], #16
    ret

// ---- pane container view (flipped) ----

// resizeSubviewsWithOldSize: lays everything out again
    .p2align 2
Lpn_resize:
    b _av_tabs_layout

// drawRect: only the gaps between panes show, in the divider color
    .p2align 2
Lpn_draw:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp d0, d1, [sp, #16]
    stp d2, d3, [sp, #32]
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    LADDR x1, _av_theme
    add x1, x1, #T_INDENT
    ldp d0, d1, [sp, #16]
    ldp d2, d3, [sp, #32]
    bl _av_fill
    ldp x29, x30, [sp], #48
    ret

// Pane *divider_at(double x, double y): split of the active tab whose divider is near the point
    .p2align 2
Ldivider_at:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp d8, d9, [sp, #16]
    fmov d8, d0
    fmov d9, d1
    bl Lcur_tab
    cbz x0, 9f
    ldr x9, [x0, #TAB_ZOOM]
    ldr x0, [x0, #TAB_ROOT]
    cbnz x9, 8f
    fmov d0, d8
    fmov d1, d9
    mov x9, #DIVIDER_SLOP
    ucvtf d2, x9
    bl _av_pane_divider_at
    b 9f
8:  mov x0, #0
9:  ldp d8, d9, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// (x, y) ev_point(NSView *self, NSEvent *e): event location in self
    .p2align 2
Lev_point:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x0, x1
    MSG locationInWindow
    mov x0, x19
    mov x2, #0
    MSG convertPoint
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// hitTest: the container takes clicks near a divider, everything else goes to the panes
    .p2align 2
Lpn_hit:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    mov x19, x0
    fmov d8, d0
    fmov d9, d1
    MSG superview
    mov x2, x0
    mov x0, x19
    fmov d0, d8
    fmov d1, d9
    MSG convertPoint
    bl Ldivider_at
    cbz x0, 1f
    mov x0, x19
    b 9f
    // [super hitTest:] through objc_super {receiver, super_class}
1:  str x19, [sp, #40]
    CLS x9, NSView
    str x9, [sp, #48]
    add x0, sp, #40
    LSEL x1, hitTest
    fmov d0, d8
    fmov d1, d9
    bl _objc_msgSendSuper
9:  ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

    .p2align 2
Lpn_mdown:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x2
    bl Lev_point
    bl Ldivider_at
    STRG x0, _av_drag_split, x9
    ldp x29, x30, [sp], #16
    ret

    .p2align 2
Lpn_mdrag:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    LDRG x19, _av_drag_split
    cbz x19, 9f
    mov x1, x2
    bl Lev_point
    mov x0, x19
    bl _av_pane_drag
    bl _av_tabs_layout
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .p2align 2
Lpn_mup:
    STRG xzr, _av_drag_split, x9
    ret

// resetCursorRects: resize cursors over the dividers
    .p2align 2
Lpn_cursors:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lcur_tab
    cbz x0, 9f
    ldr x9, [x0, #TAB_ZOOM]
    cbnz x9, 9f
    ldr x0, [x0, #TAB_ROOT]
    bl Lcursor_walk
9:  ldp x29, x30, [sp], #16
    ret

// void cursor_walk(Pane *n): cursor rect for the divider of split n, then its children
    .p2align 2
Lcursor_walk:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x9, [x19, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 9f
    ldr x10, [x19, #P_A]
    mov x11, #DIVIDER_SLOP
    ucvtf d4, x11
    fadd d5, d4, d4
    fmov d6, #1.0
    fadd d5, d5, d6
    b.ne 1f
    ldr d0, [x10, #P_X]
    ldr d1, [x10, #P_W]
    fadd d0, d0, d1
    fsub d0, d0, d4
    ldr d1, [x19, #P_Y]
    fmov d2, d5
    ldr d3, [x19, #P_H]
    stp d0, d1, [sp, #32]
    stp d2, d3, [sp, #48]
    CLS x0, NSCursor
    MSG resizeLeftRight
    b 2f
1:  ldr d0, [x19, #P_X]
    ldr d1, [x10, #P_Y]
    ldr d2, [x10, #P_H]
    fadd d1, d1, d2
    fsub d1, d1, d4
    ldr d2, [x19, #P_W]
    fmov d3, d5
    stp d0, d1, [sp, #32]
    stp d2, d3, [sp, #48]
    CLS x0, NSCursor
    MSG resizeUpDown
2:  mov x2, x0
    LDRG x0, _av_container
    ldp d0, d1, [sp, #32]
    ldp d2, d3, [sp, #48]
    MSG addCursorRect
    ldr x0, [x19, #P_A]
    bl Lcursor_walk
    ldr x0, [x19, #P_B]
    bl Lcursor_walk
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

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

// (index, leaf) find(const char *path): tab and pane showing this file, index -1 if none
    .p2align 2
Lfind:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, #0
1:  LDRG x9, _av_ntabs
    cmp x20, x9
    b.hs 4f
    TAB x9, x20
    ldr x0, [x9, #TAB_ROOT]
    bl _av_pane_first
    mov x21, x0
2:  cbz x21, 3f
    ldr x9, [x21, #P_DOC]
    cbz x9, 21f
    ldr x0, [x9, #DOC_PATH]
    cbz x0, 21f
    mov x1, x19
    bl _strcmp
    cbz w0, 5f
21: mov x0, x21
    bl _av_pane_after
    mov x21, x0
    b 2b
3:  add x20, x20, #1
    b 1b
4:  mov x20, #-1
    mov x21, #0
5:  mov x0, x20
    mov x1, x21
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// long av_tab_find(const char *path), -1 if no tab shows this file
FUNC_BEGIN _av_tab_find
    b Lfind

// long new_tab(Pane *leaf): appends a tab holding just leaf, returns its index
    .p2align 2
Lnew_tab:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x0, #TAB_SIZE
    bl _av_arena_alloc
    mov x20, x0
    stp x19, x19, [x20, #TAB_ROOT]
    LDRG x9, _av_ntabs
    LADDR x10, _av_tabs
    str x20, [x10, x9, lsl #3]
    add x10, x9, #1
    STRG x10, _av_ntabs, x11
    mov x0, x9
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// long av_tab_open(const char *path or NULL): focuses an existing pane for the same file
FUNC_BEGIN _av_tab_open
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    cbz x19, 1f
    bl Lfind
    tbnz x0, #63, 1f
    mov x19, x0
    TAB x0, x19
    bl Lset_focus_any
    mov x0, x19
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
    bl _av_editor_state
    mov x2, x0
    mov x0, #PK_EDITOR
    mov x1, x21
    mov x3, x20
    bl _av_pane_leaf
    bl Lnew_tab
    mov x19, x0
    bl _av_tab_activate
    mov x0, x19
    b 9f
8:  bl _NSBeep
    mov x0, #-1
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// long av_tab_open_term(void): new tab running the login shell, -1 on failure
FUNC_BEGIN _av_tab_open_term
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    LDRG x9, _av_ntabs
    cmp x9, #MAX_TABS
    b.hs 8f
    bl _av_term_create
    cbz x0, 8f
    mov x21, x0
    bl _av_term_state
    mov x20, x0
    mov x2, x0
    mov x0, #PK_TERMINAL
    mov x1, x21
    mov x3, #0
    bl _av_pane_leaf
    bl Lnew_tab
    mov x19, x0
    // activating lays the view out, so the shell starts with the right size
    bl _av_tab_activate
    mov x0, x20
    mov x1, #0
    bl _av_term_start
    cbnz x0, 7f
    mov x0, x19
    b 9f
7:  mov x0, x19
    bl _av_tab_close
8:  bl _NSBeep
    mov x0, #-1
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_tabs_term_exited(Term *t): the shell is gone, close its pane if still open
FUNC_BEGIN _av_tabs_term_exited
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, #0
1:  LDRG x9, _av_ntabs
    cmp x20, x9
    b.hs 9f
    TAB x9, x20
    ldr x0, [x9, #TAB_ROOT]
    bl _av_pane_first
    mov x21, x0
2:  cbz x21, 3f
    ldr x9, [x21, #P_KIND]
    cmp x9, #PK_TERMINAL
    b.ne 21f
    ldr x9, [x21, #P_VIEW]
    cmp x9, x19
    b.ne 21f
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl Lclose_leaf
    b 9f
21: mov x0, x21
    bl _av_pane_after
    mov x21, x0
    b 2b
3:  add x20, x20, #1
    b 1b
9:  ldr x21, [sp, #32]
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
    // detach the previous tab's panes, they stay alive with it
    cmp x20, x9
    b.hs 1f
    TAB x0, x20
    mov x1, #0
    bl Lunmount
    STRG x20, _av_tab_last, x9
1:  STRG x19, _av_tab_cur, x9
    TAB x0, x19
    bl Lmount
    bl _av_tabs_layout
2:  bl Lsync_focus
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_tabs_update_window(void): title, proxy icon and edited dot of the focused pane
FUNC_BEGIN _av_tabs_update_window
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    LDRG x19, _av_window
    cbz x19, 9f
    bl Lcur_tab
    cbz x0, 9f
    ldr x21, [x0, #TAB_FOCUS]
    cbz x21, 9f
    ldr x20, [x21, #P_DOC]
    cbz x20, 3f
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
    b 9f
    // terminal: the program's title, no proxy icon
3:  ldr x0, [x21, #P_VIEW]
    bl _av_term_title
    mov x2, x0
    CLS x0, NSString
    MSG stringWithUTF8String
    mov x2, x0
    mov x0, x19
    MSG setTitle
    mov x0, x19
    CFSTR x2, empty
    MSG setRepresentedFilename
    mov x0, x19
    mov x2, #0
    MSG setDocumentEdited
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
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

// const char *leaf_name(Pane *leaf): file name, or the terminal title
    .p2align 2
Lleaf_name:
    ldr x9, [x0, #P_DOC]
    cbz x9, 1f
    mov x0, x9
    b Ldisplay_name
1:  ldr x0, [x0, #P_VIEW]
    b _av_term_title

// const char *tab_name(Tab *t): name of the focused pane
    .p2align 2
Ltab_name:
    ldr x0, [x0, #TAB_FOCUS]
    b Lleaf_name

// int tab_dirty(Tab *t): 1 when a pane shows a doc with unsaved changes
    .p2align 2
Ltab_dirty:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    ldr x0, [x0, #TAB_ROOT]
    bl _av_pane_first
    mov x19, x0
1:  cbz x19, 8f
    ldr x9, [x19, #P_DOC]
    cbz x9, 2f
    ldr x9, [x9, #BUF_FLAGS]
    tbnz x9, #0, 7f
2:  mov x0, x19
    bl _av_pane_after
    mov x19, x0
    b 1b
7:  mov x0, #1
    b 9f
8:  mov x0, #0
9:  ldr x19, [sp, #16]
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

// int save_leaf(Pane *leaf): untitled docs ask for a path first; 0 on success
    .p2align 2
Lsave_leaf:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    ldr x20, [x19, #P_DOC]
    cbz x20, 7f
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
    ldr x0, [x19, #P_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    bl _av_tabs_update_window
    bl _av_tabbar_redraw
    mov x0, #0
    b 9f
7:  bl _NSBeep
8:  mov x0, #-1
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_tab_save(size_t i): saves the focused pane of tab i; 0 on success
FUNC_BEGIN _av_tab_save
    LDRG x9, _av_ntabs
    cmp x0, x9
    b.hs 1f
    TAB x9, x0
    ldr x0, [x9, #TAB_FOCUS]
    b Lsave_leaf
1:  mov x0, #-1
    ret

// int ask_leaf(Pane *leaf, int whole_tab): confirms closing, saving if asked; 1 to go ahead
// a pane whose doc stays open in another pane goes without asking, unless the whole tab closes
    .p2align 2
Lask_leaf:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x20, [x19, #P_DOC]
    cbz x20, 5f
    ldr x9, [x20, #BUF_FLAGS]
    tbz x9, #0, 8f
    cbnz x1, 1f
    ldr x9, [x20, #DOC_VIEWS]
    ldr x9, [x9, #V_NEXT]
    cbnz x9, 8f
1:  mov x0, x20
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
    b.eq 8f
    cmp x0, #ALERT_FIRST
    b.ne 7f
    mov x0, x19
    bl Lsave_leaf
    cbnz x0, 7f
    b 8f
    // terminal: ask only when a job other than the shell is running
5:  ldr x0, [x19, #P_VIEW]
    bl _av_term_busy
    cbz w0, 8f
    CFSTR x0, askKill
    mov x1, #0
    CFSTR x2, bTerminate
    CFSTR x3, bCancel
    mov x4, #0
    bl Lalert
    cmp x0, #ALERT_FIRST
    b.ne 7f
8:  mov w0, #1
    b 9f
7:  mov w0, #0
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int seen_before(Tab *t, Pane *leaf): an earlier pane of t shows the same doc
    .p2align 2
Lseen_before:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    ldr x19, [x1, #P_DOC]
    mov x20, x1
    cbz x19, 8f
    ldr x0, [x0, #TAB_ROOT]
    bl _av_pane_first
1:  cmp x0, x20
    b.eq 8f
    ldr x9, [x0, #P_DOC]
    cmp x9, x19
    b.eq 7f
    bl _av_pane_after
    b 1b
7:  mov x0, #1
    b 9f
8:  mov x0, #0
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void destroy_leaf(Pane *leaf): view gone, doc freed with its last pane, shell hung up
    .p2align 2
Ldestroy_leaf:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #P_NSVIEW]
    bl _av_findbar_forget
    ldr x0, [x19, #P_NSVIEW]
    LDRG x9, _av_focus_view
    cmp x0, x9
    b.ne 1f
    STRG xzr, _av_focus_view, x9
1:  MSG removeFromSuperview
    ldr x0, [x19, #P_NSVIEW]
    MSG release
    ldr x20, [x19, #P_DOC]
    cbz x20, 2f
    mov x0, x20
    ldr x1, [x19, #P_VIEW]
    bl _av_doc_detach
    cbnz x0, 9f
    mov x0, x20
    bl _av_doc_free
    b 9f
2:  ldr x0, [x19, #P_VIEW]
    bl _av_term_destroy
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int close_leaf(size_t i, Pane *leaf, int ask): 1 closed, 0 cancelled; the last pane closes the tab
    .p2align 2
Lclose_leaf:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x22, x2
    TAB x21, x19
    ldr x9, [x21, #TAB_ROOT]
    cmp x9, x20
    b.ne 1f
    mov x0, x19
    bl _av_tab_close
    b 9f
1:  cbz x22, 2f
    mov x0, x20
    mov x1, #0
    bl Lask_leaf
    cbz w0, 8f
2:  mov x0, x20
    bl Ldestroy_leaf
    ldr x9, [x21, #TAB_FOCUS]
    cmp x9, x20
    b.ne 3f
    str xzr, [x21, #TAB_FOCUS]
3:  add x0, x21, #TAB_ROOT
    mov x1, x20
    bl _av_pane_remove
    ldr x22, [x21, #TAB_FOCUS]
    cbnz x22, 4f
    mov x22, x0
4:  str xzr, [x21, #TAB_ZOOM]
    bl Lcur_tab
    cmp x0, x21
    b.ne 5f
    mov x0, x21
    bl Lmount
    bl _av_tabs_layout
5:  mov x0, x21
    mov x1, x22
    bl Lset_focus
    bl _av_tabbar_redraw
    mov x0, #1
    b 9f
8:  mov x0, #0
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_tab_close(size_t i): asks about unsaved changes and running jobs; 1 closed, 0 cancelled
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
    // every pane confirms first, each doc once
    ldr x0, [x20, #TAB_ROOT]
    bl _av_pane_first
    mov x21, x0
1:  cbz x21, 2f
    mov x0, x20
    mov x1, x21
    bl Lseen_before
    cbnz x0, 11f
    mov x0, x21
    mov x1, #1
    bl Lask_leaf
    cbz w0, Lc_cancel
11: mov x0, x21
    bl _av_pane_after
    mov x21, x0
    b 1b
2:  ldr x0, [x20, #TAB_ROOT]
    cbz x0, 22f
    bl _av_pane_first
    mov x21, x0
    bl Ldestroy_leaf
    add x0, x20, #TAB_ROOT
    mov x1, x21
    bl _av_pane_remove
    b 2b
22:
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

// int av_tabs_confirm_quit(void): 1 when nothing is dirty or running, or the user accepts
FUNC_BEGIN _av_tabs_confirm_quit
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, #0
1:  LDRG x9, _av_ntabs
    cmp x19, x9
    b.hs 3f
    TAB x9, x19
    ldr x0, [x9, #TAB_ROOT]
    bl _av_pane_first
    mov x20, x0
10: cbz x20, 14f
    ldr x10, [x20, #P_DOC]
    cbz x10, 11f
    ldr x10, [x10, #BUF_FLAGS]
    tbnz x10, #0, 2f
    b 12f
11: ldr x0, [x20, #P_VIEW]
    bl _av_term_busy
    cbnz w0, 21f
12: mov x0, x20
    bl _av_pane_after
    mov x20, x0
    b 10b
14: add x19, x19, #1
    b 1b
2:  CFSTR x0, unsaved
    CFSTR x1, quitInfo
    b 22f
21: CFSTR x0, running
    CFSTR x1, runningInfo
22: CFSTR x2, bQuit
    CFSTR x3, bCancel
    mov x4, #0
    bl Lalert
    cmp x0, #ALERT_FIRST
    cset w0, eq
    b 4f
3:  mov w0, #1
4:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---- actions ----

// open panel; an untouched untitled tab with a single pane is replaced by the opened files
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
    bl Lcur_tab
    cbz x0, 1f
    ldr x9, [x0, #TAB_ROOT]
    ldr x9, [x9, #P_KIND]
    cmp x9, #PK_ROW
    b.hs 1f
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
    TAB x9, x0
    ldr x19, [x9, #TAB_FOCUS]
    ldr x21, [x19, #P_DOC]
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
    ldr x0, [x19, #P_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    bl _av_tabs_update_window
    bl _av_tabbar_redraw
9:  add sp, sp, #1040
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void split(size_t kind, int terminal): new pane right of (PK_ROW) or below (PK_COL) the focused
// one; editors get a second view on their doc, terminals and the terminal variant a new shell
    .p2align 2
Lsplit:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    sub sp, sp, #1024
    mov x25, x0
    mov x26, x1
    bl Lcur_tab
    cbz x0, 9f
    mov x19, x0
    bl Lunzoom
    ldr x20, [x19, #TAB_FOCUS]
    ldr x9, [x20, #P_KIND]
    cmp x9, #PK_TERMINAL
    b.eq 3f
    cbnz x26, 3f
    // same doc, same spot
    ldr x0, [x20, #P_DOC]
    bl _av_editor_create
    mov x21, x0
    bl _av_editor_state
    mov x22, x0
    ldr x9, [x20, #P_VIEW]
    ldp x10, x11, [x9, #V_CUR]
    stp x10, x11, [x22, #V_CUR]
    ldp x10, x11, [x9, #V_SCROLLY]
    stp x10, x11, [x22, #V_SCROLLY]
    mov x0, #PK_EDITOR
    mov x1, x21
    mov x2, x22
    ldr x3, [x20, #P_DOC]
    bl _av_pane_leaf
    mov x24, x0
    b 6f
    // the shell starts where the job runs, or in the folder of the file
3:  mov x23, #0
    ldr x9, [x20, #P_KIND]
    cmp x9, #PK_TERMINAL
    b.ne 4f
    ldr x0, [x20, #P_VIEW]
    mov x1, sp
    bl _av_term_cwd
    cbnz x0, 5f
    mov x23, sp
    b 5f
4:  ldr x9, [x20, #P_DOC]
    ldr x1, [x9, #DOC_PATH]
    cbz x1, 5f
    mov x0, sp
    mov x2, #1024
    bl _strlcpy
    mov x0, sp
    mov w1, #'/'
    bl _strrchr
    cbz x0, 41f
    // "/file" keeps the "/"
    mov x9, sp
    cmp x0, x9
    cinc x0, x0, eq
    strb wzr, [x0]
    mov x23, sp
    b 5f
    // a relative path is relative to our own directory
41: mov w9, #'.'
    strh w9, [sp]
    mov x23, sp
5:  bl _av_term_create
    cbz x0, 8f
    mov x21, x0
    bl _av_term_state
    mov x22, x0
    mov x0, #PK_TERMINAL
    mov x1, x21
    mov x2, x22
    mov x3, #0
    bl _av_pane_leaf
    mov x24, x0
6:  add x0, x19, #TAB_ROOT
    mov x1, x20
    mov x2, x24
    mov x3, x25
    bl _av_pane_split
    LDRG x0, _av_container
    mov x2, x21
    mov x3, #NSWindowBelow
    mov x4, #0
    MSG addSubviewBelow
    bl _av_tabs_layout
    mov x0, x19
    mov x1, x24
    bl Lset_focus
    ldr x9, [x24, #P_KIND]
    cmp x9, #PK_TERMINAL
    b.ne 9f
    // laid out first, so the shell starts with the pane's size
    mov x0, x22
    mov x1, x23
    bl _av_term_start
    cbz x0, 9f
    LDRG x0, _av_tab_cur
    mov x1, x24
    mov x2, #0
    bl Lclose_leaf
8:  bl _NSBeep
9:  add sp, sp, #1024
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// void focus_dir(size_t dir): focus the neighbouring pane in that direction
    .p2align 2
Lfocus_dir:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x20, x0
    bl Lcur_tab
    cbz x0, 9f
    mov x19, x0
    bl Lunzoom
    ldr x0, [x19, #TAB_ROOT]
    ldr x1, [x19, #TAB_FOCUS]
    mov x2, x20
    bl _av_pane_neighbor
    cbz x0, 9f
    mov x1, x0
    mov x0, x19
    bl Lset_focus
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void next_pane(void): focus the next pane in reading order, wrapping
    .p2align 2
Lnext_pane:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    bl Lcur_tab
    cbz x0, 9f
    mov x19, x0
    ldr x0, [x19, #TAB_ROOT]
    ldr x1, [x19, #TAB_FOCUS]
    bl _av_pane_next
    mov x1, x0
    mov x0, x19
    bl Lset_focus_any
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void close_pane(void): closes the focused pane, asking first
    .p2align 2
Lclose_pane:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lcur_tab
    cbz x0, 9f
    ldr x1, [x0, #TAB_FOCUS]
    LDRG x0, _av_tab_cur
    mov x2, #1
    bl Lclose_leaf
9:  ldp x29, x30, [sp], #16
    ret

// void zoom(void): the focused pane fills the tab, or back to all panes
    .p2align 2
Lzoom:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    bl Lcur_tab
    cbz x0, 9f
    mov x19, x0
    ldr x9, [x19, #TAB_ROOT]
    ldr x9, [x9, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 9f
    ldr x9, [x19, #TAB_ZOOM]
    cbz x9, 1f
    mov x0, x19
    bl Lunzoom
    b 2f
1:  mov x9, #1
    str x9, [x19, #TAB_ZOOM]
    mov x0, x19
    ldr x1, [x19, #TAB_FOCUS]
    bl Lunmount
    bl _av_tabs_layout
2:  bl Lsync_focus
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void resize(size_t dir): moves the nearest divider by four columns or two lines
    .p2align 2
Lresize:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl Lcur_tab
    cbz x0, 9f
    ldr x9, [x0, #TAB_ZOOM]
    cbnz x9, 9f
    ldr x0, [x0, #TAB_FOCUS]
    LDRD d0, _av_adv
    fmov d1, #4.0
    fmul d2, d0, d1
    LDRD d0, _av_line_h
    fmov d1, #2.0
    fmul d3, d0, d1
    cmp x19, #DIR_UP
    fcsel d0, d3, d2, hs
    mov x1, x19
    bl _av_pane_resize
    cbz x0, 9f
    bl _av_tabs_layout
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
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
    b La_term
    b La_split_r
    b La_split_d
    b La_split_tr
    b La_split_td
    .rept 4
    b La_pane_dir
    .endr
    b La_next_pane
    b La_close_pane
    b La_zoom
    .rept 4
    b La_resize
    .endr
    b La_palette
    b La_find
    b La_replace
    b La_find_next
    b La_find_prev
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
    b La_out
La_term:
    bl _av_tab_open_term
    b La_out
La_split_r:
    mov x0, #PK_ROW
    mov x1, #0
    bl Lsplit
    b La_out
La_split_d:
    mov x0, #PK_COL
    mov x1, #0
    bl Lsplit
    b La_out
La_split_tr:
    mov x0, #PK_ROW
    mov x1, #1
    bl Lsplit
    b La_out
La_split_td:
    mov x0, #PK_COL
    mov x1, #1
    bl Lsplit
    b La_out
La_pane_dir:
    sub x0, x19, #A_PANE_LEFT
    bl Lfocus_dir
    b La_out
La_next_pane:
    bl Lnext_pane
    b La_out
La_close_pane:
    bl Lclose_pane
    b La_out
La_zoom:
    bl Lzoom
    b La_out
La_resize:
    sub x0, x19, #A_RESIZE_LEFT
    bl Lresize
    b La_out
La_palette:
    bl _av_palette_toggle
    b La_out
La_find:
    mov x0, #0
    bl _av_findbar_open
    b La_out
La_replace:
    mov x0, #1
    bl _av_findbar_open
    b La_out
La_find_next:
    mov x0, #0
    bl _av_find_step
    b La_out
La_find_prev:
    mov x0, #1
    bl _av_find_step
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
    // the prefix twice goes through to the view (a terminal gets C-s)
    and x9, x20, #MOD_CHORD
    LDRG x10, _av_prefix_mods
    and x10, x10, #MOD_CHORD
    cmp x9, x10
    b.ne 11f
    LDRG x10, _av_prefix_cp
    cmp x21, x10
    b.eq 8f
11: cmp w22, #KEY_ESC_CODE
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
    TAB x0, x0
    bl Ltab_name
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
    TAB x0, x20
    bl Ltab_dirty
    mov x9, x0
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
