## <center>Lab5实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
---

### 一、练习0：填写已有实验

1. ``trap.c``中，根据注释，修改时钟中断处理，实现了时间片轮转调度，每次中断设置下一次时钟事件并更新系统滴答计数，当当前进程用完一个时间片后，通过设置 ``need_resched`` 标志请求调度器在安全时机进行进程切换。

    ```c
    case IRQ_S_TIMER:
            /* LAB5 GRADE   YOUR CODE :  */
            /* 时间片轮转： 
            *(1) 设置下一次时钟中断（clock_set_next_event）
            *(2) ticks 计数器自增
            *(3) 每 TICK_NUM 次中断（如 100 次），进行判断当前是否有进程正在运行，如
                果有则标记该进程需要被重新调度（current->need_resched）
            */
            
            clock_set_next_event();
            ticks++;

            if (ticks % TICK_NUM == 0) {
                if (current != NULL) {
                    current->need_resched = 1;
                }
            }
            break;
    ```

2. 维护进程间的父子与兄弟关系以及等待状态，在 ``alloc_proc`` 阶段补充对``wait_state`` 以及 ``cptr``、``yptr``、``optr`` 的初始化 ，避免新建进程带有未定义的等待状态或非法的关系指针，保证后面 ``do_fork``、``do_wait`` 和 ``do_exit`` 等的正确性。

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

            // LAB5 YOUR CODE : (update LAB4 steps)
            /*
            * below fields(add in LAB5) in proc_struct need to be initialized
            *       uint32_t wait_state;                        // waiting state
            *       struct proc_struct *cptr, *yptr, *optr;     // relations between processes
            */

            proc->wait_state = 0;
            proc->cptr = NULL;
            proc->yptr = NULL;
            proc->optr = NULL;
        }
        return proc;
    }
    ```

3. 在``do_fork``函数里提前设置子进程的 ``parent`` 并清零父进程的 ``wait_state``，将进程插入以及关系建立逻辑交给 ``set_links``，避免父进程处于等待状态导致阻塞。

    ```c
    int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
    {
        int ret = -E_NO_FREE_PROC;
        struct proc_struct *proc;
        if (nr_process >= MAX_PROCESS)
        {
            goto fork_out;
        }
        ret = -E_NO_MEM;

        if ((proc = alloc_proc()) == NULL)
            goto fork_out;

        proc->parent = current;
        current->wait_state = 0;
        
        if (setup_kstack(proc) != 0)
            goto bad_fork_cleanup_proc;

        if (copy_mm(clone_flags, proc) != 0)
            goto bad_fork_cleanup_kstack;

        copy_thread(proc, stack, tf);

        proc->pid = get_pid();

        hash_proc(proc);

        set_links(proc);

        wakeup_proc(proc);

        ret = proc->pid;

        // LAB5 YOUR CODE : (update LAB4 steps)
        // TIPS: you should modify your written code in lab4(step1 and step5), not add more code.
        /* Some Functions
        *    set_links:  set the relation links of process.  ALSO SEE: remove_links:  lean the relation links of process
        *    -------------------
        *    update step 1: set child proc's parent to current process, make sure current process's wait_state is 0
        *    update step 5: insert proc_struct into hash_list && proc_list, set the relation links of process
        */

    fork_out:
        return ret;

    bad_fork_cleanup_kstack:
        put_kstack(proc);
    bad_fork_cleanup_proc:
        kfree(proc);
        goto fork_out;
    }
    ```
<br>

### 二、练习1：加载应用程序并执行 （苏耀磊 2311727）

这里我们需要补充``load_icode``的第6步，建立相应的用户内存空间来放置应用程序的代码段、数据段等，且要设置好``proc_struct``结构中的成员变量``trapframe``中的内容，确保在执行此进程后，能够从应用程序设定的起始执行地址开始执行。

```c
    //(6) setup trapframe for user environment
    struct trapframe *tf = current->tf;
    // Keep sstatus
    uintptr_t sstatus = tf->status;
    memset(tf, 0, sizeof(struct trapframe));
    /* LAB5:EXERCISE1 YOUR CODE
     * should set tf->gpr.sp, tf->epc, tf->status
     * NOTICE: If we set trapframe correctly, then the user level process can return to USER MODE from kernel. So
     *          tf->gpr.sp should be user stack top (the value of sp)
     *          tf->epc should be entry point of user program (the value of sepc)
     *          tf->status should be appropriate for user program (the value of sstatus)
     *          hint: check meaning of SPP, SPIE in SSTATUS, use them by SSTATUS_SPP, SSTATUS_SPIE(defined in risv.h)
     */

    tf->gpr.sp = USTACKTOP;
    tf->epc = elf->e_entry;
    tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;

    ret = 0;
