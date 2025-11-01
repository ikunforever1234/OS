## <center>Lab3实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
---

### 一、练习1：完善中断处理

首先定义一个计数器``count``来统计打印次数，之后声明一下``sbi_shutdown()``函数，这个函数在``sbi.c``文件里已经实现。
```c
static uint64_t count = 0;
extern void sbi_shutdown(void);
```

接下来是具体实现。
```c
clock_set_next_event();
            
ticks++;
if (ticks == 100) {
    print_ticks();
    count++;
    ticks = 0;
}
if (count >= 10) {
    sbi_shutdown();
}
break;
```

首先调用``clock_set_next_event()``设置下次时钟中断时间为当前时钟周期加一个时间基准``timebase``，然后``ticks``加一，如果``ticks``等于``100``，则打印``ticks``，并将``count``加一，同时将``ticks``置零，如果``count``大于等于``10``，则调用``sbi_shutdown()``关机。

```c
static uint64_t timebase = 100000;
void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
```

##### 定时器中断处理流程

注意到在``idt_init(void)``函数里的这几行：

```c
extern void __alltraps(void);

write_csr(stvec, &__alltraps);
```

这里我们设置将``stvec``寄存器的值为``__alltraps``函数的地址，而``stvec``寄存器的作用就是设置异常和中断的处理程序入口地址，这样当发生中断时，就会跳转到``__alltraps``函数里执行。而我们在``trapentry.S``文件里定义了``__alltraps``函数：

```assembly
    .globl __alltraps

__alltraps:
    SAVE_ALL

    move  a0, sp
    jal trap
    # sp should be the same as before "jal trap"

```

首先使用``SAVE_ALL``宏保存所有寄存器的值，``move a0, sp``将栈指针的值保存到 ``a0`` 寄存器中，之后跳转到``trap``函数执行。

```c
void trap(struct trapframe *tf) {
    // dispatch based on what type of trap occurred
    trap_dispatch(tf);
}
```

``trap``函数调用``trap_dispatch``函数，传入``trapframe``结构体指针``tf``，``trapframe``结构体里保存了异常或中断处理时所需的寄存器状态。

```c
static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
    }
}
```

之后判断是中断还是异常，如果``cause``小于``0``，意味着发生的是中断，则调用``interrupt_handler``函数，根据发生定时器中断时具体``cause``的值，跳转到``IRQ_S_TIMER``处执行。


### 二、扩展练习Challenge1：描述与理解中断流程

回答：描述ucore中处理中断异常的流程（从异常的产生开始），其中mov a0，sp的目的是什么？SAVE_ALL中寄寄存器保存在栈中的位置是什么确定的？对于任何中断，__alltraps 中都需要保存所有寄存器吗？请说明理由。

#### 1.ucore中处理中断异常的流程

- 异常中断产生阶段：
CPU在执行指令时检测到中断/异常事件，硬件自动把当前`PC`保存到`sepc`，把异常类型写入`scause`，然后根据`stvec`跳转到中断入口。

- 进入`__alltraps`汇编入口，保存上下文：
在内核初始化时，将该寄存器设置为`__alltraps`，CPU进入到`trapentry.S`中的`__alltraps`入口处。执行`SAVE_ALL`，将所有通用寄存器压栈，构造`trapframe`。接着执行`mv a0, sp`，把`trapframe`的地址（`sp`）传给C函数作为参数，将`sp`保存到`a0`中。

- 调用C层的`trap()`统一处理入口
汇编调用C函数`trap(tf)`。`trap()`调用`trap_dispatch(tf)`，根据`scause`判断类型：若为中断 → 调用`interrupt_handler(tf)`；若为异常 → 调用 `exception_handler(tf)`。

- 完成中断/异常的实际处理逻辑：
根据不同`case`，中断函数对中断(时钟中断、外设中断)等执行对应处理。异常函数对异常(系统调用、页错误、非法指令等)执行对应逻辑。处理完后返回到汇编层。

- 返回原执行点：
在`__trapret`中执行`RESTORE_ALL`，从`trapframe`恢复寄存器；接着执行`sret`指令，跳回`sepc`指向的位置继续执行原程序。



#### 2.mov a0，sp的目的
- RISC-V 调用约定（ABI）说明 `a0~a7`是用于传递函数参数的寄存器。而`trap`函数只有一个参数，是指向一个结构体的指针。
- 把当前的栈指针`sp`放入`a0`，作为参数传递给`trap()`后，由于在`SAVE_ALL`宏里，所有通用寄存器和部分`CSR`（如`sstatus`、`sepc`等）都已经被压入栈中，所以`sp`当前正好指向`struct trapframe`的起始地址。
- 因此`trap()`函数能够通过`a0`获取到保存的上下文数据（即`trapframe`），访问并处理所有中断或异常相关的寄存器状态，
#### 3.SAVE_ALL中寄存器保存在栈中的位置
- 在 RISC-V 架构的 `SAVE_ALL` 宏中，寄存器的保存顺序与 `struct pushregs`的字段声明顺序严格对应：首先将 32 个通用寄存器，从`zero`到`t6`，按结构体定义的顺序依次压入栈中，形成`gpr`部分；随后依次保存四个关键的`CSR`寄存器——`sstatus`、`sepc`、`stval`和`scause`，它们分别对应`trapframe`结构体中的`status`、`epc`、`badvaddr`和`cause`字段。
- 整个布局确保了栈上的内容可以直接被类型转换为`struct trapframe*`指针并进行访问，作为函数`trap`的参数的具体内容
- 在 RISC-V 的 `SAVE_ALL` 宏中，寄存器是从高地址向低地址方向保存的。
#### 4.__alltraps保存寄存器
- 对于任何中断，`__alltraps` 中需要保存所有寄存器.
- 中断处理会暂停当前程序的执行，修改寄存器的值，保存所有寄存器可以确保中断处理后准确恢复程序状态，防止寄存器值丢失或错误恢复。
- 另外，这些寄存器都是trap函数的一部分参数，不保存所有寄存器会导致函数参数不完整，如果修改参数的结构体定义则可以不保存所有寄存器（比如0寄存器）。

