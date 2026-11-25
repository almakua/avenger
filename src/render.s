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
.set GUIDE_MAX,   64
.set GUIDE_SCAN,  5000           // lines looked at above the first visible one

// drawRect locals
.set L_Y0,     160
.set L_LINEH,  168
.set L_LS,     176
.set L_LE,     184
.set L_CA,     192
.set L_ROW,    200
.set L_RSTART, 208
.set L_NUMEND, 240
.set L_TXT,    256
.set L_TXTLEN, 264
.set L_NRUNS,  272
.set L_RUN,    280
.set L_BYTE,   288
.set L_COL,    296
.set L_HLP,    304
.set L_HLRGBA, 320
.set L_CURON,  352
.set L_CURX,   360
.set L_CURY,   368
.set L_REND,   376             // run end byte, run slot
.set L_PEND,   392             // piece end byte, its column
.set DRAW_FRAME, 416

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
    // wrap width and row starts of the line being drawn
    .zerofill __DATA,__bss,_av_rwrap,8,3
    .zerofill __DATA,__bss,_av_rstarts,(WRAP_MAX * 8),3
    // indent guides: columns of the enclosing blocks of the line being drawn
    .zerofill __DATA,__bss,_av_gstack,(GUIDE_MAX * 8),3
    .zerofill __DATA,__bss,_av_gdepth,8,3
    .zerofill __DATA,__bss,_av_rctx,8,3
    .globl _av_attrs
    .globl _av_font
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

