## <center>Lab3实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
---

### 一、练习1：分配并初始化一个进程控制块

我们的任务是要为类型为``struct proc_struct``的``proc``进行初始化，首先我们转到``struct proc_struct``的定义，在``proc.h``：

```c
struct proc_struct
{
    enum proc_state state;        // Process state
    int pid;                      // Process ID
    int runs;                     // the running times of Proces
    uintptr_t kstack;             // Process kernel stack
    volatile bool need_resched;   // bool value: need to be rescheduled to release CPU?
    struct proc_struct *parent;   // the parent process
    struct mm_struct *mm;         // Process's memory management field
    struct context context;       // Switch here to run process
    struct trapframe *tf;         // Trap frame for current interrupt
    uintptr_t pgdir;              // the base addr of Page Directroy Table(PDT)
    uint32_t flags;               // Process flag
    char name[PROC_NAME_LEN + 1]; // Process name
    list_entry_t list_link;       // Process link list
    list_entry_t hash_link;       // Process hash list
};
```

可以看到我们需要初始化的成员变量如上，参考指导书，我们可以完成相应的初始化工作：

- ``state``：进程状态，初始化为PROC_UNINIT
- ``pid``：进程ID，初始化为-1
- ``runs``：进程运行次数，初始化为0
- ``kstack``：内核栈地址，初始化为0
- ``need_resched``：是否需要调度，初始化为0
- ``parent``：父进程，初始化为NULL
- ``mm``：内存管理，初始化为NULL
- ``context``：上下文，初始化为0
- ``tf``：中断帧，初始化为NULL
- ``pgdir``：页目录表地址，初始化为boot_pgdir_pa，表示为内核页表的物理地址
- ``flags``：进程标志，初始化为0
- ``name``：进程名，初始化为0
- ``list_link``：进程链表，初始化为NULL
- ``hash_link``：进程哈希表，初始化为NULL

因此最后初始化结果为：

```c
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        proc->state = PROC_UNINIT;
        proc->pid = -1;
        proc->runs = 0;
        proc->kstack = 0;
        proc->need_resched = 0;
        proc->parent = NULL;
        proc->mm = NULL;
        memset(&proc->context, 0, sizeof(struct context));
        proc->tf = NULL;
        proc->pgdir = boot_pgdir_pa;
        proc->flags = 0;
        memset(proc->name, 0, sizeof(proc->name));
        
    }
    return proc;
}
```

到这里我们的初始化工作就完成了。

#### 问题解读

##### ``struct context context``含义与作用：

这里我们观察 ``context`` 的定义：
```c
struct context
{
    uintptr_t ra;
    uintptr_t sp;
    uintptr_t s0;
    uintptr_t s1;
    uintptr_t s2;
    uintptr_t s3;
    uintptr_t s4;
    uintptr_t s5;
    uintptr_t s6;
    uintptr_t s7;
    uintptr_t s8;
    uintptr_t s9;
    uintptr_t s10;
    uintptr_t s11;
};
```

可以看到，``context`` 是一个结构体，包含了 ``14`` 个 ``uintptr_t`` 类型的成员变量。这些成员变量分别对应了寄存器 ``ra``、``sp``、``s0`` 到 ``s11`` 的值，可用于在进程切换中还原之前的运行状态，在我们后面的``proc_run``函数里，我们就调用了``switch_to函数``：

