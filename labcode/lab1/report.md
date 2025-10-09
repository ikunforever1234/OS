# Lab1实验报告

> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）


配置完成相应的环境后，进入``/labcode/lab1/``，在该环境下打开终端，输入``tmux``，在两个命令行窗格的前提下进行本次实验。

## 一、练习1

``la`` 是``load address``，``sp``是``栈指针寄存器（Stack Pointer）``，``bootstacktop``代表栈顶地址，与之相对的还有``bootstack``代表这一块栈空间的起始地址，因此，指令 ``la sp, bootstacktop`` 就是把预先分配好的 内核栈空间的顶端地址 装入寄存器 ``sp``，以后函数执行时，CPU 就知道在哪里存放局部变量、返回地址和寄存器备份了。

结合代码段分析
```ld
.section .data
    # .align 2^12
    .align PGSHIFT
    .global bootstack
bootstack:
    .space KSTACKSIZE
    .global bootstacktop
bootstacktop:
```

``bootstack``用来分配一块大小为 ``KSTACKSIZE`` 的内存，作为内核栈。``bootstacktop``位于这块内存的末尾，即“栈顶”。在进入函数``kern_init`` 前，必须设置栈指针 ``sp``，由于栈是由高地址向低地址增长的，所以将 ``sp`` 设置到 ``bootstacktop``，这样局部变量和调用压栈时就会从高地址往低地址存储。

查阅资料，``tail``是 RISC-V 的伪指令，用途相当于跳转指令``j``，表示无条件无返回跳转到内核 C 入口函数 ``kern_init``，开始执行内核初始化的逻辑。

## 二、练习2

在目录``/labcode/lab1/``下，使用``tmux``，按键``Ctrl+B、%``，左侧输入``make debug``，右侧输入``make gdb``，左侧debug暂时没有输出内容，右侧gdb输出内容如下：

```bash
│syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab1$ make gdb
│riscv64-unknown-elf-gdb \
│    -ex 'file bin/kernel' \
│    -ex 'set arch riscv:rv64' \
│    -ex 'target remote localhost:1234'
│GNU gdb (SiFive GDB-Metal 10.1.0-2020.12.7) 10.1
│Copyright (C) 2020 Free Software Foundation, Inc.
│License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
│This is free software: you are free to change and redistribute it.
│There is NO WARRANTY, to the extent permitted by law.
│Type "show copying" and "show warranty" for details.
│This GDB was configured as "--host=x86_64-linux-gnu --target=riscv64-unknown-elf".
│Type "show configuration" for configuration details.
│For bug reporting instructions, please see:
│<https://github.com/sifive/freedom-tools/issues>.
│Find the GDB manual and other documentation resources online at:
│--Type <RET> for more, q to quit, c to continue without paging--c
│    <http://www.gnu.org/software/gdb/documentation/>.
│
│For help, type "help".
│Type "apropos word" to search for commands related to "word".
│Reading symbols from bin/kernel...
│The target architecture is set to "riscv:rv64".
│Remote debugging using localhost:1234
│0x0000000000001000 in ?? ()
│(gdb) 
```

最后弹出的``0x0000000000001000 in ?? ()``说明我们的程序现在执行到地址``0x1000``，根据指导书所写，这里其实是 QEMU 内置的固件（BIOS）代码，还没执行到我们的内核，同时，这个说明我们的RISC-V 硬件加电后，从物理地址 ``0x1000`` 开始执行，是 OpenSBI 的入口指令。

### 1.硬件初始化和固件启动
根据指导书内容，QEMU 模拟的这款riscv处理器的复位地址是``0x1000``，所以 CPU 一上电就从 ``0x1000`` 开始执行指令。输入指令``x/5i $pc``，我们能够看到接下来即将执行的5条指令分别是：

```c
(gdb) x/5i $pc 
│=> 0x1000:      auipc   t0,0x0
    0x1004:      addi    a1,t0,32
    0x1008:      csrr    a0,mhartid
    0x100c:      ld      t0,24(t0)
    0x1010:      jr      t0
```

这里先将当前 ``PC`` 的高位写进``t0``寄存器，经过一系列运算后，从 ``t0+24`` 的内存中取一个地址，加载到 ``t0``，这一步就是从启动代码的数据区里取出一个函数指针，下一步就是无条件跳转到刚才t0保存的地址。下面我们使用指令``si``和``i r t0``开始单步调试，观察程序的执行过程以及``t0``寄存器的值变化：

