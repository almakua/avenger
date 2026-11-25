// objc runtime helpers for hand-written AArch64, mirrors what clang emits
// selrefs and classrefs are fixed up by dyld/libobjc at image load, zero runtime cost

// declare a selector: SELDEF label, "name:with:"
.macro SELDEF label, name
    .section __TEXT,__objc_methname,cstring_literals
Lsn_\label:
    .asciz "\name"
    .section __DATA,__objc_selrefs,literal_pointers,no_dead_strip
    .p2align 3
Lsr_\label:
    .quad Lsn_\label
    .text
.endm

// declare a class reference: CLASSREF NSWindow
.macro CLASSREF name
    .section __DATA,__objc_classrefs,regular,no_dead_strip
    .p2align 3
Lcr_\name:
    .quad _OBJC_CLASS_$_\name
    .text
.endm

// declare a constant NSString: CFSTRDEF label, "text"
.macro CFSTRDEF label, text
    .section __TEXT,__cstring,cstring_literals
Lcs_\label:
    .asciz "\text"
Lcs_end_\label:
    .section __DATA,__cfstring
    .p2align 3
Lcf_\label:
    .quad ___CFConstantStringClassReference
    .long 0x7c8
    .space 4
    .quad Lcs_\label
    .quad Lcs_end_\label - Lcs_\label - 1
    .text
.endm

// load selector into reg
.macro LSEL reg, label
    adrp \reg, Lsr_\label@PAGE
    ldr \reg, [\reg, Lsr_\label@PAGEOFF]
.endm

// load class into reg
.macro CLS reg, name
    adrp \reg, Lcr_\name@PAGE
    ldr \reg, [\reg, Lcr_\name@PAGEOFF]
.endm

// load constant NSString address into reg
.macro CFSTR reg, label
    adrp \reg, Lcf_\label@PAGE
    add \reg, \reg, Lcf_\label@PAGEOFF
.endm

// send message: receiver in x0, args already in x2..x7/d0..d7
.macro MSG label
    LSEL x1, \label
    bl _objc_msgSend
.endm

// load an exported global (e.g. NSString *const) value via GOT
.macro LEXTERN reg, sym
    adrp \reg, \sym@GOTPAGE
    ldr \reg, [\reg, \sym@GOTPAGEOFF]
    ldr \reg, [\reg]
.endm

// address of an exported global (e.g. a callbacks struct) via GOT
.macro LGOT reg, sym
    adrp \reg, \sym@GOTPAGE
    ldr \reg, [\reg, \sym@GOTPAGEOFF]
.endm
