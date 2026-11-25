// theme resolution: palette bytes land in the right slots as normalized doubles

.include "macros.inc"
.include "theme.inc"
.include "yaml.inc"
.include "harness.inc"

// x0 = 0 if NUL-terminated strings at x0 and label s are equal
.macro STREQ s
    LADDR x1, \s
    bl _strcmp
    sxtw x0, w0
.endm

.macro PARSE_CFG doc
    LADDR x0, \doc
    bl _strlen
    mov x1, x0
    LADDR x0, \doc
    bl _av_config_parse
.endm

    .zerofill __DATA,__bss,_tctx,Y_SIZE,4

    .section __TEXT,__cstring,cstring_literals
Lcfg:
    .ascii "font: Fira Code\n"
    .ascii "font_size: 200\n"
    .ascii "tab_width: 2\n"
    .ascii "wrap: off\n"
    .ascii "theme: \"catppuccin-latte\"\n"
    .ascii "keys:\n"
    .asciz "  next_tab: C-n\n"
Lcfg_bad:  .asciz "font: [\n"
Lv_fira:   .asciz "Fira Code"
Ln_frappe: .asciz "Frapp\303\251"
Ln_mocha:  .asciz "Catppuccin Mocha"
Ln_nope:   .asciz "nope"
Lthm:
    .ascii "base: latte\n"
    .ascii "palette:\n"
    .ascii "  base: \"#000000\"\n"
    .ascii "colors:\n"
    .ascii "  keyword: \"#ff000080\"\n"
    .ascii "  string: peach\n"
    .asciz "  bogus: red\n"

// x0 = component c (0 r, 1 g, 2 b, 3 a) of slot scaled back to 0..255
.macro CHANNEL slot, c
    LADDR x9, _av_theme
    ldr d0, [x9, #(\slot + \c * 8)]
    mov w10, #255
    ucvtf d1, w10
    fmul d0, d0, d1
    fcvtas x0, d0
.endm

.macro CHECK_RGB id, slot, r, g, b
    CHANNEL \slot, 0
    CHECK \id, \r
    CHANNEL \slot, 1
    CHECK (\id + 1), \g
    CHANNEL \slot, 2
    CHECK (\id + 2), \b
.endm

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // mocha: base #1e1e2e, text #cdd6f4, keyword mauve #cba6f7
    mov x0, #THEME_MOCHA
    bl _av_theme_load
    CHECK_RGB 1, T_BG, 0x1e, 0x1e, 0x2e
    CHECK_RGB 4, T_TEXT, 0xcd, 0xd6, 0xf4
    CHECK_RGB 7, S_KEYWORD, 0xcb, 0xa6, 0xf7
    CHECK_RGB 80, T_ANSI, 0x45, 0x47, 0x5a
    CHECK_RGB 83, (T_ANSI + 6 * T_SLOT), 0x94, 0xe2, 0xd5
    CHANNEL T_BG, 3
    CHECK 10, 255
    CHANNEL T_SEL, 3
    CHECK 11, 140
    bl _av_theme_is_light
    CHECK 12, 0
    LDRG x0, _av_theme_index
    CHECK 13, THEME_MOCHA

    // latte is light: base #eff1f5, string green #40a02b
    mov x0, #THEME_LATTE
    bl _av_theme_load
    CHECK_RGB 14, T_BG, 0xef, 0xf1, 0xf5
    CHECK_RGB 17, S_STRING, 0x40, 0xa0, 0x2b
    bl _av_theme_is_light
    CHECK 20, 1
    // terminal grays flip on light flavors: black is subtext1, bright white surface1
    CHECK_RGB 70, T_ANSI, 0x5c, 0x5f, 0x77
    CHECK_RGB 73, (T_ANSI + 15 * T_SLOT), 0xbc, 0xc0, 0xcc
    CHECK_RGB 76, (T_ANSI + 1 * T_SLOT), 0xd2, 0x0f, 0x39

    // frappe and macchiato bases
    mov x0, #THEME_FRAPPE
    bl _av_theme_load
    CHECK_RGB 21, T_BG, 0x30, 0x34, 0x46
    mov x0, #THEME_MACCHIATO
    bl _av_theme_load
    CHECK_RGB 24, T_BG, 0x24, 0x27, 0x3a
    CHECK_RGB 27, T_TABBAR, 0x18, 0x19, 0x26

    // out of range falls back to the default
    mov x0, #99
    bl _av_theme_load
    LDRG x0, _av_theme_index
    CHECK 30, THEME_DEFAULT
    CHECK_RGB 31, S_LINK, 0xb4, 0xbe, 0xfe

    // config values, clamping and keeping the previous config on errors
    PARSE_CFG Lcfg
    CHECK 40, 0
    LDRG x0, _av_tab_width
    CHECK 41, 2
    LDRD d0, _av_cfg_font_size
    fcvtzs x0, d0
    CHECK 42, 96
    LDRG x0, _av_cfg_font
    STREQ Lv_fira
    CHECK 43, 0
    LDRG x0, _av_cfg_theme
    bl _av_theme_index_of
    CHECK 44, THEME_LATTE
    LDRG x0, _av_cfg_keys
    cmp x0, #0
    cset x0, ne
    CHECK 45, 1
    LDRG x0, _av_cfg_wrap
    CHECK 90, 0
    LDRG x0, _av_cfg_guides
    CHECK 91, 1
    PARSE_CFG Lcfg_bad
    CHECK 46, -1
    LDRG x0, _av_tab_width
    CHECK 47, 2
    LDRG x0, _av_cfg_err
    CHECK 48, YE_FLOW

    // flavor names
    LADDR x0, Ln_frappe
    bl _av_theme_index_of
    CHECK 49, THEME_FRAPPE
    LADDR x0, Ln_mocha
    bl _av_theme_index_of
    CHECK 50, THEME_MOCHA
    LADDR x0, Ln_nope
    bl _av_theme_index_of
    CHECK 51, -1

    // theme file: base flavor, palette override, slot overrides (hex with alpha, palette name)
    LADDR x0, Lthm
    bl _strlen
    mov x2, x0
    LADDR x0, _tctx
    LADDR x1, Lthm
    bl _av_yaml_parse
    bl _av_theme_load_yaml
    CHECK 52, 0
    CHECK_RGB 53, T_BG, 0, 0, 0
    CHECK_RGB 56, S_KEYWORD, 0xff, 0, 0
    CHANNEL S_KEYWORD, 3
    CHECK 59, 0x80
    CHECK_RGB 60, S_STRING, 0xfe, 0x64, 0x0b
    CHECK_RGB 63, T_TEXT, 0x4c, 0x4f, 0x69
    LDRG x0, _av_theme_index
    CHECK 66, THEME_CUSTOM
    LADDR x0, _tctx
    bl _av_yaml_free

    bl Lsummary
    ldp x29, x30, [sp], #16
    ret
