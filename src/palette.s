// command palette: every action and open tab, fuzzy filtered as you type; shared text field
// and color helpers for the find bar

.include "macros.inc"
.include "objc.inc"
.include "theme.inc"
.include "keymap.inc"

.set MAX_ITEMS, 128
.set IT_ID,    0               // action id, or TAB_ITEM + tab index
.set IT_SCORE, 8
.set IT_LABEL, 16              // 72 bytes
.set IT_KEY,   88              // 24 bytes
.set IT_SIZE,  112
.set TAB_ITEM, 0x1000
.set MAX_ROWS, 12
.set PAL_W,    640
.set PAD,      8
.set NSFocusRingTypeNone, 1

    CLASSREF NSView
    CLASSREF NSTextField
    CLASSREF NSColor
    CLASSREF NSString
    CLASSREF NSGraphicsContext

    SELDEF alloc, "alloc"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF addSubview, "addSubview:"
    SELDEF removeFromSuperview, "removeFromSuperview"
    SELDEF setFrame, "setFrame:"
    SELDEF bounds, "bounds"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF window, "window"
    SELDEF selectText, "selectText:"
    SELDEF currentEditor, "currentEditor"
    SELDEF setInsertionPointColor, "setInsertionPointColor:"
    SELDEF srgb, "colorWithSRGBRed:green:blue:alpha:"
    SELDEF setBezeled, "setBezeled:"
    SELDEF setBordered, "setBordered:"
    SELDEF setDrawsBackground, "setDrawsBackground:"
    SELDEF setBackgroundColor, "setBackgroundColor:"
    SELDEF setTextColor, "setTextColor:"
    SELDEF setFont, "setFont:"
    SELDEF setFocusRingType, "setFocusRingType:"
    SELDEF setDelegate, "setDelegate:"
    SELDEF setPlaceholderString, "setPlaceholderString:"
    SELDEF setStringValue, "setStringValue:"
    SELDEF stringValue, "stringValue"
    SELDEF cell, "cell"
    SELDEF setUsesSingleLineMode, "setUsesSingleLineMode:"
    SELDEF setScrollable, "setScrollable:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"
    SELDEF UTF8String, "UTF8String"
    SELDEF currentContext, "currentContext"
    SELDEF CGContext, "CGContext"
    SELDEF locationInWindow, "locationInWindow"
    SELDEF convertPoint, "convertPoint:fromView:"
    SELDEF drawRect, "drawRect:"
    SELDEF mouseDown, "mouseDown:"
    SELDEF textDidChange, "controlTextDidChange:"
    SELDEF textDidEnd, "controlTextDidEndEditing:"
    SELDEF doCommand, "control:textView:doCommandBySelector:"
    SELDEF moveUp, "moveUp:"
    SELDEF moveDown, "moveDown:"
    SELDEF insertNewline, "insertNewline:"
    SELDEF cancelOperation, "cancelOperation:"

    .section __TEXT,__cstring,cstring_literals
Lpal_name:   .asciz "AvPalette"
Lt_rect:     .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_obj:      .asciz "v@:@"
Lt_cmd:      .asciz "c@:@@:"
Ls_hint:     .asciz "Run a command or go to a tab"
Ls_tab:      .asciz "tab: "

    .section __DATA,__const
    .p2align 3
Lpal_methods:
    .quad Lsr_drawRect, Lpal_draw, Lt_rect
    .quad Lsr_mouseDown, Lpal_mouse, Lt_obj
    .quad Lsr_textDidChange, Lpal_changed, Lt_obj
    .quad Lsr_doCommand, Lpal_command, Lt_cmd
    .quad Lsr_textDidEnd, Lpal_ended, Lt_obj
Lpal_methods_end:

    .zerofill __DATA,__bss,_av_pal_class,8,3
    .zerofill __DATA,__bss,_av_pal_view,8,3
    .zerofill __DATA,__bss,_av_pal_field,8,3
    .zerofill __DATA,__bss,_av_pal_items,(MAX_ITEMS * IT_SIZE),4
    .zerofill __DATA,__bss,_av_pal_nitems,8,3
    .zerofill __DATA,__bss,_av_pal_order,(MAX_ITEMS * 8),3
    .zerofill __DATA,__bss,_av_pal_n,8,3
    .zerofill __DATA,__bss,_av_pal_sel,8,3
    .zerofill __DATA,__bss,_av_pal_top,8,3
    .zerofill __DATA,__bss,_av_pal_run,8,3
    .zerofill __DATA,__bss,_av_pal_ctx,8,3

    .text
