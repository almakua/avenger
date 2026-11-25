// pty: login shell (or sh -c command) on a pseudo terminal, resize, write, busy check, reaping

.include "macros.inc"

.set TIOCSWINSZ, 0x80087467
.set F_SETFD,    2
.set F_SETFL,    4
.set FD_CLOEXEC, 1
.set O_NONBLOCK, 4
.set SIGHUP,     1
.set WNOHANG,    1
.set EINTR,      4
.set EAGAIN,     35
.set POLLOUT,    4
.set PW_DIR,     48
.set PW_SHELL,   56
.set ENV_EXTRA,  8
.set PROC_PIDVNODEPATHINFO, 9
.set VPI_SIZE,      2352       // struct proc_vnodepathinfo
.set VPI_CDIR_PATH, 152        // pvi_cdir.vip_path

// spawn locals
.set SP_WS,    48              // struct winsize
.set SP_FD,    56
.set SP_ENVSZ, 64
.set SP_ARGV,  72              // 4 pointers
.set SP_ARG0,  104             // "-zsh"
.set SP_CWD,   168
.set SP_FRAME, 192

    .section __TEXT,__cstring,cstring_literals
Lk_shell:    .asciz "SHELL"
Lk_home:     .asciz "HOME"
Ldef_shell:  .asciz "/bin/zsh"
Lsh:         .asciz "/bin/sh"
Lsh_name:    .asciz "sh"
Ldash_c:     .asciz "-c"
Le_term:     .asciz "TERM=xterm-256color"
Le_color:    .asciz "COLORTERM=truecolor"
Le_prog:     .asciz "TERM_PROGRAM=Avenger"
Le_lang:     .asciz "LANG=en_US.UTF-8"
Lp_term:     .asciz "TERM="
Lp_color:    .asciz "COLORTERM="
Lp_prog:     .asciz "TERM_PROGRAM="
Lp_lang:     .asciz "LANG="
Lp_lcall:    .asciz "LC_ALL="
Lp_ctype:    .asciz "LC_CTYPE="

    // shell name without the login dash, the fallback terminal title
    .zerofill __DATA,__bss,_av_pty_name,64,3
    .globl _av_pty_name

    .text
// int starts(const char *s, const char *prefix)
    .p2align 2
Lstarts:
1:  ldrb w9, [x1], #1
    cbz w9, 2f
    ldrb w10, [x0], #1
    cmp w9, w10
    b.eq 1b
    mov w0, #0
    ret
2:  mov w0, #1
    ret

// char **make_env(size_t *bytes): environ without our overrides, plus TERM and friends
// LANG is added only when no locale is set, GUI apps start without one
    .p2align 2
Lmake_env:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x24, x0
    bl __NSGetEnviron
    ldr x19, [x0]
    mov x9, #0
