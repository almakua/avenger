// AvTermView: terminal tab, pty output fed to vt.s from a run loop source, cells drawn with CoreText

.include "macros.inc"
.include "objc.inc"
.include "theme.inc"
.include "keymap.inc"
.include "vt.inc"

// Term, one per terminal tab (arena, the vt and the pty are released on close)
.set TM_VT,        0
.set TM_FD,        8
.set TM_PID,       16
.set TM_NSVIEW,    24
.set TM_CFFD,      32
.set TM_SRC,       40
.set TM_OFF,       48          // lines scrolled back into the scrollback
.set TM_SEL_A,     56          // selection ends: line * 1024 + column, lines < 0 in the scrollback
.set TM_SEL_B,     64
.set TM_SELON,     72
.set TM_ACC,       80          // scroll wheel remainder, points
.set TM_TITLE_GEN, 88
.set TM_DEAD,      96
.set TM_BELL,      104
.set TM_SIZE,      128

.set NSUTF8StringEncoding, 4
.set CF_READ_CB,  1
.set READ_MAX,    65536
.set READ_BUDGET, 0x100000
.set EINTR,  4
.set EAGAIN, 35
.set SEL_SHIFT, 10

// special keys: key code, kind, final byte or number
.set K_CSI,   1                // CSI letter, SS3 when the application cursor mode is on
.set K_SS3,   2
.set K_TILDE, 3

// drawRect locals
.set D_SS,    160
.set D_SE,    168
.set D_RGBA,  176
.set D_NB,    208
.set D_NBC,   216
.set D_OFF,   224
.set D_FRAME, 240

    CLASSREF NSView
    CLASSREF NSGraphicsContext
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
    SELDEF paste, "paste:"

    SELDEF alloc, "alloc"
    SELDEF release, "release"
    SELDEF initWithFrame, "initWithFrame:"
    SELDEF currentContext, "currentContext"
    SELDEF CGContext, "CGContext"
    SELDEF bounds, "bounds"
    SELDEF setNeedsDisplay, "setNeedsDisplay:"
    SELDEF modifierFlags, "modifierFlags"
    SELDEF keyCode, "keyCode"
    SELDEF characters, "characters"
    SELDEF charsIgnoring, "charactersIgnoringModifiers"
    SELDEF UTF8String, "UTF8String"
    SELDEF locationInWindow, "locationInWindow"
    SELDEF convertPoint, "convertPoint:fromView:"
    SELDEF clickCount, "clickCount"
    SELDEF scrollingDeltaY, "scrollingDeltaY"
    SELDEF hasPrecise, "hasPreciseScrollingDeltas"
    SELDEF generalPasteboard, "generalPasteboard"
    SELDEF clearContents, "clearContents"
    SELDEF setStringForType, "setString:forType:"
    SELDEF stringForType, "stringForType:"
    SELDEF initWithBytes, "initWithBytes:length:encoding:"

    .section __TEXT,__cstring,cstring_literals
Lclass_name: .asciz "AvTermView"
Livar_name:  .asciz "st"
Livar_type:  .asciz "^v"
Lt_rect:     .asciz "v@:{CGRect={CGPoint=dd}{CGSize=dd}}"
Lt_bool:     .asciz "c@:"
Lt_obj:      .asciz "v@:@"
Ls_term:     .asciz "terminal"
Ls_paste_on:  .asciz "\033[200~"
Ls_paste_off: .asciz "\033[201~"

    .section __DATA,__const
    .p2align 3
Lmethods:
    .quad Lsr_drawRect, Ltm_draw, Lt_rect
    .quad Lsr_acceptsFR, Lyes, Lt_bool
    .quad Lsr_isOpaque, Lyes, Lt_bool
    .quad Lsr_keyDown, Ltm_key, Lt_obj
    .quad Lsr_mouseDown, Ltm_mdown, Lt_obj
    .quad Lsr_mouseDragged, Ltm_mdrag, Lt_obj
    .quad Lsr_scrollWheel, Ltm_scroll, Lt_obj
    .quad Lsr_copy, Ltm_copy, Lt_obj
    .quad Lsr_paste, Ltm_paste, Lt_obj
Lmethods_end:

    .section __TEXT,__const
Lkeys:
    .byte 126, K_CSI, 'A', 0       // up
    .byte 125, K_CSI, 'B', 0       // down
    .byte 124, K_CSI, 'C', 0       // right
    .byte 123, K_CSI, 'D', 0       // left
    .byte 115, K_CSI, 'H', 0       // home
    .byte 119, K_CSI, 'F', 0       // end
    .byte 114, K_TILDE, 2, 0       // help / insert
    .byte 117, K_TILDE, 3, 0       // forward delete
    .byte 116, K_TILDE, 5, 0       // page up
    .byte 121, K_TILDE, 6, 0       // page down
    .byte 122, K_SS3, 'P', 0       // F1..F4
    .byte 120, K_SS3, 'Q', 0
    .byte 99, K_SS3, 'R', 0
    .byte 118, K_SS3, 'S', 0
    .byte 96, K_TILDE, 15, 0       // F5..F12
    .byte 97, K_TILDE, 17, 0
    .byte 98, K_TILDE, 18, 0
    .byte 100, K_TILDE, 19, 0
    .byte 101, K_TILDE, 20, 0
    .byte 109, K_TILDE, 21, 0
    .byte 103, K_TILDE, 23, 0
    .byte 111, K_TILDE, 24, 0
Lkeys_end:

    .zerofill __DATA,__bss,_av_tm_class,8,3
    .zerofill __DATA,__bss,_av_tm_ivar,8,3
    .zerofill __DATA,__bss,_av_tm_buf,READ_MAX,4
    .zerofill __DATA,__bss,_av_tm_line,(VT_MAXCOLS * 4 + 16),4

