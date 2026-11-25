// memory: page allocations via mmap for big growable blocks, bump arena for small long-lived objects

.include "macros.inc"

.set PROT_RW,        3
.set MAP_PRIVATE_ANON, 0x1002
.set ARENA_CHUNK,    0x40000

    .zerofill __DATA,__bss,_av_arena_ptr,8,3
    .zerofill __DATA,__bss,_av_arena_end,8,3

    .text
// void *av_pages_alloc(size_t n), zero-filled, NULL on failure
FUNC_BEGIN _av_pages_alloc
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0
    mov x0, #0
    mov w2, #PROT_RW
    mov w3, #MAP_PRIVATE_ANON
    mov w4, #-1
    mov x5, #0
    bl _mmap
    cmn x0, #1
    csel x0, xzr, x0, eq
    ldp x29, x30, [sp], #16
    ret

// void av_pages_free(void *p, size_t n)
FUNC_BEGIN _av_pages_free
    cbz x0, 1f
    b _munmap
1:  ret

// void *av_arena_alloc(size_t n), 16-byte aligned, zero-filled, never freed
FUNC_BEGIN _av_arena_alloc
    add x0, x0, #15
    and x0, x0, #0xfffffffffffffff0
    LDRG x1, _av_arena_ptr
    LDRG x2, _av_arena_end
    add x3, x1, x0
    cbz x1, 1f
    cmp x3, x2
    b.hi 1f
    STRG x3, _av_arena_ptr, x4
    mov x0, x1
    ret
    // slow path: big requests get their own pages, otherwise start a new chunk
1:  stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    cmp x19, #(ARENA_CHUNK / 4)
    b.hs 2f
    mov x0, #ARENA_CHUNK
    bl _av_pages_alloc
    cbz x0, 3f
    add x1, x0, x19
    STRG x1, _av_arena_ptr, x2
    add x1, x0, #ARENA_CHUNK
    STRG x1, _av_arena_end, x2
    b 3f
2:  mov x0, x19
    bl _av_pages_alloc
3:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void *av_pages_grow(void *p, size_t used, size_t old_size, size_t new_size), NULL keeps p
FUNC_BEGIN _av_pages_grow
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x0, x3
    bl _av_pages_alloc
    cbz x0, 1f
    mov x22, x0
    mov x1, x19
    mov x2, x20
    bl _memcpy
    mov x0, x19
    mov x1, x21
    bl _av_pages_free
    mov x0, x22
1:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
