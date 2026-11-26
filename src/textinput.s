// NSTextInputClient for AvEditorView: dead keys, IMEs, the accent menu, emoji and dictation
// marked (still composing) text stays out of the buffer, the renderer draws it at the cursor;
// ranges are UTF-16 offsets inside the cursor's line, enough for input methods

.include "macros.inc"
.include "objc.inc"
.include "buffer.inc"
.include "doc.inc"

.set MK_MAX, 256
.set NSNotFound, 0x7fffffffffffffff

    CLASSREF NSAttributedString
    CLASSREF NSArray

    SELDEF isKindOfClass, "isKindOfClass:"
    SELDEF string, "string"
    SELDEF UTF8String, "UTF8String"
    SELDEF array, "array"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF window, "window"
    SELDEF convertRectToView, "convertRect:toView:"
    SELDEF convertRectToScreen, "convertRectToScreen:"
    SELDEF bounds, "bounds"
    SELDEF insertTextRange, "insertText:replacementRange:"
    SELDEF setMarkedText, "setMarkedText:selectedRange:replacementRange:"
    SELDEF unmarkText, "unmarkText"
    SELDEF hasMarkedText, "hasMarkedText"
    SELDEF markedRange, "markedRange"
    SELDEF selectedRange, "selectedRange"
    SELDEF attributedSubstring, "attributedSubstringForProposedRange:actualRange:"
    SELDEF validAttributes, "validAttributesForMarkedText"
    SELDEF firstRect, "firstRectForCharacterRange:actualRange:"
    SELDEF characterIndex, "characterIndexForPoint:"
    SELDEF doCommand, "doCommandBySelector:"

    .section __TEXT,__cstring,cstring_literals
Lproto:     .asciz "NSTextInputClient"
Lt_insert:  .asciz "v@:@{_NSRange=QQ}"
Lt_mark:    .asciz "v@:@{_NSRange=QQ}{_NSRange=QQ}"
Lt_void:    .asciz "v@:"
Lt_bool:    .asciz "c@:"
Lt_range:   .asciz "{_NSRange=QQ}@:"
Lt_sub:     .asciz "@@:{_NSRange=QQ}^{_NSRange=QQ}"
Lt_obj:     .asciz "@@:"
Lt_rect:    .asciz "{CGRect={CGPoint=dd}{CGSize=dd}}@:{_NSRange=QQ}^{_NSRange=QQ}"
Lt_index:   .asciz "Q@:{CGPoint=dd}"
Lt_cmd:     .asciz "v@::"

    // selector slot, IMP, type encoding
    .section __DATA,__const
    .p2align 3
Lmethods:
    .quad Lsr_insertTextRange, Lti_insert, Lt_insert
    .quad Lsr_setMarkedText, Lti_set_marked, Lt_mark
    .quad Lsr_unmarkText, Lti_unmark, Lt_void
    .quad Lsr_hasMarkedText, Lti_has_marked, Lt_bool
    .quad Lsr_markedRange, Lti_marked_range, Lt_range
    .quad Lsr_selectedRange, Lti_selected_range, Lt_range
    .quad Lsr_attributedSubstring, Lti_nil, Lt_sub
    .quad Lsr_validAttributes, Lti_valid_attrs, Lt_obj
    .quad Lsr_firstRect, Lti_first_rect, Lt_rect
    .quad Lsr_characterIndex, Lti_char_index, Lt_index
    .quad Lsr_doCommand, Lti_do_command, Lt_cmd
Lmethods_end:

    .zerofill __DATA,__bss,_av_mk_view,8,3
    .zerofill __DATA,__bss,_av_mk_len,8,3
    .zerofill __DATA,__bss,_av_mk_text,MK_MAX,3
    .globl _av_mk_view
    .globl _av_mk_len
    .globl _av_mk_text

    .text
// void av_textinput_add(Class c): the protocol and its methods on the editor view class
FUNC_BEGIN _av_textinput_add
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
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
    // without the protocol NSView hands out no input context
