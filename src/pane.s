// pane trees: split, remove, layout, directional focus, resize and divider hits

.include "macros.inc"
.include "pane.inc"

    .zerofill __DATA,__bss,_av_pane_free_list,8,3

    .section __TEXT,__const
    .p2align 3
Lmin_ratio: .double 0.1
Lmax_ratio: .double 0.9
Lbig:       .double 1000000.0

    .text
// Pane *av_pane_new(void): zeroed node, recycled from closed panes when possible
FUNC_BEGIN _av_pane_new
    LDRG x0, _av_pane_free_list
    cbz x0, 1f
    ldr x9, [x0, #P_PARENT]
    STRG x9, _av_pane_free_list, x10
    stp xzr, xzr, [x0]
    stp xzr, xzr, [x0, #16]
    stp xzr, xzr, [x0, #32]
    stp xzr, xzr, [x0, #48]
    stp xzr, xzr, [x0, #64]
    ret
1:  mov x0, #P_SIZE
    b _av_arena_alloc

// void av_pane_free(Pane *p)
FUNC_BEGIN _av_pane_free
    cbz x0, 1f
    LDRG x9, _av_pane_free_list
    str x9, [x0, #P_PARENT]
    STRG x0, _av_pane_free_list, x10
1:  ret

// Pane *av_pane_leaf(size_t kind, NSView *nsview, void *view, Doc *doc)
FUNC_BEGIN _av_pane_leaf
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _av_pane_new
    cbz x0, 1f
    str x19, [x0, #P_KIND]
    stp x20, x21, [x0, #P_NSVIEW]
    str x22, [x0, #P_DOC]
1:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Pane *av_pane_first(Pane *n) / av_pane_last(Pane *n): leftmost or rightmost leaf under n
FUNC_BEGIN _av_pane_first
1:  ldr x9, [x0, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 2f
    ldr x0, [x0, #P_A]
    b 1b
2:  ret

FUNC_BEGIN _av_pane_last
1:  ldr x9, [x0, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 2f
    ldr x0, [x0, #P_B]
    b 1b
2:  ret

// Pane *av_pane_after(Pane *leaf): next leaf in reading order, NULL after the last one
FUNC_BEGIN _av_pane_after
1:  ldr x9, [x0, #P_PARENT]
    cbz x9, 2f
    ldr x10, [x9, #P_A]
    cmp x10, x0
    mov x0, x9
    b.ne 1b
    ldr x0, [x9, #P_B]
    b _av_pane_first
2:  mov x0, #0
    ret

// Pane *av_pane_next(Pane *root, Pane *leaf): next leaf, wrapping to the first
FUNC_BEGIN _av_pane_next
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    mov x0, x1
    bl _av_pane_after
    cbnz x0, 1f
    mov x0, x19
    bl _av_pane_first
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Pane *av_pane_split(Pane **root, Pane *leaf, Pane *nw, size_t kind): nw goes right of or
// below leaf, the new split node takes the leaf's place; NULL when out of memory
FUNC_BEGIN _av_pane_split
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    bl _av_pane_new
    cbz x0, 9f
    str x22, [x0, #P_KIND]
    stp x20, x21, [x0, #P_A]
    fmov d0, #0.5
    str d0, [x0, #P_RATIO]
    ldp x10, x11, [x20, #P_X]
    stp x10, x11, [x0, #P_X]
    ldp x10, x11, [x20, #P_W]
    stp x10, x11, [x0, #P_W]
    ldr x9, [x20, #P_PARENT]
    str x9, [x0, #P_PARENT]
    str x0, [x20, #P_PARENT]
    str x0, [x21, #P_PARENT]
    cbz x9, 1f
    ldr x10, [x9, #P_A]
    cmp x10, x20
    add x11, x9, #P_A
    add x12, x9, #P_B
    csel x11, x11, x12, eq
    str x0, [x11]
    b 9f
1:  str x0, [x19]
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Pane *av_pane_remove(Pane **root, Pane *leaf): frees the leaf, its sibling takes the parent's
// place; returns the leaf next to the removed one, NULL when the tree is now empty
FUNC_BEGIN _av_pane_remove
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x21, [x20, #P_PARENT]
    cbnz x21, 1f
    str xzr, [x19]
    mov x0, x20
    bl _av_pane_free
    mov x0, #0
    b 9f
1:  ldp x9, x10, [x21, #P_A]
    cmp x9, x20
    cset x22, eq
    csel x9, x10, x9, eq
    ldr x10, [x21, #P_PARENT]
    str x10, [x9, #P_PARENT]
    cbz x10, 2f
    ldr x11, [x10, #P_A]
    cmp x11, x21
    add x11, x10, #P_A
    add x12, x10, #P_B
    csel x11, x11, x12, eq
    str x9, [x11]
    b 3f
2:  str x9, [x19]
3:  mov x19, x9
    mov x0, x20
    bl _av_pane_free
    mov x0, x21
    bl _av_pane_free
    // the neighbour is the sibling's leaf on the side that touched the removed pane
    mov x0, x19
    cbz x22, 4f
    bl _av_pane_first
    b 9f
4:  bl _av_pane_last
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// void av_pane_layout(Pane *n, double x, double y, double w, double h): rects of n and below
// the first child gets round((size - gap) * ratio), a PANE_GAP divider separates the children
FUNC_BEGIN _av_pane_layout
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    stp d10, d11, [sp, #40]
    stp d12, d13, [sp, #56]
    mov x19, x0
    stp d0, d1, [x19, #P_X]
    stp d2, d3, [x19, #P_W]
    ldr x9, [x19, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 9f
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    // d12 first child size, d13 second child size
    fcsel d5, d10, d11, eq
    fmov d4, #1.0
    fsub d5, d5, d4
    movi d7, #0
    fmax d5, d5, d7
    ldr d6, [x19, #P_RATIO]
    fmul d6, d5, d6
    frinta d6, d6
    fmax d6, d6, d7
    fmin d12, d6, d5
    fsub d13, d5, d12
    ldr x9, [x19, #P_KIND]
    cmp x9, #PK_ROW
    b.ne 2f
    ldr x0, [x19, #P_A]
    fmov d0, d8
    fmov d1, d9
    fmov d2, d12
    fmov d3, d11
    bl _av_pane_layout
    ldr x0, [x19, #P_B]
    fmov d4, #1.0
    fadd d0, d8, d12
    fadd d0, d0, d4
    fmov d1, d9
    fmov d2, d13
    fmov d3, d11
    bl _av_pane_layout
    b 9f
2:  ldr x0, [x19, #P_A]
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d12
    bl _av_pane_layout
    ldr x0, [x19, #P_B]
    fmov d4, #1.0
    fmov d0, d8
    fadd d1, d9, d12
    fadd d1, d1, d4
    fmov d2, d10
    fmov d3, d13
    bl _av_pane_layout
9:  ldp d12, d13, [sp, #56]
    ldp d10, d11, [sp, #40]
    ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// rect of node x0 projected for direction x1: d0..d1 along it, d2..d3 across it
// left and up are mirrored so the search always goes towards larger values
    .p2align 2
Lproj:
    ldp d4, d5, [x0, #P_X]
    ldp d6, d7, [x0, #P_W]
    fadd d6, d4, d6
    fadd d7, d5, d7
    cmp x1, #DIR_UP
    b.hs 1f
    fmov d0, d4
    fmov d1, d6
    fmov d2, d5
    fmov d3, d7
    b 2f
1:  fmov d0, d5
    fmov d1, d7
    fmov d2, d4
    fmov d3, d6
2:  tbnz x1, #0, 3f
    fneg d4, d1
    fneg d1, d0
    fmov d0, d4
3:  ret

// Pane *av_pane_neighbor(Pane *root, Pane *from, size_t dir): closest leaf beyond the edge of
// from in that direction that overlaps it on the other axis, ties go to the nearest center
FUNC_BEGIN _av_pane_neighbor
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    stp d8, d9, [sp, #56]
    stp d10, d11, [sp, #72]
    str d12, [sp, #88]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x0, x20
    mov x1, x21
    bl Lproj
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    mov x0, x19
    bl _av_pane_first
    mov x22, x0
    mov x23, #0
1:  cbz x22, 8f
    cmp x22, x20
    b.eq 3f
    mov x0, x22
    mov x1, x21
    bl Lproj
    fmov d4, #0.5
    fsub d5, d9, d4
    fcmp d0, d5
    b.lt 3f
    fcmp d2, d11
    b.ge 3f
    fcmp d3, d10
    b.le 3f
    // distance first, then how far apart the centers are
    fsub d6, d0, d9
    LDRD d5, Lbig
    fmul d6, d6, d5
    fadd d7, d2, d3
    fadd d5, d10, d11
    fsub d7, d7, d5
    fabs d7, d7
    fadd d6, d6, d7
    cbz x23, 2f
    fcmp d6, d12
    b.ge 3f
2:  mov x23, x22
    fmov d12, d6
3:  mov x0, x22
    bl _av_pane_after
    mov x22, x0
    b 1b
8:  mov x0, x23
    ldr d12, [sp, #88]
    ldp d10, d11, [sp, #72]
    ldp d8, d9, [sp, #56]
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// clamp ratio d0 and store it in split x0, returns 1
    .p2align 2
Lset_ratio:
    LDRD d1, Lmin_ratio
    fmax d0, d0, d1
    LDRD d1, Lmax_ratio
    fmin d0, d0, d1
    str d0, [x0, #P_RATIO]
    mov x0, #1
    ret

// int av_pane_resize(Pane *leaf, size_t dir, double points): moves the divider of the nearest
// split along that axis by points in direction dir; 0 when there is none
FUNC_BEGIN _av_pane_resize
    mov x9, #PK_ROW
    mov x10, #PK_COL
    cmp x1, #DIR_UP
    csel x9, x10, x9, hs
1:  ldr x0, [x0, #P_PARENT]
    cbz x0, 8f
    ldr x10, [x0, #P_KIND]
    cmp x10, x9
    b.ne 1b
    tbnz x1, #0, 2f
    fneg d0, d0
2:  ldr d1, [x0, #P_W]
    ldr d2, [x0, #P_H]
    cmp x9, #PK_ROW
    fcsel d1, d1, d2, eq
    fmov d2, #1.0
    fsub d1, d1, d2
    fcmp d1, #0.0
    b.le 8f
    fdiv d0, d0, d1
    ldr d1, [x0, #P_RATIO]
    fadd d0, d1, d0
    b Lset_ratio
8:  mov x0, #0
    ret

// int av_pane_drag(Pane *split, double x, double y): puts the divider under the pointer
FUNC_BEGIN _av_pane_drag
    ldr x9, [x0, #P_KIND]
    cmp x9, #PK_ROW
    ldp d2, d3, [x0, #P_X]
    ldp d4, d5, [x0, #P_W]
    fcsel d0, d0, d1, eq
    fcsel d2, d2, d3, eq
    fcsel d4, d4, d5, eq
    fsub d0, d0, d2
    fmov d1, #0.5
    fsub d0, d0, d1
    fmov d1, #1.0
    fsub d4, d4, d1
    fcmp d4, #0.0
    b.le 1f
    fdiv d0, d0, d4
    b Lset_ratio
1:  mov x0, #0
    ret

// Pane *av_pane_divider_at(Pane *n, double x, double y, double slop): split whose divider is
// within slop points of (x, y), NULL if none
FUNC_BEGIN _av_pane_divider_at
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    str d10, [sp, #40]
    mov x19, x0
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    ldr x9, [x19, #P_KIND]
    cmp x9, #PK_ROW
    b.lo 8f
    // d3 divider start, d4 pointer along the split, d5..d6 extent across it, d7 pointer across
    ldr x10, [x19, #P_A]
    b.ne 1f
    ldr d3, [x10, #P_X]
    ldr d4, [x10, #P_W]
    fadd d3, d3, d4
    fmov d4, d8
    ldr d5, [x19, #P_Y]
    ldr d6, [x19, #P_H]
    fmov d7, d9
    b 2f
1:  ldr d3, [x10, #P_Y]
    ldr d4, [x10, #P_H]
    fadd d3, d3, d4
    fmov d4, d9
    ldr d5, [x19, #P_X]
    ldr d6, [x19, #P_W]
    fmov d7, d8
2:  fsub d16, d3, d10
    fcmp d4, d16
    b.lt 3f
    fmov d16, #1.0
    fadd d16, d3, d16
    fadd d16, d16, d10
    fcmp d4, d16
    b.gt 3f
    fcmp d7, d5
    b.lt 3f
    fadd d6, d5, d6
    fcmp d7, d6
    b.gt 3f
    mov x0, x19
    b 9f
3:  ldr x0, [x19, #P_A]
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    bl _av_pane_divider_at
    cbnz x0, 9f
    ldr x0, [x19, #P_B]
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    bl _av_pane_divider_at
    b 9f
8:  mov x0, #0
9:  ldr d10, [sp, #40]
    ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
