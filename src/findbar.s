// find bar: incremental search in the focused editor pane, next/previous, replace one or all,
// match count; the pattern is shared with the renderer for highlighting

.include "macros.inc"
.include "objc.inc"
.include "doc.inc"
.include "theme.inc"
.include "keymap.inc"

.set PAT_MAX, 1024
.set FIND_ICASE, 1
.set LABEL_COLS, 14            // room for "123/4567" on the right
.set GAP, 6

    CLASSREF NSView
    CLASSREF NSString
    CLASSREF NSGraphicsContext

    SELDEF alloc, "alloc"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF addSubview, "addSubview:"
    SELDEF removeFromSuperview, "removeFromSuperview"
    SELDEF setFrame, "setFrame:"
    SELDEF setHidden, "setHidden:"
    SELDEF bounds, "bounds"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF setNextKeyView, "setNextKeyView:"
    SELDEF setStringValue, "setStringValue:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"
    SELDEF object, "object"
    SELDEF currentEvent, "currentEvent"
    SELDEF modifierFlags, "modifierFlags"
    SELDEF currentContext, "currentContext"
    SELDEF CGContext, "CGContext"
    SELDEF drawRect, "drawRect:"
    SELDEF textDidChange, "controlTextDidChange:"
    SELDEF doCommand, "control:textView:doCommandBySelector:"
    SELDEF insertNewline, "insertNewline:"
    SELDEF insertNewlineIgnoring, "insertNewlineIgnoringFieldEditor:"
    SELDEF cancelOperation, "cancelOperation:"

    .section __TEXT,__cstring,cstring_literals
Lfb_name:    .asciz "AvFindBar"
Lt_rect:     .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_obj:      .asciz "v@:@"
Lt_cmd:      .asciz "c@:@@:"
Ls_find:     .asciz "Find (\342\206\251 next, \342\207\247\342\206\251 previous, esc closes)"
Ls_replace:  .asciz "Replace with (\342\206\251 one, \342\214\245\342\206\251 all)"
Ls_none:     .asciz "no matches"
Lf_pos:      .asciz "%ld/%ld"
Lf_total:    .asciz "%ld found"
Lf_done:     .asciz "%ld replaced"

    .section __DATA,__const
    .p2align 3
Lfb_methods:
    .quad Lsr_drawRect, Lfb_draw, Lt_rect
    .quad Lsr_textDidChange, Lfb_changed, Lt_obj
    .quad Lsr_doCommand, Lfb_command, Lt_cmd
Lfb_methods_end:

    .zerofill __DATA,__bss,_av_fb_class,8,3
    .zerofill __DATA,__bss,_av_fb_view,8,3
    .zerofill __DATA,__bss,_av_fb_find,8,3
    .zerofill __DATA,__bss,_av_fb_rep,8,3
    .zerofill __DATA,__bss,_av_fb_target,8,3
    .zerofill __DATA,__bss,_av_fb_origin,8,3
    .zerofill __DATA,__bss,_av_fb_ctx,8,3
    .zerofill __DATA,__bss,_av_fb_label,64,3
    .zerofill __DATA,__bss,_av_find_pat,PAT_MAX,4
    .zerofill __DATA,__bss,_av_find_n,8,3
    .zerofill __DATA,__bss,_av_find_flags,8,3
    .zerofill __DATA,__bss,_av_find_hl,8,3
    .globl _av_find_pat
    .globl _av_find_flags
    .globl _av_find_hl

    .text
// Class fb_class(void): AvFindBar, built on first use
    .p2align 2
Lfb_class:
    LDRG x0, _av_fb_class
    cbz x0, 1f
    ret
1:  stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    CLS x0, NSView
    LADDR x1, Lfb_name
    mov x2, #0
    bl _objc_allocateClassPair
    mov x19, x0
    LADDR x20, Lfb_methods
    LADDR x21, Lfb_methods_end
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
    STRG x19, _av_fb_class, x9
    mov x0, x19
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// double field_h(void) / bar_h(void): one row, or two with the replace field
    .p2align 2
Lfield_h:
    LDRD d0, _av_line_h
    fmov d1, #6.0
    fadd d0, d0, d1
    ret

    .p2align 2
Lbar_h:
    LDRD d0, _av_line_h
    fmov d1, #12.0
    fadd d0, d0, d1
    LDRG x9, _av_fb_rep
    cbz x9, 1f
    fadd d0, d0, d0
1:  fmov d1, #6.0
    fadd d0, d0, d1
    ret