```c
.text
# void switch_to(struct proc_struct* from, struct proc_struct* to)
.globl switch_to
switch_to:
    # save from's registers
    STORE ra, 0*REGBYTES(a0)
    STORE sp, 1*REGBYTES(a0)
    STORE s0, 2*REGBYTES(a0)
    STORE s1, 3*REGBYTES(a0)
    STORE s2, 4*REGBYTES(a0)
    STORE s3, 5*REGBYTES(a0)
    STORE s4, 6*REGBYTES(a0)
    STORE s5, 7*REGBYTES(a0)
    STORE s6, 8*REGBYTES(a0)
    STORE s7, 9*REGBYTES(a0)
    STORE s8, 10*REGBYTES(a0)
    STORE s9, 11*REGBYTES(a0)
    STORE s10, 12*REGBYTES(a0)
    STORE s11, 13*REGBYTES(a0)

    # restore to's registers
    LOAD ra, 0*REGBYTES(a1)
    LOAD sp, 1*REGBYTES(a1)
    LOAD s0, 2*REGBYTES(a1)
    LOAD s1, 3*REGBYTES(a1)
    LOAD s2, 4*REGBYTES(a1)
    LOAD s3, 5*REGBYTES(a1)
    LOAD s4, 6*REGBYTES(a1)
    LOAD s5, 7*REGBYTES(a1)
    LOAD s6, 8*REGBYTES(a1)
    LOAD s7, 9*REGBYTES(a1)
    LOAD s8, 10*REGBYTES(a1)
    LOAD s9, 11*REGBYTES(a1)
    LOAD s10, 12*REGBYTES(a1)
    LOAD s11, 13*REGBYTES(a1)

    ret
```

可以看到，``switch_to`` 函数的作用是将 ``from`` 进程的寄存器值保存到 ``from->context`` 中，然后将 ``to`` 进程的寄存器值从 ``to->context`` 中恢复到寄存器中，从而实现了进程的切换。

##### ``struct trapframe *tf``含义与作用：

同样的，我们先找到``struct tarpframe``的定义：

```c
struct trapframe
{
    struct pushregs gpr;
    uintptr_t status;
    uintptr_t epc;
    uintptr_t badvaddr;
    uintptr_t cause;
};
```

它保存了``32``个通用寄存器以及剩余的与中断异常处理相关的寄存器，当我们的进程发生中断或异常时，CPU会将当前的寄存器状态保存到``trapframe``中，以便在处理完中断或异常后恢复进程的运行状态，这就与我们的lab3相呼应了。

### 二、练习2：为新创建的内核线程分配资源

完成在kern/process/proc.c中的do_fork函数中的处理过程，简要说明设计实现过程。
请说明ucore是否做到给每个新fork的线程一个唯一的id？请说明你的分析和理由。

完整代码为
```c
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;

    if (nr_process >= MAX_PROCESS)
        goto fork_out;

    ret = -E_NO_MEM;

    // 1. 分配 PCB
    if ((proc = alloc_proc()) == NULL)
        goto fork_out;

    // 2. 分配内核栈
    if (setup_kstack(proc) != 0)
        goto bad_fork_cleanup_proc;

    // 3. 复制 mm 信息（内核线程不用处理）
    if (copy_mm(clone_flags, proc) != 0)
        goto bad_fork_cleanup_kstack;

    // 4. 设置 trapframe & context
    copy_thread(proc, stack, tf);

    // 5. 分配唯一 PID
    proc->pid = get_pid();

    // 6. 设置父进程
    proc->parent = current;

    // 7. 加入进程哈希表 & 全局链表
    list_add(&proc_list, &(proc->list_link));
    hash_proc(proc);

    // 8. 成为 RUNNABLE
    wakeup_proc(proc);

    nr_process++;

    ret = proc->pid;

fork_out:
    return ret;

bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}
```
具体过程是：