// dst = Term * of the AvTermView in reg self, clobbers x9
.macro STATE dst, self
    LDRG x9, _av_tm_ivar
    ldr \dst, [\self, x9]
.endm

.macro PUTB ptr, ch
    mov w9, #\ch
    strb w9, [\ptr], #1
.endm

    .text
// void av_term_class_init(void)
FUNC_BEGIN _av_term_class_init
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
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
    STRG x19, _av_tm_class, x9
    mov x0, x19
    LADDR x1, Livar_name
    bl _class_getInstanceVariable
    bl _ivar_getOffset
    STRG x0, _av_tm_ivar, x9
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .p2align 2
Lyes:
    mov w0, #1
    ret

// NSView *av_term_create(void): view and emulator, the shell starts with av_term_start
FUNC_BEGIN _av_term_create
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x0, #TM_SIZE
    bl _av_arena_alloc
    mov x19, x0
    bl _av_vt_new
    cbz x0, 8f
    str x0, [x19, #TM_VT]
    mov x9, #-1
    str x9, [x19, #TM_FD]
    LDRG x0, _av_tm_class
    MSG alloc
    movi d0, #0
    movi d1, #0
    fmov d2, #10.0
    fmov d3, #10.0
    MSG initWithFrame
    mov x20, x0
    LDRG x9, _av_tm_ivar
    str x19, [x20, x9]
    str x20, [x19, #TM_NSVIEW]
    mov x0, x20
    b 9f
8:  mov x0, #0
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Term *av_term_state(NSView *view)
FUNC_BEGIN _av_term_state
    STATE x0, x0
    ret

// const char *av_term_title(Term *t): title set by the program, else the shell name
FUNC_BEGIN _av_term_title
    ldr x9, [x0, #TM_VT]
    add x0, x9, #VT_TITLE
    ldrb w10, [x0]
    cbnz w10, 1f
    LADDR x0, _av_pty_name
    ldrb w10, [x0]
    cbnz w10, 1f
    LADDR x0, Ls_term
1:  ret

// int av_term_busy(Term *t): a job other than the shell runs in the foreground
FUNC_BEGIN _av_term_busy
    ldr x9, [x0, #TM_DEAD]
    cbnz x9, 1f
    ldr x9, [x0, #TM_FD]
    tbnz x9, #63, 1f
    ldr x1, [x0, #TM_PID]
    mov x0, x9
    b _av_pty_busy
1:  mov w0, #0
    ret

// int av_term_cwd(Term *t, char *buf): working directory of the foreground job, 0 on success
FUNC_BEGIN _av_term_cwd
    mov x2, x1
    ldr w9, [x0, #TM_FD]
    ldr x1, [x0, #TM_PID]
    mov w0, w9
    b _av_pty_cwd

// void fit(Term *t): grid size from the view bounds, resizes the emulator and the pty
    .p2align 2
Lfit:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    ldr x0, [x19, #TM_NSVIEW]
    MSG bounds
    fmov d5, #12.0
    fsub d2, d2, d5
    fsub d3, d3, d5
    LDRD d6, _av_adv
    fdiv d2, d2, d6
    fcvtzs x21, d2
    LDRD d6, _av_line_h
    fdiv d3, d3, d6
    fcvtzs x20, d3
    mov x9, #1
    cmp x20, x9
    csel x20, x9, x20, lt
    mov x9, #VT_MAXROWS
    cmp x20, x9
    csel x20, x9, x20, gt
    mov x9, #2
    cmp x21, x9
    csel x21, x9, x21, lt
    mov x9, #VT_MAXCOLS
    cmp x21, x9
    csel x21, x9, x21, gt
    ldr x22, [x19, #TM_VT]
    ldp x9, x10, [x22, #VT_ROWS]
    cmp x9, x20
    ccmp x10, x21, #0, eq
    b.eq 9f
    mov x0, x22
    mov x1, x20
    mov x2, x21
    bl _av_vt_resize
    ldr x0, [x19, #TM_FD]
    tbnz x0, #63, 1f
    mov x1, x20
    mov x2, x21
    bl _av_pty_resize
1:  ldr x9, [x19, #TM_OFF]
    ldr x10, [x22, #VT_SB_N]
    cmp x9, x10
    csel x9, x10, x9, hi
    str x9, [x19, #TM_OFF]
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_term_start(Term *t, const char *cwd): spawn the login shell sized to the view in cwd
// (NULL for $HOME), 0 on success
FUNC_BEGIN _av_term_start
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    bl Lfit
    ldr x9, [x19, #TM_VT]
    ldp x0, x1, [x9, #VT_ROWS]
    mov x2, #0
    add x3, sp, #32
    mov x4, x20
    bl _av_pty_spawn
    tbnz x0, #63, 8f
    str x0, [x19, #TM_PID]
    ldrsw x9, [sp, #32]
    str x9, [x19, #TM_FD]
    // CFFileDescriptorContext {version, info, retain, release, copyDescription}
    str xzr, [sp, #40]
    str x19, [sp, #48]
    stp xzr, xzr, [sp, #56]
    str xzr, [sp, #72]
    mov x0, #0
    ldr x1, [x19, #TM_FD]
    mov w2, #0
    adr x3, Ltm_readable
    add x4, sp, #40
    bl _CFFileDescriptorCreate
    cbz x0, 7f
    str x0, [x19, #TM_CFFD]
    mov x1, #CF_READ_CB
    bl _CFFileDescriptorEnableCallBacks
    mov x0, #0
    ldr x1, [x19, #TM_CFFD]
    mov x2, #0
    bl _CFFileDescriptorCreateRunLoopSource
    str x0, [x19, #TM_SRC]
    // common modes: output keeps flowing during menus, alerts and live resize
    bl _CFRunLoopGetMain
    ldr x1, [x19, #TM_SRC]
    LEXTERN x2, _kCFRunLoopCommonModes
    bl _CFRunLoopAddSource
    mov x0, #0
    b 9f
7:  ldr x0, [x19, #TM_FD]
    ldr x1, [x19, #TM_PID]
    bl _av_pty_close
    mov x9, #-1
    str x9, [x19, #TM_FD]
8:  mov x0, #-1
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// void av_term_destroy(Term *t): stop watching the pty, hang up the shell, free the emulator
FUNC_BEGIN _av_term_destroy
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #TM_CFFD]
    cbz x0, 1f
    bl _CFFileDescriptorInvalidate
    ldr x0, [x19, #TM_CFFD]
    bl _CFRelease
    str xzr, [x19, #TM_CFFD]
1:  ldr x0, [x19, #TM_SRC]
    cbz x0, 2f
    bl _CFRelease
    str xzr, [x19, #TM_SRC]
2:  ldr x0, [x19, #TM_FD]
    tbnz x0, #63, 3f
    ldr x1, [x19, #TM_PID]
    bl _av_pty_close
    mov x9, #-1
    str x9, [x19, #TM_FD]
3:  ldr x0, [x19, #TM_VT]
    bl _av_vt_free
    str xzr, [x19, #TM_VT]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void flush_reply(Term *t): answers to terminal queries go back to the program
    .p2align 2
Lflush_reply:
    ldr x9, [x0, #TM_VT]
    ldr x2, [x9, #VT_REPLY_LEN]
    cbz x2, 1f
    str xzr, [x9, #VT_REPLY_LEN]
    ldr x0, [x0, #TM_FD]
    add x1, x9, #VT_REPLY
    b _av_pty_write
1:  ret

// void after_output(Term *t): bell, title and redraw
    .p2align 2
Lafter_output:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x9, [x19, #TM_VT]
    ldr x10, [x9, #VT_BELL]
    ldr x11, [x19, #TM_BELL]
    cmp x10, x11
    b.eq 1f
    str x10, [x19, #TM_BELL]
    bl _NSBeep
1:  ldr x9, [x19, #TM_VT]
    ldr x10, [x9, #VT_TITLE_GEN]
    ldr x11, [x19, #TM_TITLE_GEN]
    cmp x10, x11
    b.eq 2f
    str x10, [x19, #TM_TITLE_GEN]
    bl _av_tabbar_redraw
    bl _av_tabs_update_window
2:  ldr x0, [x19, #TM_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// CFFileDescriptor callout(f, flags, Term *t): drain the pty, at most READ_BUDGET per call
// EOF or EIO means the shell exited, the tab is closed once the callout has returned
    .p2align 2
Ltm_readable:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x2
    mov x22, x0
    mov x21, #0
1:  ldr x0, [x19, #TM_FD]
    LADDR x1, _av_tm_buf
    mov x2, #READ_MAX
    bl _read
    cmp x0, #0
    b.gt 2f
    b.eq 4f
    bl ___error
    ldr w9, [x0]
    cmp w9, #EINTR
    b.eq 1b
    cmp w9, #EAGAIN
    b.eq 3f
    b 4f
2:  add x21, x21, x0
    mov x2, x0
    ldr x0, [x19, #TM_VT]
    LADDR x1, _av_tm_buf
    bl _av_vt_feed
    mov x0, x19
    bl Lflush_reply
    cmp x21, #READ_BUDGET
    b.lo 1b
3:  mov x0, x19
    bl Lafter_output
    mov x0, x22
    mov x1, #CF_READ_CB
    bl _CFFileDescriptorEnableCallBacks
    b 9f
4:  mov x9, #1
    str x9, [x19, #TM_DEAD]
    mov x0, x19
    bl Lafter_output
    LGOT x0, __dispatch_main_q
    mov x1, x19
    LADDR x2, _av_tabs_term_exited
    bl _dispatch_async_f
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void send(Term *t, const void *p, size_t n): input to the program, back to the live screen
    .p2align 2
Lsend:
    ldr x9, [x0, #TM_DEAD]
    cbnz x9, 2f
    ldr x9, [x0, #TM_FD]
    tbnz x9, #63, 2f
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x9, [x19, #TM_OFF]
    ldr x10, [x19, #TM_SELON]
    orr x9, x9, x10
    cbz x9, 1f
    str xzr, [x19, #TM_OFF]
    str xzr, [x19, #TM_SELON]
    ldr x0, [x19, #TM_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
1:  ldr x0, [x19, #TM_FD]
    mov x1, x20
    mov x2, x21
    bl _av_pty_write
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
2:  ret

// u8 *put_num(u8 *p, size_t n < 1000), decimal, leaf
    .p2align 2
Lput_num:
    mov x11, #10
    udiv x10, x1, x11
    msub x14, x10, x11, x1
    cbz x10, 3f
    udiv x12, x10, x11
    msub x13, x12, x11, x10
    cbz x12, 2f
    add w12, w12, #'0'
    strb w12, [x0], #1
2:  add w13, w13, #'0'
    strb w13, [x0], #1
3:  add w14, w14, #'0'
    strb w14, [x0], #1
    ret

// keyDown:, x22 modifiers, w23 key code then the final byte, x24 xterm modifier parameter
// (1 + shift + 2 alt + 4 ctrl)
// the 32 bytes at sp + 64 hold the bytes to send
    .p2align 2
Ltm_key:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    mov x0, x21
    bl _av_keymap_handle
    cbnz w0, Lkt_out
    mov x0, x21
    MSG modifierFlags
    mov x22, x0
    // command chords belong to the menus
    tst x22, #MOD_CMD
    b.ne Lkt_out
    mov x0, x21
    MSG keyCode
    and w23, w0, #0xffff
    ubfx x24, x22, #17, #1
    ubfx x9, x22, #19, #1
    add x24, x24, x9, lsl #1
    ubfx x9, x22, #18, #1
    add x24, x24, x9, lsl #2
    add x24, x24, #1
    add x0, sp, #64

    cmp w23, #36
    b.eq Lkt_ret
    cmp w23, #76
    b.eq Lkt_ret
    cmp w23, #48
    b.eq Lkt_tab
    cmp w23, #51
    b.eq Lkt_bs
    cmp w23, #53
    b.eq Lkt_esc
    LADDR x9, Lkeys
    LADDR x10, Lkeys_end
1:  cmp x9, x10
    b.hs Lkt_plain
    ldrb w11, [x9]
    cmp w11, w23
    b.eq 2f
    add x9, x9, #4
    b 1b
2:  ldrb w12, [x9, #1]
    ldrb w23, [x9, #2]
    cmp w12, #K_TILDE
    b.eq Lkt_tilde
    cmp w12, #K_SS3
    b.eq Lkt_ss3
    // option left/right move by word in shells, like Terminal
    cmp x24, #3
    b.ne 3f
    cmp w23, #'D'
    mov w10, #'b'
    b.eq 4f
    cmp w23, #'C'
    mov w10, #'f'
    b.ne 3f
4:  PUTB x0, 0x1b
    strb w10, [x0], #1
    b Lkt_send
3:  cmp x24, #1
    b.ne Lkt_mod
    PUTB x0, 0x1b
    ldr x10, [x20, #TM_VT]
    ldr x10, [x10, #VT_MODE]
    mov w11, #'['
    mov w12, #'O'
    tst x10, #M_APPCUR
    csel w11, w12, w11, ne
    strb w11, [x0], #1
    strb w23, [x0], #1
    b Lkt_send
Lkt_ss3:
    cmp x24, #1
    b.ne Lkt_mod
    PUTB x0, 0x1b
    PUTB x0, 'O'
    strb w23, [x0], #1
    b Lkt_send
    // ESC [ 1 ; m X
Lkt_mod:
    PUTB x0, 0x1b
    PUTB x0, '['
    PUTB x0, '1'
    PUTB x0, ';'
    mov x1, x24
    bl Lput_num
    strb w23, [x0], #1
    b Lkt_send
    // ESC [ n ~ or ESC [ n ; m ~
Lkt_tilde:
    PUTB x0, 0x1b
    PUTB x0, '['
    mov x1, x23
    bl Lput_num
    cmp x24, #1
    b.eq 5f
    PUTB x0, ';'
    mov x1, x24
    bl Lput_num
5:  PUTB x0, '~'
    b Lkt_send
Lkt_ret:
    tst x22, #MOD_OPT
    b.eq 6f
    PUTB x0, 0x1b
6:  PUTB x0, 13
    b Lkt_send
Lkt_tab:
    tst x22, #MOD_SHIFT
    b.eq 7f
    PUTB x0, 0x1b
    PUTB x0, '['
    PUTB x0, 'Z'
    b Lkt_send
7:  PUTB x0, 9
    b Lkt_send
    // option backspace deletes a word, control backspace sends BS
Lkt_bs:
    tst x22, #MOD_OPT
    b.eq 8f
    PUTB x0, 0x1b
8:  mov w10, #0x7f
    mov w11, #8
    tst x22, #MOD_CTRL
    csel w10, w11, w10, ne
    strb w10, [x0], #1
    b Lkt_send
Lkt_esc:
    PUTB x0, 0x1b
    b Lkt_send

    // control chords: the base key masked to a control byte, option adds ESC
Lkt_plain:
    tst x22, #MOD_CTRL
    b.eq Lkt_chars
    mov x0, x21
    MSG charsIgnoring
    MSG UTF8String
    cbz x0, Lkt_chars
    ldrb w9, [x0]
    mov w10, #0
    cmp w9, #' '
    b.eq 1f
    mov w10, #0x1f
    cmp w9, #'/'
    b.eq 1f
    mov w10, #0x7f
    cmp w9, #'?'
    b.eq 1f
    cmp w9, #0x40
    b.lo Lkt_chars
    cmp w9, #0x7e
    b.hi Lkt_chars
    and w10, w9, #0x1f
1:  add x0, sp, #64
    tst x22, #MOD_OPT
    b.eq 2f
    PUTB x0, 0x1b
2:  strb w10, [x0], #1
    b Lkt_send
    // text as typed, option composes characters (Italian @ # [ ] live there)
Lkt_chars:
    mov x0, x21
    MSG characters
    MSG UTF8String
    cbz x0, Lkt_out
    mov x23, x0
    ldrb w9, [x23]
    cbz w9, Lkt_out
    // U+F700..U+F7FF are AppKit function-key codes (EF 9C..9F xx)
    cmp w9, #0xef
    b.ne 3f
    ldrb w10, [x23, #1]
    sub w10, w10, #0x9c
    cmp w10, #3
    b.ls Lkt_out
3:  mov x0, x23
    bl _strlen
    mov x2, x0
    mov x1, x23
    mov x0, x20
    bl Lsend
    b Lkt_out
Lkt_send:
    add x1, sp, #64
    sub x2, x0, x1
    mov x0, x20
    bl Lsend
Lkt_out:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// scrollWheel:, scrollback on the main screen, arrow keys on the alternate one (less, man, vim)
    .p2align 2
Ltm_scroll:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    mov x0, x21
    MSG scrollingDeltaY
    fmov d8, d0
    LDRD d9, _av_line_h
    mov x0, x21
    MSG hasPrecise
    tst w0, #0xff
    b.ne 1f
    fmul d8, d8, d9
1:  ldr d0, [x20, #TM_ACC]
    fadd d0, d0, d8
    fdiv d1, d0, d9
    fcvtzs x21, d1
    scvtf d1, x21
    fmsub d0, d1, d9, d0
    str d0, [x20, #TM_ACC]
    cbz x21, 9f
    ldr x22, [x20, #TM_VT]
    ldr x9, [x22, #VT_MODE]
    tbnz x9, #MB_ALT, 3f
    ldr x9, [x20, #TM_OFF]
    adds x9, x9, x21
    csel x9, xzr, x9, lt
    ldr x10, [x22, #VT_SB_N]
    cmp x9, x10
    csel x9, x10, x9, gt
    str x9, [x20, #TM_OFF]
    ldr x0, [x20, #TM_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    b 9f
    // one arrow per line, up for positive deltas
3:  mov w10, #'A'
    cmp x21, #0
    b.gt 4f
    neg x21, x21
    mov w10, #'B'
4:  mov x9, #50
    cmp x21, x9
    csel x21, x9, x21, hi
    ldr x9, [x22, #VT_MODE]
    mov w11, #'['
    mov w12, #'O'
    tst x9, #M_APPCUR
    csel w11, w12, w11, ne
    mov w9, #0x1b
    strb w9, [sp, #40]
    strb w11, [sp, #41]
    strb w10, [sp, #42]
5:  mov x0, x20
    add x1, sp, #40
    mov x2, #3
    bl Lsend
    subs x21, x21, #1
    b.ne 5b
9:  ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// long hit(NSView *self, NSEvent *e): line * 1024 + column under the mouse
    .p2align 2
Ltm_hit:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    STATE x20, x19
    mov x0, x1
    MSG locationInWindow
    mov x0, x19
    mov x2, #0
    MSG convertPoint
    fmov d8, d0
    fmov d9, d1
    mov x0, x19
    MSG bounds
    ldr x21, [x20, #TM_VT]
    fmov d4, #6.0
    fsub d0, d8, d4
    LDRD d1, _av_adv
    fdiv d0, d0, d1
    fcvtms x9, d0
    fsub d0, d3, d4
    fsub d0, d0, d9
    LDRD d1, _av_line_h
    fdiv d0, d0, d1
    fcvtms x10, d0
    ldp x11, x12, [x21, #VT_ROWS]
    sub x11, x11, #1
    sub x12, x12, #1
    cmp x9, #0
    csel x9, xzr, x9, lt
    cmp x9, x12
    csel x9, x12, x9, gt
    cmp x10, #0
    csel x10, xzr, x10, lt
    cmp x10, x11
    csel x10, x11, x10, gt
    ldr x11, [x20, #TM_OFF]
    sub x10, x10, x11
    lsl x10, x10, #SEL_SHIFT
    add x0, x10, x9
    ldp d8, d9, [sp, #48]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// int blank_at(u64 *line, size_t col)
    .p2align 2
Lblank_at:
    ldr x9, [x0, x1, lsl #3]
    and x9, x9, #CELL_CP
    cmp x9, #' '
    cset w0, ls
    ret

// mouseDown:, double click selects a word, triple click the line
    .p2align 2
Ltm_mdown:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    mov x19, x0
    mov x21, x2
    STATE x20, x19
    bl _av_tabs_focus_view
    mov x0, x19
    mov x1, x21
    bl Ltm_hit
    mov x22, x0
    stp x22, x22, [x20, #TM_SEL_A]
    str xzr, [x20, #TM_SELON]
    mov x0, x21
    MSG clickCount
    cmp x0, #2
    b.lo 9f
    asr x23, x22, #SEL_SHIFT
    and x24, x22, #((1 << SEL_SHIFT) - 1)
    ldr x0, [x20, #TM_VT]
    ldr x25, [x0, #VT_COLS]
    b.hi 5f
    mov x1, x23
    bl _av_vt_line
    mov x21, x0
    mov x1, x24
    bl Lblank_at
    cbnz w0, 9f
    mov x22, x24
1:  cbz x22, 2f
    mov x0, x21
    sub x1, x22, #1
    bl Lblank_at
    cbnz w0, 2f
    sub x22, x22, #1
    b 1b
2:  add x9, x24, #1
    cmp x9, x25
    b.hs 3f
    mov x0, x21
    mov x1, x9
    bl Lblank_at
    cbnz w0, 3f
    add x24, x24, #1
    b 2b
3:  lsl x9, x23, #SEL_SHIFT
    add x10, x9, x22
    add x11, x9, x24
    b 6f
5:  lsl x9, x23, #SEL_SHIFT
    mov x10, x9
    add x11, x9, x25
    sub x11, x11, #1
6:  stp x10, x11, [x20, #TM_SEL_A]
    mov x9, #1
    str x9, [x20, #TM_SELON]
9:  mov x0, x19
    mov x2, #1
    MSG setNeedsDisplay
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

    .p2align 2
Ltm_mdrag:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    STATE x20, x19
    mov x1, x2
    bl Ltm_hit
    str x0, [x20, #TM_SEL_B]
    mov x9, #1
    str x9, [x20, #TM_SELON]
    mov x0, x19
    mov x2, #1
    MSG setNeedsDisplay
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// copy:, selected cells as UTF-8 lines without trailing blanks
// x20 term, x21 vt, x22 line, x23 out, x24 last non-blank end, x25 end line, x26 column,
// x27 column end, x28 buffer; sp + 96 selection start, + 104 end, + 112 line cells
    .p2align 2
Ltm_copy:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    STATE x20, x19
    ldr x9, [x20, #TM_SELON]
    cbz x9, 9f
    ldr x21, [x20, #TM_VT]
    ldp x9, x10, [x20, #TM_SEL_A]
    cmp x9, x10
    csel x11, x9, x10, lt
    csel x12, x10, x9, lt
    stp x11, x12, [sp, #96]
    asr x22, x11, #SEL_SHIFT
    asr x25, x12, #SEL_SHIFT
    mov x0, x20
    bl Lcopy_size
    bl _av_pages_alloc
    cbz x0, 9f
    mov x28, x0
    mov x23, x0
1:  mov x0, x21
    mov x1, x22
    bl _av_vt_line
    str x0, [sp, #112]
    mov x26, #0
    ldr x10, [sp, #96]
    asr x11, x10, #SEL_SHIFT
    cmp x22, x11
    b.ne 2f
    and x26, x10, #((1 << SEL_SHIFT) - 1)
2:  ldr x27, [x21, #VT_COLS]
    cmp x22, x25
    b.ne 3f
    ldr x10, [sp, #104]
    and x10, x10, #((1 << SEL_SHIFT) - 1)
    add x10, x10, #1
    cmp x10, x27
    csel x27, x10, x27, lo
3:  mov x24, x23
4:  cmp x26, x27
    b.hs 5f
    ldr x9, [sp, #112]
    ldr x10, [x9, x26, lsl #3]
    and x0, x10, #CELL_CP
    add x26, x26, #1
    cmp x0, #' '
    b.hi 41f
    mov w9, #' '
    strb w9, [x23], #1
    b 4b
41: mov x1, x23
    bl _av_utf8_encode
    add x23, x23, x0
    mov x24, x23
    b 4b
5:  mov x23, x24
    cmp x22, x25
    b.ge 6f
    mov w9, #10
    strb w9, [x23], #1
    add x22, x22, #1
    b 1b
6:  CLS x0, NSString
    MSG alloc
    mov x2, x28
    sub x3, x23, x28
    mov x4, #NSUTF8StringEncoding
    MSG initWithBytes
    mov x21, x0
    mov x0, x20
    bl Lcopy_size
    mov x1, x0
    mov x0, x28
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
9:  ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret

// size_t copy_size(Term *t): lines * (4 * cols + 1), room for the selection as UTF-8
    .p2align 2
Lcopy_size:
    ldp x9, x10, [x0, #TM_SEL_A]
    asr x9, x9, #SEL_SHIFT
    asr x10, x10, #SEL_SHIFT
    subs x9, x10, x9
    cneg x9, x9, lt
    add x9, x9, #1
    ldr x10, [x0, #TM_VT]
    ldr x10, [x10, #VT_COLS]
    lsl x10, x10, #2
    add x10, x10, #1
    mul x0, x9, x10
    ret

// paste:, newlines become CR like typed Return, wrapped in bracketed paste when asked for
    .p2align 2
Ltm_paste:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
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
    mov x22, x0
    bl _av_pages_alloc
    cbz x0, 9f
    mov x23, x0
    mov x9, #0
    mov x10, #0
    mov w12, #0
1:  cmp x9, x22
    b.hs 3f
    ldrb w11, [x21, x9]
    add x9, x9, #1
    mov w13, w12
    mov w12, w11
    cmp w11, #10
    b.ne 2f
    // CR LF stays a single CR
    cmp w13, #13
    b.eq 1b
    mov w11, #13
2:  strb w11, [x23, x10]
    add x10, x10, #1
    b 1b
3:  mov x24, x10
    ldr x9, [x20, #TM_VT]
    ldr x9, [x9, #VT_MODE]
    tbz x9, #MB_PASTE, 4f
    mov x0, x20
    LADDR x1, Ls_paste_on
    mov x2, #6
    bl Lsend
4:  mov x0, x20
    mov x1, x23
    mov x2, x24
    bl Lsend
    ldr x9, [x20, #TM_VT]
    ldr x9, [x9, #VT_MODE]
    tbz x9, #MB_PASTE, 5f
    mov x0, x20
    LADDR x1, Ls_paste_off
    mov x2, #6
    bl Lsend
5:  mov x0, x23
    mov x1, x22
    bl _av_pages_free
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// color keys: 0x10000 | theme slot index, or rgb555; bit 20 marks underline
// long color_key(u16 color, size_t default_slot, int bold), leaf, keeps x11 and x12
    .p2align 2
Lcolor_key:
    cbnz x0, 1f
    orr x0, x1, #0x10000
    ret
1:  cmp x0, #16
    b.hi 2f
    // ANSI 0..15, bold brightens 0..7
    sub x0, x0, #1
    cmp x0, #8
    b.hs 11f
    cbz x2, 11f
    add x0, x0, #8
11: add x0, x0, #T_ANSI_IDX
    orr x0, x0, #0x10000
    ret
2:  tbnz x0, #15, 5f
    sub x0, x0, #1
    cmp x0, #232
    b.hs 4f
    // 6x6x6 cube: levels 0, 95, 135, 175, 215, 255
    sub x0, x0, #16
    mov x9, #36
    udiv x13, x0, x9
    msub x0, x13, x9, x0
    mov x9, #6
    udiv x14, x0, x9
    msub x15, x14, x9, x0
    mov x9, #40
    mov x10, #55
    madd x0, x13, x9, x10
    cmp x13, #0
    csel x13, xzr, x0, eq
    madd x0, x14, x9, x10
    cmp x14, #0
    csel x14, xzr, x0, eq
    madd x0, x15, x9, x10
    cmp x15, #0
    csel x15, xzr, x0, eq
    lsr x13, x13, #3
    lsr x14, x14, #3
    lsr x15, x15, #3
    lsl x0, x13, #10
    orr x0, x0, x14, lsl #5
    orr x0, x0, x15
    ret
    // gray ramp 8, 18, .. 238
4:  sub x0, x0, #232
    mov x9, #10
    mul x0, x0, x9
    add x0, x0, #8
    lsr x0, x0, #3
    orr x9, x0, x0, lsl #5
    orr x0, x9, x0, lsl #10
    ret
5:  and x0, x0, #0x7fff
    ret

// long fg_key(u64 cell): glyph color, reverse video takes the background
    .p2align 2
Lfg_key:
    ubfx x11, x0, #AB_UNDER, #1
    ubfx x2, x0, #AB_BOLD, #1
    mov x1, #(T_TEXT / T_SLOT)
    tbnz x0, #AB_REVERSE, 1f
    ubfx x0, x0, #32, #16
    b 2f
1:  ubfx x0, x0, #48, #16
    mov x1, #(T_BG / T_SLOT)
    mov x2, #0
2:  mov x12, x30
    bl Lcolor_key
    orr x0, x0, x11, lsl #20
    ret x12

// long bg_key(u64 cell): fill color, -1 for the plain background
    .p2align 2
Lbg_key:
    tbnz x0, #AB_REVERSE, 1f
    ubfx x0, x0, #48, #16
    cbz x0, 2f
    mov x1, #0
    mov x2, #0
    b Lcolor_key
1:  ubfx x0, x0, #32, #16
    mov x1, #(T_TEXT / T_SLOT)
    mov x2, #0
    b Lcolor_key
2:  mov x0, #-1
    ret

// CFDictionaryRef key_attrs(long key)
    .p2align 2
Lkey_attrs:
    and x0, x0, #~(1 << 20)
    tbz x0, #16, 1f
    and x0, x0, #0xff
    LADDR x9, _av_attrs
    ldr x0, [x9, x0, lsl #3]
    ret
1:  b _av_render_rgb_attrs

// void key_rgba(long key, double *rgba)
    .p2align 2
Lkey_rgba:
    and x0, x0, #~(1 << 20)
    tbz x0, #16, 1f
    and x0, x0, #0xff
    LADDR x9, _av_theme
    add x9, x9, x0, lsl #5
    ldp x10, x11, [x9]
    stp x10, x11, [x1]
    ldp x10, x11, [x9, #16]
    stp x10, x11, [x1, #16]
    ret
1:  b _av_rgb555_rgba

// fill d0..d3 with the cursor color in drawRect, context in x21
.macro CURSOR_FILL
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_CURSOR
    bl _av_fill
.endm

// drawRect:, per row: background runs, selection, then text runs of one color
// x19 self, x20 term, x21 ctx, x22 vt, x23 row, x24 line, x25 run start, x26 column, x27 key,
// x28 text out; d8 W, d9 H, d10 line h, d11 advance, d12 row bottom, d13 padding,
// d14/d15 cursor origin
    .p2align 2
Ltm_draw:
    stp x29, x30, [sp, #-D_FRAME]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d8, d9, [sp, #96]
    stp d10, d11, [sp, #112]
    stp d12, d13, [sp, #128]
    stp d14, d15, [sp, #144]
    mov x19, x0
    STATE x20, x19
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    mov x21, x0
    LGOT x1, _CGAffineTransformIdentity
    bl _CGContextSetTextMatrix
    mov x0, x20
    bl Lfit
    mov x0, x19
    MSG bounds
    fmov d8, d2
    fmov d9, d3
    // views do not clip to their bounds since macOS 14, rows above the top would cover the tab bar
    mov x0, x21
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d9
    bl _CGContextClipToRect
    mov x0, x21
    LADDR x1, _av_theme
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d9
    bl _av_fill
    ldr x22, [x20, #TM_VT]
    LDRD d10, _av_line_h
    LDRD d11, _av_adv
    fmov d13, #6.0
    ldr x9, [x20, #TM_OFF]
    str x9, [sp, #D_OFF]
    // ordered selection, or an empty range
    mov x11, #0x7fffffffffffffff
    mov x12, #0x8000000000000000
    ldr x9, [x20, #TM_SELON]
    cbz x9, 1f
    ldp x9, x10, [x20, #TM_SEL_A]
    cmp x9, x10
    csel x11, x9, x10, lt
    csel x12, x10, x9, lt
1:  stp x11, x12, [sp, #D_SS]
    mov x23, #0

Ltd_row:
    ldr x9, [x22, #VT_ROWS]
    cmp x23, x9
    b.hs Ltd_cursor
    add x9, x23, #1
    ucvtf d0, x9
    fmul d0, d0, d10
    fsub d0, d9, d0
    fsub d12, d0, d13
    ldr x9, [sp, #D_OFF]
    sub x1, x23, x9
    mov x0, x22
    bl _av_vt_line
    mov x24, x0
    cbz x24, Ltd_next_row

    mov x25, #0
Ltd_bg:
    ldr x9, [x22, #VT_COLS]
    cmp x25, x9
    b.hs Ltd_sel
    ldr x0, [x24, x25, lsl #3]
    bl Lbg_key
    mov x27, x0
    add x26, x25, #1
1:  ldr x9, [x22, #VT_COLS]
    cmp x26, x9
    b.hs 2f
    ldr x0, [x24, x26, lsl #3]
    bl Lbg_key
    cmp x0, x27
    b.ne 2f
    add x26, x26, #1
    b 1b
2:  tbnz x27, #63, 3f
    mov x0, x27
    add x1, sp, #D_RGBA
    bl Lkey_rgba
    ucvtf d0, x25
    fmul d0, d0, d11
    fadd d0, d0, d13
    sub x9, x26, x25
    ucvtf d2, x9
    fmul d2, d2, d11
    fmov d1, d12
    fmov d3, d10
    mov x0, x21
    add x1, sp, #D_RGBA
    bl _av_fill
3:  mov x25, x26
    b Ltd_bg

Ltd_sel:
    ldr x9, [sp, #D_OFF]
    sub x9, x23, x9
    ldp x10, x11, [sp, #D_SS]
    asr x12, x10, #SEL_SHIFT
    asr x13, x11, #SEL_SHIFT
    cmp x9, x12
    b.lt Ltd_text
    cmp x9, x13
    b.gt Ltd_text
    mov x14, #0
    cmp x9, x12
    b.ne 4f
    and x14, x10, #((1 << SEL_SHIFT) - 1)
4:  ldr x15, [x22, #VT_COLS]
    cmp x9, x13
    b.ne 5f
    and x10, x11, #((1 << SEL_SHIFT) - 1)
    add x10, x10, #1
    cmp x10, x15
    csel x15, x10, x15, lo
5:  cmp x15, x14
    b.ls Ltd_text
    ucvtf d0, x14
    fmul d0, d0, d11
    fadd d0, d0, d13
    sub x9, x15, x14
    ucvtf d2, x9
    fmul d2, d2, d11
    fmov d1, d12
    fmov d3, d10
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_SEL
    bl _av_fill

Ltd_text:
    mov x25, #0
Ltd_run:
    ldr x9, [x22, #VT_COLS]
    cmp x25, x9
    b.hs Ltd_next_row
    ldr x10, [x24, x25, lsl #3]
    and x11, x10, #CELL_CP
    cmp x11, #' '
    b.ls 9f
    tbnz x10, #AB_HIDDEN, 9f
    mov x0, x10
    bl Lfg_key
    mov x27, x0
    LADDR x28, _av_tm_line
    mov x26, x25
    // blanks join the run as spaces, trailing ones are dropped
6:  ldr x9, [x22, #VT_COLS]
    cmp x26, x9
    b.hs 8f
    ldr x10, [x24, x26, lsl #3]
    and x11, x10, #CELL_CP
    cmp x11, #' '
    b.ls 7f
    tbnz x10, #AB_HIDDEN, 7f
    mov x0, x10
    bl Lfg_key
    cmp x0, x27
    b.ne 8f
    ldr x10, [x24, x26, lsl #3]
    and x0, x10, #CELL_CP
    mov x1, x28
    bl _av_utf8_encode
    add x28, x28, x0
    add x26, x26, #1
    str x28, [sp, #D_NB]
    str x26, [sp, #D_NBC]
    b 6b
7:  mov w9, #' '
    strb w9, [x28], #1
    add x26, x26, #1
    b 6b
8:  mov x0, x27
    bl Lkey_attrs
    mov x3, x0
    LADDR x1, _av_tm_line
    ldr x2, [sp, #D_NB]
    sub x2, x2, x1
    mov x0, x21
    ucvtf d0, x25
    fmul d0, d0, d11
    fadd d0, d0, d13
    LDRD d1, _av_base_off
    fadd d1, d1, d12
    bl _av_draw_text
    tbz x27, #20, 81f
    mov x0, x27
    add x1, sp, #D_RGBA
    bl Lkey_rgba
    ucvtf d0, x25
    fmul d0, d0, d11
    fadd d0, d0, d13
    ldr x9, [sp, #D_NBC]
    sub x9, x9, x25
    ucvtf d2, x9
    fmul d2, d2, d11
    LDRD d1, _av_base_off
    fadd d1, d1, d12
    fmov d3, #2.0
    fsub d1, d1, d3
    fmov d3, #1.0
    mov x0, x21
    add x1, sp, #D_RGBA
    bl _av_fill
81: mov x25, x26
    b Ltd_run
9:  add x25, x25, #1
    b Ltd_run

Ltd_next_row:
    add x23, x23, #1
    b Ltd_row

    // block cursor, the glyph under it in the background color
Ltd_cursor:
    ldr x9, [x22, #VT_MODE]
    tbz x9, #MB_CURSOR, Ltd_out
    ldr x9, [x20, #TM_DEAD]
    cbnz x9, Ltd_out
    ldp x23, x24, [x22, #VT_CX]
    ldr x9, [sp, #D_OFF]
    add x9, x24, x9
    ldr x10, [x22, #VT_ROWS]
    cmp x9, x10
    b.hs Ltd_out
    ucvtf d14, x23
    fmul d14, d14, d11
    fadd d14, d14, d13
    add x9, x9, #1
    ucvtf d15, x9
    fmul d15, d15, d10
    fsub d15, d9, d15
    fsub d15, d15, d13
    LDRG x9, _av_focus_view
    cmp x9, x19
    b.eq 1f
    // pane without focus: outline only
    fmov d0, d14
    fmov d1, d15
    fmov d2, #1.0
    fmov d3, d10
    CURSOR_FILL
    fadd d0, d14, d11
    fmov d1, #1.0
    fsub d0, d0, d1
    fmov d1, d15
    fmov d2, #1.0
    fmov d3, d10
    CURSOR_FILL
    fmov d0, d14
    fmov d1, d15
    fmov d2, d11
    fmov d3, #1.0
    CURSOR_FILL
    fadd d1, d15, d10
    fmov d0, #1.0
    fsub d1, d1, d0
    fmov d0, d14
    fmov d2, d11
    fmov d3, #1.0
    CURSOR_FILL
    b Ltd_out
1:  fmov d0, d14
    fmov d1, d15
    fmov d2, d11
    fmov d3, d10
    CURSOR_FILL
    mov x0, x22
    mov x1, x24
    bl _av_vt_line
    ldr x10, [x0, x23, lsl #3]
    and x0, x10, #CELL_CP
    cmp x0, #' '
    b.ls Ltd_out
    LADDR x1, _av_tm_line
    bl _av_utf8_encode
    mov x2, x0
    LADDR x1, _av_tm_line
    ATTRS x3, T_BG
    mov x0, x21
    fmov d0, d14
    LDRD d1, _av_base_off
    fadd d1, d1, d15
    bl _av_draw_text
Ltd_out:
    ldp d14, d15, [sp, #144]
    ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]
    ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #D_FRAME
    ret
