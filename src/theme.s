// themes: built-in Catppuccin palettes plus one slot map shared by every flavor
// a theme is resolved into _av_theme (doubles) so drawing never touches the palette

.include "macros.inc"
.include "theme.inc"
.include "buffer.inc"
.include "yaml.inc"

.set PAL_COLORS, 26
.set PAL_SIZE,   PAL_COLORS * 3

// palette indices, Catppuccin order
.set P_ROSEWATER, 0
.set P_FLAMINGO,  1
.set P_PINK,      2
.set P_MAUVE,     3
.set P_RED,       4
.set P_MAROON,    5
.set P_PEACH,     6
.set P_YELLOW,    7
.set P_GREEN,     8
.set P_TEAL,      9
.set P_SKY,       10
.set P_SAPPHIRE,  11
.set P_BLUE,      12
.set P_LAVENDER,  13
.set P_TEXT,      14
.set P_SUBTEXT1,  15
.set P_SUBTEXT0,  16
.set P_OVERLAY2,  17
.set P_OVERLAY1,  18
.set P_OVERLAY0,  19
.set P_SURFACE2,  20
.set P_SURFACE1,  21
.set P_SURFACE0,  22
.set P_BASE,      23
.set P_MANTLE,    24
.set P_CRUST,     25

    .section __TEXT,__const
Lpalettes:
    // latte
    .byte 0xdc,0x8a,0x78, 0xdd,0x78,0x78, 0xea,0x76,0xcb, 0x88,0x39,0xef, 0xd2,0x0f,0x39, 0xe6,0x45,0x53
    .byte 0xfe,0x64,0x0b, 0xdf,0x8e,0x1d, 0x40,0xa0,0x2b, 0x17,0x92,0x99, 0x04,0xa5,0xe5, 0x20,0x9f,0xb5
    .byte 0x1e,0x66,0xf5, 0x72,0x87,0xfd, 0x4c,0x4f,0x69, 0x5c,0x5f,0x77, 0x6c,0x6f,0x85, 0x7c,0x7f,0x93
    .byte 0x8c,0x8f,0xa1, 0x9c,0xa0,0xb0, 0xac,0xb0,0xbe, 0xbc,0xc0,0xcc, 0xcc,0xd0,0xda, 0xef,0xf1,0xf5
    .byte 0xe6,0xe9,0xef, 0xdc,0xe0,0xe8
    // frappe
    .byte 0xf2,0xd5,0xcf, 0xee,0xbe,0xbe, 0xf4,0xb8,0xe4, 0xca,0x9e,0xe6, 0xe7,0x82,0x84, 0xea,0x99,0x9c
    .byte 0xef,0x9f,0x76, 0xe5,0xc8,0x90, 0xa6,0xd1,0x89, 0x81,0xc8,0xbe, 0x99,0xd1,0xdb, 0x85,0xc1,0xdc
    .byte 0x8c,0xaa,0xee, 0xba,0xbb,0xf1, 0xc6,0xd0,0xf5, 0xb5,0xbf,0xe2, 0xa5,0xad,0xce, 0x94,0x9c,0xbb
    .byte 0x83,0x8b,0xa7, 0x73,0x79,0x94, 0x62,0x68,0x80, 0x51,0x57,0x6d, 0x41,0x45,0x59, 0x30,0x34,0x46
    .byte 0x29,0x2c,0x3c, 0x23,0x26,0x34
    // macchiato
    .byte 0xf4,0xdb,0xd6, 0xf0,0xc6,0xc6, 0xf5,0xbd,0xe6, 0xc6,0xa0,0xf6, 0xed,0x87,0x96, 0xee,0x99,0xa0
    .byte 0xf5,0xa9,0x7f, 0xee,0xd4,0x9f, 0xa6,0xda,0x95, 0x8b,0xd5,0xca, 0x91,0xd7,0xe3, 0x7d,0xc4,0xe4
    .byte 0x8a,0xad,0xf4, 0xb7,0xbd,0xf8, 0xca,0xd3,0xf5, 0xb8,0xc0,0xe0, 0xa5,0xad,0xcb, 0x93,0x9a,0xb7
    .byte 0x80,0x87,0xa2, 0x6e,0x73,0x8d, 0x5b,0x60,0x78, 0x49,0x4d,0x64, 0x36,0x3a,0x4f, 0x24,0x27,0x3a
    .byte 0x1e,0x20,0x30, 0x18,0x19,0x26
    // mocha
    .byte 0xf5,0xe0,0xdc, 0xf2,0xcd,0xcd, 0xf5,0xc2,0xe7, 0xcb,0xa6,0xf7, 0xf3,0x8b,0xa8, 0xeb,0xa0,0xac
    .byte 0xfa,0xb3,0x87, 0xf9,0xe2,0xaf, 0xa6,0xe3,0xa1, 0x94,0xe2,0xd5, 0x89,0xdc,0xeb, 0x74,0xc7,0xec
    .byte 0x89,0xb4,0xfa, 0xb4,0xbe,0xfe, 0xcd,0xd6,0xf4, 0xba,0xc2,0xde, 0xa6,0xad,0xc8, 0x93,0x99,0xb2
    .byte 0x7f,0x84,0x9c, 0x6c,0x70,0x86, 0x58,0x5b,0x70, 0x45,0x47,0x5a, 0x31,0x32,0x44, 0x1e,0x1e,0x2e
    .byte 0x18,0x18,0x25, 0x11,0x11,0x1b

    // slot -> (palette index, alpha 0..255), follows the Catppuccin style guide