```c
(gdb) si
0x0000000000001004 in ?? ()
(gdb) i r t0
t0             0x1000   4096
(gdb) si    
0x0000000000001008 in ?? ()
(gdb) i r t0
t0             0x1000   4096
(gdb) si    
0x000000000000100c in ?? ()
(gdb) i r t0
t0             0x1000   4096
(gdb) si    
0x0000000000001010 in ?? ()
(gdb) i r t0
t0             0x80000000       2147483648
(gdb) si    
0x0000000080000000 in ?? ()
```

回顾理论，在操作系统执行之前，必然有一个``bootloader``执行，把操作系统加载到内存，而在 QEMU 模拟的riscv计算机里，我们使用的是 QEMU 自带的``bootloader``: OpenSBI 固件，注意到我们跳转到地址``0x80000000``，那么在 Qemu 开始执行任何指令之前，首先要将作为 ``bootloader`` 的 ``OpenSBI.bin`` 加载到物理内存以物理地址 ``0x80000000`` 开头的区域上，以上我们就完成了这个任务，将控制权交给 OpenSBI 。

### 2.OpenSBI 初始化与内核加载

同样的方法，我们输入指令``x/10i 0x80000000``，可以查看在``0x80000000``附近的代码：

```c
(gdb) x/10i 0x80000000
│=> 0x80000000:  csrr    a6,mhartid
    0x80000004:  bgtz    a6,0x80000108
    0x80000008:  auipc   t0,0x0
    0x8000000c:  addi    t0,t0,1032
    0x80000010:  auipc   t1,0x0
    0x80000014:  addi    t1,t1,-16
    0x80000018:  sd      t1,0(t0)
    0x8000001c:  auipc   t0,0x0
    0x80000020:  addi    t0,t0,1020
    0x80000024:  ld      t0,0(t0)
```

以上列举了部分代码，这里持续运行，初始化处理器的运行环境，准备开始加载并启动操作系统内核， 将编译生成的内核镜像文件加载到物理内存的``0x80200000``地址处，就是我们说的内核第一条指令，将控制权移交内核。

这里我们输入指令``b *0x80200000``，在该位置添加断点，输出为：

```c
(gdb) b *0x80200000
Breakpoint 1 at 0x80200000: file kern/init/entry.S, line 7.
```

输入``c``，让程序执行到断点，右侧gdb输出如下：

```c
(gdb) c
Continuing.

Breakpoint 1, kern_entry () at kern/init/entry.S:7
7           la sp, bootstacktop
```

左侧debug输出如下：

```c
OpenSBI v0.4 (Jul  2 2019 11:53:53)
   ____                    _____ ____ _____ 
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | | 
        |_|
                        
Platform Name          : QEMU Virt Machine  
Platform HART Features : RV64ACDFIMSU             
Platform Max HARTs     : 8                    
Current Hart           : 0                   
Firmware Base          : 0x80000000        
Firmware Size          : 112 KB            
Runtime SBI Version    : 0.1              
                                           
PMP0: 0x0000000080000000-0x000000008001ffff (A) 
PMP1: 0x0000000000000000-0xffffffffffffffff (A,R,W,X)  
```

这说明我们的 OpenSBI 成功启动。

### 3.内核启动执行

输入``x/10i 0x80200000``，查看即将执行的一些汇编代码：

```py
(gdb) x/10i 0x80200000
|=> 0x80200000 <kern_entry>:     auipc   sp,0x3
    0x80200004 <kern_entry+4>:   mv      sp,sp
    0x80200008 <kern_entry+8>:   j       0x8020000a <kern_init>
    0x8020000a <kern_init>:      auipc   a0,0x3
    0x8020000e <kern_init+4>:    addi    a0,a0,-2
    0x80200012 <kern_init+8>:    auipc   a2,0x3
    0x80200016 <kern_init+12>:   addi    a2,a2,-10
    0x8020001a <kern_init+16>:   addi    sp,sp,-16
    0x8020001c <kern_init+18>:   li      a1,0
    0x8020001e <kern_init+20>:   sub     a2,a2,a0
```

注意到这里执行的就是``kern_entry``，那么为什么是``kern_entry``呢？以及为什么上面为什么要将内核加载到``0x80200000``处呢？

答案在我们的链接脚本``/labcode/lab1/tools/kernel.ld``中，有关代码如下：

```ld
OUTPUT_ARCH(riscv)
ENTRY(kern_entry)

BASE_ADDRESS = 0x80200000;
```