2:  LADDR x0, Lproto
    bl _objc_getProtocol
    cbz x0, 9f
    mov x1, x0
    mov x0, x19
    bl _class_addProtocol
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_textinput_composing(NSView *v): v holds marked text
FUNC_BEGIN _av_textinput_composing
    LDRG x9, _av_mk_view
    LDRG x10, _av_mk_len
    cmp x9, x0
    ccmp x10, #0, #4, eq
    cset w0, ne
    ret

// View *state(NSView *v)
    .p2align 2
Lstate:
    LDRG x9, _av_ev_ivar
    ldr x0, [x0, x9]
    ret

// const char *utf8_of(id s): NSString or NSAttributedString as UTF-8, "" when empty
    .p2align 2
Lutf8_of:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    CLS x2, NSAttributedString
    MSG isKindOfClass
    tst w0, #0xff
    b.eq 1f
    mov x0, x19
    MSG string
    mov x19, x0
1:  mov x0, x19
    MSG UTF8String
    cbnz x0, 2f
    adr x0, Lempty
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
Lempty:
    .byte 0
    .p2align 2

// size_t u16_len(const char *s, size_t n): UTF-16 units of n UTF-8 bytes
    .p2align 2
Lu16_len:
    mov x2, #0
    mov x3, #0
1:  cmp x3, x1
    b.hs 3f
    ldrb w4, [x0, x3]
    add x3, x3, #1
    and w5, w4, #0xc0
    cmp w5, #0x80
    b.eq 1b
    add x2, x2, #1
    // four byte sequences are surrogate pairs
    cmp w4, #0xf0
    cinc x2, x2, hs
    b 1b
3:  mov x0, x2
    ret

// (line start, cursor offset) cursor_u16(View *v): UTF-16 units from the line start to the cursor
    .p2align 2