```

``load_icode``的前五步负责准备进程的用户地址空间：创建 ``mm``、建立页表、把 ``ELF`` 段映射并拷贝、创建用户栈、并切换到新页表，我们要补充的第6步为用户态重新设置好 ``trapframe``。

首先从 ``current->tf`` 读取并保存 ``sstatus``，之后清空整个``trapframe``，避免旧值的影响，之后设置``sp``指向用户栈顶，也就是 ``USTACKTOP`` ，这里是用户程序执行的基点，``epc``指向 ``ELF`` 的入口地址 ``elf->e_entry``，也就是用户程序执行的起始地址，``status`` 设置为 ``(sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE``，这里我们清除了 ``SSTATUS_SPP``，也就是将 ``SSTATUS`` 中的 ``SPP ``设置为 ``0``，表示进入用户态，同时将 ``SPIE`` 设置为 ``1``，表示允许中断。

<br>

##### 请简要描述这个用户态进程被ucore选择占用CPU执行（RUNNING态）到具体执行应用程序第一条指令的整个经过。


1. 在上个实验中，1号线程执行``init_main()``只用来输出一句话，而本次实验中，在``init_main()``中进一步使用``kernel_thread()``新建了一个内核进程，执行函数 ``user_main()``。
   ```c
    int pid = kernel_thread(user_main, NULL, 0);
   ```

2. 在``user_main()``中，调用了``kernel_execve()``，来加载程序 ``exit``，并在 ``user_main`` 这个进程里开始执行，这时 ``user_main`` 就从内核进程变成了用户进程。
    ```c
    #define __KERNEL_EXECVE(name, binary, size) ({           \
        cprintf("kernel_execve: pid = %d, name = \"%s\".\n", \
                current->pid, name);                         \
        kernel_execve(name, binary, (size_t)(size));         \
    })

    ......

    #define KERNEL_EXECVE2(x, xstart, xsize) __KERNEL_EXECVE2(x, xstart, xsize)

    // user_main - kernel thread used to exec a user program
    static int
    user_main(void *arg)
    {
    #ifdef TEST
        KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
    #else
        KERNEL_EXECVE(exit);
    #endif
        panic("user_main execve failed.\n");
    }
    ```
3. 下面是``kernel_execve()``的实现。
   ```c
   static int
    kernel_execve(const char *name, unsigned char *binary, size_t size)
    {
        int64_t ret = 0, len = strlen(name);
        //   ret = do_execve(name, len, binary, size);
        asm volatile(
            "li a0, %1\n"
            "lw a1, %2\n"
            "lw a2, %3\n"
            "lw a3, %4\n"
            "lw a4, %5\n"
            "li a7, 10\n"
            "ebreak\n"
            "sw a0, %0\n"
            : "=m"(ret)
            : "i"(SYS_exec), "m"(name), "m"(len), "m"(binary), "m"(size)
            : "memory");
        cprintf("ret = %d\n", ret);
        return ret;
    }
    ```
    用 ``ebreak`` 产生断点中断进行处理，跳转到``__alltraps``，继而跳转到``trap``，在``trap``中又会执行``trap_dispatch()``，根据``tf->cause``进入到``exception_handler()``分支的``CAUSE_BREAKPOINT``情形下，调用``syscall()``。

4. 在``syscall()``中，根据对应参数的值，来调用``sys_exec()``。
    ```c
    void
    syscall(void) {
        struct trapframe *tf = current->tf;
        uint64_t arg[5];
        int num = tf->gpr.a0;
        if (num >= 0 && num < NUM_SYSCALLS) {
            if (syscalls[num] != NULL) {
                arg[0] = tf->gpr.a1;
                arg[1] = tf->gpr.a2;
                arg[2] = tf->gpr.a3;
                arg[3] = tf->gpr.a4;
                arg[4] = tf->gpr.a5;
                tf->gpr.a0 = syscalls[num](arg);
                return ;
            }
        }
        print_trapframe(tf);
        panic("undefined syscall %d, pid = %d, name = %s.\n",
                num, current->pid, current->name);
    }
    ```
5. 在``sys_exec()``中，我们又调用了``do_execve()``，使用练习1中的``load_icode()``来加载程序。
    ```c
    static int
    sys_exec(uint64_t arg[]) {
        const char *name = (const char *)arg[0];
        size_t len = (size_t)arg[1];
        unsigned char *binary = (unsigned char *)arg[2];
        size_t size = (size_t)arg[3];
        return do_execve(name, len, binary, size);
    }

    int do_execve(const char *name, size_t len, unsigned char *binary, size_t size)
    {
        struct mm_struct *mm = current->mm;
        if (!user_mem_check(mm, (uintptr_t)name, len, 0))
        {
            return -E_INVAL;
        }
        if (len > PROC_NAME_LEN)
        {
            len = PROC_NAME_LEN;
        }

        char local_name[PROC_NAME_LEN + 1];
        memset(local_name, 0, sizeof(local_name));
        memcpy(local_name, name, len);

        if (mm != NULL)
        {
            cputs("mm != NULL");
            lsatp(boot_pgdir_pa);
            if (mm_count_dec(mm) == 0)
            {
                exit_mmap(mm);
                put_pgdir(mm);
                mm_destroy(mm);
            }
            current->mm = NULL;
        }
        int ret;
        if ((ret = load_icode(binary, size)) != 0)
        {
            goto execve_exit;
        }
        set_proc_name(current, local_name);
        return 0;

    execve_exit:
        do_exit(ret);
        panic("already exit: %e.\n", ret);
    }

    ```

6. 到这里我们就走到最深处了，现在一路返回到最开始调用的地方``__alltraps``，接着执行``__trapret``的``RESTORE_ALL``以及``sret``，退出内核态，进入用户态，开始执行应用程序的第一条指令。
    ```bash
        .globl __trapret
    __trapret:
        RESTORE_ALL
        # return from supervisor call
        sret
    ```

### 三、练习2: 父进程复制自己的内存空间给子进程（郭思达 2310688）

#### 1.`copy_range`的设计实现过程

创建子进程的函数`do_fork`在执行中将拷贝当前进程（即父进程）的用户内存地址空间中的合法内容到新进程中（子进程），完成内存资源的复制。具体是通过`copy_range`函数（位于kern/mm/pmm.c中）实现的，请补充`copy_range`的实现，确保能够正确执行。

完整代码为：
```c
int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end,
               bool share)
{
    assert(start % PGSIZE == 0 && end % PGSIZE == 0);
    assert(USER_ACCESS(start, end));
    // copy content by page unit.
    do
    {
        // call get_pte to find process A's pte according to the addr start
        pte_t *ptep = get_pte(from, start, 0), *nptep;
        if (ptep == NULL)
        {
            start = ROUNDDOWN(start + PTSIZE, PTSIZE);
            continue;
        }
        // call get_pte to find process B's pte according to the addr start. If
        // pte is NULL, just alloc a PT
        if (*ptep & PTE_V)
        {
            if ((nptep = get_pte(to, start, 1)) == NULL)
            {
                return -E_NO_MEM;
            }
            uint32_t perm = (*ptep & PTE_USER);
            // get page from ptep
            struct Page *page = pte2page(*ptep);
            // alloc a page for process B
            struct Page *npage = alloc_page();
            assert(page != NULL);
            assert(npage != NULL);
            int ret = 0;      
            // (1) 找到源页的内核虚拟地址
            void *src_kvaddr = page2kva(page);
            // (2) 找到目标页的内核虚拟地址
            void *dst_kvaddr = page2kva(npage);
            // (3) 复制一整页内容
            memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
            // (4) 将新页映射到进程 B 的页表中
            ret = page_insert(to, npage, start, perm | PTE_V);

            assert(ret == 0);
        }
        start += PGSIZE;
    } while (start != 0 && start < end);
    return 0;
}
```

`copy_range`函数以页Page为最小单位，在区间 `[start, end)` 内遍历父进程的用户虚拟地址空间，并将其中已映射的用户页复制到子进程中。具体来说，`copy_range`函数需要完成以下任务：

1. 遍历用户虚拟地址空间 

```c
do {
    ...
    start += PGSIZE;
} while (start != 0 && start < end);
```
函数通过循环以`PGSIZE`为步长递增 start，逐页扫描父进程的用户虚拟地址空间，这样可以确保所有用户页都被检查。

2. 查找父进程页表项
```c
pte_t *ptep = get_pte(from, start, 0), *nptep;
```
- 使用`get_pte(from, start, 0)`在父进程页表中查找虚拟地址`start`对应的页表项。
- 若该地址所在的页目录项不存在，说明这一整段虚拟地址区间均未映射。
```c
if (ptep == NULL) {
    start = ROUNDDOWN(start + PTSIZE, PTSIZE);
    continue;
}
```
此时直接跳过当前页目录项覆盖的地址范围，避免对未映射区域做无效处理。

3. 检查页表项是否有效
```c
if (*ptep & PTE_V) 
```
通过检查页表项中的`PTE_V（Valid）`位，判断该虚拟页是否为合法映射页。只有有效页才需要被复制到子进程。

4. 为子进程准备页表项
```c
if ((nptep = get_pte(to, start, 1)) == NULL) {
    return -E_NO_MEM;
}
```
- 调用 `get_pte(to, start, 1)` 在子进程页表中获取，新建对应的页表项。
- 若页表分配失败，说明系统内存不足，函数返回错误

5. 分配新的物理页
```c
struct Page *page = pte2page(*ptep);
struct Page *npage = alloc_page();
```
- 使用 `pte2page(*ptep)` 获取父进程虚拟地址`start`对应的物理页。
- 调用 `alloc_page()` 为子进程分配新的物理页。`npage`用于存放复制后的内容。

为子进程分配新的物理页，保证父子进程之间的内存相互独立。

6. 复制页内容
```c
void *src_kvaddr = page2kva(page);
void *dst_kvaddr = page2kva(npage);
memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
```
- 使用 `page2kva` 将物理页转换为内核虚拟地址
- 通过 `memcpy`将父进程页中的内容完整复制到子进程的新页中

这一步实现了物理页内容的深拷贝。

7. 建立子进程页表映射
```c
uint32_t perm = (*ptep & PTE_USER);
ret = page_insert(to, npage, start, perm | PTE_V);
```

- 从父进程页表项中继承用户态访问权限

- 调用 `page_insert`，在子进程页表中建立虚拟地址 `start` 到新物理页 `npage` 的映射

- 设置 `PTE_V`，保证该页在`RISC-V` 架构下是有效页。


至此，`copy_range`函数完成了父进程用户内存地址空间到子进程的复制。父子进程拥有相同的虚拟地址布局，每个用户页对应独立的物理内存，子进程对内存的修改不会影响父进程，采用了非 **Copy-on-Write** 的深拷贝策略。


#### 2.如何设计实现Copy on Write机制？给出概要设计，鼓励给出详细设计。

> Copy-on-write（简称COW）的基本概念是指如果有多个使用者对一个资源A（比如内存块）进行读操作，则每个使用者只需获得一个指向同一个资源A的指针，就可以该资源了。若某使用者需要对这个资源A进行写操作，系统会对该资源进行拷贝操作，从而使得该“写操作”使用者获得一个该资源A的“私有”拷贝—资源B，可对资源B进行写操作。该“写操作”使用者对资源B的改变对于其他的使用者而言是不可见的，因为其他使用者看到的还是资源A。

答：

- 在传统的 fork 实现中，子进程会立即获得父进程用户空间的完整内存拷贝，这在大多数子进程随后执行 exec 的场景下会造成大量不必要的内存复制。
- COW 的核心思想是：在 fork 阶段仅复制页表，而不复制实际的物理内存页。

在采用 COW 机制时，父进程和子进程最初共享同一组物理页，并且这些页在页表中被统一标记为只读状态。只要进程只对这些内存页进行读操作，系统就不需要进行任何额外处理，实现内存页的安全共享，减少内存占用和fork的时间开销。

当父进程或子进程试图对共享页进行写操作时，由于页表中禁止写权限，会触发一次**写保护异常**。内核在异常处理过程中检测到该异常属于COW场景后，会为当前进程分配一个新的物理页，并将原共享页的内容复制到新页中，然后更新页表，使**当前进程指向新的私有页并恢复写权限**，而***其他进程仍然保持对原物理页的只读共享**。

通过这种方式，系统实现了“写时复制”，在保证进程隔离性的同时提高了整体性能。


### 四、练习3：fork/exec/wait/exit 的实现分析 （吴行健 2310686）

1) 执行流程概述

- 用户发起系统调用（用户）
    - 由用户库函数或应用直接调用系统调用封装（例如 `syscall` 封装，产生 `ecall`/`ebreak` 指令）。这一步在用户态完成，仅设置好寄存器参数并执行陷入指令。

- 进入内核（陷入/陷阱处理，内核态）
    - 异常向量 `__alltraps`（见 `kern/trap/trapentry.S`）保存上下文并跳转到 `trap`/`trap_dispatch`（见 `kern/trap/trap.c`）。
    - 在 `trap` 中根据 `tf->gpr.a0`（系统调用号）调用 `syscall()`（见 `kern/syscall/syscall.c`）完成系统调用分发。

- `fork` 的内核处理（`sys_fork` / `do_fork`，见 `kern/process/proc.c`）
    - 分配子进程结构 `alloc_proc()`、设置 `parent`、分配内核栈 `setup_kstack()`。
    - 复制或共享用户内存：调用 `copy_mm()` → `dup_mmap()` → `copy_range()`（见 `kern/mm/pmm.c`），按实现选择深拷贝或共享(COW)策略，涉及页表操作（`get_pte`、`page_insert`、`alloc_page` 等）。
    - 复制寄存器/陷阱帧上下文：`copy_thread()` 设置子进程的 trapframe，使得子进程在返回时 `a0=0`（fork 在子进程返回0）。父进程返回子 pid（通过修改父的 trapframe 的返回值寄存器）。
    - 建立进程链表/哈希并唤醒子进程（`hash_proc`、`set_links`、`wakeup_proc`）。

- `exec` 的内核处理（`sys_exec` / `do_execve` / `load_icode`）
    - `sys_exec` 调 `do_execve`，若当前进程已有 `mm` 则可能先释放其旧地址空间（`exit_mmap`/`mm_destroy`）。
    - 调 `load_icode` 加载 ELF：建立新的 `mm`、创建/切换页表（`lsatp`/`put_pgdir`）、把程序段 `p->vaddr` 映射并拷贝到物理页、建立用户栈、最后设置 `current->tf` 中的 `gpr.sp`（用户栈顶）、`epc`（入口点）和 `status`（清 SPP、置 SPIE）以便内核返回后直接进入用户程序的第一条指令。

- `wait` / `exit` 的交互（等待与终结）
    - `do_exit`：释放资源（文件、内存等），设置进程状态为 `PROC_ZOMBIE`，记录退出码并唤醒父进程（若父在 `wait` 阻塞）。
    - `do_wait`：若没有已退出的子进程则将父进程置为等待状态（睡眠），直到被 `wakeup`（子进程退出或信号）唤醒，唤醒后 `do_wait` 取得子进程退出码并回收子进程资源（从 `hash`/链表移除、释放内存）。

2) 哪些操作在用户态完成，哪些在内核态完成？

- 用户态完成：
    - 系统调用参数的准备（把参数放入寄存器或堆栈）、调用 `ecall/ebreak` 指令触发陷入、接收系统调用的返回值并继续执行用户代码。

- 内核态完成：
    - 系统调用的实际处理（`sys_*` / `do_*` 系列），包括分配/回收内核数据结构、页表操作（映射/复制/解除映射）、创建/销毁进程结构、调度决策、阻塞/唤醒、以及对返回值的设置。

3) 内核态与用户态如何交错执行？内核态如何返回结果给用户？

- 交错模型：当用户执行 `ecall`/异常时，处理器保存用户上下文并切换到内核栈与内核态（`trapentry.S` 的 `SAVE_ALL`），此后内核以当前进程的上下文在内核态执行系统调用处理。内核可能在处理中发生调度（调用调度器让出 CPU），于是其他进程在用户/内核态运行。处理完毕后内核把结果写回到当前进程的 `trapframe`（例如 `tf->gpr.a0` 保存返回值），调用 `RESTORE_ALL` 并执行 `sret` 返回用户态，用户程序继续执行并在寄存器中看到返回值。

- 返回机制（代码层面）：系统调用处理函数通过修改 `current->tf`（或 `trapframe *tf`）里的通用寄存器字段来设置系统调用返回值（常见为 `tf->gpr.a0`），然后通过 `__trapret`/`RESTORE_ALL` 恢复寄存器并执行 `sret` 跳回用户态；因此用户态在 `ecall` 之后看到的就是 `a0` 中的返回值。

4) 进程执行状态生命周期图（简要 ASCII 图）

状态集合：UNINIT -> RUNNABLE -> RUNNING -> SLEEPING/WAITING -> ZOMBIE -> EXIT(回收)

流程示意：

```
 [NEW/UNINIT] --(alloc_proc/do_fork)--> [RUNNABLE]
            |                                   |
            |                                   v
            |                                schedule
            |                                   |
            v                                   v
     (直接exec)                        [RUNNING] --(block: wait/read/sleep)--> [SLEEPING]
            |                                   ^                                          |
            |                                   |              (wakeup/event)             v
            +--(do_execve, replace mm)--> [RUNNING] <---------------------------------- [RUNNABLE]
                                                                                                            |
                                                                                                            v
                                                                                             (do_exit) -> [ZOMBIE] --(parent do_wait)--> [EXIT/资源回收]
