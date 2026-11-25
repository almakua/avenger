// Vt: terminal state, one mmap block: header, row maps, scrollback ring, row pool
// rows are reached through pointer maps so scrolling moves pointers, not cells

.set VT_MAXROWS, 256
.set VT_MAXCOLS, 512
.set VT_ROWB,    4096          // one row, VT_MAXCOLS cells
.set VT_SBLINES, 3000

.set VT_ROWS,      0
.set VT_COLS,      8
.set VT_MAP,       16          // active row map (main or alt)
.set VT_CX,        24
.set VT_CY,        32
.set VT_PEN,       40          // cell template for printing, codepoint bits zero
.set VT_TOP,       48          // scroll region, inclusive
.set VT_BOT,       56
.set VT_MODE,      64          // M_* bits
.set VT_SAVE_X,    72
.set VT_SAVE_Y,    80
.set VT_SAVE_PEN,  88
.set VT_SAVE_MODE, 96
.set VT_STATE,     104         // parser state
.set VT_NPARAM,    112         // index of the parameter being parsed
.set VT_PRIV,      120         // CSI private marker ('?', '>', ...)
.set VT_INTER,     128         // intermediate byte
.set VT_UCP,       136         // UTF-8 decoder: partial codepoint
.set VT_UNEED,     144         // ... continuation bytes still expected
.set VT_LAST,      152         // last printed codepoint, for REP
.set VT_SB_HEAD,   160         // next scrollback slot
.set VT_SB_N,      168         // scrollback lines in use
.set VT_POOLN,     176         // rows handed out from the pool
.set VT_BELL,      184         // BEL count
.set VT_TITLE_GEN, 192         // bumped on every title change
.set VT_OSC_LEN,   200
.set VT_REPLY_LEN, 208
.set VT_PARAMS,    256         // 16 x u32
.set VT_REPLY,     320         // answers to queries, drained by the caller
.set VT_TITLE,     384         // NUL-terminated window title
.set VT_OSC,       512
.set VT_MAP_MAIN,  1024
.set VT_MAP_ALT,   3072
.set VT_SBRING,    8192
.set VT_POOL,      32768
.set VT_ALLOC,     VT_POOL + (2 * VT_MAXROWS + VT_SBLINES) * VT_ROWB

.set VT_REPLY_MAX, 63
.set VT_TITLE_MAX, 127
.set VT_OSC_MAX,   511

// modes
.set MB_WRAPNEXT, 0            // cursor sits past the last column
.set MB_AUTOWRAP, 1
.set MB_CURSOR,   2            // cursor visible
.set MB_APPCUR,   3            // arrows send SS3
.set MB_ALT,      4
.set MB_PASTE,    5            // bracketed paste
.set MB_ORIGIN,   6
.set MB_INSERT,   7
.set MB_G0GFX,    8            // DEC line drawing in G0 / G1
.set MB_G1GFX,    9
.set MB_SHIFTOUT, 10           // G1 active
.set M_WRAPNEXT, 1 << MB_WRAPNEXT
.set M_AUTOWRAP, 1 << MB_AUTOWRAP
.set M_CURSOR,   1 << MB_CURSOR
.set M_APPCUR,   1 << MB_APPCUR
.set M_ALT,      1 << MB_ALT
.set M_PASTE,    1 << MB_PASTE
.set M_ORIGIN,   1 << MB_ORIGIN
.set M_INSERT,   1 << MB_INSERT
.set M_G0GFX,    1 << MB_G0GFX
.set M_G1GFX,    1 << MB_G1GFX
.set M_SHIFTOUT, 1 << MB_SHIFTOUT

// cell, u64: codepoint bits 0..20 (0 = never written), attributes 24..31,
// fg 32..47, bg 48..63; colors: 0 default, 1..256 index + 1, 0x8000 | rgb555
.set CELL_CP,    0x1fffff
.set AB_BOLD,    24
.set AB_DIM,     25
.set AB_ITALIC,  26
.set AB_UNDER,   27
.set AB_BLINK,   28
.set AB_REVERSE, 29
.set AB_HIDDEN,  30
.set AB_STRIKE,  31
.set AT_BOLD,    1 << AB_BOLD
.set AT_DIM,     1 << AB_DIM
.set AT_UNDER,   1 << AB_UNDER
.set AT_REVERSE, 1 << AB_REVERSE
.set AT_HIDDEN,  1 << AB_HIDDEN
.set COLOR_RGB,  0x8000
