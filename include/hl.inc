// syntax highlighting: languages, language definitions and color runs

.set LANG_NONE,     0
.set LANG_YAML,     1
.set LANG_ASM,      2
.set LANG_C,        3
.set LANG_JSON,     4
.set LANG_SHELL,    5
.set LANG_PYTHON,   6
.set LANG_MARKDOWN, 7
.set LANG_COUNT,    8

// language definition
.set LD_FLAGS,    0
.set LD_KEYWORDS, 8      // word lists: (len byte, chars)*, 0
.set LD_TYPES,    16
.set LD_CONSTS,   24
.set LD_BUILTINS, 32
.set LD_DEFFN,    40     // keywords after which the next identifier is a function name
.set LD_DEFTYPE,  48     // ... or a type name
.set LD_LEXER,    56     // custom lexer, 0 = generic table-driven lexer
.set LD_SIZE,     64

.set LF_STATEFUL, 1      // has constructs spanning lines, keep per-line start states
.set LF_CCOMMENT, 2      // // and /* */
.set LF_HASH,     4      // # comments
.set LF_SQ,       8      // '...' strings
.set LF_BT,       16     // `...` strings
.set LF_TRIPLE,   32     // """ / ''' strings
.set LF_FUNC,     64     // identifier before '(' is a function
.set LF_JSONKEY,  128    // string before ':' is a key
.set LF_SHELL,    256    // $VAR, ${...}
.set LF_DECOR,    512    // @decorator
.set LF_PREPROC,  1024   // #directive at line start

// color run produced by av_hl_lex: [start u32][len u16][slot index u16]
.set RUN_START, 0
.set RUN_LEN,   4
.set RUN_SLOT,  6
.set RUN_SIZE,  8
.set MAX_RUNS,  1024

// longest line lexed, longer lines are truncated for display and state tracking
.set HL_LINE_MAX, 8192
