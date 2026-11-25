// AvEditorView: NSView subclass built at runtime, maps AppKit events onto edit.s operations

.include "macros.inc"
.include "objc.inc"
.include "consts.inc"
.include "buffer.inc"
.include "doc.inc"
.include "keymap.inc"

.set NSUTF8StringEncoding, 4

.set KEY_RETURN,   36
.set KEY_TAB,      48
.set KEY_DELETE,   51
.set KEY_ESCAPE,   53
.set KEY_ENTER,    76
.set KEY_HOME,     115
.set KEY_PAGEUP,   116
.set KEY_FWDDEL,   117
.set KEY_END,      119
.set KEY_PAGEDOWN, 121
.set KEY_LEFT,     123
.set KEY_RIGHT,    124
.set KEY_DOWN,     125
.set KEY_UP,       126

    CLASSREF NSView
    CLASSREF NSPasteboard
    CLASSREF NSString

    SELDEF drawRect, "drawRect:"
    SELDEF acceptsFR, "acceptsFirstResponder"
    SELDEF isOpaque, "isOpaque"
    SELDEF keyDown, "keyDown:"
    SELDEF mouseDown, "mouseDown:"
    SELDEF mouseDragged, "mouseDragged:"
    SELDEF scrollWheel, "scrollWheel:"
    SELDEF copy, "copy:"
    SELDEF cut, "cut:"
    SELDEF paste, "paste:"
    SELDEF selectAll, "selectAll:"
    SELDEF undo, "undo:"
    SELDEF redo, "redo:"
    SELDEF saveDocument, "saveDocument:"

    SELDEF alloc, "alloc"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF modifierFlags, "modifierFlags"
    SELDEF keyCode, "keyCode"
    SELDEF characters, "characters"
    SELDEF UTF8String, "UTF8String"
    SELDEF locationInWindow, "locationInWindow"
    SELDEF convertPoint, "convertPoint:fromView:"
    SELDEF clickCount, "clickCount"
    SELDEF scrollingDeltaX, "scrollingDeltaX"
    SELDEF scrollingDeltaY, "scrollingDeltaY"
    SELDEF hasPrecise, "hasPreciseScrollingDeltas"
    SELDEF bounds, "bounds"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF window, "window"
    SELDEF setDocumentEdited, "setDocumentEdited:"
    SELDEF generalPasteboard, "generalPasteboard"
    SELDEF clearContents, "clearContents"
    SELDEF setStringForType, "setString:forType:"
    SELDEF stringForType, "stringForType:"
    SELDEF initWithBytes, "initWithBytes:length:encoding:"

    .section __TEXT,__cstring,cstring_literals
Lclass_name: .asciz "AvEditorView"
Livar_name:  .asciz "st"
Livar_type:  .asciz "^v"
Lt_rect:     .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_bool:     .asciz "c@:"
Lt_obj:      .asciz "v@:@"

    // selector slot, IMP, type encoding
    .section __DATA,__const
    .p2align 3
Lmethods:
    .quad Lsr_drawRect, _av_render_draw, Lt_rect
    .quad Lsr_acceptsFR, Lyes, Lt_bool
    .quad Lsr_isOpaque, Lyes, Lt_bool
    .quad Lsr_keyDown, Lkey_down, Lt_obj
    .quad Lsr_mouseDown, Lmouse_down, Lt_obj
    .quad Lsr_mouseDragged, Lmouse_dragged, Lt_obj
    .quad Lsr_scrollWheel, Lscroll_wheel, Lt_obj
    .quad Lsr_copy, Lcopy, Lt_obj
    .quad Lsr_cut, Lcut, Lt_obj
    .quad Lsr_paste, Lpaste, Lt_obj
    .quad Lsr_selectAll, Lselect_all, Lt_obj
    .quad Lsr_undo, Lundo, Lt_obj
    .quad Lsr_redo, Lredo, Lt_obj
    .quad Lsr_saveDocument, Lsave, Lt_obj
Lmethods_end:

    .zerofill __DATA,__bss,_av_ev_class,8,3
    .zerofill __DATA,__bss,_av_ev_ivar,8,3
    .globl _av_ev_ivar

