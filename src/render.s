// font metrics and CoreText drawing of the visible lines, gutter, selection and cursor

.include "macros.inc"
.include "objc.inc"
.include "buffer.inc"
.include "doc.inc"
.include "theme.inc"
.include "hl.inc"

.set DISPLAY_MAX, 8192
.set ENC_LATIN1,  0x0201
.set RGB_COLORS,  32768

// drawRect locals
.set L_Y0,     160
.set L_YBOT,   168
.set L_LS,     176
.set L_LE,     184
.set L_CA,     192
.set L_LAST,   200
.set L_NUMEND, 240
.set L_TXT,    256
.set L_TXTLEN, 264
.set L_NRUNS,  272
.set L_RUN,    280
.set L_BYTE,   288
.set L_COL,    296
.set DRAW_FRAME, 320

    CLASSREF NSGraphicsContext
    SELDEF currentContext, "currentContext"
    SELDEF CGContext, "CGContext"
    SELDEF bounds, "bounds"

    .section __TEXT,__cstring,cstring_literals
Ldefault_font:
    .asciz "Menlo"
Lfont_warn:
    .asciz "avenger: font '%s' is missing or not monospaced, using Menlo\n"

    .zerofill __DATA,__bss,_av_font,8,3
    .zerofill __DATA,__bss,_av_line_h,8,3
    .zerofill __DATA,__bss,_av_adv,8,3
    .zerofill __DATA,__bss,_av_base_off,8,3
    .zerofill __DATA,__bss,_av_line_scratch,(DISPLAY_MAX + 32),4
    .zerofill __DATA,__bss,_av_attrs,(T_SLOTS * 8),3
    // terminal colors outside the theme, by rgb555, created on first use
    .zerofill __DATA,__bss,_av_rgb_attrs,(RGB_COLORS * 8),3
    .globl _av_attrs
    .globl _av_line_h
    .globl _av_adv
    .globl _av_base_off

    .text
// void av_render_init(void), default font until the config is applied
FUNC_BEGIN _av_render_init
    LADDR x0, Ldefault_font
    fmov d0, #14.0
    b _av_render_set_font

