# dataTest.s
	.data
a:	.quad	0x114514

	.text
	.globl	_main
_main:
	movq	a(%rip), %rax
	retq