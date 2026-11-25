// key specs, default prefix bindings and overrides from YAML

.include "macros.inc"
.include "yaml.inc"
.include "keymap.inc"
.include "harness.inc"

.macro SPEC id, lit, mods, cp
    LADDR x0, \lit
    bl _av_key_parse
    CHECK \id, ((\mods << 32) | \cp)
.endm

.macro BAD id, lit
    LADDR x0, \lit
    bl _av_key_parse
    CHECK \id, -1
.endm

.macro LOOKUP id, mods, cp, action
    ldr x0, =\mods
    ldr x1, =\cp
    bl _av_keymap_lookup
    CHECK \id, \action
.endm

    .zerofill __DATA,__bss,_tctx,Y_SIZE,4

    .section __TEXT,__cstring,cstring_literals
Ls_cs:     .asciz "C-s"
Ls_mx:     .asciz "M-x"
Ls_ax:     .asciz "A-x"
Ls_dt:     .asciz "D-t"
Ls_csa:    .asciz "C-S-a"
Ls_left:   .asciz "Left"
Ls_space:  .asciz "space"
Ls_pct:    .asciz "%"
Ls_dash:   .asciz "C--"
Ls_euro:   .asciz "\342\202\254"
Ls_empty:  .asciz ""
Ls_cdash:  .asciz "C-"
Ls_foo:    .asciz "Foo"
Ls_ca:     .asciz "C-a"
Ln_open:   .asciz "open_config"
Ln_tab9:   .asciz "TAB_9"
Ln_nope:   .asciz "nope"
Lkeys:
    .ascii "new_tab: t\n"
    .ascii "close_tab: C-w\n"
    .ascii "last_tab:\n"
    .ascii "bogus: z\n"
    .asciz "save: \"C-\"\n"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    SPEC 1, Ls_cs, MOD_CTRL, 's'
    SPEC 2, Ls_mx, MOD_OPT, 'x'
    SPEC 3, Ls_ax, MOD_OPT, 'x'
    SPEC 4, Ls_dt, MOD_CMD, 't'
    SPEC 5, Ls_csa, (MOD_CTRL | MOD_SHIFT), 'a'
    SPEC 6, Ls_left, 0, KEY_LEFT_CP
    SPEC 7, Ls_space, 0, ' '
    SPEC 8, Ls_pct, 0, '%'
    SPEC 9, Ls_dash, MOD_CTRL, '-'
    SPEC 10, Ls_euro, 0, 0x20ac
    BAD 11, Ls_empty
    BAD 12, Ls_cdash
    BAD 13, Ls_foo

    LADDR x0, Ln_open
    bl _av_action_id
    CHECK 20, A_OPEN_CONFIG
    LADDR x0, Ln_tab9
    bl _av_action_id
    CHECK 21, A_TAB_9
    LADDR x0, Ln_nope
    bl _av_action_id
    CHECK 22, 0

    // defaults; shift is ignored unless the binding asks for it
    mov x0, #0
    mov x1, #0
    bl _av_keymap_configure
    LDRG x0, _av_prefix_mods
    CHECK 30, MOD_CTRL
    LDRG x0, _av_prefix_cp
    CHECK 31, 's'
    LOOKUP 32, 0, 'c', A_NEW_TAB
    LOOKUP 33, MOD_SHIFT, ',', A_OPEN_CONFIG
    LOOKUP 34, MOD_CTRL, 'c', 0
    LOOKUP 35, 0, '9', A_TAB_9
    LOOKUP 36, 0, 'z', 0
    LOOKUP 37, 0, 't', A_NEW_TERM
    LOOKUP 38, MOD_SHIFT, 'T', A_NEXT_THEME

    // overrides from YAML, custom prefix
    LADDR x0, Lkeys
    bl _strlen
    mov x2, x0
    LADDR x0, _tctx
    LADDR x1, Lkeys
    bl _av_yaml_parse
    mov x1, x0
    LADDR x0, Ls_ca
    bl _av_keymap_configure
    LDRG x0, _av_prefix_cp
    CHECK 40, 'a'
    LOOKUP 41, 0, 't', A_NEW_TAB
    LOOKUP 42, 0, 'c', 0
    LOOKUP 43, MOD_CTRL, 'w', A_CLOSE_TAB
    LOOKUP 44, 0, 'x', 0
    LOOKUP 45, 0, 'l', 0
    // an invalid key keeps the default binding
    LOOKUP 46, 0, 's', A_SAVE
    LOOKUP 47, 0, 'n', A_NEXT_TAB

    // invalid prefix falls back to C-s
    LADDR x0, Ls_foo
    mov x1, #0
    bl _av_keymap_configure
    LDRG x0, _av_prefix_cp
    CHECK 48, 's'

    LADDR x0, _tctx
    bl _av_yaml_free
    bl Lsummary
    ldp x29, x30, [sp], #16
    ret
