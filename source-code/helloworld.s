# helloworld.s
    .section    __TEXT, __cstring
helloworld:
    .asciz  "helloworld, %d\n"

    .text
    .globl  _main
_main:
    pushq   %rbp
    leaq    helloworld(%rip), %rdi
    movq    $114514, %rsi
    movb    $0, %al
    callq   _printf

    popq    %rbp
    movq    $0, %rax
    retq