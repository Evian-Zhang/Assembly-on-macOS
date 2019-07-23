作为这一系列文章中的最后一篇，这篇文章我打算讨论的是从编译到执行的全过程。因为许多地方都是要有了汇编的基础知识以后才方便讨论，所以我把它放到了最后一篇。

# 编译

编译并不是对汇编代码来说的，而是对更高级的语言，如C、C++来说的。如果一个语言最终的编译结果是可执行文件，那么它一定会先被编译为汇编语言，然后再被汇编、链接为可执行文件。对于C和C++来说，大部分的编译器都支持输出汇编结果。比如说对于`test.c`, 我们想查看其编译后的汇编代码，只需要在命令行中键入

```bash
clang test.c -S -o test.s
```

然后就会生成一个包含其汇编代码的`test.s`文件。

研究编译器生成的汇编代码很有意义。因为现代的编译器，其都针对不同的平台、架构有许多优化，这对于我们写汇编代码是很有意义的。比如说，对

```c
return 0;
```

的编译结果，是

```assembly
xorl	%eax, %eax
retq
```

事实上，通过异或自身来清零这一操作，在任何架构上都是最高效的。

# 汇编

所谓汇编，就是输入我们的汇编代码，输出目标文件。什么是目标文件呢？假设我们有一个汇编文件`test.s`, 然后我们利用

```bash
as test.s -o test.o
```

生成一个`test.o`文件。然后，我们在终端下利用`file`指令查看其文件类型：

```bash
$ file test.o
test.o: Mach-O 64-bit object x86_64
```

可以看到， 这个文件是object, 也就是目标文件。

那么，目标文件是做什么用的呢？要了解这个，首先我们需要知道「汇编」这一步骤究竟做了什么。

我们知道，汇编语言可以看作机器码的human-readable版本。因此，从最直观来看，汇编只需要把汇编代码翻译为机器码就ok了，也就是汇编代码直接变成可执行文件。这个粗略来看是对的，对于大多数代码来说，确实直接翻译为机器码就好了。但是，如果真的是这样，随着人们写的代码越来越多，汇编器的有一项工作的负担就越来越重——翻译符号。我们之前在汇编语言中大量运用了标签，一个标签就对应一个地址。此外，我们也可以引用别的文件、动态链接库的标签。因此，对于一个标签，其可能的情况有好多好多种。所以，人们就把这部分功能从汇编器中解放出来，同时，汇编器就变成了对于一个汇编文件，输出其目标文件。目标文件几乎包含的就是可执行文件中的机器码，但是标签部分却是空缺的。其会把所有遇到的符号放到一个符号表中，以便查阅。

举个例子，我们现在有两个汇编程序`test.s`和`tmp.s`, 其代码分别如下：

`tmp.s`:

```assembly
# tmp.s
    .data
    .globl  tmp_var
tmp_var:    .quad   0x114514

    .text
    .globl  _tmp_func
_tmp_func:
    retq
```

`test.s`:

```assembly
# test.s
	.data
var:	.asciz	"hello, world!\n"

	.text
	.globl	_main
_func:
	retq

_main:
	pushq	%rbp

	callq	_func	# internal call
	leaq	var(%rip), %rdi	# internal variable
	movb	$0, %al
	callq	_printf	# dylib call
	movq	tmp_var(%rip), %rdi	# external variable
	callq	_tmp_func	# external variable

	popq	%rbp
	movq	$0, %rax
	retq
```

其中主函数位于`test.s`. 且`test.s`分别包含了对本文件下函数的调用、本文件下变量的访问、动态链接库中函数的调用、外部文件中函数的调用和外部文件中变量的访问。

我们在终端中依次键入

```bash
as test.s -o test.o
as tmp.s -o tmp.o
```

得到两个目标文件。我们利用

```
otool -v -t test.o
```

可以查看`test.o`文件中`__TEXT`段`__text`节的代码：

```assembly
test.o:
(__TEXT,__text) section
_func:
0000000000000000	retq
_main:
0000000000000001	pushq	%rbp
0000000000000002	callq	0x7
0000000000000007	leaq	(%rip), %rdi
000000000000000e	movb	$0x0, %al
0000000000000010	callq	0x15
0000000000000015	movq	(%rip), %rdi
000000000000001c	callq	0x21
0000000000000021	popq	%rbp
0000000000000022	movq	$0x0, %rax
0000000000000029	retq
```

同时，我们在终端中键入

```bash
nm -n -m test.o
```

可以查看`test.o`的符号表：

```bash
                 (undefined) external _printf
                 (undefined) external _tmp_func
                 (undefined) external tmp_var
0000000000000000 (__TEXT,__text) non-external _func
0000000000000001 (__TEXT,__text) external _main
000000000000002a (__DATA,__data) non-external var
```

可以看到，对于本文件中定义的符号，符号表中已经有了位置，同时依据是否用`.globl`声明区分为external和non-external. 对于未在本文件中定义的符号，都是undefined.

# 链接

之前我们讲到的符号定位的功能，就是链接的作用。链接器接收多个目标文件，最终输出为一个可执行文件。对于刚刚我们生成的两个目标文件`test.o`和`tmp.o`, 我们在终端中键入

```bash
ld test.o tmp.o -o test -lSystem
```

