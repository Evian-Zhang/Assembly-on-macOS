# Fibonacci.s
    .text
    .globl  _main
_main:
    movq    $13, %rdi
    callq   _Fibonacci
    retq

_Fibonacci:
    movq    $1, %rax
    movq    $1, %rbx
compare:
    cmp $2, %rdi
    jg loop_continue
    retq
loop_continue:
    movq    %rax, %rcx
    addq    %rbx, %rax
    movq    %rcx, %rbx
    decq %rdi
    jmp compare