```

关键事件与对应函数：
- fork: `do_fork()` 创建子进程 -> 子进程进入 `RUNNABLE`（由 scheduler 选中后 RUNNING）
- exec: `do_execve()` 在当前进程上下文替换用户地址空间并设置 `trapframe`（仍为 RUNNING）
- wait: `do_wait()` 若无已退出子进程则父进程 sleep（SLEEPING），当子 `do_exit()` 唤醒父进程后继续并回收子进程资源
- exit: `do_exit()` 设置为 ZOMBIE 并唤醒父进程，等待 `do_wait()` 回收

5) 总结

- 用户态负责发起系统调用与处理返回值，内核态负责实际的资源管理、内存/页表操作以及调度与同步。
- 内核通过保存/修改进程的 `trapframe`（寄存器上下文）并执行 `sret` 把执行权和结果返回给用户程序。
- 在源码中，相关主干函数和文件为：
    - `kern/trap/trapentry.S`（上下文保存/恢复、`__alltraps`、`__trapret`、`forkrets`）
    - `kern/trap/trap.c`（异常/中断分发、`exception_handler`）
    - `kern/syscall/syscall.c`（系统调用分发与 `sys_*`）
    - `kern/process/proc.c`（`do_fork`、`copy_thread`、`do_execve`、`load_icode`、`do_exit`、`do_wait`）
    - `kern/mm/pmm.c`（`copy_range`、页表/页操作）


<br>

完成上面的内容后，我们执行``make grade``，得到以下结果，说明实验验证成功。

```c
badsegment:              (1.0s)
  -check result:                             OK
  -check output:                             OK
divzero:                 (1.0s)
  -check result:                             OK
  -check output:                             OK
softint:                 (1.0s)
  -check result:                             OK
  -check output:                             OK
faultread:               (91.1s)
  -check result:                             OK
  -check output:                             OK
faultreadkernel:         (91.0s)
  -check result:                             OK
  -check output:                             OK
hello:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
testbss:                 (91.1s)
  -check result:                             OK
  -check output:                             OK
pgdir:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
yield:                   (1.0s)
  -check result:                             OK
  -check output:                             OK
badarg:                  (1.0s)
  -check result:                             OK
  -check output:                             OK
exit:                    (1.0s)
  -check result:                             OK
  -check output:                             OK
spin:                    (4.0s)
  -check result:                             OK
  -check output:                             OK
forktest:                (1.0s)
  -check result:                             OK
  -check output:                             OK
Total Score: 130/130
```

### 五、扩展练习 Challenge （吴行健 2310686）
#### 1.COW
核心思路是在 fork 阶段仅复制页表，而不复制实际的物理内存页，父子进程最初共享同一组物理页，并将这些页在页表中标记为只读。

当任一进程试图对共享页进行写操作时，会触发写保护异常。内核在异常处理中识别该异常属于 COW 场景后，会为当前进程分配新的物理页，复制原页内容，更新页表指向新页并恢复写权限，而其他进程仍保持对原物理页的只读共享。
```c
int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end,
               bool share) {
    assert(start % PGSIZE == 0 && end % PGSIZE == 0);
    assert(USER_ACCESS(start, end));
    do {
        pte_t *ptep = get_pte(from, start, 0), *nptep;
        if (ptep == NULL) {
            start = ROUNDDOWN(start + PTSIZE, PTSIZE);
            continue;
        }
        if (*ptep & PTE_V) {
            if ((nptep = get_pte(to, start, 1)) == NULL) {
                return -E_NO_MEM;
            }
            uint32_t perm = (*ptep & PTE_USER);
            struct Page *page = pte2page(*ptep);
            int ret = 0;

            if (share) {
                // COW 机制：物理页面共享，并设置两个 PTE 为只读
                // 这样可以避免不必要的引用计数操作
                // 首先，清除父进程页表的写权限
                *ptep = (*ptep) & ~PTE_W;
                // 然后，设置子进程页表项为只读
                *nptep = (*ptep);
                
                // 增加页面的引用计数（因为现在有两个进程共享这个页面）
                page_ref_inc(page);
                
                ret = 0;
            } else {
                // 原有深拷贝逻辑
                struct Page *npage = alloc_page();
                assert(page != NULL);
                assert(npage != NULL);
                uintptr_t *src = page2kva(page);
                uintptr_t *dst = page2kva(npage);
                memcpy(dst, src, PGSIZE);
                ret = page_insert(to, npage, start, perm);
            }
            assert(ret == 0);
        }
        start += PGSIZE;
    } while (start != 0 && start < end);
    return 0;
}
```

- share 为 true 时：

我们直接操作页表项，而不是通过 page_insert 函数。这样做的好处是可以精确控制页表项的权限设置。首先，清除父进程页表中对应页表项的写权限位（PTE_W），使其变为只读。然后，将子进程的页表项设置为与父进程相同的值（同样是只读）。增加物理页面的引用计数，表示现在有两个进程共享这个页面。

- share 为 false 时：
保持原有的深拷贝逻辑不变，为子进程分配新的物理页并复制内容。

写保护异常处理：当进程尝试写入一个只读的 COW 页面时，会触发页错误异常。
在异常处理程序中，我们需要：检查是否为 COW 页面（通过检查页面引用计数是否大于1）,如果是 COW 页面，则为当前进程分配新的物理页,复制原页内容到新页,更新当前进程的页表项，指向新页并恢复写权限,减少原页面的引用计数。

#### 2.用户程序加载方式分析
##### 1> ucore 中的加载方式
ucore 中，用户程序通过 do_execve → load_icode 被一次性加载到内存中。具体过程包括：
解析 ELF 文件头、程序头表；为每个程序段（代码段、数据段等）分配物理页，并建立页表映射;将段内容从文件拷贝到对应的内存页中；
设置用户栈和 trapframe，准备执行。

在程序开始执行前，所有必需的代码和数据都已加载到物理内存中。这种方式的优点是实现简单，无需复杂的缺页异常处理机制，但缺点是启动时内存占用较大，且可能加载了程序实际不会使用的代码段。
##### 2>常见操作系统的加载方式
现代通用操作系统（如 Linux、Windows）普遍采用 懒加载（Lazy Loading） 机制：
execve 时仅建立虚拟地址空间布局，读取 ELF 头与程序头表，并设置好页表项，但不立即加载程序段内容；当程序执行到某个尚未加载的虚拟地址时，触发缺页异常（Page Fault）；在缺页异常处理程序中，内核从磁盘读取对应的页面到内存，并更新页表；该过程按需进行，只有实际访问的页面才会被加载。

- ucore 采用的一次性加载方式简化了内存管理，适合教学与嵌入式环境；而懒加载机制更适合通用操作系统，能显著提升系统整体性能与资源利用率。两种方式各有优劣，选择哪种取决于具体的应用场景和设计目标。

### 六、Lab2分支任务：gdb 调试页表查询过程 （苏耀磊 2311727）


首先我们按照指导书的内容，将原来的``makefile``脚本中的``QEMU``的地址换成我们重新编译过后的路径，之后开启三个终端，分别运行以下命令：

第一个终端T1执行如下，启动我们新编译的调试版``QEMU``，并暂停在初始状态：
```c
make debug
```

第三个终端T3执行如下，启动``gdb``，并连接到``T1``的``QEMU``：
```c
make gdb
```

这里我手动找到了加载页表基址的``satp``的汇编代码的地址为``0x80200034``，因此我们在这里添加断点，并执行：

```c
(gdb) b *0x80200034
Breakpoint 1 at 0x80200034
(gdb) c
Continuing.