得到可执行文件`test`. 我们利用`otool`查看其`__TEXT`段`__text`节的代码为：

```assembly
test:
(__TEXT,__text) section
_func:
0000000100000f6b	retq
_main:
0000000100000f6c	pushq	%rbp
0000000100000f6d	callq	0x100000f6b
0000000100000f72	leaq	0x1097(%rip), %rdi
0000000100000f79	movb	$0x0, %al
0000000100000f7b	callq	0x100000f96
0000000100000f80	movq	0x1098(%rip), %rdi
0000000100000f87	callq	0x100000f95
0000000100000f8c	popq	%rbp
0000000100000f8d	movq	$0x0, %rax
0000000100000f94	retq
_tmp_func:
0000000100000f95	retq
```

可以看到，链接器将两个目标文件的段合并了。同一个段同一个节中的代码被放在了一起。此外，之前标签处占位的地址，现在也变成了正确的地址。

接着，我们利用`nm`查看其符号表：

```bash
                 (undefined) external _printf (from libSystem)
                 (undefined) external dyld_stub_binder (from libSystem)
0000000100000000 (__TEXT,__text) [referenced dynamically] external __mh_execute_header
0000000100000f6b (__TEXT,__text) non-external _func
0000000100000f6c (__TEXT,__text) external _main
0000000100000f95 (__TEXT,__text) external _tmp_func
0000000100002008 (__DATA,__data) non-external __dyld_private
0000000100002010 (__DATA,__data) non-external var
000000010000201f (__DATA,__data) external tmp_var
```

其中多出来的`dyld_stub_binder`等只是为了动态链接，我们暂时不考虑。我们发现，之前处于undefined状态的`_tmp_func`和`tmp_var`现在已经被定义了。而且`_printf`这样的动态链接库中的函数，也被确定是from `libSystem`了。这就是链接器的主要作用。

# 动态链接

我刚刚上面多次提到了动态链接库，那么，动态链接究竟是什么呢？

首先，我们考虑一个问题。我们知道，有许多库函数如`_printf`等都是十分常用的，所以许多文件在链接时都要链接包含这些库函数的文件。那么，如果我们的这些库函数像上面的汇编过程一样，包含在某些`.o`文件中，比如说`lib.o`. 那么，作为链接器，`ld`会将这些实现`_printf`的汇编代码合并到最终的可执行文件中。当可执行文件执行的时候，又会将这部分代码放到内存中。那么，假设我们同时运行10个链接了`lib.o`的可执行文件，那么，内存中同样的代码有10份。这显然是不可以接受的。

此外，还有一个问题。我们知道，系统是不断升级的。那么，系统提供的库函数也会随着时间的变化而不断升级。如果所有的库函数都像上面描述的那样，作为代码直接写死到可执行文件里面去，那么，每次升级过后，之前链接了这些库函数的可执行文件，使用的依然是老旧的库函数。如果要使用新的库函数，还得重新链接。这显然也是不可以接受的。

为了解决这两个问题，动态链接就应运而生了。与汇编、链接不同，动态链接是在执行阶段的。我们的库函数，都被放到了一个以`.dylib`结尾的动态链接库中。我们在使用`ld`链接的时候，也可以链接动态链接库，如`-lSystem`选项实质上就是链接了动态链接库`libSystem.dylib`. 链接器如果遇到动态链接库，那么只会给符号重定位，而不会将代码整合到可执行文件中。同时，可执行文件中会包含其链接的动态链接库。我们也可以利用`otool`查看某个可执行文件链接的动态链接库，比如说，对于上述的可执行文件`test`, 我们在终端下键入：

```bash
otool -L test
```

然后就会出现其链接的动态链接库（实际上`libSystem.dylib`是`libSystem.B.dylib`的一个软链接，说不定以后库文件大规模升级以后，就会软链接到`libSystem.C.dylib`）：

```bash
test:
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1281.0.0)
```

然后，到程序执行的时候，就是动态链接器`dyld`发挥的时候了。顺便一提，Apple的`dyld`是开源的，可以去[opensource-apple/dyld](https://github.com/opensource-apple/dyld)上查看。

当程序执行的时候，首先，内核将代码装载入其逻辑地址空间，然后，又装载了动态链接器。接着，内核就把控制权转交给`dyld`. 动态链接器做的，是找到这个可执行文件链接的动态链接器，然后把它们装载入逻辑地址空间。用一个图表示如下：

![address_space](macOS上的汇编入门（十三）——从编译到执行/address_space.png)

注意到，我们提到的是将动态链接库装载入逻辑地址空间。事实上，在物理内存中，动态链接库只有一份。而内存映射单元MMU将同一个动态链接库的不同逻辑地址映射入同一个物理地址中，这样就解决了在内存中多个拷贝的问题。

同时，由于是在执行时才装载，因此，就解决了升级不便的问题。

# 可以在哪看到这系列文章

我在我的[GitHub](https://github.com/Evian-Zhang/Assembly-on-macOS)上，[知乎专栏](https://zhuanlan.zhihu.com/c_1132336120712765440)上和[CSDN](https://blog.csdn.net/EvianZhang)上同步更新。

上一篇文章：[macOS上的汇编入门（十二）——调试](macOS上的汇编入门（十二）——调试.md)