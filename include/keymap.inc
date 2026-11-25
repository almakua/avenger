// actions shared by menus, prefix keys and (later) the command palette

.set A_NONE,        0
.set A_NEW_TAB,     1
.set A_CLOSE_TAB,   2
.set A_NEXT_TAB,    3
.set A_PREV_TAB,    4
.set A_LAST_TAB,    5
.set A_OPEN,        6
.set A_OPEN_CONFIG, 7
.set A_SAVE,        8
.set A_NEXT_THEME,  9
.set A_TAB_1,       10
.set A_TAB_9,       18
.set A_COUNT,       19

// key binding after the prefix: [mods u32][codepoint u32][action u32][pad]
.set KM_MODS,   0
.set KM_CP,     4
.set KM_ACTION, 8
.set KM_SIZE,   16
.set KM_MAX,    64

// NSEvent modifier flag bits
.set MOD_SHIFT, 0x20000
.set MOD_CTRL,  0x40000
.set MOD_OPT,   0x80000
.set MOD_CMD,   0x100000
.set MOD_ALL,   0x1e0000
.set MOD_CHORD, 0x1c0000

// AppKit codepoints for named keys (charactersIgnoringModifiers)
.set KEY_UP_CP,    0xF700
.set KEY_DOWN_CP,  0xF701
.set KEY_LEFT_CP,  0xF702
.set KEY_RIGHT_CP, 0xF703
