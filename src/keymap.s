// key specs ("C-s", "M-x", "D-t", "Left") and the table of bindings used after the prefix key

.include "macros.inc"
.include "yaml.inc"
.include "keymap.inc"

    .section __TEXT,__cstring,cstring_literals
La_new_tab:     .asciz "new_tab"
La_close_tab:   .asciz "close_tab"
La_next_tab:    .asciz "next_tab"
La_prev_tab:    .asciz "prev_tab"
La_last_tab:    .asciz "last_tab"
La_open:        .asciz "open"
La_open_config: .asciz "open_config"
La_save:        .asciz "save"
La_next_theme:  .asciz "next_theme"
La_tab_1:       .asciz "tab_1"
La_tab_2:       .asciz "tab_2"
La_tab_3:       .asciz "tab_3"
La_tab_4:       .asciz "tab_4"
La_tab_5:       .asciz "tab_5"
La_tab_6:       .asciz "tab_6"
La_tab_7:       .asciz "tab_7"
La_tab_8:       .asciz "tab_8"
La_tab_9:       .asciz "tab_9"

Lk_space:    .asciz "space"
Lk_tab:      .asciz "tab"
Lk_enter:    .asciz "enter"
Lk_return:   .asciz "return"
Lk_esc:      .asciz "esc"
Lk_escape:   .asciz "escape"
Lk_bs:       .asciz "backspace"
Lk_left:     .asciz "left"
Lk_right:    .asciz "right"
Lk_up:       .asciz "up"
Lk_down:     .asciz "down"
Lk_home:     .asciz "home"
Lk_end:      .asciz "end"
Lk_pgup:     .asciz "pageup"
Lk_pgdn:     .asciz "pagedown"
Lk_delete:   .asciz "delete"

Ldef_prefix: .asciz "C-s"
Lfmt_prefix: .asciz "avenger: prefix: invalid key '%s', using C-s\n"
Lfmt_action: .asciz "avenger: keys.%s: unknown action\n"
Lfmt_key:    .asciz "avenger: keys.%s: invalid key '%s'\n"

    .section __DATA,__const
    .p2align 3
Laction_names:
    .quad 0, La_new_tab, La_close_tab, La_next_tab, La_prev_tab, La_last_tab
    .quad La_open, La_open_config, La_save, La_next_theme
    .quad La_tab_1, La_tab_2, La_tab_3, La_tab_4, La_tab_5, La_tab_6, La_tab_7, La_tab_8, La_tab_9
Lkey_names:
    .quad Lk_space, ' ', Lk_tab, 9, Lk_enter, 13, Lk_return, 13, Lk_esc, 27, Lk_escape, 27
    .quad Lk_bs, 127, Lk_left, KEY_LEFT_CP, Lk_right, KEY_RIGHT_CP, Lk_up, KEY_UP_CP
    .quad Lk_down, KEY_DOWN_CP, Lk_home, 0xF729, Lk_end, 0xF72B, Lk_pgup, 0xF72C
    .quad Lk_pgdn, 0xF72D, Lk_delete, 0xF728
Lkey_names_end:

    // defaults after the prefix, tmux flavoured
    .section __TEXT,__const
    .p2align 2
Ldefaults:
    .long 0, 'c', A_NEW_TAB, 0
    .long 0, 'x', A_CLOSE_TAB, 0
    .long 0, 'n', A_NEXT_TAB, 0
    .long 0, 'p', A_PREV_TAB, 0
    .long 0, 'l', A_LAST_TAB, 0
    .long 0, 'o', A_OPEN, 0
    .long 0, ',', A_OPEN_CONFIG, 0
    .long 0, 's', A_SAVE, 0
    .long 0, 't', A_NEXT_THEME, 0
    .long 0, '1', A_TAB_1, 0
    .long 0, '2', A_TAB_1 + 1, 0
    .long 0, '3', A_TAB_1 + 2, 0
    .long 0, '4', A_TAB_1 + 3, 0
    .long 0, '5', A_TAB_1 + 4, 0
    .long 0, '6', A_TAB_1 + 5, 0
    .long 0, '7', A_TAB_1 + 6, 0
    .long 0, '8', A_TAB_1 + 7, 0
    .long 0, '9', A_TAB_1 + 8, 0
