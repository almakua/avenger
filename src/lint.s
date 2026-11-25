// YAML validation while editing: 300 ms after the last change a copy of the text is parsed on a
// background queue, the first error (line and code) lands in the doc for the renderer

.include "macros.inc"
.include "objc.inc"
.include "buffer.inc"
.include "doc.inc"
.include "hl.inc"
.include "yaml.inc"

.set DELAY_NS, 300000000

// background job, one per check
.set J_DOC,  0
.set J_GEN,  8
.set J_TEXT, 16
.set J_LEN,  24
.set J_ERR,  32
.set J_LINE, 40
.set J_CTX,  48
.set J_SIZE, (J_CTX + Y_SIZE)

    SELDEF setNeedsDisplay, "setNeedsDisplay:"

    .text
// void av_lint_touch(Doc *d): after a change (or on open) schedules a check of a YAML doc
FUNC_BEGIN _av_lint_touch
    ldr x9, [x0, #DOC_LANG]
    cmp x9, #LANG_YAML
    b.eq 1f
    // other languages carry no error
    mov x1, #0
    mov x2, #0
    b Lapply
1:  ldr x9, [x0, #DOC_LINTING]
    cbnz x9, 9f
    // DOC_LINT_GEN holds generation + 1, so a fresh doc is checked once
    ldr x9, [x0, #DOC_GEN]
    ldr x10, [x0, #DOC_LINT_GEN]
    add x11, x9, #1
    cmp x11, x10
    b.eq 9f
    str x9, [x0, #DOC_ARM_GEN]
    mov x9, #1
    str x9, [x0, #DOC_LINTING]
    b Larm
9:  ret

// void arm(Doc *d): fire after the delay on the main queue
    .p2align 2
Larm:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x0, #0
    ldr x1, =DELAY_NS
    bl _dispatch_time
    LGOT x1, __dispatch_main_q
    mov x2, x19
    adr x3, Lfire
    bl _dispatch_after_f
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// fire(Doc *d): still typing re-arms, else the text goes to the background queue
    .p2align 2
Lfire:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    ldr x9, [x19, #DOC_VIEWS]
    cbz x9, 8f
    ldr x9, [x19, #DOC_GEN]
    ldr x10, [x19, #DOC_ARM_GEN]
    cmp x9, x10
    b.eq 1f
    str x9, [x19, #DOC_ARM_GEN]
    mov x0, x19
    bl Larm
    b 9f
1:  add x10, x9, #1
    str x10, [x19, #DOC_LINT_GEN]
    mov x0, #1
    mov x1, #J_SIZE
    bl _calloc
    cbz x0, 8f
    mov x20, x0
    str x19, [x20, #J_DOC]
    ldr x9, [x19, #DOC_GEN]
    str x9, [x20, #J_GEN]
    mov x0, x19
    bl _av_buf_len
    mov x21, x0
    str x21, [x20, #J_LEN]
    add x0, x21, #1
    bl _malloc
    cbz x0, 7f
    mov x22, x0
    str x22, [x20, #J_TEXT]
    mov x0, x19
    mov x1, #0
    mov x2, x22
    mov x3, x21
    bl _av_buf_copy
    strb wzr, [x22, x21]
    // Helm and Jinja templates are not YAML until rendered
    mov x0, x22
    mov x1, x21
    bl _av_yaml_is_template
    cbnz w0, 6f
    mov x0, #0
    mov x1, #0
    bl _dispatch_get_global_queue
    mov x1, x20
    adr x2, Lwork
    bl _dispatch_async_f
    b 9f
6:  mov x0, x22
    bl _free
7:  mov x0, x20
    bl _free
    mov x0, x19
    mov x1, #0
    mov x2, #0
    bl Lapply
8:  str xzr, [x19, #DOC_LINTING]
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// work(Job *j), background queue: parse, keep only the error, hand back to the main queue
    .p2align 2
Lwork:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    add x0, x19, #J_CTX
    ldr x1, [x19, #J_TEXT]
    ldr x2, [x19, #J_LEN]
    bl _av_yaml_parse
    ldr x9, [x19, #(J_CTX + Y_ERR)]
    str x9, [x19, #J_ERR]
    ldr x9, [x19, #(J_CTX + Y_ERRLINE)]
    str x9, [x19, #J_LINE]
    add x0, x19, #J_CTX
    bl _av_yaml_free
    ldr x0, [x19, #J_TEXT]
    bl _free
    LGOT x0, __dispatch_main_q
    mov x1, x19
    adr x2, Ldone
    bl _dispatch_async_f
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// done(Job *j), main queue: the result counts only if the doc did not change meanwhile
    .p2align 2
Ldone:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x20, x0
    ldr x19, [x20, #J_DOC]
    str xzr, [x19, #DOC_LINTING]
    ldr x9, [x19, #DOC_VIEWS]
    cbz x9, 1f
    ldr x9, [x20, #J_GEN]
    ldr x10, [x19, #DOC_GEN]
    cmp x9, x10
    b.ne 1f
    ldr x2, [x20, #J_ERR]
    ldr x1, [x20, #J_LINE]
    cmp x2, #0
    csel x1, xzr, x1, eq
    mov x0, x19
    bl Lapply
1:  mov x0, x20
    bl _free
    ldr x9, [x19, #DOC_VIEWS]
    cbz x9, 9f
    mov x0, x19
    bl _av_lint_touch
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void apply(Doc *d, size_t line, size_t err): store the result, redraw the doc's panes on change
    .p2align 2
Lapply:
    ldr x9, [x0, #DOC_ERR_LINE]
    ldr x10, [x0, #DOC_ERR]
    cmp x9, x1
    ccmp x10, x2, #0, eq
    b.ne 1f
    ret
1:  stp x1, x2, [x0, #DOC_ERR_LINE]
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    ldr x19, [x0, #DOC_VIEWS]
2:  cbz x19, 9f
    ldr x0, [x19, #V_NSVIEW]
    mov x2, #1
    MSG setNeedsDisplay
    ldr x19, [x19, #V_NEXT]
    b 2b
9:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