Lslot_map:
    .byte P_BASE, 255        // bg
    .byte P_MANTLE, 255      // gutter
    .byte P_SURFACE0, 115    // current line
    .byte P_SURFACE2, 140    // selection
    .byte P_OVERLAY0, 255    // line number
    .byte P_LAVENDER, 255    // current line number
    .byte P_TEXT, 255        // text
    .byte P_ROSEWATER, 255   // cursor
    .byte P_CRUST, 255       // tab bar
    .byte P_BASE, 255        // active tab
    .byte P_SUBTEXT0, 255    // tab text
    .byte P_TEXT, 255        // active tab text
    .byte P_MAUVE, 255       // accent
    .byte P_SURFACE1, 153    // indent guide
    .byte P_RED, 255         // error
    .byte P_YELLOW, 255      // warning
    .byte P_MAUVE, 255       // keyword
    .byte P_GREEN, 255       // string
    .byte P_PEACH, 255       // number
    .byte P_OVERLAY2, 255    // comment
    .byte P_YELLOW, 255      // type
    .byte P_BLUE, 255        // function
    .byte P_SKY, 255         // operator
    .byte P_OVERLAY2, 255    // punctuation
    .byte P_PEACH, 255       // constant
    .byte P_BLUE, 255        // key
    .byte P_FLAMINGO, 255    // label
    .byte P_MAROON, 255      // special (registers, builtins)
    .byte P_PINK, 255        // escape
    .byte P_TEAL, 255        // tag, anchor
    .byte P_RED, 255         // heading
    .byte P_LAVENDER, 255    // link
    // terminal, the Catppuccin terminal ports
    .byte P_SURFACE1, 255    // black
    .byte P_RED, 255
    .byte P_GREEN, 255
    .byte P_YELLOW, 255
    .byte P_BLUE, 255
    .byte P_PINK, 255        // magenta
    .byte P_TEAL, 255        // cyan
    .byte P_SUBTEXT1, 255    // white
    .byte P_SURFACE2, 255    // bright black
    .byte P_RED, 255
    .byte P_GREEN, 255
    .byte P_YELLOW, 255
    .byte P_BLUE, 255
    .byte P_PINK, 255
    .byte P_TEAL, 255
    .byte P_SUBTEXT0, 255    // bright white
    // light flavors swap the grays so black stays dark: (slot, palette index)
Lslot_light:
    .byte T_ANSI_IDX + 0, P_SUBTEXT1
    .byte T_ANSI_IDX + 7, P_SURFACE2
    .byte T_ANSI_IDX + 8, P_SUBTEXT0
    .byte T_ANSI_IDX + 15, P_SURFACE1

    .section __TEXT,__cstring,cstring_literals
Ln_latte:     .asciz "Catppuccin Latte"
Ln_frappe:    .asciz "Catppuccin Frapp\303\251"
Ln_macchiato: .asciz "Catppuccin Macchiato"
Ln_mocha:     .asciz "Catppuccin Mocha"

    // names used in theme YAML files