Ldefaults_end:

    .zerofill __DATA,__bss,_av_keymap,(KM_MAX * KM_SIZE),4
    .zerofill __DATA,__bss,_av_keymap_n,8,3
    .globl _av_keymap
    .globl _av_keymap_n
    .section __DATA,__data
    .p2align 3
    .globl _av_prefix_mods
    .globl _av_prefix_cp
_av_prefix_mods: .quad MOD_CTRL
_av_prefix_cp:   .quad 's'

    .text
// (codepoint, bytes) av_utf8_decode(const char *p), no validation
FUNC_BEGIN _av_utf8_decode
    ldrb w2, [x0]
    cmp w2, #0x80
    b.hs 1f
    mov x0, x2
    mov x1, #1
    ret
1:  ldrb w3, [x0, #1]
    and w3, w3, #0x3f
    cmp w2, #0xe0
    b.hs 2f
    and w2, w2, #0x1f
    orr w0, w3, w2, lsl #6
    mov x1, #2
    ret
2:  ldrb w4, [x0, #2]
    and w4, w4, #0x3f
    cmp w2, #0xf0
    b.hs 3f
    and w2, w2, #0x0f
    lsl w2, w2, #12
    orr w2, w2, w3, lsl #6
    orr w0, w2, w4
    mov x1, #3
    ret
3:  ldrb w5, [x0, #3]
    and w5, w5, #0x3f
    and w2, w2, #0x07
    lsl w2, w2, #18
    orr w2, w2, w3, lsl #12
    orr w2, w2, w4, lsl #6
    orr w0, w2, w5
    mov x1, #4
    ret

// long av_key_parse(const char *spec): (mods << 32) | codepoint, -1 if invalid
// modifiers C- ctrl, M-/A- option, D- command, S- shift; then one character or a key name
FUNC_BEGIN _av_key_parse
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, #0
    cbz x19, 9f
1:  ldrb w9, [x19]
    ldrb w10, [x19, #1]
    cmp w10, #'-'
    b.ne 2f
    ldrb w11, [x19, #2]
    cbz w11, 2f
    mov x12, #MOD_CTRL
    cmp w9, #'C'
    b.eq 11f
    mov x12, #MOD_OPT
    cmp w9, #'M'
    b.eq 11f
    cmp w9, #'A'
    b.eq 11f
    mov x12, #MOD_CMD
    cmp w9, #'D'
    b.eq 11f
    mov x12, #MOD_SHIFT
    cmp w9, #'S'
    b.ne 2f
11: orr x20, x20, x12
    add x19, x19, #2
    b 1b
2:  ldrb w9, [x19]
    cbz w9, 9f
    mov x0, x19
    bl _av_utf8_decode
    ldrb w9, [x19, x1]
    mov x21, x0
    cbz w9, 8f
    // named key
    LADDR x21, Lkey_names
    LADDR x22, Lkey_names_end
3:  cmp x21, x22
    b.hs 9f
    ldr x0, [x21]
    mov x1, x19
    bl _strcasecmp
    cbz w0, 4f
    add x21, x21, #16
    b 3b
4:  ldr x21, [x21, #8]
8:  orr x0, x21, x20, lsl #32
    b 10f
9:  mov x0, #-1
10: ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_keymap_reset(void)
FUNC_BEGIN _av_keymap_reset
    LADDR x1, Ldefaults
    LADDR x2, Ldefaults_end
    sub x2, x2, x1
    lsr x9, x2, #4
    STRG x9, _av_keymap_n, x10
    LADDR x0, _av_keymap
    b _memcpy

// void av_keymap_set(size_t action, long spec): replaces the action's bindings, spec -1 unbinds
// the key is taken away from any other action that used it
FUNC_BEGIN _av_keymap_set
    LADDR x2, _av_keymap
    LDRG x3, _av_keymap_n
    mov x4, #0
    mov x5, #0
    lsr x11, x1, #32
    mov w12, w1
    // drop entries of this action or of this key, compacting in place
1:  cmp x4, x3
    b.hs 2f
    add x6, x2, x4, lsl #4
    add x4, x4, #1
    ldr w7, [x6, #KM_ACTION]
    cmp x7, x0
    b.eq 1b
    tbnz x1, #63, 11f
    ldp w9, w10, [x6, #KM_MODS]
    cmp x9, x11
    ccmp w10, w12, #0, eq
    b.eq 1b
11: add x8, x2, x5, lsl #4
    ldp x9, x10, [x6]
    stp x9, x10, [x8]
    add x5, x5, #1
    b 1b
2:  tbnz x1, #63, 3f
    cmp x5, #KM_MAX
    b.hs 3f
    add x8, x2, x5, lsl #4
    lsr x9, x1, #32
    str w9, [x8, #KM_MODS]
    str w1, [x8, #KM_CP]
    str w0, [x8, #KM_ACTION]
    add x5, x5, #1
3:  STRG x5, _av_keymap_n, x9
    ret

// size_t av_keymap_lookup(u64 mods, u32 codepoint), 0 if unbound
// ctrl/option/command must match exactly, shift only when the binding asks for it
FUNC_BEGIN _av_keymap_lookup
    LADDR x2, _av_keymap
    LDRG x3, _av_keymap_n
    and x4, x0, #MOD_CHORD
    mov x5, #0
1:  cmp x5, x3
    b.hs 3f
    add x6, x2, x5, lsl #4
    add x5, x5, #1
    ldr w7, [x6, #KM_CP]
    cmp w7, w1
    b.ne 1b
    ldr w7, [x6, #KM_MODS]
    and x8, x7, #MOD_CHORD
    cmp x8, x4
    b.ne 1b
    tbz w7, #17, 2f
    tbz x0, #17, 1b
2:  ldr w0, [x6, #KM_ACTION]
    ret
3:  mov x0, #0
    ret

// size_t av_action_id(const char *name), 0 if unknown
FUNC_BEGIN _av_action_id
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, #1
1:  cmp x20, #A_COUNT
    b.hs 2f
    LADDR x9, Laction_names
    ldr x0, [x9, x20, lsl #3]
    mov x1, x19
    bl _strcasecmp
    cbz w0, 3f
    add x20, x20, #1
    b 1b
2:  mov x20, #0
3:  mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// const char *av_action_name(size_t id)
FUNC_BEGIN _av_action_name
    cmp x0, #A_COUNT
    csel x0, x0, xzr, lo
    LADDR x1, Laction_names
    ldr x0, [x1, x0, lsl #3]
    ret

// void av_keymap_configure(const char *prefix, Node *keys): prefix spec plus per-action overrides
// keys map action -> key pressed after the prefix (null unbinds); problems go to stderr
FUNC_BEGIN _av_keymap_configure
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov x20, x1
    LADDR x0, Ldef_prefix
    cmp x19, #0
    csel x0, x0, x19, eq
    bl _av_key_parse
    tbz x0, #63, 1f
    sub sp, sp, #16
    str x19, [sp]
    mov w0, #2
    LADDR x1, Lfmt_prefix
    bl _dprintf
    add sp, sp, #16
    LADDR x0, Ldef_prefix
    bl _av_key_parse
1:  lsr x9, x0, #32
    STRG x9, _av_prefix_mods, x10
    mov w9, w0
    STRG x9, _av_prefix_cp, x10
    bl _av_keymap_reset

    cbz x20, 9f
    ldrb w9, [x20, #N_TYPE]
    cmp w9, #Y_MAP
    b.ne 9f
    ldr x21, [x20, #N_PTR]
2:  cbz x21, 9f
    ldr x0, [x21, #N_KEY]
    bl _av_action_id
    mov x22, x0
    cbnz x22, 3f
    sub sp, sp, #16
    ldr x9, [x21, #N_KEY]
    str x9, [sp]
    mov w0, #2
    LADDR x1, Lfmt_action
    bl _dprintf
    add sp, sp, #16
    b 8f
3:  ldrb w9, [x21, #N_TYPE]
    cmp w9, #Y_NULL
    b.ne 4f
    mov x0, x22
    mov x1, #-1
    bl _av_keymap_set
    b 8f
4:  mov x0, x21
    bl _av_yaml_str
    mov x23, x0
    bl _av_key_parse
    tbnz x0, #63, 5f
    mov x1, x0
    mov x0, x22
    bl _av_keymap_set
    b 8f
5:  sub sp, sp, #16
    ldr x9, [x21, #N_KEY]
    stp x9, x23, [sp]
    mov w0, #2
    LADDR x1, Lfmt_key
    bl _dprintf
    add sp, sp, #16
8:  ldr x21, [x21, #N_NEXT]
    b 2b
9:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