地址``0x80200000``由``BASE_ADDRESS``指定，``kern_entry``由``ENTRY``指定。这里可以与我们的练习1相结合，在练习1中我们提到一条无条件跳转指令``tail kern_init``，与之相呼应，我们这里的汇编代码也是执行完``kern_entry``以后直接执行``kern_init``。

结合``kern_init``详细代码：

```c
int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);

    const char *message = "(THU.CST) os is loading ...\n";
    cprintf("%s\n\n", message);
   while (1)
        ;
}
```

这里应该输出一行``(THU.CST) os is loading ...``后直接进入死循环。输入指令``b* kern_init``，在该位置设置断点，输入``c``，发现左侧debug的输出无变化，右侧gdb输出：

```c
(gdb) c
Continuing.

Breakpoint 4, kern_init () at kern/init/init.c:8
8           memset(edata, 0, end - edata);
```

继续输入``c``，左侧debug输出一行：

```c
(THU.CST) os is loading ...
```

右侧gdb进入无限循环。到这里我们的内核就运行完毕了。

#### 问题解读：

RISC-V 硬件加电后最初执行的几条指令位于地址``0x1000``到地址``0x1010``。

- ``0x1000: auipc   t0,0x0`` 这里``t0 = PC + (0 << 12)``，把当前PC的高20位装入``t0``。
- ``0x1004: addi    a1,t0,32`` 把``t0+32``的值赋给``a1``，即``0x1020``。
- ``0x1008: csrr    a0,mhartid`` 从控制状态寄存器里读出当前 CPU 核id，存入 ``a0``。
- ``0x100c: ld      t0,24(t0)`` 从内存``t0 + 24 = 0x1000 + 24 = 0x1018``并放回到``t0``。
- ``0x1010: jr      t0`` 跳转到 ``t0`` 指定的地址执行。


## 三、总结

##### 1.实验理论联系

- 硬件启动与固件阶段，QEMU 将复位向量地址设为 ``0x1000``，CPU 从这里取指执行；随后通过 ``ld t0, 24(t0)`` 和 ``jr t0`` 跳转启动 OpenSBI（位于 0x80000000） ，再由 OpenSBI 负责加载内核至 `0x80200000`，最后将控制权移交内核。这与对应的操作系统加载启动的原理相同，同时可以类比个人计算机的开机过程，类似于 x86 体系中的 BIOS 或 UEFI，不同之处在于，RISC-V 采用了标准化的 OpenSBI 固件，而 x86 体系依赖厂商特定实现。

- 实验中使用 ``csrr    a0,mhartid`` 获取 CPU 核id，这个体现出在后续学习中会有多核处理器的情况，需要利用核id进行区分，在实验中直观感受到核id被传递给操作系统内核，而在理论学习里会涉及到利用多核对任务进行调度。

- 实验中的内核入口，链接脚本部分展示了操作系统镜像的构建过程，通过 `kernel.ld` 指定 `kern_entry` 为入口点，并将内核基址固定在 `0x80200000` 处，使内核能够在启动后正确执行。链接脚本在此起到关键作用，它将操作系统原理中关于可执行文件段布局与地址分配的理论概念具体化。

- 在栈初始化部分，实验通过 `la sp, bootstacktop` 设置内核栈顶，并利用 `.space KSTACKSIZE` 指令静态分配栈空间，体现了内核启动时必须先建立栈结构以支持函数调用的原理。与完整操作系统不同，实验中仅使用了单一静态内核栈，而操作系统原理中栈的分配通常与进程或线程管理动态关联。

- 通过 `tail kern_init` 指令实现从汇编到 C 语言的过渡，完成控制权移交，体现了启动阶段从底层硬件配置到高级语言环境的自然衔接。
##### 2.实验未涉及

- 实验中只有内核启动，没有进程的创建和调度，当然也就没有进程间的通信，系统中仅运行单一循环程序。

- 虚拟内存管理是现代操作系统的核心，但实验仅基于物理地址访问，未实现页表与地址映射；

- 这一次实验没有引入中断与异常处理，缺乏对硬件交互的支持。

- 由于最后初始化文件相对较为简单，只输出一行文字，因此不涉及磁盘文件读写的部分。

- 此外，文件系统、设备驱动、系统调用机制、用户态与内核态隔离等操作系统的重要组成部分在实验中均未涉及。这一次的实验更接近于“引导程序”而非完整的操作系统实现，后续实验考虑这些实现多任务处理、安全隔离及用户程序交互的模块。