Lf_latte:      .asciz "latte"
Lf_frappe:     .asciz "frappe"
Lf_macchiato:  .asciz "macchiato"
Lf_mocha:      .asciz "mocha"
Lf_frappe2:    .asciz "frapp\303\251"
Lprefix:       .asciz "catppuccin"
Lk_base:       .asciz "base"
Lk_palette:    .asciz "palette"
Lk_colors:     .asciz "colors"

Lp_rosewater:  .asciz "rosewater"
Lp_flamingo:   .asciz "flamingo"
Lp_pink:       .asciz "pink"
Lp_mauve:      .asciz "mauve"
Lp_red:        .asciz "red"
Lp_maroon:     .asciz "maroon"
Lp_peach:      .asciz "peach"
Lp_yellow:     .asciz "yellow"
Lp_green:      .asciz "green"
Lp_teal:       .asciz "teal"
Lp_sky:        .asciz "sky"
Lp_sapphire:   .asciz "sapphire"
Lp_blue:       .asciz "blue"
Lp_lavender:   .asciz "lavender"
Lp_text:       .asciz "text"
Lp_subtext1:   .asciz "subtext1"
Lp_subtext0:   .asciz "subtext0"
Lp_overlay2:   .asciz "overlay2"
Lp_overlay1:   .asciz "overlay1"
Lp_overlay0:   .asciz "overlay0"
Lp_surface2:   .asciz "surface2"
Lp_surface1:   .asciz "surface1"
Lp_surface0:   .asciz "surface0"
Lp_base:       .asciz "base"
Lp_mantle:     .asciz "mantle"
Lp_crust:      .asciz "crust"

Ls_background: .asciz "background"
Ls_gutter:     .asciz "gutter"
Ls_curline:    .asciz "current_line"
Ls_selection:  .asciz "selection"
Ls_linenr:     .asciz "line_number"
Ls_linenr_on:  .asciz "line_number_active"
Ls_text:       .asciz "text"
Ls_cursor:     .asciz "cursor"
Ls_tabbar:     .asciz "tab_bar"
Ls_tab_on:     .asciz "tab_active"
Ls_tab_text:   .asciz "tab_text"
Ls_tab_text_on: .asciz "tab_text_active"
Ls_accent:     .asciz "accent"
Ls_indent:     .asciz "indent_guide"
Ls_error:      .asciz "error"
Ls_warning:    .asciz "warning"
Ls_keyword:    .asciz "keyword"
Ls_string:     .asciz "string"
Ls_number:     .asciz "number"
Ls_comment:    .asciz "comment"
Ls_type:       .asciz "type"
Ls_function:   .asciz "function"
Ls_operator:   .asciz "operator"
Ls_punct:      .asciz "punctuation"
Ls_constant:   .asciz "constant"
Ls_key:        .asciz "key"
Ls_label:      .asciz "label"
Ls_special:    .asciz "special"
Ls_escape:     .asciz "escape"
Ls_tag:        .asciz "tag"
Ls_heading:    .asciz "heading"
Ls_link:       .asciz "link"
La_black:      .asciz "ansi_black"
La_red:        .asciz "ansi_red"
La_green:      .asciz "ansi_green"
La_yellow:     .asciz "ansi_yellow"
La_blue:       .asciz "ansi_blue"
La_magenta:    .asciz "ansi_magenta"
La_cyan:       .asciz "ansi_cyan"
La_white:      .asciz "ansi_white"
La_bblack:     .asciz "ansi_bright_black"
La_bred:       .asciz "ansi_bright_red"
La_bgreen:     .asciz "ansi_bright_green"
La_byellow:    .asciz "ansi_bright_yellow"
La_bblue:      .asciz "ansi_bright_blue"
La_bmagenta:   .asciz "ansi_bright_magenta"
La_bcyan:      .asciz "ansi_bright_cyan"
La_bwhite:     .asciz "ansi_bright_white"

    .section __DATA,__const
    .p2align 3
Lnames:
    .quad Ln_latte, Ln_frappe, Ln_macchiato, Ln_mocha