// View *target_view(void): state of the pane the bar belongs to, NULL when closed
    .p2align 2
Ltarget_view:
    LDRG x0, _av_fb_target
    cbz x0, 1f
    b _av_editor_state
1:  ret

// void set_pattern(void): field text into the shared pattern, smart case
    .p2align 2
Lset_pattern:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x0, _av_fb_find
    bl _av_ui_text
    mov x1, x0
    LADDR x0, _av_find_pat
    mov x2, #PAT_MAX
    bl _strlcpy
    LADDR x0, _av_find_pat
    bl _strlen
    STRG x0, _av_find_n, x9
    STRG x0, _av_find_hl, x9
    // ignore case unless the pattern has a capital
    LADDR x9, _av_find_pat
    mov x10, #FIND_ICASE
1:  ldrb w11, [x9], #1
    cbz w11, 2f
    sub w11, w11, #'A'
    cmp w11, #25
    b.hi 1b
    mov x10, #0
2:  STRG x10, _av_find_flags, x9
    ldp x29, x30, [sp], #16
    ret

// ssize_t find_from(Doc *d, size_t from): next match at or after from, wrapping to the start
    .p2align 2
Lfind_from:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    bl _av_buf_len
    mov x2, x0
    mov x0, x19
    mov x1, x20
    LADDR x3, _av_find_pat
    LDRG x4, _av_find_n
    LDRG x5, _av_find_flags
    bl _av_buf_find
    tbz x0, #63, 9f
    cbz x20, 9f
    mov x0, x19
    bl _av_buf_len
    mov x2, x0
    mov x0, x19
    mov x1, #0
    LADDR x3, _av_find_pat
    LDRG x4, _av_find_n
    LDRG x5, _av_find_flags
    bl _av_buf_find
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int is_match(Doc *d, size_t start, size_t end): [start, end) is exactly one match
    .p2align 2
Lis_match:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    LDRG x9, _av_find_n
    sub x10, x2, x1
    cmp x10, x9
    b.ne 8f
    cbz x9, 8f
    mov x19, x1
    LADDR x3, _av_find_pat
    mov x4, x9
    LDRG x5, _av_find_flags
    bl _av_buf_find
    cmp x0, x19
    cset w0, eq
    b 9f
8:  mov w0, #0
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void select_match(View *v, size_t pos): pos.. selected, scrolled into view
    .p2align 2