// void av_render_set_font(const char *name, double size)
// CoreText silently substitutes unknown names, so anything not monospaced falls back to Menlo
FUNC_BEGIN _av_render_set_font
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, xzr, [sp, #32]
    str d8, [sp, #40]
    fmov d8, d0
    mov x21, x0
    mov x1, x0
    mov x0, #0
    mov w2, #0x0100
    movk w2, #0x0800, lsl #16
    bl _CFStringCreateWithCString
    mov x19, x0
    fmov d0, d8
    mov x1, #0
    bl _CTFontCreateWithName
    mov x20, x0
    mov x0, x19
    bl _CFRelease
    mov x0, x20
    bl _CTFontGetSymbolicTraits
    tbnz w0, #10, 2f
    mov x0, x20
    bl _CFRelease
    sub sp, sp, #16
    str x21, [sp]
    mov w0, #2
    LADDR x1, Lfont_warn
    bl _dprintf
    add sp, sp, #16
    LADDR x0, Ldefault_font
    fmov d0, d8
    bl _av_render_set_font
    b 3f
2:  LDRG x0, _av_font
    STRG x20, _av_font, x9
    cbz x0, 1f
    bl _CFRelease
1:  bl Lmetrics
3:  ldr d8, [sp, #40]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// line height, baseline offset and cell advance of _av_font
    .p2align 2
Lmetrics:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    stp d10, d11, [sp, #48]
    sub sp, sp, #16
    LDRG x19, _av_font
    mov x0, x19
    bl _CTFontGetAscent
    fmov d8, d0
    mov x0, x19
    bl _CTFontGetDescent
    fmov d9, d0
    mov x0, x19
    bl _CTFontGetLeading
    fmov d10, d0

    // line height with a little air, baseline centred in it
    fadd d0, d8, d9
    fadd d0, d0, d10
    frintp d0, d0
    fmov d1, #6.0
    fadd d11, d0, d1
    adrp x16, _av_line_h@PAGE
    str d11, [x16, _av_line_h@PAGEOFF]
    fadd d0, d8, d9
    fsub d0, d11, d0
    fmov d1, #0.5
    fmul d0, d0, d1
    fadd d0, d0, d9
    frinta d0, d0
    adrp x16, _av_base_off@PAGE
    str d0, [x16, _av_base_off@PAGEOFF]

    // monospace advance from 'M'
    mov w0, #'M'
    strh w0, [sp]
    mov x0, x19
    mov x1, sp
    add x2, sp, #2
    mov x3, #1
    bl _CTFontGetGlyphsForCharacters
    mov x0, x19
    mov w1, #0
    add x2, sp, #2
    mov x3, #0
    mov x4, #1
    bl _CTFontGetAdvancesForGlyphs
    adrp x16, _av_adv@PAGE
    str d0, [x16, _av_adv@PAGEOFF]

    add sp, sp, #16
    ldp d10, d11, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_render_rebuild_attrs(void), one attribute dict per theme slot
FUNC_BEGIN _av_render_rebuild_attrs
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, #0
    LADDR x20, _av_attrs
1:  ldr x0, [x20, x19, lsl #3]
    cbz x0, 2f
    bl _CFRelease
2:  LADDR x0, _av_theme
    add x0, x0, x19, lsl #5
    bl Lmake_attrs
    str x0, [x20, x19, lsl #3]
    add x19, x19, #1
    cmp x19, #T_SLOTS
    b.lo 1b
    // the font may have changed, cached terminal colors start over
    mov x19, #0
    LADDR x20, _av_rgb_attrs
3:  ldr x0, [x20, x19, lsl #3]
    cbz x0, 4f
    str xzr, [x20, x19, lsl #3]
    bl _CFRelease
4:  add x19, x19, #1
    cmp x19, #RGB_COLORS
    b.lo 3b
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// CFDictionaryRef av_render_rgb_attrs(u32 rgb555)
FUNC_BEGIN _av_render_rgb_attrs
    and x0, x0, #0x7fff
    LADDR x9, _av_rgb_attrs
    ldr x10, [x9, x0, lsl #3]
    cbz x10, 1f
    mov x0, x10
    ret
1:  stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    add x1, sp, #32
    bl _av_rgb555_rgba
    add x0, sp, #32
    bl Lmake_attrs
    LADDR x9, _av_rgb_attrs
    str x0, [x9, x19, lsl #3]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_rgb555_rgba(u32 rgb555, double *rgba), opaque
FUNC_BEGIN _av_rgb555_rgba
    mov w9, #31
    ucvtf d7, w9
    ubfx w9, w0, #10, #5
    ucvtf d0, w9
    fdiv d0, d0, d7
    ubfx w9, w0, #5, #5
    ucvtf d1, w9
    fdiv d1, d1, d7
    and w9, w0, #31
    ucvtf d2, w9
    fdiv d2, d2, d7
    fmov d3, #1.0
    stp d0, d1, [x1]
    stp d2, d3, [x1, #16]
    ret

// CFDictionaryRef make_attrs(const double *rgba): {font, foreground color}
    .p2align 2
Lmake_attrs:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    ldp d0, d1, [x0]
    ldp d2, d3, [x0, #16]
    bl _CGColorCreateSRGB
    mov x19, x0
    LEXTERN x0, _kCTFontAttributeName
    LEXTERN x1, _kCTForegroundColorAttributeName
    stp x0, x1, [sp, #32]
    LDRG x0, _av_font
    stp x0, x19, [sp, #48]
    mov x0, #0
    add x1, sp, #32
    add x2, sp, #48
    mov x3, #2
    LGOT x4, _kCFTypeDictionaryKeyCallBacks
    LGOT x5, _kCFTypeDictionaryValueCallBacks
    bl _CFDictionaryCreate
    str x0, [sp, #24]
    mov x0, x19
    bl _CFRelease
    ldr x0, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// double av_render_gutter_w(Buffer *b), at least 3 digits so it does not jump early
FUNC_BEGIN _av_render_gutter_w
    ldr x1, [x0, #BUF_NLINES]
    mov x2, #0
    mov x3, #10
1:  udiv x1, x1, x3
    add x2, x2, #1
    cbnz x1, 1b
    mov x4, #3
    cmp x2, x4
    csel x2, x2, x4, hs
    add x2, x2, #2
    ucvtf d0, x2
    LDRD d1, _av_adv
    fmul d0, d0, d1
    ret

// double av_render_text_x(Buffer *b), x where column 0 starts
FUNC_BEGIN _av_render_text_x
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl _av_render_gutter_w
    fmov d1, #10.0
    fadd d0, d0, d1
    ldp x29, x30, [sp], #16
    ret

// void drawRect:(NSRect)dirty, IMP of AvEditorView
// x19 self, x20 view, x21 ctx, x22 doc, x23 line, x24 nlines, x25 cursor line
// x26/x27 selection, x28 first visible line; d8 W, d9 H, d10 line h, d11 row top
// d12 text x, d13 scroll x, d14 advance, d15 gutter width
FUNC_BEGIN _av_render_draw
    stp x29, x30, [sp, #-DRAW_FRAME]!
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
    LDRG x9, _av_ev_ivar
    ldr x20, [x19, x9]
    CLS x0, NSGraphicsContext
    MSG currentContext
    MSG CGContext
    mov x21, x0
    LGOT x1, _CGAffineTransformIdentity
    bl _CGContextSetTextMatrix
    mov x0, x19
    MSG bounds
    fmov d8, d2
    fmov d9, d3

    mov x0, x21
    LADDR x1, _av_theme
    movi d0, #0
    movi d1, #0
    fmov d2, d8
    fmov d3, d9
    bl _av_fill

    ldr x22, [x20, #V_DOC]
    ldr x24, [x22, #BUF_NLINES]
    LDRD d10, _av_line_h
    LDRD d14, _av_adv
    mov x0, x22
    bl _av_render_gutter_w
    fmov d15, d0
    fmov d1, #10.0
    fadd d12, d0, d1
    ldr d13, [x20, #V_SCROLLX]

    // first visible line and its top edge (view is not flipped, y grows up)
    ldr d0, [x20, #V_SCROLLY]
    fdiv d1, d0, d10
    frintm d1, d1
    fcvtzu x23, d1
    fmul d2, d1, d10
    fsub d2, d0, d2
    fadd d11, d9, d2
    str d11, [sp, #L_Y0]
    mov x28, x23

    mov x0, x22
    ldr x1, [x20, #V_CUR]
    bl _av_buf_line_of
    mov x25, x0
    SEL_RANGE x20, x26, x27

Lrow:
    cmp x23, x24
    b.hs Lrows_end
    fcmp d11, #0.0
    b.le Lrows_end
    fsub d0, d11, d10
    str d0, [sp, #L_YBOT]

    cmp x23, x25
    b.ne 1f
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_CURLINE
    fmov d0, d15
    ldr d1, [sp, #L_YBOT]
    fsub d2, d8, d15
    fmov d3, d10
    bl _av_fill

1:  mov x0, x22
    mov x1, x23
    bl _av_buf_line_start
    str x0, [sp, #L_LS]
    mov x0, x22
    mov x1, x23
    bl _av_buf_line_end
    str x0, [sp, #L_LE]

    // selection overlapping this line, the newline counts as one extra cell
    cmp x26, x27
    b.eq 2f
    ldp x9, x10, [sp, #L_LS]
    cmp x26, x10
    b.hi 2f
    cmp x27, x9
    b.ls 2f
    cmp x26, x9
    csel x1, x26, x9, hi
    mov x0, x22
    bl _av_col_of
    str x0, [sp, #L_CA]
    ldr x10, [sp, #L_LE]
    cmp x27, x10
    csel x1, x27, x10, lo
    mov x0, x22
    bl _av_col_of
    ldr x10, [sp, #L_LE]
    cmp x27, x10
    cinc x0, x0, hi
    ldr x9, [sp, #L_CA]
    subs x1, x0, x9
    b.ls 2f
    ucvtf d2, x1
    fmul d2, d2, d14
    ucvtf d0, x9
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    ldr d1, [sp, #L_YBOT]
    fmov d3, d10
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_SEL
    bl _av_fill

    // text: lex the expanded line, draw each color run at its column
2:  mov x0, x22
    ldp x1, x2, [sp, #L_LS]
    bl Lexpand
    cbz x1, 3f
    stp x0, x1, [sp, #L_TXT]
    mov x0, x22
    mov x1, x23
    bl _av_hl_state_at
    mov x3, x0
    ldr x0, [x22, #DOC_LANG]
    ldp x1, x2, [sp, #L_TXT]
    LADDR x4, _av_runs
    bl _av_hl_lex
    str x1, [sp, #L_NRUNS]
    str xzr, [sp, #L_RUN]
    str xzr, [sp, #L_BYTE]
    str xzr, [sp, #L_COL]
Lrun:
    ldp x9, x10, [sp, #L_NRUNS]
    cmp x10, x9
    b.hs 3f
    LADDR x11, _av_runs
    add x11, x11, x10, lsl #3
    ldr w12, [x11, #RUN_START]
    ldrh w13, [x11, #RUN_LEN]
    ldrh w14, [x11, #RUN_SLOT]
    add x10, x10, #1
    str x10, [sp, #L_RUN]
    // advance the column over the bytes before this run (UTF-8 lead bytes only)
    ldp x15, x16, [sp, #L_BYTE]
    ldr x17, [sp, #L_TXT]
4:  cmp x15, x12
    b.hs 5f
    ldrb w0, [x17, x15]
    add x15, x15, #1
    and w0, w0, #0xc0
    cmp w0, #0x80
    cinc x16, x16, ne
    b 4b
5:  stp x15, x16, [sp, #L_BYTE]
    ucvtf d0, x16
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    fcmp d0, d8
    b.ge 3f
    mov x0, x21
    add x1, x17, x12
    mov x2, x13
    LADDR x3, _av_attrs
    ldr x3, [x3, x14, lsl #3]
    ldr d1, [sp, #L_YBOT]
    LDRD d2, _av_base_off
    fadd d1, d1, d2
    bl _av_draw_text
    b Lrun
3:  add x23, x23, #1
    fsub d11, d11, d10
    b Lrow

Lrows_end:
    str x23, [sp, #L_LAST]
    // gutter drawn after text so horizontally scrolled text slides under it
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_GUTTER
    movi d0, #0
    movi d1, #0
    fmov d2, d15
    fmov d3, d9
    bl _av_fill
    ldr d11, [sp, #L_Y0]
    mov x23, x28
Lnum:
    ldr x9, [sp, #L_LAST]
    cmp x23, x9
    b.hs Lnum_end
    add x0, x23, #1
    add x1, sp, #L_NUMEND
    bl Litoa
    ucvtf d0, x1
    fmov d1, #1.0
    fadd d0, d0, d1
    fmul d0, d0, d14
    fsub d0, d15, d0
    fsub d1, d11, d10
    LDRD d2, _av_base_off
    fadd d1, d1, d2
    ATTRS x3, T_LINENR
    cmp x23, x25
    b.ne 4f
    ATTRS x3, T_LINENR_CUR
4:  mov x2, x1
    mov x1, x0
    mov x0, x21
    bl _av_draw_text
    add x23, x23, #1
    fsub d11, d11, d10
    b Lnum

Lnum_end:
    // only the focused pane shows its cursor
    LDRG x9, _av_focus_view
    cmp x9, x19
    b.ne Lout
    cmp x25, x28
    b.lo Lout
    ldr x9, [sp, #L_LAST]
    cmp x25, x9
    b.hs Lout
    mov x0, x22
    ldr x1, [x20, #V_CUR]
    bl _av_col_of
    ucvtf d0, x0
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    fcmp d0, d15
    b.lt Lout
    sub x9, x25, x28
    add x9, x9, #1
    ucvtf d1, x9
    fmul d1, d1, d10
    ldr d2, [sp, #L_Y0]
    fsub d1, d2, d1
    fmov d4, #2.0
    fadd d1, d1, d4
    fmov d2, #2.0
    fsub d3, d10, d4
    fsub d3, d3, d4
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_CURSOR
    bl _av_fill

Lout:
    ldp d14, d15, [sp, #144]
    ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]
    ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #DRAW_FRAME
    ret

// void av_fill(CGContextRef c, const double *rgba, CGRect r in d0..d3)
FUNC_BEGIN _av_fill
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp d8, d9, [sp, #16]
    stp d10, d11, [sp, #32]
    str x19, [sp, #48]
    mov x19, x0
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    ldp d0, d1, [x1]
    ldp d2, d3, [x1, #16]
    bl _CGContextSetRGBFillColor
    mov x0, x19
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d11
    bl _CGContextFillRect
    ldr x19, [sp, #48]
    ldp d10, d11, [sp, #32]
    ldp d8, d9, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void av_draw_text(CGContextRef c, const char *p, size_t n, CFDictionaryRef attrs, double x, double y)
// invalid UTF-8 falls back to Latin-1 so binary junk still renders
FUNC_BEGIN _av_draw_text
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    mov x20, x3
    mov x21, x1
    mov x22, x2
    fmov d8, d0
    fmov d9, d1
    mov x0, #0
    mov w3, #0x0100
    movk w3, #0x0800, lsl #16
    mov w4, #0
    bl _CFStringCreateWithBytes
    cbnz x0, 1f
    mov x0, #0
    mov x1, x21
    mov x2, x22
    mov w3, #ENC_LATIN1
    mov w4, #0
    bl _CFStringCreateWithBytes
    cbz x0, 9f
1:  mov x21, x0
    mov x0, #0
    mov x1, x21
    mov x2, x20
    bl _CFAttributedStringCreate
    mov x22, x0
    bl _CTLineCreateWithAttributedString
    mov x20, x0
    mov x0, x19
    fmov d0, d8
    fmov d1, d9
    bl _CGContextSetTextPosition
    mov x0, x20
    mov x1, x19
    bl _CTLineDraw
    mov x0, x20
    bl _CFRelease
    mov x0, x22
    bl _CFRelease
    mov x0, x21
    bl _CFRelease
9:  ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// (ptr, len) expand(Buffer *b, size_t ls, size_t le): line bytes with tabs as spaces, CR dropped
    .p2align 2
Lexpand:
    BUF_GEOM x0
    LADDR x3, _av_line_scratch
    mov x4, x3
    add x5, x3, #DISPLAY_MAX
    mov x6, #0
1:  cmp x1, x2
    b.hs 3f
    cmp x4, x5
    b.hs 3f
    BUF_BYTE w7, x1
    add x1, x1, #1
    cmp w7, #9
    b.eq 4f
    cmp w7, #13
    b.eq 1b
    strb w7, [x4], #1
    and w9, w7, #0xc0
    cmp w9, #0x80
    b.eq 1b
    add x6, x6, #1
    b 1b
4:  mov w9, #' '
    LDRG x14, _av_tab_width
    udiv x15, x6, x14
    madd x15, x15, x14, x14
5:  strb w9, [x4], #1
    add x6, x6, #1
    cmp x6, x15
    b.lo 5b
    b 1b
3:  mov x0, x3
    sub x1, x4, x3
    ret

// (ptr, len) itoa(size_t n, char *end), digits written backwards ending at end
    .p2align 2
Litoa:
    mov x2, x1
    mov x3, #10
1:  udiv x4, x0, x3
    msub x5, x4, x3, x0
    add w5, w5, #'0'
    strb w5, [x1, #-1]!
    mov x0, x4
    cbnz x0, 1b
    sub x4, x2, x1
    mov x0, x1
    mov x1, x4
    ret