### 三、扩展练习Challenge2：理解上下文切换机制

#### 1.csrw sscratch, sp 和 csrrw s0, sscratch, x0 的操作
##### 操作流程：
1. **`csrw sscratch, sp`**
   - 将当前栈指针 `sp` 的值写入 `sscratch` 控制状态寄存器
   - 此时 `sscratch` 保存了进入异常前的栈指针

2. **`csrrw s0, sscratch, x0`**
   - 原子操作：读取 `sscratch` 的值到 `s0`，同时将 `x0`（恒为0）写入 `sscratch`
   - 效果：`s0` = 原栈指针，`sscratch` = 0

##### 设计目的：
- 在异常入口立即保存用户态（或之前上下文）的栈指针，避免调整栈指针后丢失原栈信息，把 `sscratch` 设为0作为"来自内核"的标志，用于检测嵌套异常，通过 `s0` 寄存器将原栈指针保存到异常栈帧的固定位置。

#### 2.为什么只保存不还原 stval、scause 等CSR寄存器

##### 寄存器特性分析：
- **stval (sbadaddr)**：存储异常相关的附加信息（如出错地址）
- **scause**：记录异常或中断的具体原因
- **sstatus**：包含处理器状态信息
- **sepc**：异常程序计数器，记录异常发生时的指令地址

##### 保存但不还原的原因：
- **信息寄存器与状态寄存器的区别**：
   - stval、scause 是**瞬时异常信息**，记录"发生了什么"
   - sstatus、sepc 是**程序状态**，记录"程序执行到哪里、处于什么状态"

- stval和scause等CSR寄存器记录的是异常事件的瞬时信息（如异常原因、出错地址），仅供异常处理程序诊断使用，不构成程序执行的连续状态。这些寄存器在每次异常时都由硬件自动更新，还原旧值既无意义又可能干扰后续异常处理，因此只需在异常入口保存以供当前处理使用，无需在异常返回时还原。


### 四、扩展练习Challenge3：完善异常中断

将异常处理的代码补全如下：
```c
        case CAUSE_ILLEGAL_INSTRUCTION:
             // 非法指令异常处理
             /* LAB3 CHALLENGE3   YOUR CODE :  */
            /*(1)输出指令异常类型（ Illegal instruction）
             *(2)输出异常指令地址
             *(3)更新 tf->epc寄存器
            */

            cprintf("Exception type: Illegal instruction\n");
            cprintf("Illegal instruction caught at 0x%lx\n", tf->epc);
            
            tf->epc += 4;
            break;
        case CAUSE_BREAKPOINT:
            //断点异常处理
            /* LAB3 CHALLLENGE3   YOUR CODE :  */
            /*(1)输出指令异常类型（ breakpoint）
             *(2)输出异常指令地址
             *(3)更新 tf->epc寄存器
            */

            cprintf("Exception type: breakpoint\n");
            cprintf("ebreak caught at 0x%lx\n", tf->epc);
            
            tf->epc += 2;
            break;
```

- 在触发非法指令异常时，输出异常类型和当前的指令地址，并更新``epc``寄存器令其加``4``，跳过当前无效的指令，继续执行下一条指令。
- 触发断点异常时，同样先输出异常类型和当前指令地址，之后跳过当前指令继续执行下一条，但是由于 ``ebreak`` 指令的长度通常是 ``2`` 字节，因此``epc``要加``2``。

之后在``kern_init()``函数里添加下面的两行，使其触发非法指令异常和断点异常。

```c
asm("mret");
asm("ebreak");
```

之后``make qemu``，输出内容如下：

```c
sbi_emulate_csr_read: hartid0: invalid csr_num=0x302
Exception type: Illegal instruction
Illegal instruction caught at 0xffffffffc0200098
Exception type: breakpoint
ebreak caught at 0xffffffffc020009c
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
100 ticks
```

说明我们的异常处理函数实现正确，到这里本次实验就完成了。


### 五、总结

本次实验与理论内容相比，有出入的点在于，在我们实际处理异常和中断的时候，往往会有多个处理程序，而不是像实验的代码中只是简单实现一个处理程序。

在我们的实验中，``stvec``寄存器指向的是一个处理程序的地址，在触发中断和异常时，直接固定运行这一个程序，但是在实践中它是指向一个中断向量表的地址，中断向量表里存放的是各个中断处理程序的地址，当发生中断时，CPU会根据中断类型，跳转到中断向量表里对应的处理程序。
