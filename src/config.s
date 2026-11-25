// config.yaml: font, font_size, theme, tab_width, wrap, indent_guides, prefix, keys
// values point into the parsed tree, which stays alive until the next successful load

.include "macros.inc"
.include "buffer.inc"
.include "yaml.inc"

.set PATH_CAP, 1024
.set STAT_SIZE, 144
.set ST_MTIME, 48

    .section __TEXT,__cstring,cstring_literals
Ldef_font:    .asciz "Menlo"
Ldef_theme:   .asciz "mocha"
Ldef_prefix:  .asciz "C-s"
Lenv_dir:     .asciz "AVENGER_CONFIG_DIR"
Lenv_home:    .asciz "HOME"
Lsub_dir:     .asciz "/.config/avenger"
Lcfg_file:    .asciz "/config.yaml"
Lthemes_dir:  .asciz "/themes/"
Lyaml_ext:    .asciz ".yaml"
Lk_font:      .asciz "font"
Lk_size:      .asciz "font_size"
Lk_theme:     .asciz "theme"
Lk_tab:       .asciz "tab_width"
Lk_wrap:      .asciz "wrap"
Lk_guides:    .asciz "indent_guides"
Lk_prefix:    .asciz "prefix"
Lk_keys:      .asciz "keys"
Lfmt_err:     .asciz "avenger: %s:%ld: %s\n"

    .section __DATA,__data
    .p2align 3
    .globl _av_cfg_font
    .globl _av_cfg_font_size
    .globl _av_cfg_theme
    .globl _av_cfg_prefix
    .globl _av_cfg_keys
    .globl _av_cfg_err
    .globl _av_cfg_err_line
    .globl _av_cfg_wrap
    .globl _av_cfg_guides
_av_cfg_font:      .quad Ldef_font
_av_cfg_font_size: .double 14.0
_av_cfg_theme:     .quad Ldef_theme
_av_cfg_prefix:    .quad Ldef_prefix
_av_cfg_keys:      .quad 0
_av_cfg_err:       .quad 0
_av_cfg_err_line:  .quad 0
_av_cfg_wrap:      .quad 1
_av_cfg_guides:    .quad 1

    .zerofill __DATA,__bss,_av_cfg_yaml,Y_SIZE,4
    .zerofill __DATA,__bss,_av_cfg_new,Y_SIZE,4
    .zerofill __DATA,__bss,_av_cfg_buf,BUF_SIZE,4
    .zerofill __DATA,__bss,_av_cfg_dir,PATH_CAP,4
    .zerofill __DATA,__bss,_av_cfg_path,PATH_CAP,4
    .zerofill __DATA,__bss,_av_cfg_theme_path,PATH_CAP,4
    .zerofill __DATA,__bss,_av_cfg_mtime,8,3
    .zerofill __DATA,__bss,_av_cfg_theme_mtime,8,3
    .globl _av_cfg_dir
    .globl _av_cfg_path

    .text
// void reset_defaults(void)
    .p2align 2
Lreset_defaults:
    LADDR x0, Ldef_font
    STRG x0, _av_cfg_font, x9
    LADDR x0, Ldef_theme
    STRG x0, _av_cfg_theme, x9
    LADDR x0, Ldef_prefix
    STRG x0, _av_cfg_prefix, x9
    STRG xzr, _av_cfg_keys, x9
    fmov d0, #14.0
    adrp x9, _av_cfg_font_size@PAGE
    str d0, [x9, _av_cfg_font_size@PAGEOFF]
    mov x0, #4
    STRG x0, _av_tab_width, x9
    ret

// store a string option if present: STR_OPT key_label, global
.macro STR_OPT key, global
    mov x0, x19
    LADDR x1, \key
    bl _av_yaml_get
    bl _av_yaml_str
    cbz x0, 97f
    STRG x0, \global, x9
97:
.endm

// void apply_root(Node *root)
    .p2align 2
