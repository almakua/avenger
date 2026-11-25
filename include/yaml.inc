// YAML node tree and parser context

// node, 64 bytes, children linked through N_NEXT
.set N_TYPE,    0      // u8
.set N_FLAGS,   1      // u8
.set N_LINE,    4      // u32, 1-based source line (key line for map values)
.set N_PTR,     8      // scalar: text; map/seq: first child
.set N_LEN,     16     // scalar: byte length; map/seq: child count
.set N_NEXT,    24
.set N_KEY,     32     // NUL-terminated key when the parent is a map
.set N_KEYLEN,  40
.set N_TAIL,    48     // last child, containers only
.set N_OFF,     56     // byte offset in the source
.set NODE_SIZE, 64

.set Y_NULL,   1
.set Y_SCALAR, 2
.set Y_MAP,    3
.set Y_SEQ,    4

.set NF_QUOTED, 1
.set NF_RAW,    2      // block scalar: N_PTR is a raw slice of the source, not NUL-terminated

// parser context
.set Y_BASE,    0
.set Y_CAP,     8
.set Y_USED,    16
.set Y_ERR,     24
.set Y_ERRLINE, 32
.set Y_ROOT,    40
.set Y_SP,      48
.set Y_SRC,     56
.set Y_DEPTH,   64
.set Y_DOCBRK,  72     // set when Lpeek crosses a "---" / "..." marker
.set Y_SIZE,    80

// documents after the first are chained from the root through N_NEXT

// error codes, messages in av_yaml_error_msg
.set YE_NONE,       0
.set YE_INDENT,     1
.set YE_COLON,      2
.set YE_QUOTE,      3
.set YE_TAB,        4
.set YE_DUP,        5
.set YE_TRAIL,      6
.set YE_FLOW,       7
.set YE_NOMEM,      8
.set YE_DEPTH,      9
.set YE_INLINE_MAP, 10
.set YE_COUNT,      11