Lcursor_u16:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x20, [x19, #V_DOC]
    ldr x1, [x19, #V_CUR]
    mov x0, x20
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x20
    bl _av_buf_line_start
    mov x1, x0
    ldr x2, [x19, #V_CUR]
    mov x3, #0
    BUF_GEOM x20
    mov x5, x1
1:  cmp x5, x2
    b.hs 3f
    BUF_BYTE w4, x5
    add x5, x5, #1
    and w6, w4, #0xc0
    cmp w6, #0x80
    b.eq 1b
    add x3, x3, #1
    cmp w4, #0xf0
    cinc x3, x3, hs
    b 1b
3:  mov x0, x1
    mov x1, x3
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t pos_at_u16(Doc *d, size_t ls, size_t u16): byte position u16 units into the line at ls
    .p2align 2
Lpos_at_u16:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl _av_buf_line_of
    mov x1, x0
    mov x0, x19
    bl _av_buf_line_end
    mov x22, x0
    mov x2, x20
    mov x3, #0
    BUF_GEOM x19
1:  cmp x2, x22
    b.hs 9f
    cmp x3, x21
    b.hs 9f
    BUF_BYTE w4, x2
    add x3, x3, #1
    cmp w4, #0xf0
    cinc x3, x3, hs
    // skip the continuation bytes of this character
2:  add x2, x2, #1
    cmp x2, x22
    b.hs 9f
    BUF_BYTE w4, x2
    and w4, w4, #0xc0
    cmp w4, #0x80
    b.eq 2b
    b 1b
9:  mov x0, x2
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void clear(void): no marked text anywhere
    .p2align 2
Lclear:
    STRG xzr, _av_mk_len, x9
    STRG xzr, _av_mk_view, x9
    ret

// insertText:replacementRange: committed text, replacing the given range of the line if any
// (the accent menu replaces the letter typed before it)
    .p2align 2
Lti_insert:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x21, x2
    mov x22, x3
    mov x23, x4
    bl Lclear
    mov x0, x19
    bl Lstate
    mov x20, x0
    ldr x9, =NSNotFound
    cmp x22, x9
    b.eq 1f
    mov x0, x20
    bl Lcursor_u16
    mov x24, x0
    ldr x0, [x20, #V_DOC]
    mov x1, x24
    mov x2, x22
    bl Lpos_at_u16
    str x0, [x20, #V_ANCHOR]
    ldr x0, [x20, #V_DOC]
    mov x1, x24
    add x2, x22, x23
    bl Lpos_at_u16
    str x0, [x20, #V_CUR]
1:  mov x0, x21
    bl Lutf8_of
    mov x21, x0
    bl _strlen
    cbz x0, 2f
    mov x2, x0
    mov x0, x20
    mov x1, x21
    mov x3, #1
    bl _av_view_insert
2:  mov x0, x19
    bl _av_editor_reveal
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// setMarkedText:selectedRange:replacementRange: text being composed, cut on a character boundary
    .p2align 2
Lti_set_marked:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x0, x2
    bl Lutf8_of
    mov x20, x0
    bl _strlen
    mov x2, x0
    cmp x2, #(MK_MAX - 1)
    b.lo 2f
    mov x2, #(MK_MAX - 1)
1:  ldrb w9, [x20, x2]
    and w9, w9, #0xc0
    cmp w9, #0x80
    b.ne 2f
    sub x2, x2, #1
    b 1b
2:  STRG x2, _av_mk_len, x9
    LADDR x0, _av_mk_text
    mov x1, x20
    bl _memcpy
    LDRG x9, _av_mk_len
    cmp x9, #0
    csel x9, xzr, x19, eq
    STRG x9, _av_mk_view, x10
    mov x0, x19
    mov x2, #1
    MSG setNeedsDisplay
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// unmarkText: the composed text is accepted as typed
    .p2align 2
Lti_unmark:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    bl _av_textinput_composing
    cbz w0, 9f
    LDRG x20, _av_mk_len
    bl Lclear
    mov x0, x19
    bl Lstate
    LADDR x1, _av_mk_text
    mov x2, x20
    mov x3, #1
    bl _av_view_insert
    mov x0, x19
    bl _av_editor_reveal
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .p2align 2
Lti_has_marked:
    b _av_textinput_composing

// markedRange: right after the cursor while composing
    .p2align 2
Lti_marked_range:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _av_textinput_composing
    cbz w0, 1f
    mov x0, x19
    bl Lstate
    bl Lcursor_u16
    mov x19, x1
    LADDR x0, _av_mk_text
    LDRG x1, _av_mk_len
    bl Lu16_len
    mov x1, x0
    mov x0, x19
    b 9f
1:  ldr x0, =NSNotFound
    mov x1, #0
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// selectedRange: an empty range at the cursor, after any marked text
    .p2align 2
Lti_selected_range:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    bl Lstate
    bl Lcursor_u16
    mov x20, x1
    mov x0, x19
    bl _av_textinput_composing
    cbz w0, 1f
    LADDR x0, _av_mk_text
    LDRG x1, _av_mk_len
    bl Lu16_len
    add x20, x20, x0
1:  mov x0, x20
    mov x1, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .p2align 2
Lti_nil:
    mov x0, #0
    ret

    .p2align 2
Lti_valid_attrs:
    CLS x0, NSArray
    LSEL x1, array
    b _objc_msgSend

// firstRectForCharacterRange:actualRange: the cursor cell in screen coordinates, where input
// methods put their candidate window
    .p2align 2
Lti_first_rect:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    cbz x4, 1f
    stp x2, x3, [x4]
1:  LDRG x9, _av_cur_view
    cmp x9, x19
    b.ne 2f
    LDRD d0, _av_cur_x
    LDRD d1, _av_cur_y
    b 3f
2:  movi d0, #0
    movi d1, #0
3:  LDRD d2, _av_adv
    LDRD d3, _av_line_h
    mov x0, x19
    mov x2, #0
    MSG convertRectToView
    stp d0, d1, [sp, #32]
    stp d2, d3, [sp, #48]
    mov x0, x19
    MSG window
    mov x20, x0
    ldp d0, d1, [sp, #32]
    ldp d2, d3, [sp, #48]
    cbz x20, 4f
    mov x0, x20
    MSG convertRectToScreen
4:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

    .p2align 2
Lti_char_index:
    ldr x0, =NSNotFound
    ret

// doCommandBySelector: keys the input method did not consume; the editor handles its keys
// before the input method sees them, so nothing is left to do
    .p2align 2
Lti_do_command:
    ret