- 判断当前系统中进程数量是否已达上限 `(MAX_PROCESS)`，如果已达上限，直接返回错误码`-E_NO_FREE_PROC`。
```c
    if (nr_process >= MAX_PROCESS)
            goto fork_out;
```
- 调用 `alloc_proc` 分配一个新的进程控制块，用于存储新线程的基本信息。如果分配失败，则返回错误。
```c
    if ((proc = alloc_proc()) == NULL)
            goto fork_out;
```
- 使用 `setup_kstack` 为新进程分配独立的内核栈，以保证内核模式下执行上下文的安全性。分配失败则释放 PCB 并返回错误。
```c
    if (setup_kstack(proc) != 0)
            goto bad_fork_cleanup_proc;
```
- 调用 `copy_mm` 将原进程的内存管理信息复制到新进程中。但对于内核线程，该步骤通常不需要执行，保持空实现即可。
```c
    if (copy_mm(clone_flags, proc) != 0)
            goto bad_fork_cleanup_kstack;
```
- 调用 `copy_thread` 将原进程的 `trapframe` 和执行上下文复制到新进程中，保证新线程从正确的状态开始执行。
```c
    copy_thread(proc, stack, tf);
```
- 为新进程分配唯一的进程号 `(pid)` 并将当前进程设置为其父进程，建立父子进程关系。
```c
    proc->pid = get_pid();
    proc->parent = current;
```
- 将新进程加入系统的全局进程链表以及哈希表中，便于调度器管理和快速查找。
```c
    list_add(&proc_list, &(proc->list_link));
    hash_proc(proc);
```
- 调用 `wakeup_proc` 将新进程标记为 `RUNNABLE`，使其可以被调度器调度执行，同时增加全局进程计数 `nr_process`。
```c
    wakeup_proc(proc);
    nr_process++;
```
- 在任何分配失败的情况下，均会正确释放已分配的内核栈和 PCB，避免资源泄漏。
```c
    bad_fork_cleanup_kstack:
        put_kstack(proc);
    bad_fork_cleanup_proc:
        kfree(proc);
```

do_fork 通过上述步骤实现了一个完整的内核线程创建过程，包括资源分配、上下文复制、进程列表管理以及调度准备，保证新线程能够独立、安全地运行。

**问题解答：**

- ucore做到了给每个新fork的线程一个唯一的id。

分析：

1. 在`do_fork`实现中，调用了`proc->pid = get_pid();`。`get_pid()`的作用就是返回一个尚未被使用的唯一 PID。

2. 找到的`get_pid`函数实现如下：
```c
static int
get_pid(void)
{
    static_assert(MAX_PID > MAX_PROCESS);
    struct proc_struct *proc;
    list_entry_t *list = &proc_list, *le;
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID)
    {
        last_pid = 1;
        goto inside;
    }
    if (last_pid >= next_safe)
    {
    inside:
        next_safe = MAX_PID;
    repeat:
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid)
            {
                if (++last_pid >= next_safe)
                {
                    if (last_pid >= MAX_PID)
                    {
                        last_pid = 1;
                    }
                    next_safe = MAX_PID;
                    goto repeat;
                }
            }
            else if (proc->pid > last_pid && next_safe > proc->pid)
            {
                next_safe = proc->pid;
            }
        }
    }
    return last_pid;
}
```
- 系统维护两个静态变量：`last_pid` 记录上一次分配的 PID，`next_safe` 记录所有大于 `last_pid` 的进程 PID 中最小的那个值，用作下一次查找 PID 时的冲突边界。每次分配时，PID 从 `last_pid + 1` 开始递增，如果超过 `MAX_PID` 则循环回 1。

- 在分配过程中，函数会遍历全局进程列表 `proc_list`，检查 `last_pid` 是否已经被占用。若已占用，则自增 `last_pid` 并重新检查，直到找到未使用的 PID。

- `next_safe` 用于加速查找未使用的 PID，记录列表中比 `last_pid` 大的最小 PID，从而避免重复扫描整个列表。

- 当找到一个未被任何进程占用的 PID 时，返回该值并分配给新进程。由于在分配前对整个进程列表进行了检查，系统保证每个 PID 在当前所有进程中都是唯一的。


3. 每个新 `fork` 的线程都会走 `do_fork` 流程，都会调用 `get_pid()`，将新进程加入全局链表后才可被调度，保证了 PID 在系统中始终唯一。

### 三、练习3：编写proc_run 函数

本练习要求我们实现并理解 `proc_run` 的行为：把指定进程 `proc` 切换到 CPU 上运行。下面给出实现要点、代码说明以及关键机制的详细解释。

实现（参考 `kern/process/proc.c`）:

```c
void proc_run(struct proc_struct *proc)
{
        if (proc != current)
        {
                struct proc_struct *prev = current;
                bool intr_flag;

                /* 保存并关闭本地中断，保证下面的切换操作是原子的 */
                local_intr_save(intr_flag);

                /* 切换页表到将要运行进程的 pgdir*/
                lsatp(proc->pgdir);

                /* 更新调度器状态：current 指向新的进程，统计运行次数 */
                current = proc;
                proc->runs++;
                proc->need_resched = 0;

                /* 把 prev 的寄存器保存到 prev->context，并把 proc 的 context 恢复到寄存器中。 */
                switch_to(&prev->context, &proc->context);

                /* 在新进程上下文中恢复中断使能为切换前的状态 */
                local_intr_restore(intr_flag);
        }
}
```