Breakpoint 1, 0x0000000080200034 in ?? ()
(gdb) delete
```

执行到这里停下以后，我们删除之前设置的断点，除此之外，因为我们要观察的是虚拟地址被翻译为物理地址的过程，因此我们需要知道一条被确切执行的``load``或者``store``指令，经过一些不可思议的操作（痛苦地单步执行跟踪），我终于找到了一条可爱的``ld``指令 ``ld ra,8(sp)``，他的地址是``0xffffffffc02000c2``，我们在这里添加断点，并执行：

```c
(gdb) b* 0xffffffffc02000c2
Breakpoint 2 at 0xffffffffc02000c2: file kern/init/init.c, line 26.
(gdb) c
Continuing.

Breakpoint 2, 0xffffffffc02000c2 in print_kerninfo ()
```

那么此时，我们的程序只要再执行一步，就会进行虚拟地址的翻译了，在这个时候，我们需要在第二个终端``T2``来获取到``qemu``这个进行的``pid``，并使用``gdb``来调试这个``qemu``：

```c
pgrep -f qemu-system-riscv64

sudo gdb
```

进入``gdb``调试界面后，在一些可爱的与页表以及虚拟地址翻译的函数名处添加断点（来自gpt的数不清多少次尝试）：

```c
attach <pid>

b riscv_tr_translate_insn

b cpu_ldl_code

b tlb_index

b tlb_fill

b get_page_addr_code

b cpu_physical_memory_read

b cpu_physical_memory_write

b memory_region_dispatch_read

b memory_region_dispatch_write
```

然后我们可以查看已经设下的断点，并执行：

```c
info breakpoints

Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x00005621567b4a9c in riscv_tr_translate_insn at /home/syl/qemu-4.1.1/target/riscv/translate.c:796
2       breakpoint     keep y   0x00005621567a7fa2 in cpu_ldl_code at /home/syl/qemu-4.1.1/include/exec/cpu_ldst_template.h:114
3       breakpoint     keep y   <MULTIPLE>         
3.1                         y   0x00005621566fa754 in tlb_index at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
3.2                         y   0x00005621567a7e3a in tlb_index at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
4       breakpoint     keep y   0x00005621566fcb55 in tlb_fill at /home/syl/qemu-4.1.1/accel/tcg/cputlb.c:871
5       breakpoint     keep y   0x00005621566fd1a4 in get_page_addr_code at /home/syl/qemu-4.1.1/accel/tcg/cputlb.c:1025
6       breakpoint     keep y   <MULTIPLE>         
6.1                         y   0x00005621566d22e4 in cpu_physical_memory_read at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:77
6.2                         y   0x00005621566d8178 in cpu_physical_memory_read at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:77
--Type <RET> for more, q to quit, c to continue without paging--c
6.3                         y   0x00005621567276cb in cpu_physical_memory_read at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:77
6.4                         y   0x000056215690fb3d in cpu_physical_memory_read at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:77
7       breakpoint     keep y   <MULTIPLE>         
7.1                         y   0x00005621566d81a8 in cpu_physical_memory_write at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:82
7.2                         y   0x000056215690fb6d in cpu_physical_memory_write at /home/syl/qemu-4.1.1/include/exec/cpu-common.h:82
8       breakpoint     keep y   0x00005621566e70c0 in memory_region_dispatch_read at /home/syl/qemu-4.1.1/memory.c:1447
9       breakpoint     keep y   0x00005621566e730d in memory_region_dispatch_write at /home/syl/qemu-4.1.1/memory.c:1489

c
```

回到刚才的``T3``，还记得我们执行到一条``ld``指令，在这里我们继续单步执行：

```c
si
```

你可以很轻松的发现它卡住了，因为我们的``T2``触发了断点，``qemu``被中断了，于是我们又回到``T2``，一步一步输入``c``，看看到底会在哪些函数触发断点，just like this：

```c
[Switching to Thread 0x7f6695fff640 (LWP 20295)]