Lapply_root:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl Lreset_defaults
    STR_OPT Lk_font, _av_cfg_font
    STR_OPT Lk_theme, _av_cfg_theme
    STR_OPT Lk_prefix, _av_cfg_prefix

    mov x0, x19
    LADDR x1, Lk_size
    bl _av_yaml_get
    fmov d0, #14.0
    bl _av_yaml_float
    fmov d1, #6.0
    fmax d0, d0, d1
    mov x9, #96
    ucvtf d1, x9
    fmin d0, d0, d1
    adrp x9, _av_cfg_font_size@PAGE
    str d0, [x9, _av_cfg_font_size@PAGEOFF]

    mov x0, x19
    LADDR x1, Lk_tab
    bl _av_yaml_get
    mov x1, #4
    bl _av_yaml_int
    mov x9, #1
    cmp x0, x9
    csel x0, x9, x0, lt
    mov x9, #16
    cmp x0, x9
    csel x0, x9, x0, gt
    STRG x0, _av_tab_width, x9

    mov x0, x19
    LADDR x1, Lk_wrap
    bl _av_yaml_get
    mov x1, #1
    bl _av_yaml_bool
    STRG x0, _av_cfg_wrap, x9
    mov x0, x19
    LADDR x1, Lk_guides
    bl _av_yaml_get
    mov x1, #1
    bl _av_yaml_bool
    STRG x0, _av_cfg_guides, x9

    mov x0, x19
    LADDR x1, Lk_keys
    bl _av_yaml_get
    STRG x0, _av_cfg_keys, x9
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_config_parse(const char *src, size_t n), keeps the previous config on error
FUNC_BEGIN _av_config_parse
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x2, x1
    mov x1, x0
    LADDR x0, _av_cfg_new
    bl _av_yaml_parse
    mov x19, x0
    LADDR x20, _av_cfg_new
    cbnz x19, 1f
    ldp x9, x10, [x20, #Y_ERR]
    STRG x9, _av_cfg_err, x11
    STRG x10, _av_cfg_err_line, x11
    mov x0, x20
    bl _av_yaml_free
    mov x0, #-1
    b 8f
1:  LADDR x0, _av_cfg_yaml
    bl _av_yaml_free
    // move the new tree into place
    LADDR x0, _av_cfg_yaml
    ldp x9, x10, [x20]
    stp x9, x10, [x0]
    ldp x9, x10, [x20, #16]
    stp x9, x10, [x0, #16]
    ldp x9, x10, [x20, #32]
    stp x9, x10, [x0, #32]
    ldp x9, x10, [x20, #48]
    stp x9, x10, [x0, #48]
    ldp x9, x10, [x20, #64]
    stp x9, x10, [x0, #64]
    STRG xzr, _av_cfg_err, x9
    STRG xzr, _av_cfg_err_line, x9
    mov x0, x19
    bl Lapply_root
    mov x0, #0
8:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_config_paths(void): $AVENGER_CONFIG_DIR or ~/.config/avenger
FUNC_BEGIN _av_config_paths
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    LADDR x0, Lenv_dir
    bl _getenv
    cbz x0, 1f
    mov x19, x0
    bl _strlen
    cmp x0, #900
    b.hs 1f
    LADDR x0, _av_cfg_dir
    mov x1, x19
    bl _stpcpy
    b 2f
1:  LADDR x0, Lenv_home
    bl _getenv
    mov x19, x0
    LADDR x0, _av_cfg_dir
    strb wzr, [x0]
    cbz x19, 2f
    mov x0, x19
    bl _strlen
    cmp x0, #900
    b.hs 2f
    LADDR x0, _av_cfg_dir
    mov x1, x19
    bl _stpcpy
    LADDR x1, Lsub_dir
    bl _stpcpy
2:  LADDR x0, _av_cfg_path
    LADDR x1, _av_cfg_dir
    bl _stpcpy
    LADDR x1, Lcfg_file
    bl _stpcpy
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// u64 mtime(const char *path) in ns, 0 when missing
    .p2align 2
Lmtime:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #STAT_SIZE
    mov x1, sp
    bl _stat
    mov x9, x0
    mov x0, #0
    cbnz w9, 1f
    ldp x9, x10, [sp, #ST_MTIME]
    mov x11, #0xca00
    movk x11, #0x3b9a, lsl #16
    madd x0, x9, x11, x10
1:  add sp, sp, #STAT_SIZE
    ldp x29, x30, [sp], #16
    ret

// int av_config_load(void): 0 loaded, 1 no file (defaults), -1 parse error (previous kept)
FUNC_BEGIN _av_config_load
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    bl _av_config_paths
    LADDR x0, _av_cfg_path
    bl Lmtime
    STRG x0, _av_cfg_mtime, x9
    LADDR x0, _av_cfg_buf
    LADDR x1, _av_cfg_path
    bl _av_buf_load
    cbz x0, 1f
    LADDR x0, _av_cfg_yaml
    bl _av_yaml_free
    bl Lreset_defaults
    mov x0, #1
    b 8f
1:  LADDR x19, _av_cfg_buf
    ldr x0, [x19, #BUF_DATA]
    ldr x1, [x19, #BUF_GS]
    bl _av_config_parse
    mov x20, x0
    mov x0, x19
    bl _av_buf_free
    tbz x20, #63, 2f
    LADDR x0, _av_cfg_path
    LDRG x1, _av_cfg_err_line
    LDRG x2, _av_cfg_err
    bl _av_report_yaml_error
2:  mov x0, x20
8:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_report_yaml_error(const char *path, long line, long code), to stderr
FUNC_BEGIN _av_report_yaml_error
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    mov x0, x2
    bl _av_yaml_error_msg
    sub sp, sp, #32
    stp x19, x20, [sp]
    str x0, [sp, #16]
    mov w0, #2
    LADDR x1, Lfmt_err
    bl _dprintf
    add sp, sp, #32
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// const char *av_config_theme_path(const char *name): <dir>/themes/<name>.yaml, remembers its mtime
FUNC_BEGIN _av_config_theme_path
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _strlen
    cmp x0, #64
    b.hs 1f
    LADDR x0, _av_cfg_theme_path
    LADDR x1, _av_cfg_dir
    bl _stpcpy
    LADDR x1, Lthemes_dir
    bl _stpcpy
    mov x1, x19
    bl _stpcpy
    LADDR x1, Lyaml_ext
    bl _stpcpy
    LADDR x0, _av_cfg_theme_path
    bl Lmtime
    STRG x0, _av_cfg_theme_mtime, x9
    LADDR x0, _av_cfg_theme_path
    b 2f
1:  bl _av_config_forget_theme
    LADDR x0, _av_cfg_theme_path
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_config_forget_theme(void), built-in theme in use: nothing to watch
FUNC_BEGIN _av_config_forget_theme
    LADDR x0, _av_cfg_theme_path
    strb wzr, [x0]
    STRG xzr, _av_cfg_theme_mtime, x9
    ret

// int av_config_changed(void), config.yaml or the custom theme file changed on disk
FUNC_BEGIN _av_config_changed
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LADDR x0, _av_cfg_path
    bl Lmtime
    LDRG x9, _av_cfg_mtime
    cmp x0, x9
    b.ne 1f
    LADDR x0, _av_cfg_theme_path
    ldrb w9, [x0]
    cbz w9, 2f
    bl Lmtime
    LDRG x9, _av_cfg_theme_mtime
    cmp x0, x9
    b.ne 1f
2:  mov w0, #0
    b 3f
1:  mov w0, #1
3:  ldp x29, x30, [sp], #16
    ret