// NSColor *av_ui_color(size_t slot): theme slot offset (T_*) as an sRGB color
FUNC_BEGIN _av_ui_color
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LADDR x9, _av_theme
    add x9, x9, x0
    ldp d0, d1, [x9]
    ldp d2, d3, [x9, #16]
    CLS x0, NSColor
    MSG srgb
    ldp x29, x30, [sp], #16
    ret

// NSTextField *av_ui_field(id delegate, const char *placeholder): borderless themed field,
// owned by the caller (+1)
FUNC_BEGIN _av_ui_field
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x20, x0
    mov x21, x1
    CLS x0, NSTextField
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x19, x0
    mov x2, #0
    MSG setBezeled
    mov x0, x19
    mov x2, #0
    MSG setBordered
    mov x0, x19
    mov x2, #1
    MSG setDrawsBackground
    mov x0, #T_BG
    bl _av_ui_color
    mov x2, x0
    mov x0, x19
    MSG setBackgroundColor
    mov x0, #T_TEXT
    bl _av_ui_color
    mov x2, x0
    mov x0, x19
    MSG setTextColor
    LDRG x2, _av_font
    mov x0, x19
    MSG setFont
    mov x0, x19
    mov x2, #NSFocusRingTypeNone
    MSG setFocusRingType
    mov x0, x19
    MSG cell
    mov x2, #1
    MSG setUsesSingleLineMode
    mov x0, x19
    MSG cell
    mov x2, #1
    MSG setScrollable
    mov x0, x19
    mov x2, x20
    MSG setDelegate
    CLS x0, NSString
    mov x2, x21
    MSG stringWithUTF8String
    mov x2, x0
    mov x0, x19
    MSG setPlaceholderString
    mov x0, x19
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_ui_focus_field(NSTextField *f): keyboard into f with its text selected, caret in the
// theme cursor color
FUNC_BEGIN _av_ui_focus_field
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    MSG window
    cbz x0, 1f
    mov x0, x19
    mov x2, #0
    MSG selectText
    mov x0, x19
    MSG currentEditor
    cbz x0, 1f
    str x0, [sp, #24]
    mov x0, #T_CURSOR
    bl _av_ui_color
    mov x2, x0
    ldr x0, [sp, #24]
    MSG setInsertionPointColor
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// const char *av_ui_text(NSTextField *f): current UTF-8 contents, valid until the next edit
FUNC_BEGIN _av_ui_text
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    MSG stringValue
    MSG UTF8String
    cbnz x0, 1f
    adr x0, Lnul
1:  ldp x29, x30, [sp], #16
    ret
Lnul:
    .byte 0
    .p2align 2

// Class make_class(void): AvPalette, built on first use
    .p2align 2
Lpal_class:
    LDRG x0, _av_pal_class
    cbz x0, 1f
    ret
1:  stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    CLS x0, NSView
    LADDR x1, Lpal_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    LADDR x20, Lpal_methods
    LADDR x21, Lpal_methods_end
2:  cmp x20, x21
    b.hs 3f
    ldp x9, x2, [x20]
    ldr x3, [x20, #16]
    ldr x1, [x9]
    mov x0, x19
    bl _class_addMethod
    add x20, x20, #24
    b 2b
3:  mov x0, x19
    bl _objc_registerClassPair
    STRG x19, _av_pal_class, x9
    mov x0, x19
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// double row_h(void) / field_h(void)
    .p2align 2
Lrow_h:
    LDRD d0, _av_line_h
    fmov d1, #4.0
    fadd d0, d0, d1
    ret

    .p2align 2
Lfield_h:
    LDRD d0, _av_line_h
    fmov d1, #6.0
    fadd d0, d0, d1
    ret

// void add_item(size_t id, const char *prefix, const char *name, long key): label is prefix +
// name with underscores as spaces, key the prefix binding as text
    .p2align 2
Ladd_item:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    LDRG x9, _av_pal_nitems
    cmp x9, #MAX_ITEMS
    b.hs 9f
    LADDR x10, _av_pal_items
    mov x11, #IT_SIZE
    madd x23, x9, x11, x10
    add x9, x9, #1
    STRG x9, _av_pal_nitems, x10
    str x19, [x23, #IT_ID]
    add x0, x23, #IT_LABEL
    mov x1, x20
    mov x2, #72
    bl _strlcpy
    add x0, x23, #IT_LABEL
    mov x1, x21
    mov x2, #72
    bl _strlcat
    add x9, x23, #IT_LABEL
1:  ldrb w10, [x9], #1
    cbz w10, 2f
    cmp w10, #'_'
    b.ne 1b
    mov w10, #' '
    sturb w10, [x9, #-1]
    b 1b
2:  strb wzr, [x23, #IT_KEY]
    tbnz x22, #63, 9f
    add x0, x23, #IT_KEY
    LDRG x1, _av_cfg_prefix
    mov x2, #24
    bl _strlcpy
    add x0, x23, #IT_KEY
    bl _strlen
    add x9, x23, #IT_KEY
    add x9, x9, x0
    mov w10, #' '
    strb w10, [x9], #1
    mov x0, x22
    mov x1, x9
    bl _av_key_format
9:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void build(void): all actions except the palette itself and tab_N, then one item per tab
    .p2align 2
Lbuild:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    STRG xzr, _av_pal_nitems, x9
    mov x19, #1
1:  cmp x19, #A_COUNT
    b.hs 3f
    cmp x19, #A_PALETTE
    b.eq 2f
    sub x9, x19, #A_TAB_1
    cmp x9, #(A_TAB_9 - A_TAB_1)
    b.ls 2f
    mov x0, x19
    bl _av_keymap_find
    mov x3, x0
    mov x0, x19
    bl _av_action_name
    mov x2, x0
    mov x0, x19
    adr x1, Lnul
    bl Ladd_item
2:  add x19, x19, #1
    b 1b
3:  mov x19, #0
4:  LDRG x9, _av_ntabs
    cmp x19, x9
    b.hs 9f
    mov x0, x19
    bl _av_tab_name
    mov x2, x0
    add x0, x19, #TAB_ITEM
    LADDR x1, Ls_tab
    mov x3, #-1
    bl Ladd_item
    add x19, x19, #1
    b 4b
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void filter(void): items matching the field, best score first (stable)
    .p2align 2
Lfilter:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    LDRG x0, _av_pal_field
    bl _av_ui_text
    mov x20, x0
    mov x19, #0
    mov x21, #0
1:  LDRG x9, _av_pal_nitems
    cmp x19, x9
    b.hs 4f
    LADDR x10, _av_pal_items
    mov x11, #IT_SIZE
    madd x22, x19, x11, x10
    mov x0, x20
    add x1, x22, #IT_LABEL
    bl _av_fuzzy_score
    str x0, [x22, #IT_SCORE]
    tbnz x0, #63, 3f
    // insertion: shift lower scores right
    LADDR x10, _av_pal_order
    mov x11, x21
2:  cbz x11, 21f
    sub x12, x11, #1
    ldr x13, [x10, x12, lsl #3]
    mov x14, #IT_SIZE
    LADDR x15, _av_pal_items
    madd x13, x13, x14, x15
    ldr x13, [x13, #IT_SCORE]
    cmp x13, x0
    b.ge 21f
    ldr x13, [x10, x12, lsl #3]
    str x13, [x10, x11, lsl #3]
    mov x11, x12
    b 2b
21: str x19, [x10, x11, lsl #3]
    add x21, x21, #1
3:  add x19, x19, #1
    b 1b
4:  STRG x21, _av_pal_n, x9
    STRG xzr, _av_pal_sel, x9
    STRG xzr, _av_pal_top, x9
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_palette_layout(void): centered under the tab bar, as tall as its rows
FUNC_BEGIN _av_palette_layout
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp d8, d9, [sp, #16]
    stp d10, d11, [sp, #32]
    LDRG x0, _av_pal_view
    cbz x0, 9f
    LDRG x0, _av_container
    MSG bounds
    fmov d8, d2
    // width min(PAL_W, W - 40)
    mov x9, #PAL_W
    ucvtf d0, x9
    mov x9, #40
    ucvtf d1, x9
    fsub d1, d8, d1
    fmin d9, d0, d1
    // height: padding, field, gap, rows
    LDRG x9, _av_pal_n
    mov x10, #MAX_ROWS
    cmp x9, x10
    csel x9, x10, x9, hi
    ucvtf d10, x9
    bl Lrow_h
    fmul d10, d10, d0
    bl Lfield_h
    fadd d10, d10, d0
    mov x9, #(PAD * 3)
    ucvtf d0, x9
    fadd d10, d10, d0
    // x centered, y just below the tab bar (the container is flipped)
    fsub d0, d8, d9
    fmov d1, #0.5
    fmul d0, d0, d1
    frinta d0, d0
    LDRD d1, _av_line_h
    fmov d2, #14.0
    fadd d1, d1, d2
    fmov d2, d9
    fmov d3, d10
    fmov d11, d0
    LDRG x0, _av_pal_view
    MSG setFrame
    // field at the top of the (unflipped) palette
    LDRG x0, _av_pal_field
    mov x9, #PAD
    ucvtf d0, x9
    fsub d2, d9, d0
    fsub d2, d2, d0
    bl Lfield_h
    fmov d3, d0
    fsub d1, d10, d3
    mov x9, #PAD
    ucvtf d0, x9
    fsub d1, d1, d0
    LDRG x0, _av_pal_field
    MSG setFrame
    LDRG x0, _av_pal_view
    mov x2, #1
    MSG setNeedsDisplay
9:  ldp d10, d11, [sp, #32]
    ldp d8, d9, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_palette_toggle(void)
FUNC_BEGIN _av_palette_toggle
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    LDRG x9, _av_pal_view
    cbz x9, 1f
    mov x0, #-1
    bl Lclose
    b 9f
1:  LDRG x9, _av_container
    cbz x9, 9f
    bl Lbuild
    bl Lpal_class
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x19, x0
    STRG x19, _av_pal_view, x9
    mov x0, x19
    LADDR x1, Ls_hint
    bl _av_ui_field
    STRG x0, _av_pal_field, x9
    mov x2, x0
    mov x0, x19
    MSG addSubview
    LDRG x0, _av_pal_field
    MSG release
    LDRG x0, _av_container
    mov x2, x19
    MSG addSubview
    mov x0, x19
    MSG release
    bl Lfilter
    bl _av_palette_layout
    LDRG x0, _av_pal_field
    bl _av_ui_focus_field
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void close(long id): on the next turn of the run loop the palette goes away, the keyboard
// returns to the pane and id runs (-1 for nothing); AppKit may still be inside the field now
    .p2align 2
Lclose:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x9, _av_pal_view
    cbz x9, 9f
    STRG x0, _av_pal_run, x10
    STRG x9, _av_pal_ctx, x10
    STRG xzr, _av_pal_view, x10
    STRG xzr, _av_pal_field, x10
    LGOT x0, __dispatch_main_q
    mov x1, #0
    adr x2, Lrun_later
    bl _dispatch_async_f
9:  ldp x29, x30, [sp], #16
    ret

    .p2align 2
Lrun_later:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    LDRG x19, _av_pal_run
    bl _av_tabs_refocus
    // the container holds the last reference
    LDRG x0, _av_pal_ctx
    cbz x0, 1f
    STRG xzr, _av_pal_ctx, x9
    MSG removeFromSuperview
1:  tbnz x19, #63, 9f
    cmp x19, #TAB_ITEM
    b.lo 2f
    sub x0, x19, #TAB_ITEM
    bl _av_tab_activate
    b 9f
2:  mov x0, x19
    bl _av_action
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// controlTextDidEndEditing: focus went elsewhere (a click on a pane or the tab bar)
    .p2align 2
Lpal_ended:
    mov x0, #-1
    b Lclose

// long selected_id(void): id of the highlighted item, -1 when nothing matches
    .p2align 2
Lselected_id:
    LDRG x9, _av_pal_n
    mov x0, #-1
    cbz x9, 1f
    LDRG x10, _av_pal_sel
    LADDR x11, _av_pal_order
    ldr x10, [x11, x10, lsl #3]
    mov x11, #IT_SIZE
    LADDR x12, _av_pal_items
    madd x10, x10, x11, x12
    ldr x0, [x10, #IT_ID]
1:  ret

// controlTextDidChange:
    .p2align 2
Lpal_changed:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lfilter
    bl _av_palette_layout
    ldp x29, x30, [sp], #16
    ret

// control:textView:doCommandBySelector: arrows move, return runs, escape closes
    .p2align 2
Lpal_command:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LSEL x9, moveUp
    cmp x4, x9
    b.eq 1f
    LSEL x9, moveDown
    cmp x4, x9
    b.eq 2f
    LSEL x9, insertNewline
    cmp x4, x9
    b.eq 3f
    LSEL x9, cancelOperation
    cmp x4, x9
    b.eq 4f
    mov w0, #0
    b 9f
1:  LDRG x9, _av_pal_sel
    subs x9, x9, #1
    csel x9, xzr, x9, lo
    b 5f
2:  LDRG x9, _av_pal_sel
    LDRG x10, _av_pal_n
    add x9, x9, #1
    cmp x9, x10
    sub x10, x10, #1
    csel x9, x10, x9, hs
    tbnz x9, #63, 8f
5:  STRG x9, _av_pal_sel, x10
    // keep the selection inside the visible rows
    LDRG x10, _av_pal_top
    cmp x9, x10
    csel x10, x9, x10, lo
    sub x11, x9, #(MAX_ROWS - 1)
    cmp x11, x10
    csel x10, x11, x10, gt
    STRG x10, _av_pal_top, x11
    LDRG x0, _av_pal_view
    mov x2, #1
    MSG setNeedsDisplay
    b 8f
3:  bl Lselected_id
    bl Lclose
    b 8f
4:  mov x0, #-1
    bl Lclose
8:  mov w0, #1
9:  ldp x29, x30, [sp], #16
    ret

// mouseDown: a click on a row runs it
    .p2align 2
Lpal_mouse:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x0, x2
    MSG locationInWindow
    mov x0, x19
    mov x2, #0
    MSG convertPoint
    str d1, [sp, #24]
    mov x0, x19
    MSG bounds
    // row from the top: (H - y - rows_top) / row_h
    ldr d1, [sp, #24]
    fsub d4, d3, d1
    str d4, [sp, #24]
    bl Lfield_h
    mov x9, #(PAD * 2)
    ucvtf d1, x9
    fadd d0, d0, d1
    ldr d4, [sp, #24]
    fsub d4, d4, d0
    str d4, [sp, #24]
    bl Lrow_h
    ldr d4, [sp, #24]
    fdiv d4, d4, d0
    fcvtms x9, d4
    tbnz x9, #63, 9f
    LDRG x10, _av_pal_top
    add x9, x9, x10
    LDRG x10, _av_pal_n
    cmp x9, x10
    b.hs 9f
    STRG x9, _av_pal_sel, x10
    bl Lselected_id
    bl Lclose
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// fill theme slot x1 over d0..d3 in the palette's context
.macro PFILL slot
    LDRG x0, _av_pal_ctx_draw
    LADDR x1, _av_theme
    add x1, x1, #\slot
    bl _av_fill
.endm

    .zerofill __DATA,__bss,_av_pal_ctx_draw,8,3

// drawRect: border, background, then the visible rows (label left, key right)
// x19 self, x20 row, x21 last row; d8 W, d9 H, d10 row h, d11 row bottom, d12 advance
    .p2align 2
Lpal_draw:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    stp d10, d11, [sp, #64]
    str d12, [sp, #80]
    mov x19, x0
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    STRG x0, _av_pal_ctx_draw, x9
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
    PFILL T_ACCENT
    fmov d0, #1.0
    fmov d1, #1.0
    fmov d4, #2.0
    fsub d2, d8, d4
    fsub d3, d9, d4
    PFILL T_TAB_ACTIVE
    bl Lrow_h
    fmov d10, d0
    LDRD d12, _av_adv
    // first row bottom = H - pad - field - pad - row
    bl Lfield_h
    mov x9, #(PAD * 2)
    ucvtf d1, x9
    fadd d0, d0, d1
    fsub d11, d9, d0
    LDRG x20, _av_pal_top
    LDRG x21, _av_pal_n
    add x9, x20, #MAX_ROWS
    cmp x21, x9
    csel x21, x9, x21, hi
1:  cmp x20, x21
    b.hs 9f
    fsub d11, d11, d10
    LDRG x9, _av_pal_sel
    cmp x9, x20
    b.ne 2f
    fmov d0, #4.0
    fmov d1, d11
    fmov d2, #8.0
    fsub d2, d8, d2
    fmov d3, d10
    PFILL T_SEL
2:  LADDR x9, _av_pal_order
    ldr x9, [x9, x20, lsl #3]
    mov x10, #IT_SIZE
    LADDR x11, _av_pal_items
    madd x22, x9, x10, x11
    add x0, x22, #IT_LABEL
    bl _strlen
    mov x2, x0
    add x1, x22, #IT_LABEL
    LDRG x0, _av_pal_ctx_draw
    ATTRS x3, T_TEXT
    fmov d0, #12.0
    LDRD d1, _av_base_off
    fmov d2, #2.0
    fadd d1, d1, d2
    fadd d1, d1, d11
    bl _av_draw_text
    // key, right aligned (ASCII)
    add x0, x22, #IT_KEY
    bl _strlen
    cbz x0, 3f
    mov x2, x0
    ucvtf d0, x2
    fmul d0, d0, d12
    fmov d1, #12.0
    fadd d0, d0, d1
    fsub d0, d8, d0
    add x1, x22, #IT_KEY
    LDRG x0, _av_pal_ctx_draw
    ATTRS x3, T_LINENR
    LDRD d1, _av_base_off
    fmov d2, #2.0
    fadd d1, d1, d2
    fadd d1, d1, d11
    bl _av_draw_text
3:  add x20, x20, #1
    b 1b
9:  ldr d12, [sp, #80]
    ldp d10, d11, [sp, #64]
    ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret
