// headless render of a view to PNG, used for visual checks without screen recording rights

.include "macros.inc"
.include "objc.inc"
.include "theme.inc"
.include "doc.inc"

.set NSBitmapImageFileTypePNG, 4
.set NSEventTypeKeyDown, 10
.set NSUTF8StringEncoding, 4
.set CLOCK_UPTIME_RAW, 8

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

// one offscreen redraw of view x20 into rep x21, bounds saved at sp+64
.macro BENCH_FRAME
    mov x0, x20
    ldp d0, d1, [sp, #64]
    ldp d2, d3, [sp, #80]
    mov x2, x21
    MSG cacheDisplay
.endm

    .section __TEXT,__cstring,cstring_literals
Lfmt_bench: .asciz "bench: startup %ld ms, still %ld us/frame, scrolling %ld us/frame (%ld frames)\n"

    .text
// void av_bench(long frames): renders the focused pane offscreen, still then scrolling one row
// per frame (editors), and prints the averages with the time since launch on stderr
FUNC_BEGIN _av_bench
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    cmp x19, #1
    mov x9, #1
    csel x19, x9, x19, lt
    mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    LDRG x9, _av_t0
    sub x24, x0, x9
    bl _av_tabs_current_view
    cbz x0, 9f
    mov x20, x0
    MSG bounds
    stp d0, d1, [sp, #64]
    stp d2, d3, [sp, #80]
    mov x0, x20
    MSG bitmapRep
    mov x21, x0
    mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    mov x22, x0
    mov x23, #0
1:  cmp x23, x19
    b.hs 2f
    BENCH_FRAME
    add x23, x23, #1
    b 1b
2:  mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    sub x22, x0, x22
    str x22, [sp, #96]
    bl _av_tabs_current_doc
    str xzr, [sp, #104]
    cbz x0, 4f
    mov x0, x20
    bl _av_editor_state
    str x0, [sp, #112]
    mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    mov x22, x0
    mov x23, #0
3:  cmp x23, x19
    b.hs 31f
    ldr x9, [sp, #112]
    ldr d0, [x9, #V_SCROLLY]
    LDRD d1, _av_line_h
    fadd d0, d0, d1
    str d0, [x9, #V_SCROLLY]
    BENCH_FRAME
    add x23, x23, #1
    b 3b
31: mov w0, #CLOCK_UPTIME_RAW
    bl _clock_gettime_nsec_np
    sub x22, x0, x22
    str x22, [sp, #104]
    // milliseconds and microseconds per frame
4:  mov x9, #1000
    ldr x10, =1000000
    udiv x0, x24, x10
    ldr x1, [sp, #96]
    udiv x1, x1, x19
    udiv x1, x1, x9
    ldr x2, [sp, #104]
    udiv x2, x2, x19
    udiv x2, x2, x9
    sub sp, sp, #32
    stp x0, x1, [sp]
    stp x2, x19, [sp, #16]
    mov w0, #2
    LADDR x1, Lfmt_bench
    bl _dprintf
    add sp, sp, #32
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret

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
