// headless render of a view to PNG, used for visual checks without screen recording rights

.include "macros.inc"
.include "objc.inc"
.include "theme.inc"

.set NSBitmapImageFileTypePNG, 4
.set NSEventTypeKeyDown, 10
.set NSUTF8StringEncoding, 4

    CLASSREF NSDictionary
    CLASSREF NSString
    CLASSREF NSEvent

    SELDEF bounds, "bounds"
    SELDEF bitmapRep, "bitmapImageRepForCachingDisplayInRect:"
    SELDEF cacheDisplay, "cacheDisplayInRect:toBitmapImageRep:"
    SELDEF dictionary, "dictionary"
    SELDEF representation, "representationUsingType:properties:"
    SELDEF stringWithUTF8String, "stringWithUTF8String:"
    SELDEF writeToFile, "writeToFile:atomically:"
    SELDEF alloc, "alloc"
    SELDEF release, "release"
    SELDEF initWithBytes, "initWithBytes:length:encoding:"
    SELDEF keyEvent, "keyEventWithType:location:modifierFlags:timestamp:windowNumber:context:characters:charactersIgnoringModifiers:isARepeat:keyCode:"
    SELDEF keyDown, "keyDown:"
    SELDEF undo, "undo:"
    SELDEF selectAll, "selectAll:"
    SELDEF firstResponder, "firstResponder"

    .text
// int av_snapshot(NSView *view, const char *png_path)
FUNC_BEGIN _av_snapshot
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    MSG bounds
    stp d0, d1, [sp, #48]
    stp d2, d3, [sp, #64]
    mov x0, x19
    MSG bitmapRep
    mov x21, x0
    mov x0, x19
    ldp d0, d1, [sp, #48]
    ldp d2, d3, [sp, #64]
    mov x2, x21
    MSG cacheDisplay
    CLS x0, NSDictionary
    MSG dictionary
    mov x3, x0
    mov x0, x21
    mov x2, #NSBitmapImageFileTypePNG
    MSG representation
    mov x22, x0
    CLS x0, NSString
    mov x2, x20
    MSG stringWithUTF8String
    mov x2, x0
    mov x0, x22
    mov x3, #0
    MSG writeToFile
    and w0, w0, #0xff
    eor w0, w0, #1
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// void av_snapshot_type(NSView *unused, const char *keys), synthetic ASCII key events to the first responder
// \n return, \b backspace, 0x1c..0x1f left/right/up/down, 0x1a undo:, 0x01 selectAll:, 0x14 next theme,
// 0x13 control-s (the default prefix), 0x10 runs the run loop for 0.5 s (terminal output)
FUNC_BEGIN _av_snapshot_type
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    sub sp, sp, #16
    mov x19, x0
    mov x20, x1
1:  ldrb w21, [x20], #1
    cbz w21, 9f
    cmp w21, #0x10
    b.ne 11f
    LEXTERN x0, _kCFRunLoopDefaultMode
    fmov d0, #0.5
    mov w1, #0
    bl _CFRunLoopRunInMode
    b 1b
11: cmp w21, #0x1a
    b.ne 2f
    bl _av_tabs_current_view
    mov x2, #0
    MSG undo
    b 1b
2:  cmp w21, #0x14
    b.ne 5f
    LDRG x0, _av_theme_index
    add x0, x0, #1
    cmp x0, #THEME_COUNT
    csel x0, x0, xzr, lo
    bl _av_theme_apply
    b 1b
5:  cmp w21, #0x01
    b.ne 3f
    bl _av_tabs_current_view
    mov x2, #0
    MSG selectAll
    b 1b
    // key code from the control byte, AppKit dispatch in keyDown: is by key code
3:  mov x22, #0
    mov x24, #0
    cmp w21, #0x13
    b.ne 31f
    mov x24, #0x40000
    mov w21, #'s'
    mov x22, #1
    b 4f
31: cmp w21, #10
    mov x9, #36
    csel x22, x9, x22, eq
    mov w9, #13
    csel w21, w9, w21, eq
    cmp w21, #8
    mov x9, #51
    csel x22, x9, x22, eq
    mov w9, #0x7f
    csel w21, w9, w21, eq
    sub w10, w21, #0x1c
    cmp w10, #3
    b.hi 4f
    LADDR x9, Larrow_codes
    ldrb w22, [x9, x10]
    mov w21, #' '
4:  strb w21, [sp, #8]
    CLS x0, NSString
    MSG alloc
    add x2, sp, #8
    mov x3, #1
    mov x4, #NSUTF8StringEncoding
    MSG initWithBytes
    mov x23, x0
    // isARepeat and keyCode go on the stack at their natural alignment
    strb wzr, [sp]
    strh w22, [sp, #2]
    CLS x0, NSEvent
    mov x2, #NSEventTypeKeyDown
    movi d0, #0
    movi d1, #0
    mov x3, x24
    movi d2, #0
    mov x4, #0
    mov x5, #0
    mov x6, x23
    mov x7, x23
    MSG keyEvent
    // to the first responder, like a real key: a pane, the palette or the find bar
    mov x19, x0
    LDRG x0, _av_window
    MSG firstResponder
    mov x2, x19
    MSG keyDown
    mov x0, x23
    MSG release
    b 1b
9:  add sp, sp, #16
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

    .section __TEXT,__const
Larrow_codes:
    .byte 123, 124, 126, 125
