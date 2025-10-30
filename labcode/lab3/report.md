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

    .globl __trapret
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
