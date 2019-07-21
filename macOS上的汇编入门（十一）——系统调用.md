在上一篇文章中，我们更深入地讨论了关于汇编语言函数方面的知识，同时也介绍了如何调用系统库`libSystem.dylib`的函数。在这篇文章中，我们讨论的是另一种系统提供的函数——系统调用。

# 什么是系统调用

所谓系统调用(System call), 就是指操作系统提供的接口。我们知道，现代的操作系统分为内核态和用户态。我们平时的汇编语言的执行过程中，都是在用户态执行的。但是，有一些核心的功能，如文件的读写、进程的创建等，都是在内核态实现的。这时候，就需要我们去调用操作系统提供给我们的接口来实现。系统调用和我们之前说的系统库有什么区别呢？其实，很多系统调用在系统库中都有封装。但是，系统调用是最底层的东西。譬如说，我们在织衣服的时候，丝线不够了。我们是不需要自己去养蚕缫丝的，只需要去丝绸店买丝线就行。丝绸店就相当于操作系统，它负责养蚕缫丝，而我们只需要去调用。同时，我们也可以不必自己去丝绸店买衣服，可以去找仆人出门。仆人有什么好处呢？这仆人十分熟悉丝绸店，知道什么丝绸店有什么丝绸店没有。我们想买紫色的丝线，仆人说“丝绸店没有紫色的丝线”，那么也就不需要去丝绸店了。仆人就相当于系统库。我们在调用系统库中涉及系统调用的函数的时候，最终都是要调用到系统调用的。

# 有哪些系统调用

我们前往`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk 1/usr/include/sys/`这个目录，找到一个叫`syscall.h`的文件。这个文件的格式如下：

```c
#define	SYS_syscall        0
#define	SYS_exit           1
#define	SYS_fork           2
#define	SYS_read           3
#define	SYS_write          4
#define	SYS_open           5
#define	SYS_close          6
#define	SYS_wait4          7
```

第二列是系统调用的名字，第三列是系统调用号。

系统调用的名字很直白地表述了系统调用的作用，比如说`SYS_exit`就是退出进程，`SYS_fork`就是创建进程，`SYS_read`就是打开文件等等。

系统调用实质上是操作系统提供给我们的一个C函数接口，那么，我们去哪里找系统调用的函数原型呢？

这个相对比较麻烦。首先，我们前往Apple官方的开源网站[opensource.apple](https://opensource.apple.com), 然后会发现每个版本的macOS都有一部分开源的文件。进入任意一个版本的开源目录下，可以找到一个以`xnu`开头的目录。这就是每个版本的内核代码，直接下载即可。如果不在意版本号，那么可以直接前往其在GitHub上的镜像[apple/darwin-xnu](https://github.com/apple/darwin-xnu)下载即可。

在下载好的`xnu`目录下，前往子目录`bsd/kern/`中，找到一个文件`syscalls.master`. 这就是所有系统调用的函数原型。我们可以利用命令行工具`cat`进行查看。其文件格式如下：

```c
0	AUE_NULL	ALL	{ int nosys(void); }   { indirect syscall }
1	AUE_EXIT	ALL	{ void exit(int rval) NO_SYSCALL_STUB; } 
2	AUE_FORK	ALL	{ int fork(void) NO_SYSCALL_STUB; } 
3	AUE_NULL	ALL	{ user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte); } 
4	AUE_NULL	ALL	{ user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte); } 
5	AUE_OPEN_RWTC	ALL	{ int open(user_addr_t path, int flags, int mode) NO_SYSCALL_STUB; } 
6	AUE_CLOSE	ALL	{ int close(int fd); } 
7	AUE_WAIT4	ALL	{ int wait4(int pid, user_addr_t status, int options, user_addr_t rusage) NO_SYSCALL_STUB; } 
```

其第一列是系统调用号，第四列则是函数原型。

# 如何使用系统调用

使用系统调用和使用系统库函数类似，但是，系统库函数我们可以利用函数名进行调用，如`_exit`, `_printf`等。但是，我们使用系统调用，则只能利用系统调用号进行调用。这里还有一点需要注意的，就是之前在操作系统基础中提到过，macOS的内核XNU是分为BSD层和Mach层。我们常用的系统调用都属于BSD的系统调用。而BSD层在逻辑地址上是位于Mach层之上的，BSD层要从`0x2000000`开始。因此，我们实际使用的调用号应该是`syscall.h`给出的调用号加上`0x2000000`之后的结果，如`SYS_exit`的调用号就应当是`0x2000001`.

在汇编语言中，系统调用号应赋给rax寄存器，然后接下来系统调用的参数按照之前讲的调用约定，依次传给rdi, rsi等寄存器中。最后，使用`syscall`即可。

比如说，我们在程序中调用`SYS_exit`系统调用：

```assembly
	movq	$0x2000001, %rax
	movq	$0, %rdi
	syscall
```

我们首先将系统调用号`0x2000001`赋给rax寄存器，然后根据其函数原型`void exit(int rval)`, 其接受一个参数作为整个进程的返回值，因此，我们将`0`赋给rdi寄存器，然后使用`syscall`进行系统调用。

# 进程的返回

讲完了系统调用，这里顺带提一句，在许多汇编教程中，都是这么写`_main`函数的：

```assembly
	.text
	.globl	_main
_main:
	# do something
	movq	$0x2000001, %rax
	movq	$0, %rdi
	syscall
```

而我在这一系列文章中都是这么写的：

```assembly
	.text
	.globl	_main
_main:
	# do something
	retq
```

这有什么区别呢？

首先，我这么写是为了和C语言对应。第一种写法对应的C程序是（`exit`实际上是库函数，但其底层依然是系统调用`SYS_exit`）：

```c
int main()
{
  exit(0);
}
```

而我的写法对应的C程序是：

```c
int main()
{
  return 0;
}
```

正常人写C程序大多会用第二种写法，因此我写汇编的时候也是对应第二种写法来写的。

其次，`exit`和`return`有什么区别呢？事实上，`exit`是真正的进程退出，执行完`exit`之后，进程就彻底没了。但是，`return`并不是这样。事实上，操作系统在加载一个程序进内存时，动态链接了一个目标文件`crt1.o`, 这个文件位于`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk 1/usr/lib/`目录下。这个文件做了什么呢？它可以理解为

```c
int rVal = main(argc, argv);
exit(rVal);
```

这段C程序。它找到我们想要执行的文件的`main`函数（在汇编中是`_main`函数），然后将`argc`和`argv`当作`main`函数的参数传递给它。在`main`函数执行完后，会有一个返回值，这也是我们写`return 0;`的目的，这时`rVal`的值就是`main`函数的返回值`0`. 最后，调用`exit`进行退出。

因此，我们虽然可以在`main`函数中直接用`exit(0);`进行退出，就相当于不执行最后一行代码。但是，更优雅的方法显然是`return 0;`.

# 可以在哪看到这系列文章

我在我的[GitHub](https://github.com/Evian-Zhang/Assembly-on-macOS)上，[知乎专栏](https://zhuanlan.zhihu.com/c_1132336120712765440)上和[CSDN](https://blog.csdn.net/EvianZhang)上同步更新。

上一篇文章：[macOS上的汇编入门（十）——再探函数](macOS上的汇编入门（十）——再探函数.md)