Lflavor_keys:
    .quad Lf_latte, Lf_frappe, Lf_macchiato, Lf_mocha, Lf_frappe2
Lpal_names:
    .quad Lp_rosewater, Lp_flamingo, Lp_pink, Lp_mauve, Lp_red, Lp_maroon, Lp_peach
    .quad Lp_yellow, Lp_green, Lp_teal, Lp_sky, Lp_sapphire, Lp_blue, Lp_lavender
    .quad Lp_text, Lp_subtext1, Lp_subtext0, Lp_overlay2, Lp_overlay1, Lp_overlay0
    .quad Lp_surface2, Lp_surface1, Lp_surface0, Lp_base, Lp_mantle, Lp_crust
Lslot_names:
    .quad Ls_background, Ls_gutter, Ls_curline, Ls_selection, Ls_linenr, Ls_linenr_on
    .quad Ls_text, Ls_cursor, Ls_tabbar, Ls_tab_on, Ls_tab_text, Ls_tab_text_on
    .quad Ls_accent, Ls_indent, Ls_error, Ls_warning, Ls_keyword, Ls_string
    .quad Ls_number, Ls_comment, Ls_type, Ls_function, Ls_operator, Ls_punct
    .quad Ls_constant, Ls_key, Ls_label, Ls_special, Ls_escape, Ls_tag
    .quad Ls_heading, Ls_link
    .quad La_black, La_red, La_green, La_yellow, La_blue, La_magenta, La_cyan, La_white
    .quad La_bblack, La_bred, La_bgreen, La_byellow, La_bblue, La_bmagenta, La_bcyan
    .quad La_bwhite

    .zerofill __DATA,__bss,_av_theme,T_SIZE,4
    .globl _av_theme
    .zerofill __DATA,__bss,_av_palette,(PAL_SIZE + 2),4
    .zerofill __DATA,__bss,_av_thm_buf,BUF_SIZE,4
    .zerofill __DATA,__bss,_av_thm_yaml,Y_SIZE,4
    .section __DATA,__data
    .globl _av_theme_index
    .p2align 3
_av_theme_index:
    .quad THEME_DEFAULT

    .text
// void av_theme_load(size_t idx), out of range falls back to the default flavor
FUNC_BEGIN _av_theme_load
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cmp x0, #THEME_COUNT
    mov x9, #THEME_DEFAULT
    csel x0, x0, x9, lo
    STRG x0, _av_theme_index, x9
    bl Lcopy_palette
    bl Lresolve
    ldp x29, x30, [sp], #16
    ret

// void copy_palette(size_t flavor), built-in palette into the working palette
    .p2align 2
Lcopy_palette:
    LADDR x1, Lpalettes
    mov x2, #PAL_SIZE
    madd x1, x0, x2, x1
    LADDR x0, _av_palette
    b _memcpy

// void resolve(void): working palette + slot map -> _av_theme
    .p2align 2
Lresolve:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    LADDR x19, Lslot_map
    mov x20, #0
