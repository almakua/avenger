// terminal emulator: printing, wrap, cursor moves, erase, SGR, scrolling, alt screen, replies

.include "macros.inc"
.include "vt.inc"
.include "harness.inc"

.macro FEED lit
    LADDR x0, \lit
    bl _strlen
    mov x2, x0
    LDRG x0, _tvt
    LADDR x1, \lit
    bl _av_vt_feed
.endm

// whole cell at (x, y), y < 0 reads the scrollback
.macro CELL id, x, y, want
    LDRG x0, _tvt
    ldr x1, =\y
    bl _av_vt_line
    ldr x0, [x0, #(\x * 8)]
    CHECK \id, \want
.endm

.macro CP id, x, y, want
    LDRG x0, _tvt
    ldr x1, =\y
    bl _av_vt_line
    ldr x0, [x0, #(\x * 8)]
    and x0, x0, #CELL_CP
    CHECK \id, \want
.endm

.macro FIELD id, off, want
    LDRG x9, _tvt
    ldr x0, [x9, #\off]
    CHECK \id, \want
.endm

.macro RESIZE rows, cols
    LDRG x0, _tvt
    mov x1, #\rows
    mov x2, #\cols
    bl _av_vt_resize
.endm

// x0 = 0 when the NUL-terminated string at vt + off equals lit
.macro STR_AT id, off, lit
    LDRG x0, _tvt
    add x0, x0, #\off
    LADDR x1, \lit
    bl _strcmp
    sxtw x0, w0
    CHECK \id, 0
.endm

    .zerofill __DATA,__bss,_tvt,8,3

    .section __TEXT,__cstring,cstring_literals
Lhello:   .asciz "hello"
Lcrlf:    .asciz "\r\nworld"
Lcup:     .asciz "\033[2J\033[5;10HX"
Lsgr:     .asciz "\033[H\033[31;1mR\033[38;5;200mA\033[38;2;255;0;0;48;5;4mB\033[0mC"
Lwrap:    .asciz "\033[H\033[2J0123456789AB"
Lexact:   .asciz "\033[H\033[2J0123456789"
Lcr:      .asciz "\r"
Lscroll:  .asciz "\033[H\033[2J\033[3J1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7"
Lregion:  .asciz "\033[2;4r\033[4;1H\n"
Lunreg:   .asciz "\033[r"
Lel:      .asciz "\033[H\033[2Jabcdef\033[1;3H\033[K"
Lich:     .asciz "\033[1;1H\033[2@"
Ldch:     .asciz "\033[1P"
Lalt_on:  .asciz "\033[H\033[2Jmain\033[?1049h"
Lalt_txt: .asciz "alt"
Lalt_off: .asciz "\033[?1049l"
Ldsr:     .asciz "\033[2;3H\033[6n"
Ldsr_ans: .asciz "\033[2;3R"
Losc0:    .asciz "\033]0;hello title\007"
Losc0_v:  .asciz "hello title"
Losc2:    .asciz "\033]2;other\033\\"
Losc2_v:  .asciz "other"
Lutf_a:   .asciz "\033[H\033[2J\303\251\342\202"
Lutf_b:   .asciz "\254"
Lgfx:     .asciz "\033(0q\033(Bq"
Lfive:    .asciz "\033[H\033[2J\033[3J1\r\n2\r\n3\r\n4\r\n5"
Lsave:    .asciz "\033[2;2H\0337\033[H\0338Z"
Lmodes:   .asciz "\033[?25l\033[?1h\033[?2004h"
Lrep:     .asciz "\033[H\033[2Jx\033[3b"

    .text
FUNC_BEGIN _main
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl _av_vt_new
    STRG x0, _tvt, x9
    FIELD 1, VT_ROWS, 24
    FIELD 2, VT_COLS, 80

    FEED Lhello
    CP 3, 0, 0, 'h'
    CP 4, 4, 0, 'o'
    FIELD 5, VT_CX, 5
    FEED Lcrlf
    CP 6, 0, 1, 'w'
    FIELD 7, VT_CY, 1

    FEED Lcup
    CP 8, 9, 4, 'X'
    CP 9, 0, 0, 0
    FIELD 10, VT_CX, 10
    FIELD 11, VT_CY, 4

    // bold red, indexed 200, direct red on indexed blue, then reset
    FEED Lsgr
    CELL 12, 0, 0, ('R' | AT_BOLD | (2 << 32))
    CELL 13, 1, 0, ('A' | AT_BOLD | (201 << 32))
    CELL 14, 2, 0, ('B' | AT_BOLD | ((COLOR_RGB | 0x7c00) << 32) | (5 << 48))
    CELL 15, 3, 0, 'C'

    RESIZE 5, 10
    FIELD 20, VT_ROWS, 5
    FIELD 21, VT_BOT, 4
    FEED Lwrap
    CP 22, 9, 0, '9'
    CP 23, 0, 1, 'A'
    FIELD 24, VT_CX, 2
    FIELD 25, VT_CY, 1
    // the last column defers the wrap until the next character
    FEED Lexact
    FIELD 26, VT_CX, 9
    FIELD 27, VT_CY, 0
    FIELD 28, VT_MODE, (M_AUTOWRAP | M_CURSOR | M_WRAPNEXT)
    FEED Lcr
    FIELD 29, VT_MODE, (M_AUTOWRAP | M_CURSOR)

    FEED Lscroll
    CP 30, 0, 0, '3'
    CP 31, 0, 4, '7'
    FIELD 32, VT_SB_N, 2
    CP 33, 0, -1, '2'
    CP 34, 0, -2, '1'
    // a scroll region scrolls alone and keeps nothing
    FEED Lregion
    CP 35, 0, 0, '3'
    CP 36, 0, 1, '5'
    CP 37, 0, 2, '6'
    CP 38, 0, 3, 0
    CP 39, 0, 4, '7'
    FIELD 40, VT_SB_N, 2
    FEED Lunreg
    FIELD 41, VT_TOP, 0
    FIELD 42, VT_BOT, 4

    FEED Lel
    CP 43, 1, 0, 'b'
    CP 44, 2, 0, 0
    FEED Lich
    CP 45, 0, 0, 0
    CP 46, 2, 0, 'a'
    FEED Ldch
    CP 47, 1, 0, 'a'

    FEED Lalt_on
    CP 50, 0, 0, 0
    FIELD 51, VT_MODE, (M_AUTOWRAP | M_CURSOR | M_ALT)
    FEED Lalt_txt
    CP 52, 4, 0, 'a'
    FEED Lalt_off
    CP 53, 0, 0, 'm'
    CP 54, 4, 0, 0
    FIELD 55, VT_CX, 4
    FIELD 56, VT_MODE, (M_AUTOWRAP | M_CURSOR)

    FEED Ldsr
    FIELD 60, VT_REPLY_LEN, 6
    LDRG x0, _tvt
    add x0, x0, #VT_REPLY
    LADDR x1, Ldsr_ans
    mov x2, #6
    bl _memcmp
    sxtw x0, w0
    CHECK 61, 0

    FEED Losc0
    STR_AT 62, VT_TITLE, Losc0_v
    FIELD 63, VT_TITLE_GEN, 1
    FEED Losc2
    STR_AT 64, VT_TITLE, Losc2_v
    FIELD 65, VT_TITLE_GEN, 2

    // a UTF-8 sequence split across reads, DEC line drawing
    FEED Lutf_a
    FEED Lutf_b
    CP 70, 0, 0, 0xe9
    CP 71, 1, 0, 0x20ac
    FEED Lgfx
    CP 72, 2, 0, 0x2500
    CP 73, 3, 0, 'q'

    // shrinking keeps the cursor line, growing brings the scrollback back
    FEED Lfive
    FIELD 80, VT_CY, 4
    RESIZE 3, 10
    CP 81, 0, 0, '3'
    FIELD 82, VT_CY, 2
    FIELD 83, VT_SB_N, 2
    CP 84, 0, -1, '2'
    RESIZE 5, 10
    CP 85, 0, 0, '1'
    CP 86, 0, 4, '5'
    FIELD 87, VT_CY, 4
    FIELD 88, VT_SB_N, 0

    FEED Lsave
    CP 90, 1, 1, 'Z'
    FIELD 91, VT_CX, 2
    FEED Lmodes
    FIELD 92, VT_MODE, (M_AUTOWRAP | M_APPCUR | M_PASTE)
    FEED Lrep
    CP 93, 3, 0, 'x'
    FIELD 94, VT_CX, 4

    LDRG x0, _tvt
    bl _av_vt_free
    bl Lsummary
    ldp x29, x30, [sp], #16
    ret