Lselect_match:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x9, _av_find_n
    add x9, x1, x9
    stp x9, x1, [x0, #V_CUR]
    mov x9, #-1
    str x9, [x0, #V_PREFCOL]
    STRG x1, _av_fb_origin, x9
    LDRG x0, _av_fb_target
    bl _av_editor_reveal
    ldp x29, x30, [sp], #16
    ret

// void update_label(void): "3/17", "17 found" or "no matches"
    .p2align 2
Lupdate_label:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    LADDR x9, _av_fb_label
    strb wzr, [x9]
    LDRG x9, _av_find_n
    cbz x9, 8f
    bl Ltarget_view
    cbz x0, 8f
    mov x21, x0
    ldr x19, [x21, #V_DOC]
    mov x0, x19
    bl _av_buf_len
    mov x1, x0
    mov x0, x19
    LADDR x2, _av_find_pat
    LDRG x3, _av_find_n
    LDRG x4, _av_find_flags
    bl _av_buf_count
    mov x20, x0
    cbnz x20, 1f
    LADDR x0, _av_fb_label
    LADDR x1, Ls_none
    mov x2, #64
    bl _strlcpy
    b 8f
1:  SEL_RANGE x21, x22, x2
    mov x0, x19
    mov x1, x22
    bl Lis_match
    cbz w0, 2f
    mov x0, x19
    mov x1, x22
    LADDR x2, _av_find_pat
    LDRG x3, _av_find_n
    LDRG x4, _av_find_flags
    bl _av_buf_count
    add x9, x0, #1
    sub sp, sp, #16
    stp x9, x20, [sp]
    LADDR x0, _av_fb_label
    mov x1, #64
    LADDR x2, Lf_pos
    bl _snprintf
    add sp, sp, #16
    b 8f
2:  sub sp, sp, #16
    str x20, [sp]
    LADDR x0, _av_fb_label
    mov x1, #64
    LADDR x2, Lf_total
    bl _snprintf
    add sp, sp, #16
8:  LDRG x0, _av_fb_view
    cbz x0, 9f
    mov x2, #1
    MSG setNeedsDisplay
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void search(void): as you type, from where the search started
    .p2align 2
Lsearch:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    bl Lset_pattern
    bl Ltarget_view
    cbz x0, 9f
    mov x19, x0
    LDRG x9, _av_find_n
    cbz x9, 2f
    ldr x0, [x19, #V_DOC]
    LDRG x1, _av_fb_origin
    bl Lfind_from
    tbnz x0, #63, 2f
    mov x1, x0
    mov x0, x19
    bl Lselect_match
    // typing refines the match in place
    b 8f
2:  LDRG x9, _av_fb_origin
    stp x9, x9, [x19, #V_CUR]
    LDRG x0, _av_fb_target
    bl _av_editor_reveal
8:  bl Lupdate_label
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void step(int back): next match after the selection, or the previous one before it
    .p2align 2
Lstep:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x20, x0
    LDRG x9, _av_find_n
    cbz x9, 9f
    bl Ltarget_view
    cbz x0, 9f
    mov x19, x0
    ldr x21, [x19, #V_DOC]
    SEL_RANGE x19, x1, x2
    cbnz x20, 1f
    mov x0, x21
    mov x1, x2
    bl Lfind_from
    b 3f
1:  mov x0, x21
    LADDR x2, _av_find_pat
    LDRG x3, _av_find_n
    LDRG x4, _av_find_flags
    bl _av_buf_find_back
    tbz x0, #63, 3f
    mov x0, x21
    bl _av_buf_len
    mov x1, x0
    mov x0, x21
    LADDR x2, _av_find_pat
    LDRG x3, _av_find_n
    LDRG x4, _av_find_flags
    bl _av_buf_find_back
3:  tbnz x0, #63, 8f
    mov x1, x0
    mov x0, x19
    bl Lselect_match
8:  bl Lupdate_label
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void replace_one(void): the selected match becomes the replacement, then on to the next
    .p2align 2
Lreplace_one:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    bl Ltarget_view
    cbz x0, 9f
    mov x19, x0
    SEL_RANGE x19, x1, x2
    ldr x0, [x19, #V_DOC]
    bl Lis_match
    cbz w0, 8f
    LDRG x0, _av_fb_rep
    bl _av_ui_text
    mov x20, x0
    bl _strlen
    mov x2, x0
    mov x0, x19
    mov x1, x20
    mov x3, #0
    bl _av_view_insert
8:  mov x0, #0
    bl Lstep
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void replace_all(void): one undo step, the count goes in the label
    .p2align 2
Lreplace_all:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    LDRG x9, _av_find_n
    cbz x9, 9f
    bl Ltarget_view
    cbz x0, 9f
    mov x19, x0
    LDRG x0, _av_fb_rep
    bl _av_ui_text
    mov x20, x0
    bl _strlen
    mov x4, x0
    ldr x0, [x19, #V_DOC]
    LADDR x1, _av_find_pat
    LDRG x2, _av_find_n
    mov x3, x20
    LDRG x5, _av_find_flags
    bl _av_doc_replace_all
    mov x21, x0
    ldr x9, [x19, #V_CUR]
    str x9, [x19, #V_ANCHOR]
    LDRG x0, _av_fb_target
    bl _av_editor_reveal
    sub sp, sp, #16
    str x21, [sp]
    LADDR x0, _av_fb_label
    mov x1, #64
    LADDR x2, Lf_done
    bl _snprintf
    add sp, sp, #16
    LDRG x0, _av_fb_view
    mov x2, #1
    MSG setNeedsDisplay
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void remove_now(void): bar out of the window, highlights off
    .p2align 2
Lremove_now:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    STRG xzr, _av_find_hl, x9
    LDRG x0, _av_fb_view
    cbz x0, 9f
    STRG xzr, _av_fb_view, x9
    STRG xzr, _av_fb_find, x9
    STRG xzr, _av_fb_rep, x9
    STRG xzr, _av_fb_target, x9
    MSG removeFromSuperview
9:  ldp x29, x30, [sp], #16
    ret

// deferred close (escape): the field must not go away while AppKit is inside it
    .p2align 2
Lclose_later:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LDRG x0, _av_fb_target
    cbz x0, 1f
    mov x2, #1
    MSG setNeedsDisplay
1:  bl _av_tabs_refocus
    bl Lremove_now
    bl _av_tabs_layout
    ldp x29, x30, [sp], #16
    ret

// void av_findbar_open(int replace): find (or find and replace) in the focused editor pane
FUNC_BEGIN _av_findbar_open
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x22, x0
    bl _av_tabs_current_doc
    cbz x0, 8f
    bl _av_tabs_current_view
    mov x19, x0
    // already open on this pane in this mode: just focus it
    LDRG x9, _av_fb_view
    cbz x9, 1f
    LDRG x10, _av_fb_target
    LDRG x11, _av_fb_rep
    cmp x11, #0
    cset x11, ne
    cmp x10, x19
    ccmp x11, x22, #0, eq
    b.eq 7f
    bl Lremove_now
1:  STRG x19, _av_fb_target, x9
    mov x0, x19
    bl _av_editor_state
    mov x20, x0
    SEL_RANGE x20, x21, x10
    STRG x21, _av_fb_origin, x9
    bl Lfb_class
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    STRG x0, _av_fb_view, x9
    LADDR x1, Ls_find
    bl _av_ui_field
    STRG x0, _av_fb_find, x9
    mov x2, x0
    LDRG x0, _av_fb_view
    MSG addSubview
    LDRG x0, _av_fb_find
    MSG release
    cbz x22, 2f
    LDRG x0, _av_fb_view
    LADDR x1, Ls_replace
    bl _av_ui_field
    STRG x0, _av_fb_rep, x9
    mov x2, x0
    LDRG x0, _av_fb_view
    MSG addSubview
    LDRG x0, _av_fb_rep
    MSG release
    // tab moves between the two fields
    LDRG x0, _av_fb_find
    LDRG x2, _av_fb_rep
    MSG setNextKeyView
    LDRG x0, _av_fb_rep
    LDRG x2, _av_fb_find
    MSG setNextKeyView
    // a one line selection seeds the pattern, else the last one stays
2:  SEL_RANGE x20, x21, x10
    sub x2, x10, x21
    cbz x2, 3f
    cmp x2, #(PAT_MAX - 1)
    b.hs 3f
    str x2, [sp, #48]
    ldr x0, [x20, #V_DOC]
    mov x1, x21
    LADDR x9, _av_find_pat
    mov x3, x2
    mov x2, x9
    bl _av_buf_copy
    ldr x2, [sp, #48]
    LADDR x9, _av_find_pat
    strb wzr, [x9, x2]
    mov x0, x9
    mov w1, #10
    bl _strchr
    cbz x0, 3f
    LADDR x9, _av_find_pat
    strb wzr, [x9]
3:  CLS x0, NSString
    LADDR x2, _av_find_pat
    MSG stringWithUTF8String
    mov x2, x0
    LDRG x0, _av_fb_find
    MSG setStringValue
    LDRG x0, _av_container
    LDRG x2, _av_fb_view
    MSG addSubview
    LDRG x0, _av_fb_view
    MSG release
    bl _av_tabs_layout
    bl Lset_pattern
    bl Lupdate_label
7:  LDRG x0, _av_fb_find
    bl _av_ui_focus_field
    b 9f
8:  bl _NSBeep
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_find_step(int back): find next/previous (⌘G), opens the bar the first time
FUNC_BEGIN _av_find_step
    LDRG x9, _av_fb_view
    cbz x9, 1f
    LDRG x9, _av_find_n
    cbz x9, 1f
    b Lstep
1:  mov x0, #0
    b _av_findbar_open

// void av_findbar_hide(void): hidden until its pane is laid out again
FUNC_BEGIN _av_findbar_hide
    LDRG x0, _av_fb_view
    cbz x0, 1f
    mov x2, #1
    LSEL x1, setHidden
    b _objc_msgSend
1:  ret

// void av_findbar_forget(NSView *pane): the pane is closing, the bar goes with it
FUNC_BEGIN _av_findbar_forget
    LDRG x9, _av_fb_target
    cmp x9, x0
    b.ne 1f
    cbz x9, 1f
    b Lremove_now
1:  ret

// (x, y, w, h) av_findbar_fit(NSView *pane, x, y, w, h): pane frame in the flipped container;
// when the bar belongs to the pane it takes the bottom and the rest is returned
FUNC_BEGIN _av_findbar_fit
    LDRG x9, _av_fb_target
    cmp x9, x0
    b.ne 1f
    LDRG x9, _av_fb_view
    cbnz x9, 2f
1:  ret
2:  stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp d8, d9, [sp, #16]
    stp d10, d11, [sp, #32]
    stp d12, d13, [sp, #48]
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    bl Lbar_h
    fmov d12, d0
    fsub d11, d11, d12
    LDRG x0, _av_fb_view
    mov x2, #0
    MSG setHidden
    LDRG x0, _av_fb_view
    fmov d0, d8
    fadd d1, d9, d11
    fmov d2, d10
    fmov d3, d12
    MSG setFrame
    // fields from the top of the (unflipped) bar, the label column on the right
    LDRD d0, _av_adv
    mov x9, #LABEL_COLS
    ucvtf d1, x9
    fmul d0, d0, d1
    fsub d13, d10, d0
    fmov d0, #8.0
    fsub d13, d13, d0
    bl Lfield_h
    fmov d3, d0
    fsub d1, d12, d0
    fmov d0, #6.0
    fsub d1, d1, d0
    fmov d0, #8.0
    fmov d2, d13
    stp d1, d3, [sp, #64]
    LDRG x0, _av_fb_find
    MSG setFrame
    LDRG x0, _av_fb_rep
    cbz x0, 3f
    ldp d1, d3, [sp, #64]
    fsub d1, d1, d3
    fmov d0, #6.0
    fsub d1, d1, d0
    fmov d0, #8.0
    fmov d2, d13
    MSG setFrame
3:  fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d11
    ldp d12, d13, [sp, #48]
    ldp d10, d11, [sp, #32]
    ldp d8, d9, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// controlTextDidChange: typing in the find field searches again
    .p2align 2
Lfb_changed:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x2
    MSG object
    LDRG x9, _av_fb_find
    cmp x0, x9
    b.ne 1f
    bl Lsearch
1:  ldp x29, x30, [sp], #16
    ret

// control:textView:doCommandBySelector: return steps or replaces, option-return replaces
// all, escape closes
    .p2align 2
Lfb_command:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x2
    LSEL x9, insertNewline
    cmp x4, x9
    b.eq 1f
    LSEL x9, insertNewlineIgnoring
    cmp x4, x9
    b.eq 2f
    LSEL x9, cancelOperation
    cmp x4, x9
    b.eq 3f
    mov w0, #0
    b 9f
1:  LDRG x9, _av_fb_rep
    cmp x19, x9
    b.ne 11f
    bl Lreplace_one
    b 8f
    // shift-return goes back
11: LDRG x0, _av_app
    MSG currentEvent
    MSG modifierFlags
    ubfx x0, x0, #17, #1
    bl Lstep
    b 8f
2:  LDRG x9, _av_fb_rep
    cmp x19, x9
    b.ne 11b
    bl Lreplace_all
    b 8f
3:  LGOT x0, __dispatch_main_q
    mov x1, #0
    adr x2, Lclose_later
    bl _dispatch_async_f
8:  mov w0, #1
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .zerofill __DATA,__bss,_av_fb_ctx_draw,8,3

// drawRect: background, a line on top, the match count right of the find field
    .p2align 2
Lfb_draw:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    str d10, [sp, #40]
    mov x19, x0
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    STRG x0, _av_fb_ctx_draw, x9
    LGOT x1, _CGAffineTransformIdentity
    bl _CGContextSetTextMatrix
    mov x0, x19
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    LDRG x0, _av_fb_ctx_draw
    LADDR x1, _av_theme
    add x1, x1, #T_GUTTER
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d9
    bl _av_fill
    LDRG x0, _av_fb_ctx_draw
    LADDR x1, _av_theme
    add x1, x1, #T_INDENT
    movi d0, #0
    fmov d1, #1.0
    fsub d1, d9, d1
    fmov d2, d8
    fmov d3, #1.0
    bl _av_fill
    LADDR x0, _av_fb_label
    bl _strlen
    cbz x0, 9f
    str x0, [sp, #48]
    // baseline of the find row: top - 6 - field + 3
    bl Lfield_h
    fsub d10, d9, d0
    fmov d0, #3.0
    fsub d10, d10, d0
    LDRD d0, _av_base_off
    fadd d10, d10, d0
    LDRD d0, _av_adv
    mov x9, #(LABEL_COLS - 1)
    ucvtf d1, x9
    fmul d0, d0, d1
    fsub d0, d8, d0
    fmov d1, d10
    ldr x2, [sp, #48]
    LDRG x0, _av_fb_ctx_draw
    LADDR x1, _av_fb_label
    ATTRS x3, T_LINENR
    bl _av_draw_text
9:  ldr d10, [sp, #40]
    ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