1:  ldr x10, [x19, x9, lsl #3]
    add x9, x9, #1
    cbnz x10, 1b
    add x9, x9, #ENV_EXTRA
    lsl x0, x9, #3
    str x0, [x24]
    bl _av_pages_alloc
    cbz x0, 9f
    mov x20, x0
    mov x21, #0
    mov x23, #0
2:  ldr x22, [x19], #8
    cbz x22, 4f
    mov x0, x22
    LADDR x1, Lp_term
    bl Lstarts
    cbnz w0, 2b
    mov x0, x22
    LADDR x1, Lp_color
    bl Lstarts
    cbnz w0, 2b
    mov x0, x22
    LADDR x1, Lp_prog
    bl Lstarts
    cbnz w0, 2b
    mov x0, x22
    LADDR x1, Lp_lang
    bl Lstarts
    orr w23, w23, w0
    mov x0, x22
    LADDR x1, Lp_lcall
    bl Lstarts
    orr w23, w23, w0
    mov x0, x22
    LADDR x1, Lp_ctype
    bl Lstarts
    orr w23, w23, w0
3:  str x22, [x20, x21, lsl #3]
    add x21, x21, #1
    b 2b
4:  LADDR x9, Le_term
    str x9, [x20, x21, lsl #3]
    add x21, x21, #1
    LADDR x9, Le_color
    str x9, [x20, x21, lsl #3]
    add x21, x21, #1
    LADDR x9, Le_prog
    str x9, [x20, x21, lsl #3]
    add x21, x21, #1
    cbnz w23, 5f
    LADDR x9, Le_lang
    str x9, [x20, x21, lsl #3]
    add x21, x21, #1
5:  str xzr, [x20, x21, lsl #3]
    mov x0, x20
9:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// pid_t av_pty_spawn(size_t rows, size_t cols, const char *cmd, int *fd, const char *cwd)
// cmd NULL runs the user's login shell, otherwise /bin/sh -c cmd; cwd NULL means $HOME for the
// shell and no chdir for a command; -1 on failure
// everything the child needs is prepared before forking, it only chdirs and execs
FUNC_BEGIN _av_pty_spawn
    stp x29, x30, [sp, #-SP_FRAME]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    strh w0, [sp, #SP_WS]
    strh w1, [sp, #(SP_WS + 2)]
    str wzr, [sp, #(SP_WS + 4)]
    mov x19, x2
    mov x20, x3
    str x4, [sp, #SP_CWD]
    bl _getuid
    bl _getpwuid
    mov x21, x0
    cbz x19, 1f
    // command: sh -c cmd, chdir only when cwd is given
    LADDR x22, Lsh
    LADDR x9, Lsh_name
    LADDR x10, Ldash_c
    stp x9, x10, [sp, #SP_ARGV]
    stp x19, xzr, [sp, #(SP_ARGV + 16)]
    ldr x19, [sp, #SP_CWD]
    b 4f
    // login shell from the user database, then $SHELL, then zsh
1:  mov x22, #0
    cbz x21, 2f
    ldr x22, [x21, #PW_SHELL]
    cbz x22, 2f
    ldrb w9, [x22]
    cbnz w9, 3f
2:  LADDR x0, Lk_shell
    bl _getenv
    mov x22, x0
    cbz x22, 21f
    ldrb w9, [x22]
    cbnz w9, 3f
21: LADDR x22, Ldef_shell
3:  mov x0, x22
    mov w1, #'/'
    bl _strrchr
    cmp x0, #0
    csinc x1, x22, x0, eq
    LADDR x0, _av_pty_name
    mov x2, #63
    bl _strlcpy
    mov w9, #'-'
    strb w9, [sp, #SP_ARG0]
    add x0, sp, #(SP_ARG0 + 1)
    LADDR x1, _av_pty_name
    mov x2, #63
    bl _strlcpy
    add x9, sp, #SP_ARG0
    stp x9, xzr, [sp, #SP_ARGV]
    ldr x19, [sp, #SP_CWD]
    cbz x19, 31f
    ldrb w9, [x19]
    cbnz w9, 4f
31: LADDR x0, Lk_home
    bl _getenv
    mov x19, x0
    cbnz x19, 4f
    cbz x21, 4f
    ldr x19, [x21, #PW_DIR]
4:  add x0, sp, #SP_ENVSZ
    bl Lmake_env
    cbz x0, 8f
    mov x21, x0
    add x0, sp, #SP_FD
    mov x1, #0
    mov x2, #0
    add x3, sp, #SP_WS
    bl _forkpty
    cbnz w0, 6f
    // child
    cbz x19, 5f
    mov x0, x19
    bl _chdir
5:  mov x0, x22
    add x1, sp, #SP_ARGV
    mov x2, x21
    bl _execve
    mov w0, #127
    bl __exit
6:  sxtw x22, w0
    mov x0, x21
    ldr x1, [sp, #SP_ENVSZ]
    bl _av_pages_free
    tbnz x22, #63, 8f
    ldr w0, [sp, #SP_FD]
    str w0, [x20]
    // fcntl is variadic: the third argument goes on the stack
    sub sp, sp, #16
    mov x9, #O_NONBLOCK
    str x9, [sp]
    mov w1, #F_SETFL
    bl _fcntl
    ldr w0, [x20]
    mov x9, #FD_CLOEXEC
    str x9, [sp]
    mov w1, #F_SETFD
    bl _fcntl
    add sp, sp, #16
    mov x0, x22
    b 9f
8:  mov x0, #-1
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #SP_FRAME
    ret

// void av_pty_resize(int fd, size_t rows, size_t cols), SIGWINCH for the foreground job
FUNC_BEGIN _av_pty_resize
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    strh w1, [sp, #16]
    strh w2, [sp, #18]
    str wzr, [sp, #20]
    add x9, sp, #16
    sub sp, sp, #16
    str x9, [sp]
    ldr x1, =TIOCSWINSZ
    bl _ioctl
    add sp, sp, #16
    ldp x29, x30, [sp], #32
    ret

// int av_pty_write(int fd, const void *p, size_t n): 0 when all written
// a full pty buffer is waited on briefly, a child that stops reading loses the rest
FUNC_BEGIN _av_pty_write
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov w19, w0
    mov x20, x1
    mov x21, x2
1:  cbz x21, 8f
    mov w0, w19
    mov x1, x20
    mov x2, x21
    bl _write
    cmp x0, #0
    b.le 2f
    add x20, x20, x0
    sub x21, x21, x0
    b 1b
2:  bl ___error
    ldr w9, [x0]
    cmp w9, #EINTR
    b.eq 1b
    cmp w9, #EAGAIN
    b.ne 7f
    // struct pollfd {int fd; short events, revents}
    sub sp, sp, #16
    str w19, [sp]
    mov w9, #POLLOUT
    strh w9, [sp, #4]
    strh wzr, [sp, #6]
    mov x0, sp
    mov w1, #1
    mov w2, #500
    bl _poll
    add sp, sp, #16
    cmp w0, #0
    b.gt 1b
7:  mov w0, #-1
    b 9f
8:  mov w0, #0
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// int av_pty_busy(int fd, pid_t shell): something other than the shell is in the foreground
FUNC_BEGIN _av_pty_busy
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov w19, w1
    bl _tcgetpgrp
    cmp w0, #0
    ccmp w0, w19, #4, gt
    cset w0, ne
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// int av_pty_cwd(int fd, pid_t pid, char *buf): working directory of the foreground job, or of
// pid when fd is -1 or has no job, into buf (1024 bytes); 0 on success
FUNC_BEGIN _av_pty_cwd
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    sub sp, sp, #VPI_SIZE
    mov w19, w1
    mov x20, x2
    tbnz w0, #31, 1f
    bl _tcgetpgrp
    cmp w0, #0
    csel w19, w0, w19, gt
1:  mov w0, w19
    mov w1, #PROC_PIDVNODEPATHINFO
    mov x2, #0
    mov x3, sp
    mov w4, #VPI_SIZE
    bl _proc_pidinfo
    cmp w0, #VPI_SIZE
    b.lt 8f
    mov x0, x20
    add x1, sp, #VPI_CDIR_PATH
    mov x2, #1024
    bl _strlcpy
    mov x0, #0
    b 9f
8:  mov x0, #-1
9:  add sp, sp, #VPI_SIZE
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_pty_close(int fd, pid_t pid): hang up the session and reap what already exited
FUNC_BEGIN _av_pty_close
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov w19, w0
    mov w0, w1
    mov w1, #SIGHUP
    bl _kill
    mov w0, w19
    bl _close
    bl _av_pty_reap
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// void av_pty_reap(void): collect exited children so they do not linger as zombies
FUNC_BEGIN _av_pty_reap
    stp x29, x30, [sp, #-16]!
    mov x29, sp
1:  mov w0, #-1
    mov x1, #0
    mov w2, #WNOHANG
    bl _waitpid
    cmp w0, #0
    b.gt 1b
    ldp x29, x30, [sp], #16
    ret