// dst = View * of the AvEditorView in reg self, clobbers x9
.macro STATE dst, self
    LDRG x9, _av_ev_ivar
    ldr \dst, [\self, x9]
.endm

// standard 6-register frame used by most IMPs
.macro IMP_ENTER
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
.endm

.macro IMP_LEAVE
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
.endm

    .text
// void av_editor_class_init(void)
FUNC_BEGIN _av_editor_class_init
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    CLS x0, NSView
    LADDR x1, Lclass_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    LADDR x1, Livar_name
    mov x2, #8
    mov w3, #3
    LADDR x4, Livar_type
    bl _class_addIvar
    LADDR x20, Lmethods
    LADDR x21, Lmethods_end
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
    STRG x19, _av_ev_class, x9
    mov x0, x19
    LADDR x1, Livar_name
    bl _class_getInstanceVariable
    bl _ivar_getOffset
    STRG x0, _av_ev_ivar, x9
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// NSView *av_editor_create(Doc *doc)
FUNC_BEGIN _av_editor_create
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x0, #V_SIZE
    bl _av_arena_alloc
    mov x20, x0
    str x19, [x20, #V_DOC]
    mov x0, #-1
    str x0, [x20, #V_PREFCOL]
    LDRG x0, _av_ev_class
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x21, x0
    LDRG x9, _av_ev_ivar
    str x20, [x21, x9]
    str x21, [x20, #V_NSVIEW]
    mov x0, x21
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .p2align 2
Lyes:
    mov w0, #1
    ret

// redraw and sync the window's edited dot with the buffer dirty flag
    .p2align 2
Lrefresh:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x2, #1
    MSG setNeedsDisplay
    mov x0, x19
    MSG window
    cbz x0, 1f
    STATE x10, x19
    ldr x10, [x10, #V_DOC]
    ldr x11, [x10, #BUF_FLAGS]
    and x2, x11, #BUF_DIRTY
    MSG setDocumentEdited
1:  bl _av_tabbar_redraw
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// scroll so the cursor is inside the view, with a few columns of margin horizontally
    .p2align 2
Lensure:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    stp d8, d9, [sp, #40]
    stp d10, d11, [sp, #56]
    str d12, [sp, #72]
    mov x19, x0
    STATE x20, x19
    ldr x21, [x20, #V_DOC]
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    LDRD d10, _av_line_h
    LDRD d11, _av_adv

    mov x0, x21
    ldr x1, [x20, #V_CUR]
    bl _av_buf_line_of
    ucvtf d0, x0
    fmul d0, d0, d10
    ldr d1, [x20, #V_SCROLLY]
    fcmp d0, d1
    b.ge 1f
    fmov d1, d0
1:  fadd d2, d0, d10
    fadd d3, d1, d9
    fcmp d2, d3
    b.le 2f
    fsub d1, d2, d9
2:  movi d4, #0
    fmax d1, d1, d4
    str d1, [x20, #V_SCROLLY]

    mov x0, x21
    ldr x1, [x20, #V_CUR]
    bl _av_col_of
    ucvtf d12, x0
    fmul d12, d12, d11
    mov x0, x21
    bl _av_render_text_x
    fsub d2, d8, d0
    ldr d1, [x20, #V_SCROLLX]
    fmov d5, #4.0
    fmul d5, d5, d11
    fcmp d12, d1
    b.ge 3f
    fsub d1, d12, d5
    b 4f
3:  fadd d3, d12, d11
    fadd d4, d1, d2
    fcmp d3, d4
    b.le 4f
    fsub d1, d3, d2
    fadd d1, d1, d5
4:  movi d4, #0
    fmax d1, d1, d4
    str d1, [x20, #V_SCROLLX]

    ldr d12, [sp, #72]
    ldp d10, d11, [sp, #56]
    ldp d8, d9, [sp, #40]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// void clamp_scroll(View *v)
    .p2align 2
Lclamp:
    ldr x1, [x0, #V_DOC]
    ldr x2, [x1, #BUF_NLINES]
    sub x2, x2, #1
    ucvtf d1, x2
    LDRD d2, _av_line_h
    fmul d1, d1, d2
    movi d3, #0
    ldr d0, [x0, #V_SCROLLY]
    fmin d0, d0, d1
    fmax d0, d0, d3
    str d0, [x0, #V_SCROLLY]
    ldr d0, [x0, #V_SCROLLX]
    fmax d0, d0, d3
    str d0, [x0, #V_SCROLLX]
    ret

// size_t hit(NSView *self, NSEvent *e), buffer position under the mouse
    .p2align 2
Lhit:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    STATE x20, x19
    ldr x21, [x20, #V_DOC]
    mov x0, x1
    MSG locationInWindow
    mov x0, x19
    mov x2, #0
    MSG convertPoint
    fmov d8, d0
    fmov d9, d1
    mov x0, x19
    MSG bounds
    fsub d0, d3, d9
    ldr d1, [x20, #V_SCROLLY]
    fadd d0, d0, d1
    LDRD d1, _av_line_h
    fdiv d0, d0, d1
    fcvtms x1, d0
    cmp x1, #0
    csel x1, xzr, x1, lt
    ldr x2, [x21, #BUF_NLINES]
    sub x2, x2, #1
    cmp x1, x2
    csel x22, x2, x1, gt
    mov x0, x21
    bl _av_render_text_x
    fsub d0, d8, d0
    ldr d1, [x20, #V_SCROLLX]
    fadd d0, d0, d1
    LDRD d1, _av_adv
    fdiv d0, d0, d1
    fcvtas x2, d0
    cmp x2, #0
    csel x2, xzr, x2, lt
    mov x0, x21
    mov x1, x22
    bl _av_pos_at_col
    ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// keyDown:, x22 modifiers, x23 key code, x24 shift
    .p2align 2
Lkey_down:
    IMP_ENTER
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    mov x0, x21
    bl _av_keymap_handle
    cbnz w0, Lk_out
    mov x0, x21
    MSG modifierFlags
    mov x22, x0
    mov x0, x21
    MSG keyCode
    and w23, w0, #0xffff
    ubfx x24, x22, #17, #1

    cmp w23, #KEY_LEFT
    b.eq Lk_left
    cmp w23, #KEY_RIGHT
    b.eq Lk_right
    cmp w23, #KEY_UP
    b.eq Lk_up
    cmp w23, #KEY_DOWN
    b.eq Lk_down
    cmp w23, #KEY_HOME
    b.eq Lk_home
    cmp w23, #KEY_END
    b.eq Lk_end
    cmp w23, #KEY_PAGEUP
    b.eq Lk_pgup
    cmp w23, #KEY_PAGEDOWN
    b.eq Lk_pgdn
    cmp w23, #KEY_DELETE
    b.eq Lk_bs
    cmp w23, #KEY_FWDDEL
    b.eq Lk_del
    cmp w23, #KEY_RETURN
    b.eq Lk_ret
    cmp w23, #KEY_ENTER
    b.eq Lk_ret
    cmp w23, #KEY_TAB
    b.eq Lk_tab
    cmp w23, #KEY_ESCAPE
    b.eq Lk_esc
    b Lk_text

    // option moves by word, command to line/document edges
Lk_left:
    mov x1, #MV_LEFT
    tst x22, #NSEventModifierFlagOption
    mov x9, #MV_WORD_LEFT
    csel x1, x9, x1, ne
    tst x22, #NSEventModifierFlagCommand
    mov x9, #MV_HOME
    csel x1, x9, x1, ne
    b Lk_move
Lk_right:
    mov x1, #MV_RIGHT
    tst x22, #NSEventModifierFlagOption
    mov x9, #MV_WORD_RIGHT
    csel x1, x9, x1, ne
    tst x22, #NSEventModifierFlagCommand
    mov x9, #MV_END
    csel x1, x9, x1, ne
    b Lk_move
Lk_up:
    mov x1, #MV_UP
    tst x22, #NSEventModifierFlagCommand
    mov x9, #MV_TOP
    csel x1, x9, x1, ne
    b Lk_move
Lk_down:
    mov x1, #MV_DOWN
    tst x22, #NSEventModifierFlagCommand
    mov x9, #MV_BOTTOM
    csel x1, x9, x1, ne
    b Lk_move
Lk_home:
    mov x1, #MV_HOME
    b Lk_move
Lk_end:
    mov x1, #MV_END
    b Lk_move
Lk_pgup:
    mov x1, #MV_PAGE_UP
    b Lk_move
Lk_pgdn:
    mov x1, #MV_PAGE_DOWN

Lk_move:
    mov x23, x1
    mov x0, x19
    MSG bounds
    LDRD d0, _av_line_h
    fdiv d3, d3, d0
    fcvtzu x3, d3
    sub x3, x3, #1
    mov x9, #1
    cmp x3, #1
    csel x3, x3, x9, hs
    mov x0, x20
    mov x1, x23
    mov x2, x24
    bl _av_view_move
    b Lk_ensure

    // option/command backspace first select back to word/line start
Lk_bs:
    tst x22, #NSEventModifierFlagOption
    mov x1, #MV_WORD_LEFT
    b.ne 1f
    tst x22, #NSEventModifierFlagCommand
    mov x1, #MV_HOME
    b.ne 1f
    b 2f
1:  ldp x9, x10, [x20, #V_CUR]
    cmp x9, x10
    b.ne 2f
    mov x0, x20
    mov x2, #1
    mov x3, #0
    bl _av_view_move
2:  mov x0, x20
    bl _av_view_backspace
    b Lk_ensure

Lk_del:
    tst x22, #NSEventModifierFlagOption
    mov x1, #MV_WORD_RIGHT
    b.ne 1f
    tst x22, #NSEventModifierFlagCommand
    mov x1, #MV_END
    b.ne 1f
    b 2f
1:  ldp x9, x10, [x20, #V_CUR]
    cmp x9, x10
    b.ne 2f
    mov x0, x20
    mov x2, #1
    mov x3, #0
    bl _av_view_move
    mov x0, x20
    bl _av_view_backspace
    b Lk_ensure
2:  mov x0, x20
    bl _av_view_delete_fwd
    b Lk_ensure

Lk_ret:
    mov x0, x20
    bl _av_view_newline
    b Lk_ensure

Lk_tab:
    mov x0, x20
    bl _av_view_tab
    b Lk_ensure

Lk_esc:
    ldr x9, [x20, #V_CUR]
    str x9, [x20, #V_ANCHOR]
    b Lk_redraw

    // printable text, command/control chords belong to menus and the prefix key
Lk_text:
    mov x9, #(NSEventModifierFlagControl | NSEventModifierFlagCommand)
    tst x22, x9
    b.ne Lk_out
    mov x0, x21
    MSG characters
    MSG UTF8String
    cbz x0, Lk_out
    mov x23, x0
    ldrb w1, [x23]
    cmp w1, #0x20
    b.lo Lk_out
    cmp w1, #0x7f
    b.eq Lk_out
    // U+F700..U+F7FF are AppKit function-key codes (EF 9C..9F xx)
    cmp w1, #0xef
    b.ne 1f
    ldrb w2, [x23, #1]
    sub w2, w2, #0x9c
    cmp w2, #3
    b.ls Lk_out
1:  mov x0, x23
    bl _strlen
    mov x2, x0
    mov x0, x20
    mov x1, x23
    mov x3, #1
    bl _av_view_insert

Lk_ensure:
    mov x0, x19
    bl Lensure
Lk_redraw:
    mov x0, x19
    bl Lrefresh
Lk_out:
    IMP_LEAVE

    .p2align 2
Lmouse_down:
    IMP_ENTER
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    mov x1, x21
    bl Lhit
    mov x22, x0
    mov x0, x21
    MSG clickCount
    cmp x0, #2
    b.eq 2f
    b.hi 3f
    mov x0, x21
    MSG modifierFlags
    ubfx x2, x0, #17, #1
    mov x0, x20
    mov x1, x22
    bl _av_view_set_cursor
    b 4f
2:  mov x0, x20
    mov x1, x22
    bl _av_view_select_word
    b 4f
3:  mov x0, x20
    mov x1, x22
    bl _av_view_select_line
4:  mov x0, x19
    bl Lrefresh
    IMP_LEAVE

    .p2align 2
Lmouse_dragged:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    mov x1, x2
    bl Lhit
    mov x1, x0
    mov x0, x20
    mov x2, #1
    bl _av_view_set_cursor
    mov x0, x19
    bl Lensure
    mov x0, x19
    bl Lrefresh
    IMP_LEAVE

// non-precise wheels report lines, trackpads report points
    .p2align 2
Lscroll_wheel:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    mov x0, x21
    MSG scrollingDeltaY
    fmov d8, d0
    mov x0, x21
    MSG scrollingDeltaX
    fmov d9, d0
    mov x0, x21
    MSG hasPrecise
    tst w0, #0xff
    b.ne 1f
    LDRD d0, _av_line_h
    fmul d8, d8, d0
    fmul d9, d9, d0
1:  ldr d0, [x20, #V_SCROLLY]
    fsub d0, d0, d8
    str d0, [x20, #V_SCROLLY]
    ldr d0, [x20, #V_SCROLLX]
    fsub d0, d0, d9
    str d0, [x20, #V_SCROLLX]
    mov x0, x20
    bl Lclamp
    mov x0, x19
    mov x2, #1
    MSG setNeedsDisplay
    ldp d8, d9, [sp, #48]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// copy selection to the general pasteboard
    .p2align 2
Lcopy:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    SEL_RANGE x20, x21, x22
    sub x22, x22, x21
    cbz x22, 9f
    mov x0, x22
    bl _av_pages_alloc
    cbz x0, 9f
    mov x23, x0
    ldr x0, [x20, #V_DOC]
    mov x1, x21
    mov x2, x23
    mov x3, x22
    bl _av_buf_copy
    CLS x0, NSString
    MSG alloc
    mov x2, x23
    mov x3, x22
    mov x4, #NSUTF8StringEncoding
    MSG initWithBytes
    mov x21, x0
    mov x0, x23
    mov x1, x22
    bl _av_pages_free
    cbz x21, 9f
    CLS x0, NSPasteboard
    MSG generalPasteboard
    mov x22, x0
    MSG clearContents
    mov x0, x22
    mov x2, x21
    LEXTERN x3, _NSPasteboardTypeString
    MSG setStringForType
    mov x0, x21
    MSG release
9:  IMP_LEAVE

    .p2align 2
Lcut:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    bl Lcopy
    mov x0, x20
    mov x1, #0
    bl _av_view_delete_sel
    b Ledit_done

    .p2align 2
Lpaste:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    CLS x0, NSPasteboard
    MSG generalPasteboard
    LEXTERN x2, _NSPasteboardTypeString
    MSG stringForType
    cbz x0, 9f
    MSG UTF8String
    cbz x0, 9f
    mov x21, x0
    bl _strlen
    cbz x0, 9f
    mov x2, x0
    mov x0, x20
    mov x1, x21
    mov x3, #0
    bl _av_view_insert
    b Ledit_done
9:  IMP_LEAVE

    .p2align 2
Lselect_all:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    mov x0, x20
    bl _av_view_select_all
    mov x0, x19
    bl Lrefresh
    IMP_LEAVE

    .p2align 2
Lundo:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    mov x0, x20
    bl _av_view_undo
    b Ledit_done

    .p2align 2
Lredo:
    IMP_ENTER
    mov x19, x0
    STATE x20, x19
    mov x0, x20
    bl _av_view_redo

    // shared tail for IMPs that entered with IMP_ENTER and x19 = self
Ledit_done:
    mov x0, x19
    bl Lensure
    mov x0, x19
    bl Lrefresh
    IMP_LEAVE

// saveDocument:, the active tab is this view
    .p2align 2
Lsave:
    mov x0, #A_SAVE
    b _av_action

// View *av_editor_state(NSView *view)
FUNC_BEGIN _av_editor_state
    STATE x0, x0
    ret