1:  mov x0, x20
    ldrb w1, [x19], #1
    ldrb w2, [x19], #1
    bl Lset_slot
    add x20, x20, #1
    cmp x20, #T_SLOTS
    b.lo 1b
    // light base (r + g + b > 384): dark grays for black, light ones for white
    LADDR x9, _av_palette
    add x9, x9, #(P_BASE * 3)
    ldrb w10, [x9]
    ldrb w11, [x9, #1]
    ldrb w12, [x9, #2]
    add w10, w10, w11
    add w10, w10, w12
    cmp w10, #384
    b.ls 3f
    LADDR x19, Lslot_light
    mov x20, #4
2:  ldrb w0, [x19], #1
    ldrb w1, [x19], #1
    mov w2, #255
    bl Lset_slot
    subs x20, x20, #1
    b.ne 2b
3:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void set_slot(size_t slot, size_t palette_index, u32 alpha)
    .p2align 2
Lset_slot:
    LADDR x9, _av_palette
    add x1, x1, x1, lsl #1
    add x9, x9, x1
    LADDR x10, _av_theme
    add x10, x10, x0, lsl #5
    mov w11, #255
    ucvtf d7, w11
    ldrb w11, [x9]
    ucvtf d0, w11
    fdiv d0, d0, d7
    ldrb w11, [x9, #1]
    ucvtf d1, w11
    fdiv d1, d1, d7
    ldrb w11, [x9, #2]
    ucvtf d2, w11
    fdiv d2, d2, d7
    ucvtf d3, w2
    fdiv d3, d3, d7
    stp d0, d1, [x10]
    stp d2, d3, [x10, #16]
    ret

// void store_rgba(double *slot, u32 rrggbbaa)
    .p2align 2
Lstore_rgba:
    mov w9, #255
    ucvtf d7, w9
    lsr w9, w1, #24
    ucvtf d0, w9
    ubfx w9, w1, #16, #8
    ucvtf d1, w9
    ubfx w9, w1, #8, #8
    ucvtf d2, w9
    and w9, w1, #0xff
    ucvtf d3, w9
    fdiv d0, d0, d7
    fdiv d1, d1, d7
    fdiv d2, d2, d7
    fdiv d3, d3, d7
    stp d0, d1, [x0]
    stp d2, d3, [x0, #16]
    ret

// long parse_hex(const char *s): "#rrggbb" or "#rrggbbaa" -> rrggbbaa, -1 if invalid
    .p2align 2
Lparse_hex:
    ldrb w9, [x0]
    cmp w9, #'#'
    cinc x0, x0, eq
    mov x1, #0
    mov x2, #0
1:  ldrb w9, [x0], #1
    cbz w9, 3f
    sub w10, w9, #'0'
    cmp w10, #9
    b.ls 2f
    orr w10, w9, #0x20
    sub w10, w10, #'a'
    cmp w10, #5
    b.hi 9f
    add w10, w10, #10
2:  lsl x1, x1, #4
    add x1, x1, x10
    add x2, x2, #1
    b 1b
3:  cmp x2, #8
    b.eq 4f
    cmp x2, #6
    b.ne 9f
    lsl x1, x1, #8
    orr x1, x1, #0xff
4:  mov x0, x1
    ret
9:  mov x0, #-1
    ret

// long find_name(const char **table, size_t n, const char *name), case-insensitive
    .p2align 2
Lfind_name:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
    cbz x21, 2f
1:  cmp x22, x20
    b.hs 2f
    ldr x0, [x19, x22, lsl #3]
    mov x1, x21
    bl _strcasecmp
    cbz w0, 3f
    add x22, x22, #1
    b 1b
2:  mov x22, #-1
3:  mov x0, x22
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// long av_theme_index_of(const char *name): built-in flavor, "catppuccin-" prefix optional, -1 if none
FUNC_BEGIN _av_theme_index_of
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    cbz x19, 2f
    LADDR x1, Lprefix
    mov x2, #10
    bl _strncasecmp
    cbnz w0, 1f
    add x19, x19, #10
    ldrb w9, [x19]
    mov w10, #' '
    mov w11, #'_'
    cmp w9, #'-'
    ccmp w9, w10, #4, ne
    ccmp w9, w11, #4, ne
    cinc x19, x19, eq
1:  LADDR x0, Lflavor_keys
    mov x1, #5
    mov x2, x19
    bl Lfind_name
    cmp x0, #4
    mov x9, #THEME_FRAPPE
    csel x0, x9, x0, eq
    b 3f
2:  mov x0, #-1
3:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_theme_load_yaml(Node *root): base flavor, palette overrides, then per-slot colors
// x19 root, x20 current child, x21 name index, x22 value text
FUNC_BEGIN _av_theme_load_yaml
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    LADDR x1, Lk_base
    bl _av_yaml_get
    bl _av_yaml_str
    bl _av_theme_index_of
    mov x9, #THEME_DEFAULT
    cmp x0, #0
    csel x0, x9, x0, lt
    bl Lcopy_palette

    mov x0, x19
    LADDR x1, Lk_palette
    bl _av_yaml_get
    bl Lfirst_child
    mov x20, x0
1:  cbz x20, 2f
    LADDR x0, Lpal_names
    mov x1, #PAL_COLORS
    ldr x2, [x20, #N_KEY]
    bl Lfind_name
    tbnz x0, #63, 11f
    mov x21, x0
    mov x0, x20
    bl _av_yaml_str
    cbz x0, 11f
    bl Lparse_hex
    tbnz x0, #63, 11f
    LADDR x9, _av_palette
    add x10, x21, x21, lsl #1
    add x9, x9, x10
    lsr w10, w0, #24
    strb w10, [x9]
    lsr w10, w0, #16
    strb w10, [x9, #1]
    lsr w10, w0, #8
    strb w10, [x9, #2]
11: ldr x20, [x20, #N_NEXT]
    b 1b
2:  bl Lresolve

    mov x0, x19
    LADDR x1, Lk_colors
    bl _av_yaml_get
    bl Lfirst_child
    mov x20, x0
3:  cbz x20, 6f
    LADDR x0, Lslot_names
    mov x1, #T_SLOTS
    ldr x2, [x20, #N_KEY]
    bl Lfind_name
    tbnz x0, #63, 5f
    mov x21, x0
    mov x0, x20
    bl _av_yaml_str
    cbz x0, 5f
    mov x22, x0
    ldrb w9, [x22]
    cmp w9, #'#'
    b.ne 4f
    bl Lparse_hex
    tbnz x0, #63, 5f
    mov w1, w0
    b 41f
    // palette color name, alpha from the slot's default
4:  LADDR x0, Lpal_names
    mov x1, #PAL_COLORS
    mov x2, x22
    bl Lfind_name
    tbnz x0, #63, 5f
    LADDR x9, _av_palette
    add x10, x0, x0, lsl #1
    add x9, x9, x10
    ldrb w10, [x9]
    ldrb w11, [x9, #1]
    ldrb w12, [x9, #2]
    LADDR x13, Lslot_map
    add x13, x13, x21, lsl #1
    ldrb w13, [x13, #1]
    lsl w1, w10, #24
    orr w1, w1, w11, lsl #16
    orr w1, w1, w12, lsl #8
    orr w1, w1, w13
41: LADDR x0, _av_theme
    add x0, x0, x21, lsl #5
    bl Lstore_rgba
5:  ldr x20, [x20, #N_NEXT]
    b 3b
6:  mov x0, #THEME_CUSTOM
    STRG x0, _av_theme_index, x9
    mov x0, #0
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Node *first_child(Node *map), NULL unless a non-empty map
    .p2align 2
Lfirst_child:
    cbz x0, 1f
    ldrb w9, [x0, #N_TYPE]
    cmp w9, #Y_MAP
    b.ne 2f
    ldr x0, [x0, #N_PTR]
    ret
2:  mov x0, #0
1:  ret

// int av_theme_load_file(const char *path), -1 if unreadable or invalid (error printed)
FUNC_BEGIN _av_theme_load_file
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x1, x0
    LADDR x0, _av_thm_buf
    bl _av_buf_load
    cbnz x0, 9f
    LADDR x9, _av_thm_buf
    ldr x1, [x9, #BUF_DATA]
    ldr x2, [x9, #BUF_GS]
    LADDR x0, _av_thm_yaml
    bl _av_yaml_parse
    cbnz x0, 1f
    LADDR x9, _av_thm_yaml
    mov x0, x19
    ldr x1, [x9, #Y_ERRLINE]
    ldr x2, [x9, #Y_ERR]
    bl _av_report_yaml_error
    mov x20, #-1
    b 2f
1:  bl _av_theme_load_yaml
    mov x20, #0
2:  LADDR x0, _av_thm_yaml
    bl _av_yaml_free
    LADDR x0, _av_thm_buf
    bl _av_buf_free
    mov x0, x20
    b 8f
9:  mov x0, #-1
8:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// size_t av_theme_count(void)
FUNC_BEGIN _av_theme_count
    mov x0, #THEME_COUNT
    ret

// const char *av_theme_name(size_t idx)
FUNC_BEGIN _av_theme_name
    LADDR x1, Lnames
    ldr x0, [x1, x0, lsl #3]
    ret

// int av_theme_is_light(void), from the loaded background
FUNC_BEGIN _av_theme_is_light
    LADDR x0, _av_theme
    ldp d0, d1, [x0, #T_BG]
    ldr d2, [x0, #(T_BG + 16)]
    fadd d0, d0, d1
    fadd d0, d0, d2
    fmov d1, #1.5
    fcmp d0, d1
    cset w0, gt
    ret
