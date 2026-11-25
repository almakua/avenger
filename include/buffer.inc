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