- 先禁中断（`local_intr_save`）
    - 禁中断保证切换过程的原子性：在切换页表、更新 `current`、并调用 `switch_to` 之间不被异步中断打断，避免在不一致状态下发生中断处理或调度，防止竞态条件（例如中断处理依赖 `current` 或访问新旧页表）。
    - `local_intr_save` 会把当前中断使能状态保存到 `intr_flag`，并在需要时调用 `intr_disable()`。之后用 `local_intr_restore(intr_flag)` 恢复为先前状态，保证切换前后的中断策略一致。

- 切换页表（`lsatp(proc->pgdir)`）
    - RISC-V 的 `satp`（通过 `lsatp` 封装）决定当前地址翻译的根（页表基址）。当我们把 CPU 切到另一个进程时，必须使该进程的页表生效，否则访问虚拟地址会映射到错误的物理页或造成页故障。
    - 一般在修改 `satp` 后需要刷新 TLB，`lsatp`/对应实现通常会处理必要的刷新。如果不先设置页表，新进程在恢复用户/内核上下文并执行时可能遇到错误。


- 在本实现中我们在禁中断的保护下先更新 `current`，这样在 `switch_to` 调用期间（以及之后的任何函数）`current` 始终指向即将运行的进程，便于随后代码（或调试输出）使用 `current`。否则会在 `switch_to` 返回后再更新 `current`。关键是确保在整个窗口期不会出现中断导致 `current` 被不一致读取；所以必须禁中断或在架构允许的原子操作范围内调整顺序，用 `local_intr_save` 保证安全性。

- `runs` 用于统计该进程被调度执行的次数。
- `need_resched` 是进程的标志位，表示是否需要被调度。进入运行态后应清除该标志（它会在进程主动调用 `yield` 或被抢占时再次设置）。

- `switch_to` 的实现原理：
    - `switch_to`会把调用者（`prev`）的被保存寄存器（`ra, sp, s0..s11`）按偏移存入 `prev->context`，然后把 `proc->context` 中保存的寄存器值恢复到实际寄存器，从而在寄存器级别完成从一个上下文到另一个上下文的切换。
    - 注意：`switch_to` 只处理 callee-saved/必要寄存器，不负责恢复 `trapframe`（`tf`）中的用户态寄存器或程序计数，这通常由中断/陷阱返回路径负责。

- fork/创建线程时如何配合 proc_run：
    - 在 `do_fork`/`copy_thread` 中，新进程的 `context` 被初始化：`context.ra = forkret; context.sp = proc->tf`。这意味着当 `switch_to` 将 `proc->context` 恢复到寄存器后，执行流会从 `forkret` 开始（`ra` 恢复后执行 ret 到 `forkret`），`forkret` 会调用 `forkrets(current->tf)`，完成 fork 后的第一段内核执行（例如把返回值设置给子进程并最终返回到用户态或内核线程入口）。


总结：`proc_run` 的核心就是在一个受保护的、原子的上下文里完成三件事：切页表（确保地址空间正确）、更新 `current`（让系统知道谁在运行）、并调用 `switch_to`（保存/恢复寄存器完成实际的上下文切换）。在设计上需要同时小心中断与地址空间一致性，这些都是操作系统上下文切换的关键细节。


### 扩展练习Challenge


#### 1.说明语句local_intr_save(intr_flag);....local_intr_restore(intr_flag);是如何实现开关中断的？

首先我们找到相关的定义如下：

```c
static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
        intr_disable();
        return 1;
    }
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
    }
}

#define local_intr_save(x) \
    do {                   \
        x = __intr_save(); \
    } while (0)
#define local_intr_restore(x) __intr_restore(x);
```

这里又看到了它们分别调用了``intr_disable``和``intr_enable``函数，我们找到它们的定义如下：

