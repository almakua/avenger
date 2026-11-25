// Buffer: gap buffer plus line-start index, 64 bytes
// logical text = data[0..gs) ++ data[ge..cap); lines[i] = logical offset of line i

.set BUF_DATA,   0
.set BUF_CAP,    8
.set BUF_GS,     16
.set BUF_GE,     24
.set BUF_LINES,  32
.set BUF_NLINES, 40
.set BUF_LCAP,   48
.set BUF_FLAGS,  56
.set BUF_SIZE,   64

.set BUF_DIRTY,  1

.set BUF_MIN_CAP,    16384
.set BUF_LINES_INIT, 1024

// load gap geometry of buffer breg: x8 data, x10 gs, x12 gap size (clobbers x11)
.macro BUF_GEOM breg
    ldr x8, [\breg, #BUF_DATA]
    ldp x10, x11, [\breg, #BUF_GS]
    sub x12, x11, x10
.endm

// wdst = byte at logical xpos, needs BUF_GEOM, clobbers x13
.macro BUF_BYTE wdst, xpos
    add x13, \xpos, x12
    cmp \xpos, x10
    csel x13, \xpos, x13, lo
    ldrb \wdst, [x8, x13]
.endm