// size_t av_render_wrap(View *v, double width): wrap width in columns for a view this wide,
// 0 when wrapping is off; also stored in the view for cursor motion
FUNC_BEGIN _av_render_wrap
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    str d8, [sp, #24]
    mov x19, x0
    fmov d8, d0
    mov x0, #0
    LDRG x9, _av_cfg_wrap
    cbz x9, 1f
    ldr x0, [x19, #V_DOC]
    bl _av_render_text_x
    fsub d0, d8, d0
    fmov d1, #6.0
    fsub d0, d0, d1
    LDRD d1, _av_adv
    fdiv d0, d0, d1
    fcvtzs x0, d0
    mov x9, #8
    cmp x0, x9
    csel x0, x9, x0, lt
1:  str x0, [x19, #V_WRAP]
    ldr d8, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// rows of line x23 into x28, row starts in av_rstarts; drawRect helper
    .p2align 2
Lline_rows:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x22
    mov x1, x23
    LDRG x2, _av_rwrap
    LADDR x3, _av_rstarts
    mov x4, #WRAP_MAX
    bl _av_wrap_rows
    mov x28, x0
    ldp x29, x30, [sp], #16
    ret

// (start col, end col) row_cols(size_t r): columns of row r of the current line, end exclusive
// (huge for the last row); drawRect helper, reads x28
    .p2align 2
Lrow_cols:
    LADDR x9, _av_rstarts
    ldr x10, [x9, x0, lsl #3]
    mov x11, #0x7fffffffffffffff
    add x12, x0, #1
    cmp x12, x28
    b.hs 1f
    cmp x12, #WRAP_MAX
    b.hs 1f
    ldr x11, [x9, x12, lsl #3]
1:  mov x0, x10
    mov x1, x11
    ret

// void fill_cols(size_t a, size_t b, const double *rgba): columns [a, b) of the current line,
// one rect per visual row; reads the drawRect registers x21 x28 d10..d14
    .p2align 2
Lfill_cols:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x23, x24, [sp, #32]
    str x25, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x23, x2
    mov x24, #0
1:  cmp x24, x28
    b.hs 9f
    cmp x24, #WRAP_MAX
    b.hs 9f
    mov x0, x24
    bl Lrow_cols
    mov x25, x0
    cmp x19, x0
    csel x2, x19, x0, hi
    cmp x20, x1
    csel x3, x20, x1, lo
    cmp x2, x3
    b.hs 2f
    sub x4, x3, x2
    ucvtf d2, x4
    fmul d2, d2, d14
    sub x4, x2, x25
    ucvtf d0, x4
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    add x4, x24, #1
    ucvtf d1, x4
    fmul d1, d1, d10
    fsub d1, d11, d1
    fmov d3, d10
    mov x0, x21
    mov x1, x23
    bl _av_fill
2:  add x24, x24, #1
    b 1b
9:  ldr x25, [sp, #48]
    ldp x23, x24, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// long indent(size_t line): columns of leading blanks, -1 for a blank line; reads x22
    .p2align 2
Lindent:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x0, x22
    mov x1, x19
    bl _av_buf_line_end
    mov x20, x0
    mov x0, x22
    mov x1, x19
    bl _av_buf_line_start
    mov x2, x0
    mov x3, #0
    BUF_GEOM x22
1:  cmp x2, x20
    b.hs 4f
    BUF_BYTE w4, x2
    cmp w4, #' '
    b.eq 2f
    cmp w4, #9
    b.eq 3f
    cmp w4, #13
    b.eq 4f
    mov x0, x3
    b 9f
2:  add x3, x3, #1
    add x2, x2, #1
    b 1b
3:  LDRG x14, _av_tab_width
    udiv x15, x3, x14
    madd x3, x15, x14, x14
    add x2, x2, #1
    b 1b
4:  mov x0, #-1
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void guides_init(void): enclosing block columns of the first visible line x23, found by
// walking up to the nearest less indented lines
    .p2align 2
Lguides_init:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x24, [sp, #32]
    STRG xzr, _av_gdepth, x9
    LDRG x9, _av_cfg_guides
    cbz x9, 9f
    mov x0, x23
    bl Lindent
    mov x20, x0
    cmp x20, #0
    mov x9, #0x7fffffff
    csel x20, x9, x20, lt
    // collected outer to inner at the top of the stack array, then moved down
    mov x21, #GUIDE_MAX
    mov x19, x23
    mov x24, #GUIDE_SCAN
1:  cbz x19, 3f
    cbz x24, 3f
    cbz x20, 3f
    cbz x21, 3f
    sub x19, x19, #1
    sub x24, x24, #1
    mov x0, x19
    bl Lindent
    tbnz x0, #63, 1b
    cmp x0, x20
    b.hs 1b
    mov x20, x0
    sub x21, x21, #1
    LADDR x9, _av_gstack
    str x0, [x9, x21, lsl #3]
    b 1b
3:  mov x9, #GUIDE_MAX
    sub x2, x9, x21
    STRG x2, _av_gdepth, x9
    LADDR x0, _av_gstack
    add x1, x0, x21, lsl #3
    lsl x2, x2, #3
    bl _memmove
9:  ldp x21, x24, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void guides_line(void): guides of line x23 over its first row, then it opens a block itself;
// a blank line keeps the guides of the line above it, minus that line's own level
    .p2align 2
Lguides_line:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    LDRG x9, _av_cfg_guides
    cbz x9, 9f
    mov x0, x23
    bl Lindent
    mov x19, x0
    LDRG x20, _av_gdepth
    LADDR x9, _av_gstack
    tbnz x19, #63, 2f
1:  cbz x20, 3f
    sub x10, x20, #1
    ldr x11, [x9, x10, lsl #3]
    cmp x11, x19
    b.lt 3f
    mov x20, x10
    b 1b
2:  subs x21, x20, #1
    csel x21, xzr, x21, lo
    b 4f
3:  mov x21, x20
4:  STRG x20, _av_gdepth, x10
    mov x10, #0
5:  cmp x10, x21
    b.hs 6f
    str x10, [sp, #40]
    LADDR x9, _av_gstack
    ldr x11, [x9, x10, lsl #3]
    ucvtf d0, x11
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    fmov d1, #2.0
    fadd d0, d0, d1
    fcmp d0, d12
    b.lt 51f
    fsub d1, d11, d10
    fmov d2, #1.0
    fmov d3, d10
    LDRG x0, _av_rctx
    LADDR x1, _av_theme
    add x1, x1, #T_INDENT
    bl _av_fill
51: ldr x10, [sp, #40]
    add x10, x10, #1
    b 5b
6:  tbnz x19, #63, 9f
    LDRG x20, _av_gdepth
    cmp x20, #GUIDE_MAX
    b.hs 9f
    LADDR x9, _av_gstack
    str x19, [x9, x20, lsl #3]
    add x20, x20, #1
    STRG x20, _av_gdepth, x9
9:  ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void error_line(size_t line_end): squiggle under the first row of line x23 and the message
// after its last row, in the error color
    .p2align 2
Lerror_line:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    str d10, [sp, #48]
    mov x1, x0
    mov x0, x22
    bl _av_col_of
    mov x19, x0
    mov x0, #0
    bl Lrow_cols
    cmp x19, x1
    csel x9, x19, x1, lo
    mov x10, #1
    cmp x9, x10
    csel x9, x10, x9, lo
    ucvtf d8, x9
    fmul d8, d8, d14
    fadd d8, d8, d12
    fsub d8, d8, d13
    fsub d9, d12, d13
    fsub d10, d11, d10
    fmov d0, #1.0
    fadd d10, d10, d0
    mov x20, #0
1:  fcmp d9, d8
    b.ge 2f
    fmov d0, d9
    and x9, x20, #1
    ucvtf d1, x9
    fadd d1, d1, d10
    fmov d2, #2.0
    fmov d3, #1.0
    LDRG x0, _av_rctx
    LADDR x1, _av_theme
    add x1, x1, #T_ERROR
    bl _av_fill
    fmov d0, #2.0
    fadd d9, d9, d0
    add x20, x20, #1
    b 1b
    // message: three columns after the end of the last row
2:  sub x0, x28, #1
    mov x9, #(WRAP_MAX - 1)
    cmp x0, x9
    csel x0, x9, x0, hi
    bl Lrow_cols
    sub x9, x19, x0
    add x9, x9, #3
    ucvtf d8, x9
    fmul d8, d8, d14
    fadd d8, d8, d12
    fsub d8, d8, d13
    ldr x0, [x22, #DOC_ERR]
    bl _av_yaml_error_msg
    mov x19, x0
    bl _strlen
    mov x2, x0
    mov x1, x19
    LDRG x0, _av_rctx
    ATTRS x3, T_ERROR
    fmov d0, d8
    ucvtf d1, x28
    LDRD d2, _av_line_h
    fmul d1, d1, d2
    fsub d1, d11, d1
    LDRD d2, _av_base_off
    fadd d1, d1, d2
    bl _av_draw_text
    ldr d10, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// void drawRect:(NSRect)dirty, IMP of AvEditorView
// lines wrap into visual rows; the scroll offset is a line index plus a fraction of its rows
// x19 self, x20 view, x21 ctx, x22 doc, x23 line, x24 nlines, x25 cursor line
// x26/x27 selection, x28 rows of the line; d8 W, d9 H, d10 line h, d11 line top
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
    STRG x0, _av_rctx, x9
    LGOT x1, _CGAffineTransformIdentity
    bl _CGContextSetTextMatrix
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
    // find matches: the accent color, faint
    LADDR x9, _av_theme
    ldp x10, x11, [x9, #T_ACCENT]
    stp x10, x11, [sp, #L_HLRGBA]
    ldr x10, [x9, #(T_ACCENT + 16)]
    str x10, [sp, #(L_HLRGBA + 16)]
    fmov d0, #0.25
    str d0, [sp, #(L_HLRGBA + 24)]

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
    // wrapped lines never scroll sideways
    mov x0, x20
    fmov d0, d8
    bl _av_render_wrap
    STRG x0, _av_rwrap, x9
    cbz x0, 1f
    str xzr, [x20, #V_SCROLLX]
1:  ldr d13, [x20, #V_SCROLLX]

    // first line and its top edge: the fraction of the offset scrolls through its rows
    ldr d0, [x20, #V_SCROLLY]
    fdiv d1, d0, d10
    frintm d2, d1
    fcvtzu x23, d2
    fsub d1, d1, d2
    str d1, [sp, #L_Y0]
    sub x9, x24, #1
    cmp x23, x9
    csel x23, x9, x23, hi
    bl Lline_rows
    ucvtf d0, x28
    fmul d0, d0, d10
    ldr d1, [sp, #L_Y0]
    fmul d0, d0, d1
    fadd d11, d9, d0

    mov x0, x22
    ldr x1, [x20, #V_CUR]
    bl _av_buf_line_of
    mov x25, x0
    SEL_RANGE x20, x26, x27
    str xzr, [sp, #L_CURON]
    bl Lguides_init

Lrow:
    cmp x23, x24
    b.hs Lrows_end
    fcmp d11, #0.0
    b.le Lrows_end
    bl Lline_rows
    ucvtf d0, x28
    fmul d0, d0, d10
    str d0, [sp, #L_LINEH]

    cmp x23, x25
    b.ne 1f
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_CURLINE
    fmov d0, d15
    ldr d3, [sp, #L_LINEH]
    fsub d1, d11, d3
    fsub d2, d8, d15
    bl _av_fill

1:  bl Lguides_line
    mov x0, x22
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
    cinc x1, x0, hi
    ldr x0, [sp, #L_CA]
    LADDR x2, _av_theme
    add x2, x2, #T_SEL
    bl Lfill_cols

    // find bar matches on this line, under the text
2:  LDRG x9, _av_find_hl
    cbz x9, 29f
    ldr x9, [sp, #L_LS]
    str x9, [sp, #L_HLP]
21: mov x0, x22
    ldr x1, [sp, #L_HLP]
    ldr x2, [sp, #L_LE]
    LADDR x3, _av_find_pat
    LDRG x4, _av_find_hl
    LDRG x5, _av_find_flags
    bl _av_buf_find
    tbnz x0, #63, 29f
    mov x1, x0
    LDRG x9, _av_find_hl
    add x9, x0, x9
    str x9, [sp, #L_HLP]
    mov x0, x22
    bl _av_col_of
    str x0, [sp, #L_CA]
    mov x0, x22
    ldr x1, [sp, #L_HLP]
    bl _av_col_of
    mov x1, x0
    ldr x0, [sp, #L_CA]
    add x2, sp, #L_HLRGBA
    bl Lfill_cols
    b 21b

    // text: lex the expanded line, draw each color run, cut at row ends
29: mov x0, x22
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
    add x13, x12, x13
    stp x13, x14, [sp, #L_REND]
    // advance the column over the bytes before this run (UTF-8 lead bytes only)
    ldp x15, x16, [sp, #L_BYTE]
    ldr x17, [sp, #L_TXT]
4:  cmp x15, x12
    b.hs Lpiece
    ldrb w0, [x17, x15]
    add x15, x15, #1
    and w0, w0, #0xc0
    cmp w0, #0x80
    cinc x16, x16, ne
    b 4b
    // one piece per visual row the run touches: x15 byte, x16 column
Lpiece:
    stp x15, x16, [sp, #L_BYTE]
    ldr x9, [sp, #L_REND]
    cmp x15, x9
    b.hs Lrun
    LADDR x0, _av_rstarts
    mov x1, x28
    mov x2, x16
    bl _av_wrap_row_of
    str x0, [sp, #L_ROW]
    bl Lrow_cols
    str x0, [sp, #L_RSTART]
    // bytes up to the row end or the run end
    ldp x15, x16, [sp, #L_BYTE]
    ldr x9, [sp, #L_REND]
    ldr x17, [sp, #L_TXT]
    mov x2, x15
    mov x3, x16
5:  cmp x2, x9
    b.hs 6f
    ldrb w4, [x17, x2]
    and w4, w4, #0xc0
    cmp w4, #0x80
    b.eq 51f
    cmp x3, x1
    b.hs 6f
    add x3, x3, #1
51: add x2, x2, #1
    b 5b
6:  stp x2, x3, [sp, #L_PEND]
    ldr x4, [sp, #L_RSTART]
    sub x4, x16, x4
    ucvtf d0, x4
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    // unwrapped: nothing more to see past the right edge
    LDRG x9, _av_rwrap
    cbnz x9, 7f
    fcmp d0, d8
    b.ge 3f
7:  ldr x9, [sp, #L_ROW]
    add x9, x9, #1
    ucvtf d1, x9
    fmul d1, d1, d10
    fsub d1, d11, d1
    LDRD d2, _av_base_off
    fadd d1, d1, d2
    mov x0, x21
    add x1, x17, x15
    sub x2, x2, x15
    ldr x14, [sp, #(L_REND + 8)]
    LADDR x3, _av_attrs
    ldr x3, [x3, x14, lsl #3]
    bl _av_draw_text
    ldp x15, x16, [sp, #L_PEND]
    // a piece that stopped at a row end continues on the next row
    b Lpiece

    // YAML error on this line: squiggle under the first row, message after the last one
3:  ldr x9, [x22, #DOC_ERR_LINE]
    sub x9, x9, #1
    cmp x9, x23
    b.ne 39f
    ldr x0, [sp, #L_LE]
    bl Lerror_line

    // cursor position, then the gutter strip and the number of this line
39: cmp x23, x25
    b.ne 31f
    mov x0, x22
    ldr x1, [x20, #V_CUR]
    bl _av_col_of
    str x0, [sp, #L_CA]
    mov x2, x0
    LADDR x0, _av_rstarts
    mov x1, x28
    bl _av_wrap_row_of
    str x0, [sp, #L_ROW]
    bl Lrow_cols
    ldr x9, [sp, #L_CA]
    sub x9, x9, x0
    ucvtf d0, x9
    fmul d0, d0, d14
    fadd d0, d0, d12
    fsub d0, d0, d13
    str d0, [sp, #L_CURX]
    ldr x9, [sp, #L_ROW]
    add x9, x9, #1
    ucvtf d1, x9
    fmul d1, d1, d10
    fsub d1, d11, d1
    str d1, [sp, #L_CURY]
    mov x9, #1
    str x9, [sp, #L_CURON]
31: mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_GUTTER
    movi d0, #0
    ldr d3, [sp, #L_LINEH]
    fsub d1, d11, d3
    fmov d2, d15
    bl _av_fill
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
    b.ne 32f
    ATTRS x3, T_LINENR_CUR
32: ldr x9, [x22, #DOC_ERR_LINE]
    sub x9, x9, #1
    cmp x9, x23
    b.ne 33f
    ATTRS x3, T_ERROR
33: mov x2, x1
    mov x1, x0
    mov x0, x21
    bl _av_draw_text
    ldr d0, [sp, #L_LINEH]
    fsub d11, d11, d0
    add x23, x23, #1
    b Lrow

Lrows_end:
    // gutter below the last line
    fcmp d11, #0.0
    b.le 1f
    mov x0, x21
    LADDR x1, _av_theme
    add x1, x1, #T_GUTTER
    movi d0, #0
    movi d1, #0
    fmov d2, d15
    fmov d3, d11
    bl _av_fill
    // only the focused pane shows its cursor
1:  LDRG x9, _av_focus_view
    cmp x9, x19
    b.ne Lout
    ldr x9, [sp, #L_CURON]
    cbz x9, Lout
    ldr d0, [sp, #L_CURX]
    fcmp d0, d15
    b.lt Lout
    ldr d1, [sp, #L_CURY]
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
