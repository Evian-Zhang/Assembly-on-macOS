在上一篇文章中，我们简要地谈了在汇编语言中是如何实现函数功能的，即用`call`和`ret`. 在这篇文章中，我们将更深入地探讨关于汇编语言中函数的话题。

# 调用约定

汇编语言中的函数，实质只是一个标签所代表的内存地址。它不像其他高级语言一样，有完整的函数原型体系。比如说，在C语言中，`int func(int a, char *b)`可以让我们知道，这个函数接受两个参数，第一个是`int`类型的，第二个是`char *`类型的，同时这个函数也返回一个`int`类型的值。但是，汇编语言中并没有这样的体系。在我们自己写的程序中，如果调用自己写的函数，那我既可以往rdi里传参数，也可以把参数压入栈里，然后函数再弹栈获得参数；函数返回既可以返回到rax里，也可以多返回到几个寄存器内实现多返回值。这一切都是我们自己约定好的。但是，写程序不只是自己用自己的，也需要用他人的函数，也需要被他人的函数用。那么，我们就应该与他人达成一个约定，如何调用函数，函数会不会改变某些寄存器的值等等。这叫做调用约定(Calling Convention). 关于调用约定，一定要看的是[System V x86-64 psABI](https://github.com/hjl-tools/x86-psABI). 这个和之前我提到的Intel的x86-64架构官方文档[64-ia-32-architectures-software-developer-instruction-set-reference-manual](https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf)一样，都是学习汇编语言一定要多看的文档，建议翻烂。

## 参数传递

调用约定包含很多方面。首先，我们来谈谈参数传递。这里传递的参数默认是INTEGER类的，比如说`int`, `long`, `short`, `char`, 以及指针等，也就是除了`double`这种我们在汇编中需要特殊对待的类型以外。

参数传递按从左至右的顺序依次是：rdi, rsi, rdx, rcx, r8, r9. 如果参数多于6个，则将多于6个的部分按从右往左的顺序压入栈内。

比如说，我有如下C程序：

```c
// test.c
int func(int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8)
{
  return 3;
}

int main()
{
  func(1, 2, 3, 4, 5, 6, 7, 8);
  return 0;
}
```

我们在终端下键入

```bash
clang test.c -S
```

可以生成一个由`test.c`编译出的汇编代码`test.s`. 我们找到其中参数传递的部分，汇编代码如下：

```assembly
	movl	$1, %edi
	movl	$2, %esi
	movl	$3, %edx
	movl	$4, %ecx
	movl	$5, %r8d
	movl	$6, %r9d
	movl	$7, (%rsp)
	movl	$8, 8(%rsp)
	callq	_func
```

我们可以看到，参数传递确实是按这种调用约定来的。

这里说明一点，为什么多于6个的时候压栈，是按从右往左的顺序压栈呢？这样的设计，满足了我们对可变参数的需求。我们知道，C语言中有`prinf`这个函数。这个函数的参数个数就是可变的，其参数的个数是由从左往右数第一个参数格式化字符串确定的。在我们程序语言的设计中，往往可变参数的个数都是由从左往右数的某个参数确定的。那么，我们从右往左压栈，函数内部弹栈获得参数的时候就是按从左往右的顺序，因此就可以在固定的位置获得用于确定可变参数个数的参数。这就是从右往左压栈的好处。

## 返回值

返回值总是传递到rax上。这也就是我们最初的第一个汇编程序，返回的时候把`$0`赋给rax的原因。

```assembly
movq	$0, %rax
retq
```

就相当于C语言中的

```c
return 0;
```

## 保留寄存器

在我们调用函数的时候，还要遵循一个约定，那就是哪些寄存器是保留寄存器。比如说，我在函数`_func`里面，修改了寄存器rbx的值，那么我在主函数中，`callq	_func`之后，并没有任何表征告诉我们rbx的值改变了，那么我们在后续的编程中就有可能使用了错误的rbx值。因此，在函数执行的时候，哪些寄存器应当保留，也属于调用约定。在这里，称调用的函数为called函数，调用called函数的函数称为calling函数。比如说：

```assembly
_main:
	callq	_func
	retq
	
_func:
	# do something
```

中，`_main`就是calling函数，`_func`就是called函数。

寄存器rbp, rbx, r12, r13, r14, r15是属于calling函数，其余的寄存器都属于called函数。called函数在使用上述寄存器的时候，应当对寄存器的初始值予以保留。

保留的最有效的方法就是将其`push`上栈，在返回之前再`pop`回来。这也就是我们当初在局部变量的时候，在使用rbp标记最初栈顶之前，首先要`pushq	%rbp`, 在函数返回之前，又要`popq	%rbp`. 同时我们也应当注意到，这也意味着我们在调用别的函数的时候，只能默认上述那几个寄存器在调用之后不会被改变，而别的寄存器是又可能被改变的。

# 函数调用

在讲完了调用约定之后，我们接下来再讨论一下函数调用的问题。在了解调用约定之前，我们只能放心大胆地调用自己的函数。在了解了调用约定之后，我们就可以和他人写的函数互动了。这里分多种情况讨论一下。

## 调用本文件中的函数

就是最基础的情况，自己调用本文件中自己写的函数，不需要任何别的东西，直接`call`就好了。

## 调用别的汇编文件中的函数

这里既有可能是自己写的多文件，也有可能是他人写的。如果要调用别的文件中的函数，那么这个函数在它被定义的那个文件中一定要是被`.globl`声明过的。假设有两个汇编文件`my.s`和`other.s`, 我们只需要在终端下依次键入

```bash
as my.s -o my.o
as other.s -o other.o
ld my.o other.o -o my -lSystem
```

这里要求`my.s`和`other.s`不能同时有`_main`. 

## 调用C语言中的函数

假设我有一个C语言中的函数`int func(int a, int b, int c)`. 那么我如果想在别的汇编代码中调用这个函数，只需要将这个函数的名字前加一个`_`. 也就是`callq	_func`即可。参数传递和返回值都是按之前说的调用约定来做。假设C语言的代码叫做`test.c`, 汇编语言的代码叫做`main.o`, 那么我们只需要在终端下依次键入

```bash
clang test.c -c -o test.o
as main.s -o main.o
ld test.o main.o -o main -lSystem
```

## 调用库函数

操作系统提供了大量的库。在macOS中，大量的库函数都包含在文件`/usr/lib/libSystem.dylib`中。包括：

* `libc`<br />C标准库
* `libinfo`<br />NetInfo库
* `libkvm`<br />内核虚存库
* `libm`<br />数学库
* `libpthread`<br />POSIX线程库

这些库的C头文件我们可以在`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk 1/usr/include/`目录下找到。

我们在链接时的参数`-lSystem`就代表链接`libSystem.dylib`. 因此，我们不需要再额外做任何工作，就能按照上述的调用C语言的方式调用系统库的函数了。因此，我们心心念念的`printf`终于可以用了！只不过要在前面加上`_`. 

不过，还有一点额外要注意的。在调用库函数的时候，栈需要16字节对齐。这是什么意思呢？在之前提到的调用约定中，其实还有一点，就是栈对齐。由于我们写函数的时候总是会在第一步就`pushq	%rbp`; 同时再在这个函数中用`call`调用别的函数的时候，实际上又把返回地址压栈。因此，called函数的起始栈地址，比calling函数的起始栈地址高了16个字节。硬件开发者就这个特点，进行了优化。导致栈进行16字节对齐的时候，效率会特别高。因此，这也就作为了一项调用约定。

那么，栈16字节对齐究竟是什么意思呢？首先，我们的`_main`函数默认其进入的时候，rsp寄存器内的地址值是16字节的倍数。接下来，我们如果要`call`任何库函数，要保证在`call`之前，`8(%rsp)`, 也就是rsp寄存器内的地址值加8，应当是16的倍数。因此，我们来算一下：在`_main`的最开始，rsp寄存器内的地址值是16的倍数；接下来一般人都会`pushq	%rbp`. 这时，rsp寄存器内的地址值是16的倍数加8. 因此，我们在接下来利用栈分配局部变量的时候，一定要让增加的栈空间是16的倍数。因此，即使只有3个`long`型的局部变量，也要将rsp减32, 而不是减24.

我们来看如何利用`printf`进行输出"helloworld, 114514"：

```assembly
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
```

我们在`__TEXT`段`__cstring`节定义了用来输出的字符串。这个节是专门用来存储C风格字符串的。

接下来的`helloworld:`自然就是标签了。

`.asciz`定义的是C风格字符串，地位和`.quad`这些汇编器指令相当。它会自动在字符串结尾补上`\0`.

接下来我们回忆一下`printf`接受的参数。第一个参数是一个字符指针，指向字符串的开头。因此，我们利用`leaq	helloworld(%rip), %rdi`, 将字符串传入第一个参数。接下来，我们的字符串中有`%d`, 说明`prinf`还得有第二个参数。因此，我们将`114514`传入rsi中。这样似乎就结束了。但是，有一个需要我们注意的，就是像`printf`这种接受可变参数的函数，还需要将参数中VECTOR寄存器的数量放入al中。所谓VECTOR寄存器，就可以理解成存放浮点数的寄存器。我们这里没有浮点数，因此将0放入al中即可。然后`callq	_printf`即可。

## 被调用

被调用的最典型的例子，就是命令行参数`argc`与`argv`了。`argc`是在命令行中该程序被调用时参数的个数，`argv`是一个`char **`类型，是各个参数的字符串数组。比如说，

```bash
./test	helloworld 1
```

那么，`argc`就是3，`argv[0]`是`"./test"`, `argv[1]`是`"helloworld"`, `argv[2]`是`"1"`.

操作系统会自动将`argc`和`argv`作为`_main`函数的参数传给程序。因此，我们在`_main`的开始，就可以用rdi获得`argc`, `rsi`获得argv.

## 被C语言调用

和调用C语言时在函数名前加`_`相反, 被C语言调用时，C代码中要把汇编语言函数前的`_`去掉。比如说汇编语言中有一个函数`_func`, 那么在C语言中调用的函数就应当是`func()`. 此外，需要在C语言代码的开头写上

```c
extern void func();
```

其中函数的返回值和参数都可以依据汇编语言来定，也可以写`extern int func(int a);`这种。

# 可以在哪看到这系列文章

我在我的[GitHub](https://github.com/Evian-Zhang/Assembly-on-macOS)上，[知乎专栏](https://zhuanlan.zhihu.com/c_1132336120712765440)上和[CSDN](https://blog.csdn.net/EvianZhang)上同步更新。

上一篇文章：[macOS上的汇编入门（九）——跳转与函数](macOS上的汇编入门（九）——跳转与函数.md)

下一篇文章：[macOS上的汇编入门（十一）——系统调用](macOS上的汇编入门（十一）——系统调用.md)