```c
void intr_enable(void) { set_csr(sstatus, SSTATUS_SIE); }


void intr_disable(void) { clear_csr(sstatus, SSTATUS_SIE); }
```

这两个函数的作用分别是将``sstatus``寄存器值得``SIE``位设置为``1``或``0``，当``SIE``位为``1``时，表示允许中断，为``0``时，表示禁止中断。

当调用``local_intr_save(intr_flag)``时，会首先读取``sstatus``的值，并根据``SIE``位的值进行下一步操作，如果``SIE``为``1``，说明此时中断是可用的，我们就调用``intr_disable()``函数将``SIE``位设置为``0``，禁止中断，并将``intr_flag``赋值为``1``；如果``SIE``为``0``，说明此时已经屏蔽中断，就返回``0``并将``intr_flag``赋值为``0``。

当调用``local_intr_restore(intr_flag)``时，会根据``intr_flag``的值进行下一步操作，如果``intr_flag``为``1``，我们就调用``intr_enable()``函数将``SIE``位设置为``1``，允许中断；如果``intr_flag``为``0``，就不进行任何操作，返回``0``。


#### 2.深入理解不同分页模式的工作原理

##### get_pte()函数中有两段形式类似的代码， 结合sv32，sv39，sv48的异同，解释这两段代码为什么如此相像。

我们找到``get_pte()``的定义如下：

```c
pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create)
{
    pde_t *pdep1 = &pgdir[PDX1(la)];
    if (!(*pdep1 & PTE_V))
    {
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL)
        {
            return NULL;
        }
        set_page_ref(page, 1);
        uintptr_t pa = page2pa(page);
        memset(KADDR(pa), 0, PGSIZE);
        *pdep1 = pte_create(page2ppn(page), PTE_U | PTE_V);
    }
    pde_t *pdep0 = &((pte_t *)KADDR(PDE_ADDR(*pdep1)))[PDX0(la)];
    if (!(*pdep0 & PTE_V))
    {
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL)
        {
            return NULL;
        }
        set_page_ref(page, 1);
        uintptr_t pa = page2pa(page);
        memset(KADDR(pa), 0, PGSIZE);
        *pdep0 = pte_create(page2ppn(page), PTE_U | PTE_V);
    }
    return &((pte_t *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)];
}
```

我们的``get_pte()``作用是在函数的作用是在多级页表结构中，根据给定的虚拟地址 ``la`` 查找或创建对应的页表项，在之前的实验中，虚拟地址到物理地址的转换是通过多级页表逐层映射完成的，每一层页表负责从虚拟地址的一部分索引出下一层页表的物理地址，最终找到具体的物理页。

在``sv39``下，把页表项里从高到低三级页表的页码分别称作``PDX1``, ``PDX0``和``PTX``，第一级页目录通过 ``PDX1`` 找到二级页表的物理地址，第二级页表再通过 ``PDX0`` 找到最终的页表项。在函数中，我们首先判断当前页表项的有效位``V``是否为``1``，为``1``表示有效，已经存在下一层页表，则不需要进行任何操作，而如果无效，说明当前层还没有分配下一层页表，并且若``create``参数为``1``，则为它分配一个新的物理页。

这两段代码看起来类似，是因为我们每一层页表的处理逻辑基本一致，区别在于两次使用的索引不同，第一次为``PDX1``，第二次为``PDX2``，而对于其他更高的分页模式比如``sv48``来说，我们会有相应的更多层这样的逻辑，从而处理更多层的页表索引，但是处理逻辑基本类似。


##### 目前get_pte()函数将页表项的查找和页表项的分配合并在一个函数里，你认为这种写法好吗？有没有必要把两个功能拆开？

当我们传入的``create``参数为``0``时，我们就只能进行查找操作，而若``create``参数为``1``，我们如果查找不到就可以进行分配，因此查找和分配由``create``这个参数来决定，这样的实现相对简洁，并且逻辑直观，控制也比较方便，因此我们也没有必要拆开，而如果为了提升系统的安全性以及可维护性，也可以选择分别实现，但是这样会增加代码的复杂度。