Thread 3 "qemu-system-ris" hit Breakpoint 5, get_page_addr_code (env=0x562158fb89a0, addr=18446744072637907138) at /home/syl/qemu-4.1.1/accel/tcg/cputlb.c:1025
1025        uintptr_t mmu_idx = cpu_mmu_index(env, true);
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 5, get_page_addr_code (env=0x562158fb89a0, addr=18446744072637907138) at /home/syl/qemu-4.1.1/accel/tcg/cputlb.c:1025
1025        uintptr_t mmu_idx = cpu_mmu_index(env, true);
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 1, riscv_tr_translate_insn (dcbase=0x7f6695ffe760, cpu=0x562158faff90) at /home/syl/qemu-4.1.1/target/riscv/translate.c:796
796         DisasContext *ctx = container_of(dcbase, DisasContext, base);
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 2, cpu_ldl_code (env=0x562158fb89a0, ptr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst_template.h:114
114         return glue(glue(glue(cpu_ld, USUFFIX), MEMSUFFIX), _ra)(env, ptr, 0);
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.

Thread 3 "qemu-system-ris" hit Breakpoint 3, tlb_index (env=0x562158fb89a0, mmu_idx=1, addr=18446744072637907138) at /home/syl/qemu-4.1.1/include/exec/cpu_ldst.h:166
166         uintptr_t size_mask = env_tlb(env)->f[mmu_idx].mask >> CPU_TLB_ENTRY_BITS;
(gdb) c
Continuing.
(gdb) 
```

那么触发的这些函数就是我们要关注的翻译过程了。

这里首先``get_page_addr_code`` 被触发，说明 ``QEMU`` 进入了页表/翻译相关的处理路径，紧接着调用了 ``tlb_index``，这表示 ``QEMU`` 在真正做页表访问前先查询软件 ``TLB``。``tlb_index`` 负责基于地址计算 ``TLB`` 索引并判断是否已有缓存的映射；若命中就可以跳过后续的页表走访，否则会回到翻译流程继续处理，之后第二次``get_page_addr_code`` 被触发，逐级读取页表条目并做有效性检查，从而得到 ``guest`` 的物理页基址或返回访问异常，随后你又观测到多次 ``tlb_index`` 的命中，说明 ``QEMU`` 在页表走访与 ``TLB`` 更新之间来回进行检查，可能读取并解析 ``PTE`` 后会尝试填表并再次确认缓存状态，或在译码/执行不同阶段重复检索。

随后命中 ``riscv_tr_translate_insn``，这表明 ``translator`` 层开始处理指令的取指与译码，触发对指令 ``PC`` 的读取，从而引出接下来的取指访问与相应的地址翻译路径，内部调用了 ``cpu_ldl_code`` ，发起对虚拟地址的读取（取指或数据读取），到这一步 ``QEMU`` 把具体的虚地址提交给 MMU/TLB 处理链，在 ``cpu_ldl_code`` 之后，``tlb_index`` 又被多次命中，显示出从 helper 发起访问到最终完成物理映射之间，``QEMU`` 在不同阶段持续进行 ``TLB`` 检测／填充与验证，最终路径会在 ``TLB`` 命中或页表走访并填表后转入物理内存读写阶段。

整个指令执行过程中囊括了完整的数据流过程``translator → helper → TLB 检查 → 页表走访 → TLB 填充 → 物理访问/返回或异常``。

##### 下面我们来看看页表翻译的过程

页表翻译主要是在这个函数 ``get_page_addr_code`` ，它的源码如下：

```c
tb_page_addr_t get_page_addr_code(CPUArchState *env, target_ulong addr)
{
    uintptr_t mmu_idx = cpu_mmu_index(env, true);
    uintptr_t index = tlb_index(env, mmu_idx, addr);
    CPUTLBEntry *entry = tlb_entry(env, mmu_idx, addr);
    void *p;

    if (unlikely(!tlb_hit(entry->addr_code, addr))) {
        if (!VICTIM_TLB_HIT(addr_code, addr)) {
            tlb_fill(env_cpu(env), addr, 0, MMU_INST_FETCH, mmu_idx, 0);
            index = tlb_index(env, mmu_idx, addr);
            entry = tlb_entry(env, mmu_idx, addr);
        }
        assert(tlb_hit(entry->addr_code, addr));
    }

    if (unlikely(entry->addr_code & (TLB_RECHECK | TLB_MMIO))) {
        /*
         * Return -1 if we can't translate and execute from an entire
         * page of RAM here, which will cause us to execute by loading
         * and translating one insn at a time, without caching:
         *  - TLB_RECHECK: means the MMU protection covers a smaller range
         *    than a target page, so we must redo the MMU check every insn
         *  - TLB_MMIO: region is not backed by RAM
         */
        return -1;
    }

    p = (void *)((uintptr_t)addr + entry->addend);
    return qemu_ram_addr_from_host_nofail(p);
}
```

这个函数首先先确定当前访问属于哪个 ``MMU`` 索引，然后用 ``tlb_index``/``tlb_entry`` 找到软件 ``TLB`` 中对应的槽，如果 ``TLB`` 未命中，尝试用 ``VICTIM_TLB_HIT`` 或填表，若映射可直接映射为 ``RAM`` 指针则返回该 ``host`` 指针，否则返回 ``-1`` 。

里面涉及到的``tlb_fill``函数如下：

```c
static void tlb_fill(CPUState *cpu, target_ulong addr, int size,
                     MMUAccessType access_type, int mmu_idx, uintptr_t retaddr)
{
    CPUClass *cc = CPU_GET_CLASS(cpu);
    bool ok;

    /*
     * This is not a probe, so only valid return is success; failure
     * should result in exception + longjmp to the cpu loop.
     */
    ok = cc->tlb_fill(cpu, addr, size, access_type, mmu_idx, false, retaddr);
    assert(ok);
}
```
它是是负责触发页表翻译和填充 ``TLB`` 的核心函数，调用 ``CPUClass`` 中的架构和CPU特定的 ``tlb_fill`` 实现去完成实际的页表翻译和 ``TLB`` 条目填充，并用 ``assert(ok)`` 确保填充成功。

##### 问题：qemu中模拟出来的tlb和我们真实cpu中的tlb有什么逻辑上的区别？

- 真实的``TLB``是硬件实现，直接嵌入`` CPU ``内部，有特定的并行访问逻辑和替换策略，在更新时硬件自动管理替换，``TLB miss`` 会触发硬件或异常处理机制，由硬件自动完成页表翻译和 ``TLB`` 更新，并返回物理地址。

- QEMU 中的软件 ``TLB`` 是纯软件实现，没有硬件并行处理和替换策略，由软件模拟 ``TLB`` 的行为，访问是通过函数查找，``TLB miss`` 时调用函数去查页表，然后更新模拟的 ``TLB`` 数据结构，并返回物理地址。（这里gpt所说``QEMU``可以灵活模拟，例如标记某些条目为 ``TLB_RECHECK`` 或 ``TLB_MMIO``，表示需要每条指令重新检查或非 ``RAM`` 区域，这在硬件中需要特殊处理。）

<br>

在调试过程中，我第一次能够实际看到，每条 ``load``/``store`` 指令如何触发虚拟地址检查，指令地址如何触发 ``get_page_addr_code()``，``TLB`` 命中与否如何通过软件的 ``tlb_hit() ``体现，``TLB miss`` 后如何调用 ``tlb_fill()``以及页表是如何一步步被遍历的等等，并且也能理解到，``QEMU`` 中的软件 ``TLB`` 是如何模拟硬件 ``TLB`` 的行为，以及如何处理 ``TLB miss`` 和页表访问的。

这里在我阅读指导书，大概搞清楚任务是什么后，我大概询问了gpt应该如何得到翻译过程，以及应该在哪里添加断点，因为函数命名的问题，我在不断试错，询问可能的函数名n次后，终于得到了正确的断点位置，这里附上部分提问提示词：

```
我现在拥有一套ucore的实验框架，现在我想观察到虚拟地址被翻译到物理地址的具体过程，这个操
作需要我有一个可调试的qemu，以及开启三个终端，第一个终端执行make debug，第二个终端用来
找到正在运行的qemu的pid，从而使用gdb来单步调试它，第三个终端用来gdb调试ucore程序，也就
是说，第二个终端用来调试第三个终端，现在我想找到ucore中某条具体的load或者store指令来观
察他翻译虚拟地址的过程，我应该在哪些终端打上哪些断点，具体的指令执行顺序是什么，详细地告
诉我


你能否直接告诉我T2应该在哪些函数打断点，因为我的grep输出什么也没有


ok我现在的情况是，我的T3已经在一条sd指令处停止，只要执行si就执行这条指令。
T2建立了上面说的那些断点，但是还没有continue，那么我接下来应该怎样继续执行
能观察到虚拟地址翻译的过程，请告诉我每一个终端要操作的指令和顺序
```

### 七、lab5分支任务：gdb 调试系统调用以及返回 （郭思达 2310688）

这一次调试主要是为了使用同一套方案来观察操作系统中一个至关重要的机制——**系统调用的完整流程**。

#### 1.调试流程：

> 在大模型的帮助下，完成整个调试的流程，观察一下ecall指令和sret指令是如何被qemu处理的，并简单阅读一下调试中涉及到的qemu源码，解释其中的关键流程。


调试的总体思路是：

- 在用户态的用户库里内联汇编里的 ecall处让内核级 gdb 停下来；单步到 ecall 指令前。

- 在运行 QEMU 的终端（附着到 qemu 的 gdb）按 Ctrl-C，在 qemu-gdb 上设置断点（对应 qemu 中处理 ecall 的位置），继续运行 qemu。

- 让用户程序执行 ecall → qemu 在处理 ecall 的代码处停下，跟踪 qemu 如何“把异常/中断”（trap）处理成进入内核态的动作（包括 CSR 保存、PC 转跳、helper 调用等）。

- 在内核处理结束、将要返回用户态（sret）前同理：在用户态侧让内核停在 sret 前，切换到 qemu-gdb，打 sret 处理点断点并单步观察返回路径。


实验过程中同时使用三个终端：
> 一个终端通过 make debug 启动 QEMU 并开启 gdbstub；
第二个终端使用 make gdb 连接 QEMU，调试运行在其中的 RISC-V 内核及用户程序；
第三个终端使用宿主机 GDB（sudo gdb qemu-system-riscv64
）附加（使用attach命令）到 QEMU 进程本身，用于观察 QEMU 对 ecall 和 sret 指令的 TCG 翻译与执行过程。

环境准备的具体步骤如下：
1. 在终端一和终端二的lab5文件夹中分别输入`make debug`和`make gdb`命令，启动qemu和gdb调试。

2. 终端二，输入`set remotetimeout unlimited`命令，设置gdb的远程超时时间为无限大，避免因为qemu运行时间过长而导致gdb超时。

3. 终端三，`sudo gdb qemu-system-riscv64`
后，输入`attach 18809`命令，将gdb附加到qemu进程上，其中18809是qemu进程的pid。(注意：qemu进程的pid可能会因为每次运行而不同，需要根据实际情况修改，使用`pidof qemu-system-riscv64`命令。)

调试步骤：


1. 内核 GDB 默认没有用户程序符号，需要手动加载:
```
(gdb) add-symbol-file obj/__user_exit.out
(y or n) y
```
ELF 文件里定义了静态链接地址（0x800020），GDB 自动知道加载位置。现在的话GDB 可以识别用户程序函数了（syscall、exit 等）。

2. 在用户syscall处打上断点：
```
(gdb) break user/libs/syscall.c:18
```
或者直接使用汇编地址：
```
(gdb) break *0x800104
```
用户程序必须已加载到内存，否则会报`Cannot access memory`。如果报错，先让程序运行到用户程序入口：
```
(gdb) break *0x800020
(gdb) continue
```
当停在用户程序入口后，再打 `*0x800104` 就不会报错。

3. 单步执行 syscall 直到 ecall。（在这之前，先continue到断点syscall处）
```
(gdb) si
```
使用 `x/7i $pc` 查看当前指令和接下来的几条指令，确认是否为 ecall。
```
0x800104 <syscall+44>: ecall
0x800108 <syscall+48>: sd a0,28(sp)
...
```
停在 ecall 前一条指令，准备观察 QEMU 模拟的硬件执行。

GDB 显示结果如下:
```
=> 0x800104 <syscall+44>:       ecall
   0x800108 <syscall+48>:       sd      a0,28(sp)
   0x80010c <syscall+52>:       lw      a0,28(sp)
   0x80010e <syscall+54>:       addi    sp,sp,144
   0x800110 <syscall+56>:       ret
   0x800112 <sys_exit>: mv      a1,a0
   0x800114 <sys_exit+2>:       li      a0,1
```
此时可以确认：CPU 仍处于 用户态（U-mode），系统调用号与参数已通过 a0–a7 寄存器准备完毕，即将执行 ecall 触发特权级切换。

4. 在上述的第三个终端里即sudo gdb，一开始是处于`continue`的状态，Ctrl+C中断后，再使用以下命令：
```
(gdb) break *<ecall处理函数入口或内核函数地址>
(gdb) continue
```
当用户程序执行 ecall 时，QEMU 会停在断点，进而观察硬件执行流程：TCG 翻译，中断处理，寄存器状态变化（sp、pc、a0–a7）。

这一过程可以使用`stepi`单步执行 QEMU 内部指令。


而对 ecall 指令执行单步，PC 立刻发生跳转，进入内核态，gdb输出如下：
```
(gdb) si
0xffffffffc0200e48 in __alltraps () at kern/trap/trapentry.S:123
123         SAVE_ALL
```
这样，PU 根据 stvec 寄存器自动跳转到内核 trap 入口，特权级从 U-mode → S-mode，开始保存用户态寄存器上下文（SAVE_ALL），该过程由 QEMU 模拟硬件行为完成。


而在`sudo gdb riscv64-softmmu/qemu-system-riscv64`中观察到以下情况(即终端三)：
 
- 执行到ecall时，qemu输入continue命令后，会经过一段时间自动退出。QEMU 里被调试的内核，即用户程序直接执行完了导致退出。

- 同样在ecall后，可以看寄存器状态：

```
(gdb) info registers
rax            0xfffffffffffffdfe  -514
rbx            0x0                 0
rcx            0x794b6b718d3e      133364832111934
rdx            0x7fff4c790160      140734476386656
rsi            0x6                 6
rdi            0x584619034eb0      97058090602160
rbp            0x7fff4c7901e0      0x7fff4c7901e0
rsp            0x7fff4c790140      0x7fff4c790140
r8             0x8                 8
r9             0x0                 0
r10            0x0                 0
r11            0x293               659
r12            0x7fff4c7905a8      140734476387752
r13            0x7fff4c790160      140734476386656
r14            0x584617b6ac18      97058068802584
r15            0x794b6bcf7040      133364838264896
rip            0x794b6b718d3e      0x794b6b718d3e <__ppoll+174>
eflags         0x293               [ CF AF SF IF ]
cs             0x33                51
ss             0x2b                43
ds             0x0                 0
es             0x0                 0
fs             0x0                 0
gs             0x0                 0
k0             0x10                16
k1             0x0                 0
k2             0xff7ff7ff          4286576639
k3             0x0                 0
k4             0x0                 0
k5             0x0                 0
k6             0x0                 0
k7             0x0                 0
```

但是看到的都是宿主的寄存器。
5. 继续内核 GDB 调试，在成功地使 QEMU 停在 ecall 时，切回 内核 GDB，如上所示。

接下来在trapentry.S处的133行，sret指令处打上断点：
```
(gdb) break kern/trap/trapentry.S:133    
Breakpoint 2 at 0xffffffffc0200f0a: file kern/trap/trapentry.S, line 133.
(gdb) c                              
Continuing.
```

成功命中断点：
```
Breakpoint 2, __trapret () at kern/trap/trapentry.S:133
133         sret
```


反汇编当前指令，查看附近的指令内容：
```
(gdb) x/7i $pc                       
=> 0xffffffffc0200f0a <__trapret+86>:   sret
   0xffffffffc0200f0e <forkrets>:       mv      sp,a0
   0xffffffffc0200f10 <forkrets+2>:
    j   0xffffffffc0200eb4 <__trapret>
   0xffffffffc0200f12 <kernel_execve_ret>:      addi      a1,a1,-288
   0xffffffffc0200f16 <kernel_execve_ret+4>:    lds1,280(a0)
   0xffffffffc0200f1a <kernel_execve_ret+8>:    sds1,280(a1)
   0xffffffffc0200f1e <kernel_execve_ret+12>:   lds1,272(a0)
```
说明内核已完成系统调用处理，用户态寄存器即将被恢复，执行 sret 将切换回用户态并恢复 PC。


6. 最后停在sret时，单步调试，返回用户态。

单步调试：
```
(gdb) si
```

PC 返回到用户程序中：
```
(gdb) si                             
0x0000000000800108 in syscall (num=5) at user/libs/syscall.c:19
19          asm volatile (
```
再去查看当前指令：
```
(gdb) x/7i $pc
=> 0x800108 <syscall+48>:       sd      a0,28(sp)
   0x80010c <syscall+52>:       lw      a0,28(sp)
   0x80010e <syscall+54>:       addi    sp,sp,144
   0x800110 <syscall+56>:       ret
   0x800112 <sys_exit>: mv      a1,a0
   0x800114 <sys_exit+2>:       li      a0,1
   0x800116 <sys_exit+4>:       j       0x8000d8 <syscall>
```
可以确认 sret 成功恢复用户态 PC，系统调用返回值已存入 a0，用户程序从 ecall 的下一条指令继续执行。

即总流程总结为：

```
U态用户程序 syscall -> ecall -> QEMU 模拟 CPU -> 内核处理 syscall -> sret -> 返回 U态
```

#### 2.理解指令翻译

> 在执行ecall和sret这类汇编指令的时候，qemu进行了很关键的一步——指令翻译（TCG Translation），了解一下这个功能，思考一下另一个双重gdb调试的实验是否也涉及到了一些相关的内容


- 在执行系统调用相关指令，如 ecall、sret时，QEMU 会通过 TCG，即Tiny Code Generator将 RISC-V 指令动态翻译为宿主 CPU 可执行的机器码。

- TCG 首先将每条 RISC-V 指令转换为中间表示（IR），在此基础上进行一定的优化，然后生成宿主指令，这样即使宿主 CPU 架构与 RISC-V 不同，也能正确执行。

- 对于 ecall 和 sret 这类触发异常，上下文切换的指令，TCG 在翻译过程中会调用 QEMU 内部的异常处理逻辑，维护寄存器和内存状态，并确保从用户态到内核态以及从内核态返回用户态的流程被准确模拟。


- 在双重 GDB 调试实验中，实际上我们观察到的指令执行、寄存器变化以及系统调用返回，实际上都是 TCG 翻译后的宿主指令执行与 QEMU 异常处理机制协同工作的结果。

#### 3.部分细节
> 记录下你调试过程中比较抓马有趣的细节，以及在观察模拟器通过软件模拟硬件执行的时候了解到的知识。

一些细节比如：
1. 有时候make debug显示报错：
```c
qemu-system-riscv64: -s: Failed to find an available port: Address already in use
```
这就需要`sudo lsof -i :1234`查询具体的进程并且`kill -9 <PID>` kill掉，才能正确执行。

2. 有时候在gdb调试时候，发现无法`run`，也无法`continue`，一个尝试过的办法是需要`(gdb) target remote :1234`连接一下，或者关闭掉全部的终端重开。

3. 在sudo gdb中，刚开始调试时未关注指令顺序，现在应该清楚，在ecall执行前，可以先打上断点后continue，执行ecall后再观测其具体的呈现。

4. 通过这个命令：

```
(gdb) info functions cpu_exec
All functions matching regular expression "cpu_exec":
```


发现，QEMU 里没有函数名，没有源码行号，GDB 只能看到地址、汇编，无法直接在具体的异常处理函数处设置断点。

因此按照lab2的调试教程即可：
```
# 进入QEMU源码目录
cd qemu-4.1.1

# 清理之前的编译结果
make distclean

# 重新配置，这次要带上调试选项
./configure --target-list=riscv32-softmmu,riscv64-softmmu --enable-debug

# 重新编译
make -j$(nproc)

```

这样，系统里就有两个QEMU：一个是我们日常使用的"正式版"，另一个是我们专门用来调试的"调试版"。

```
gsd2_ubuntu2204@PC-20231128ZVKY:~/qemu-4.1.1$ file riscv64-softmmu/qemu-system-riscv64
riscv64-softmmu/qemu-system-riscv64: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=6a1c0e5a50210df20385563545c14554616b4ae5, for GNU/Linux 3.2.0, with debug_info, not stripped
```

说明成功带有了调试信息。
#### 4.与大模型的交互
> 记录实验过程中，有哪些通过大模型解决的问题，记录下当时的情景，你的思路，以及你和大模型交互的过程。

部分提问语句内容：

- 帮我理解如下一段话：在 QEMU 端设置断点，切换到 QEMU 调试的 GDB 终端（这个终端之前显示 Continuing）。 按 Ctrl + C 停止 QEMU。 在 QEMU GDB 端打断点：(gdb) break <ecall处理函数入口> 然后继续执行 QEMU： (gdb) continue 当用户程序执行 ecall 时，QEMU 会停在我们设置的断点。我该使用何类指令解决这个问题。

- 对于整个流程，把调试的步骤完完整整的告诉我，包括使用到的指令，以及在不同终端中各自的区别。

- 帮我理解下面这个错误`Command aborted`出现的原因，并给出我解决办法。
```c
Breakpoint 2, syscall (num=2) at user/libs/syscall.c:19 19 asm volatile ( (gdb) si Warning: Cannot insert breakpoint 1: Cannot access memory at address 0xffffffffc0200000 Command aborted. (gdb) break user/libs/syscall.c:18 Note: breakpoint 2 also set at pc 0x8000f8. Breakpoint 3 at 0x8000f8: file user/libs/syscall.c, line 19. (gdb) si Warning: Cannot insert breakpoint 1: Cannot access memory at address 0xffffffffc0200000 Command aborted
```

<br>

### 八、总结


在本次实验中，存在一些与理论课不同的内容，首先用户态通过 ecall/ebreak 进入内核，保存寄存器，内核执行后再恢复返回，而理论课中，我们也了解到系统调用是用户态安全进入内核态的唯一正规入口，除此之外，在本次实验中，通过 sscratch 在中断时切换用户栈和内核栈，而原理课中特权级切换必须使用独立内核栈，防止用户破坏内核。

我认为，本次实验的重点是fork 系统调用通过复制当前进程的 PCB 和页表，创建了一个新的子进程。父进程与子进程通过返回值区分，父进程得到子进程的 PID，子进程则得到 0，从而在不同路径中执行各自的任务。exec 系统调用则是将当前进程的地址空间替换为一个新的程序，加载新的 ELF 格式程序并重新设置进程的栈与 trapframe，完成了进程内容的更换，但进程 ID 保持不变。

总的来说，本实验详细地展现了用户程序是如何被完整地执行的，向我们展示了操作系统如何管理和调度进程、内存以及如何在用户与内核之间进行有效的交互，这些知识让我们在对操作系统底层的认识上有了更深入的理解。


