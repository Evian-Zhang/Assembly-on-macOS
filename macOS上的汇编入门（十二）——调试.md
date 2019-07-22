随着我们编写的汇编程序越来越复杂，往往就需要调试。对于汇编语言而言，常见的调试器有LLDB和GDB. 由于我比较喜欢用LLVM系列的产品，因此，在这篇文章中我主要介绍的是LLDB来调试汇编语言的方法。关于详细的LLDB的使用方法，大家可去官网[lldb.llvm.org](https://lldb.llvm.org/index.html)查看。

同时，在新版本的macOS上使用GDB是一件比较麻烦的事，需要证书签名。关于使用方法请参见我之前的文章[在macOS10.14上使用GDB教程](https://evian-zhang.github.io/articles/macOS/在macOS10.14上使用GDB教程/在macOS10.14上使用GDB教程.html)。

为了演示LLDB的调试，我们首先有一个汇编程序`test.s`:

```assembly
# test.s
	.text
	.globl	_main
_main:
	movq	$0x2000001, %rax
	movq	$0, %rdi
	syscall
```

为了以源码级别调试程序，我们需要在汇编时加入调试选项`-g`. 也就是说，我们在终端下依次键入下面语句：

```bash
as test.s -g -o test.o
ld test.o -o test -lSystem
```

这样就可以将调试信息储存在`test.o`中以便我们接下来的调试。

# 载入程序

首先是将程序载入LLDB. 假设我们要调试的可执行程序是`test`. 那么，我们在终端下键入

```bash
lldb test
```

即可进入LLDB调试界面，同时会出现

```bash
(lldb) target create "test"
Current executable set to 'test' (x86_64).
(lldb)
```

的提示语句。

我们输入`quit`即可退出LLDB的调试界面：

```bash
(lldb) quit
```

# 运行程序

接下来，我们可以输入`run`来执行这个程序：

```bash
(lldb) run
Process 1512 launched: '/Users/evian/Downloads/test' (x86_64)
Process 1512 exited with status = 0 (0x00000000)
```

程序顺利执行，没有发生错误。

但是，如果我们在某个地方写错了，比如说写成了`movq	$0x2001, %rax`, 那么汇编、链接时并不会发生错误，但在终端下运行时则会出现以下的错误报告：

```bash
./test
[1]    1556 segmentation fault  ./test
```

这让我们摸不着头脑，段错误是为什么会出现呢？这时，在LLDB中一个简单的`run`就可以让我们找到答案：

```bash
(lldb) run
Process 1573 launched: '/Users/evian/Downloads/test' (x86_64)
Process 1573 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = EXC_SYSCALL (code=8193, subcode=0x1)
    frame #0: 0x0000000100000fb8 test
    0x100000fb8: addl   %eax, (%rax)
    0x100000fba: addb   %al, (%rax)
    0x100000fbc: sbbb   $0x0, %al
    0x100000fbe: addb   %al, (%rax)
Target 0: (test) stopped.
```

注意看到其中的`stop reason = EXC_SYSCALL`. 这就说明是我们在系统调用时出现了问题。

`run`除了直接运行以外，还可以传命令行参数。比如说，我们在终端下想这样运行：

```bash
./test helloworld 114514
```

也就是将两个命令行参数传递给`test`. 那么，我们在LLDB中也可以用`run`模拟这种传递过程：

```bash
(lldb) run helloworld 114514
```

即可。

# 设置断点

LLDB的功能远不止直接执行程序这么简单。接下来的工作，都需要我们首先设置断点。比如说，我想让程序在执行完`movq	%0x2000001, %rax`后停下来，也就是不继续执行`movq	%0, %rdi`. 这时应当怎么办呢？

首先，我们找到`movq	%0, %rdi`所在的行数，是第6行。因此，我们需要在第6行设置断点。在某行设置断点的意思就是在某行之前设置断点，当程序遇到断点时就会自动停下来，不继续执行。因此，我们在LLDB中输入并得到反馈：

```bash
(lldb) breakpoint set --file test.s --line 6
Breakpoint 1: where = test`main + 7, address = 0x0000000100000faf
```

程序就自动设置了一个断点。这句话的意思就是在名叫`test.s`的文件的第6行设置断点。

接下来，我们如果直接`run`，会出现：

```bash
(lldb) run
Process 1669 launched: '/Users/evian/Downloads/test' (x86_64)
Process 1669 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x0000000100000faf test`main at test.s:6
   3   		.globl	_main
   4   	_main:
   5   		movq	$0x2000001, %rax
-> 6   		movq	$0, %rdi
   7   		syscall
Target 0: (test) stopped.
```

也就直接在第6行停了下来。我们可以用`continue`让其继续执行：

```bash
(lldb) continue
Process 1669 resuming
Process 1669 exited with status = 0 (0x00000000)
```

或者利用`nexti`进行单步调试：

```bash
(lldb) nexti
Process 1680 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = instruction step over
    frame #0: 0x0000000100000fb6 test`main at test.s:7
   4   	_main:
   5   		movq	$0x2000001, %rax
   6   		movq	$0, %rdi
-> 7   		syscall
Target 0: (test) stopped.
```

所谓单步调试，就是指在当前指令的下一个指令处再设置一个断点，然后继续执行。实际效果也就相当于又往后执行了一个指令，然后停止。

# 寄存器与内存

在进程停止在某个断点处时，我们还可以读取此时寄存器和内存的值。

利用`register read`可以阅读大部分常用寄存器的值：

```bash
(lldb) register read
General Purpose Registers:
       rax = 0x0000000002000001
       rbx = 0x0000000000000000
       rcx = 0x00007ffeefbff910
       rdx = 0x00007ffeefbff7e8
       rdi = 0x0000000000000001
       rsi = 0x00007ffeefbff7d8
       rbp = 0x00007ffeefbff7c8
       rsp = 0x00007ffeefbff7b8
        r8 = 0x0000000000000000
        r9 = 0x0000000000000000
       r10 = 0x0000000000000000
       r11 = 0x0000000000000000
       r12 = 0x0000000000000000
       r13 = 0x0000000000000000
       r14 = 0x0000000000000000
       r15 = 0x0000000000000000
       rip = 0x0000000100000faf  test`main + 7
    rflags = 0x0000000000000246
        cs = 0x000000000000002b
        fs = 0x0000000000000000
        gs = 0x0000000000000000
```

如果输入`register read —all`, 则会输出所有寄存器的值。

此外，我们还可以单独查看某个寄存器，比如说

```bash
(lldb) register read rsp
     rsp = 0x00007ffeefbff7b8
```

就会返回rsp内存储的值。

同时，我们也可以查看内存中的值。我们刚刚查看到了此时栈顶指针位于`0x00007ffeefbff7b8`. 因此，我们利用

```bash
(lldb) memory read 0x00007ffeefbff7b8
0x7ffeefbff7b8: 35 fc 2e 6d ff 7f 00 00 35 fc 2e 6d ff 7f 00 00  5�.m�...5�.m�...
0x7ffeefbff7c8: 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00  ................
```

就获得了当前栈顶的内容。

# 可以在哪看到这系列文章

我在我的[GitHub](https://github.com/Evian-Zhang/Assembly-on-macOS)上，[知乎专栏](https://zhuanlan.zhihu.com/c_1132336120712765440)上和[CSDN](https://blog.csdn.net/EvianZhang)上同步更新。

上一篇文章：[macOS上的汇编入门（十一）——系统调用](macOS上的汇编入门（十一）——系统调用.md)