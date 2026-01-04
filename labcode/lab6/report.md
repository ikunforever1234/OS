## <center>Lab6实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
---

### 一、练习0：填写已有实验

1. 在`trap.c`中根据注释，补充中断处理如下：
   ```c
   case IRQ_S_TIMER:
        // "All bits besides SSIP and USIP in the sip register are
        // read-only." -- privileged spec1.9.1, 4.1.4, p59
        // In fact, Call sbi_set_timer will clear STIP, or you can clear it
        // directly.
        // clear_csr(sip, SIP_STIP);

        /* LAB3 :填写你在lab3中实现的代码 */
        /*(1)设置下次时钟中断- clock_set_next_event()
         *(2)计数器（ticks）加一
         *(3)当计数器加到100的时候，我们会输出一个`100ticks`表示我们触发了100次时钟中断，同时打印次数（num）加一
         * (4)判断打印次数，当打印次数为10时，调用<sbi.h>中的关机函数关机
         */
        clock_set_next_event();
        ticks++;
        if (ticks % TICK_NUM == 0) {
            if (current != NULL) {
                // 标记当前进程需要被重新调度
                current->need_resched = 1;
            }
        }
        // lab6: YOUR CODE  (update LAB3 steps)
        //  在时钟中断时调用调度器的 sched_class_proc_tick 函数
        sched_class_proc_tick(current);
        break;
    ```

2.  补充`static struct proc_struct *alloc_proc(void)`的实现，也就是初始化状态的补充。
   
    ```c
    static struct proc_struct *
    alloc_proc(void)
    {
        struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
        if (proc != NULL)
        {
            // LAB4:填写你在lab4中实现的代码
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

            // LAB5:填写你在lab5中实现的代码 (update LAB4 steps)
            proc->wait_state = 0;   /* not waiting */
            proc->cptr = NULL;      /* first child */
            proc->yptr = NULL;      /* younger sibling */
            proc->optr = NULL;      /* older sibling */

            // LAB6:YOUR CODE (update LAB5 steps)
            proc->rq = NULL;                        // 进程还未加入任何运行队列
            list_init(&(proc->run_link));          // 初始化运行队列链表节点
            proc->time_slice = 0;                   // 初始时间片为0
            proc->lab6_run_pool.left = proc->lab6_run_pool.right = proc->lab6_run_pool.parent = NULL;  // 初始化斜堆节点
            proc->lab6_stride = 0;                  // stride值初始化为0
            proc->lab6_priority = 0;                // 优先级初始化为0（默认优先级）
        }
        return proc;
    }
    ```

3. 补充`proc_run`的代码，这里可以直接将之前实验的代码粘贴上去。
   ```c
   void proc_run(struct proc_struct *proc)
    {
        if (proc != current)
        {
            // LAB4:填写你在lab4中实现的代码
            struct proc_struct *prev = current;
            bool intr_flag;
            local_intr_save(intr_flag);
            lsatp(proc->pgdir);
            current = proc;
            proc->runs++;
            proc->need_resched = 0;
            switch_to(&prev->context, &proc->context);
            local_intr_restore(intr_flag);
        }
    }
    ```

4. 补充`do_fork`的代码，这里可以直接将之前实验的代码粘贴上去。
   
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
        // LAB5:填写你在lab5中实现的代码 (update LAB4 steps)
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
        

    fork_out:
        return ret;

    bad_fork_cleanup_kstack:
        put_kstack(proc);
    bad_fork_cleanup_proc:
        kfree(proc);
        goto fork_out;
    }
    ```

5. 补充`copy_range`。
    ```c
    int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end,
                bool share)
    {
        assert(start % PGSIZE == 0 && end % PGSIZE == 0);
        assert(USER_ACCESS(start, end));
        do
        {
            pte_t *ptep = get_pte(from, start, 0), *nptep;
            if (ptep == NULL)
            {
                start = ROUNDDOWN(start + PTSIZE, PTSIZE);
                continue;
            }
            if (*ptep & PTE_V)
            {
                if ((nptep = get_pte(to, start, 1)) == NULL)
                {
                    return -E_NO_MEM;
                }
                uint32_t perm = (*ptep & PTE_USER);
                struct Page *page = pte2page(*ptep);
                struct Page *npage = alloc_page();
                assert(page != NULL);
                assert(npage != NULL);
                int ret = 0;
                /* LAB5:填写你在lab5中实现的代码*/
                void *src_kvaddr = page2kva(page);
                void *dst_kvaddr = page2kva(npage);
                memcpy(dst_kvaddr, src_kvaddr, PGSIZE);
                ret = page_insert(to, npage, start, perm | PTE_V);
                assert(ret == 0);
            }
            start += PGSIZE;
        } while (start != 0 && start < end);
        return 0;
    }
    ```

6. 补充`load_icode`。
   ```c
   load_icode(unsigned char *binary, size_t size)
    {
        ...
        //(6) setup trapframe for user environment
        struct trapframe *tf = current->tf;
        // Keep sstatus
        uintptr_t sstatus = tf->status;
        memset(tf, 0, sizeof(struct trapframe));
        /* LAB5:填写你在lab5中实现的代码*/
        tf->gpr.sp = USTACKTOP;
        tf->epc = elf->e_entry;
        tf->status = (sstatus & ~SSTATUS_SPP) | SSTATUS_SPIE;

        ret = 0;
    out:
        return ret;
    bad_cleanup_mmap:
        exit_mmap(mm);
    bad_elf_cleanup_pgdir:
        put_pgdir(mm);
    bad_pgdir_cleanup_mm:
        mm_destroy(mm);
    bad_mm:
        goto out;
    }
    ```

### 二、练习1：理解调度器框架的实现

#### 1.阅读并分析以下调度器框架的实现，并回答以下问题：

- (1) 调度类结构体 sched_class 的分析：请详细解释 sched_class 结构体中每个函数指针的作用和调用时机，分析为什么需要将这些函数定义为函数指针，而不是直接实现函数。


```c
struct sched_class {
    const char *name;
    void (*init)(struct run_queue *rq);
    void (*enqueue)(struct run_queue *rq, struct proc_struct *proc);
    void (*dequeue)(struct run_queue *rq, struct proc_struct *proc);
    struct proc_struct *(*pick_next)(struct run_queue *rq);
    void (*proc_tick)(struct run_queue *rq, struct proc_struct *proc);
};
```

##### 调度类函数指针的作用和调用时机

1. 函数指针`init(struct run_queue *rq)`
**作用**:初始化该调度算法所使用的运行队列数据结构。
**调用时机**:在调度器初始化时调用，`sched_init()`，以设置运行队列的初始状态。
```c
sched_class->init(rq);
```
  不同调度算法对`run_queue`的组织方式不同（如 FIFO、时间片轮转、stride），因此初始化逻辑必须由具体调度类完成。

2. 函数指针`enqueue(struct run_queue *rq, struct proc_struct *proc)`
**作用**:将一个可运行进程插入运行队列。
**调用时机**:进程被唤醒`wakeup_proc()`，当前进程在`schedule()`中被重新放回队列

```c
sched_class_enqueue(proc);
```
只负责“插入”，不涉及调度决策,插入方式由调度算法决定（链表尾、按优先级、斜堆等）。

3. 函数指针`dequeue(struct run_queue *rq, struct proc_struct *proc)`
**作用**:将一个进程从运行队列中移除。
**调用时机**:当某个进程被选中即将运行时，从运行队列中移除。

```c
sched_class_dequeue(next);
```

4. 函数指针`pick_next(struct run_queue *rq)`
**作用**:从运行队列中选择下一个要运行的进程。
**调用时机**:`schedule()`中做调度决策时。

```c
next = sched_class_pick_next();
```
这是调度算法的核心决策函数，不同算法在这里体现差异（RR / stride / priority）。

5. 函数指针`proc_tick(struct run_queue *rq, struct proc_struct *proc)`
**作用**:在时钟中断发生时，更新当前进程的调度状态。
**调用时机**:每次时钟中断，由 `sched_class_proc_tick()` 间接调用

```c
sched_class->proc_tick(rq, proc);
```
可以用来减少时间片，判断是否需要触发重新调度等等。

##### 为什么需要将这些函数定义为函数指针


答:这是**典型的策略模式，将调度算法的具体实现与调度器框架解耦，使得调度器框架可以支持多种不同的调度算法。**

  1. 解耦调度框架与调度算法，`schedule()`、`wakeup_proc()` 完全不依赖具体算法

  2. 便于扩展，新增调度算法只需实现一个新的 `sched_class`

  3. 支持运行期切换调度策略，通过修改 `sched_class` 指针即可切换



- (2) 运行队列结构体 run_queue 的分析：比较lab5和lab6中 run_queue 结构体的差异，解释为什么lab6的 run_queue 需要支持两种数据结构（链表和斜堆）。

##### 运行队列结构体 run_queue 的差异分析

1. lab5 中的调度队列特点:
lab5 中没有统一的调度框架，调度逻辑高度耦合在 `schedule()` 中：
```c
void schedule(void);
void wakeup_proc(struct proc_struct *proc);
```
没有 `sched_class`，没有统一的 `run_queue`，调度策略不可扩展。

2. lab6 中 `run_queue` 的设计:

```c
struct run_queue {
    list_entry_t run_list;//通用链表，支持简单调度算法
    unsigned int proc_num;//当前可运行进程数
    int max_time_slice;//最大时间片
    skew_heap_entry_t *lab6_run_pool;//斜堆，支持stride调度算法，仅供 lab6 使用
};
```

##### 为什么 lab6 需要支持两种数据结构？

答：

1. 链表`run_list`:
适合`Round-Robin`，`FIFO`，插入 / 删除简单，时间复杂度低，但不支持有序调度。

2. 斜堆`lab6_run_pool`:
适合`Stride` 调度算法，需要按 `pass` 值排序，每次选取最小 `stride` 值进程。

3. lab6 同时保留两者，是为了不破坏原有调度算法，支持更复杂的调度策略。



- (3) 调度器框架函数分析：分析 sched_init()、wakeup_proc() 和 schedule() 函数在lab6中的实现变化，理解这些函数如何与具体的调度算法解耦。

1. `sched_init`
```c
void sched_init(void)
{
    list_init(&timer_list);

    // sched_class = &default_sched_class;
    sched_class = &stride_sched_class;

    rq = &__rq;
    rq->max_time_slice = MAX_TIME_SLICE;
    sched_class->init(rq);

    cprintf("sched class: %s\n", sched_class->name);
}
```
步骤：初始化调度器全局结构，选择默认调度类（lab6 使用 stride_sched_class），初始化运行队列，调用调度类自己的初始化函数。

调度算法的选择仅体现在这一行：
```c
sched_class = &stride_sched_class;
```

2. `wakeup_proc()`

lab5 中 wakeup_proc() 只负责“唤醒进程”，而 lab6 中 wakeup_proc() 同时承担了“唤醒 + 调度队列维护”的职责，这是从隐式调度队列到显式调度队列框架的重要转变。

```c

if (proc->state != PROC_RUNNABLE)
{
    proc->state = PROC_RUNNABLE;
    proc->wait_state = 0;
    if (proc != current)
    {
        sched_class_enqueue(proc);
    }
}
```

可以看到：

- 在 lab5 的设计中，没有统一的 `run_queue`，没有 `sched_class`，调度队列是隐式存在的。核心假设是“只要进程是 `RUNNABLE`，调度器就能在 `schedule()` 中找到它”。不需要关心“调度算法”，也不负责“插入调度队列”

- lab6中该过程新增的核心动作是`enqueue`，将进程插入到斜堆中。本质上RUNNABLE ≠ 一定会被调度，只有在 `run_queue` 中的 RUNNABLE 进程，才是“可被调度”的。使用显式的运行队列`run_queue`，调度器只从`run_queue` 中 `pick_next`，不再遍历所有进程。

也就是说，lab6 的 `wakeup_proc()`除了状态切换外，还需要将进程插入调度类维护的`run_queue`，通过 `sched_class_enqueue()`间接调用具体调度算法的入队逻辑，体现了调度框架与调度策略解耦的设计思想。

3. `schedule(void)`

具体代码这里不多叙述，可以参考上下文所提供的代码。

- lab5 的 `schedule()` 直接在调度函数内部实现调度算法，本质是一个基于进程链表的简单轮询（`Round-Robin`）调度。

   首先清除重调度标志，确定遍历起点，遍历全局进程链表，遍历所有进程，在 `schedule()` 内部直接完成调度决策，调度逻辑与内核结构强耦合。最后兜底选择 `idle` 进程。


- lab6 的 `schedule()` 已经完全不包含任何调度策略，只做三件事：维护当前进程状态，调用调度类接口，执行上下文切换。

   同样清除重调度标志，当前进程重新入队，当前进程用完时间片后，如果仍可运行，放回 `run_queue`，具体“怎么放”完全由调度类决定。选择下一个进程，`pick_next()`是调度算法核心，`dequeue()`是维护队列一致性，`schedule()`不知道队列结构。最后同样兜底 idle 进程。

也就是说，lab5 的 `schedule()` 是“调度算法本身”，而 lab6 的` schedule()` 只是“调度算法的执行框架”，真正的调度策略已经被完全抽象并下沉到 `sched_class` 中。




#### 2.对于调度器框架的使用流程，请完成以下分析：


- (1) 调度类的初始化流程：描述从内核启动到调度器初始化完成的完整流程，分析 default_sched_class 如何与调度器框架关联。

答：内核启动->调用 sched_init()->设置 sched_class->初始化 run_queue->调度器准备就绪。

更详细来说：

1. 内核入口在 kern_init。它做完控制台、物理内存管理 pmm、外设中断 pic、异常向量 idt、虚拟内存管理 vmm 之后，会调用 sched_init()，再调用 proc_init()，最后才初始化时钟中断并打开中断。

2. sched_init()做的是“把一个具体算法挂到框架上”：
1）初始化调度器内部用的 timer_list。
2）把全局指针 sched_class 设为某个调度类实例，比如现在选的是 stride_sched_class，也可以换回 default_sched_class。
3）初始化全局运行队列 rq：设置 max_time_slice，然后调用 sched_class->init(rq)，让具体算法完成 run_queue 的内部初始化（RR 用链表，stride 用链表+斜堆）。
4）打印当前使用的调度器名字。
这一步的关键是：框架“只知道有一个 sched_class 指针”，它不知道后面是 RR 还是 stride，算法通过这个指针被“插件式”接入。

3. proc_init()在调度框架就绪之后创建两个内核线程：
1）构造 idleproc，状态设为 RUNNABLE，并把 current 指向它，need_resched 设为 1，表示一启动就可以被调度出去。
2）用 kernel_thread(init_main, …) 再起一个内核线程 initproc，后面由它再去 fork 用户进程。
这时调度器已经具备：有调度类（sched_class）、有就绪队列（rq）、也有了至少一个可调度进程（idleproc），后面时钟一响就可以开始真正的进程调度。


而对于分析 default_sched_class 如何与调度器框架关联。

- 可以把 “default_sched_class 和调度器框架的关联” 拆成三层看：类型层、对象层、调用层。

- sched_class（类型）定义了调度算法要提供的接口；

- default_sched_class（对象）用 RR_* 函数填满了这个接口；

- sched.c 里的全局指针 sched_class 在 sched_init() 中被设为 &default_sched_class，之后 wakeup_proc、schedule、时钟中断等所有调度相关路径，都是通过这个指针间接调用 RR 的实现。


---

- (2) 进程调度流程：绘制一个完整的进程调度流程图，包括：时钟中断触发、proc_tick 被调用、schedule() 函数执行、调度类各个函数的调用顺序。并解释 need_resched 标志位在调度过程中的作用。


```

时钟中断触发
    ↓
interrupt_handler(tf)
    ↓
IRQ_S_TIMER 分支
    ↓
clock_set_next_event()
ticks++
sched_class_proc_tick(current)
    ↓
（proc_tick：扣时间片）
time_slice 用完
→ current->need_resched = 1
    ↓
中断返回 → trap(tf) 收尾
    ↓
若从用户态返回 且 need_resched = 1
    ↓
schedule()
    ↓
清 need_resched + 关中断
    ↓
enqueue(current)（若仍可运行）
    ↓
pick_next()（RR / stride）
    ↓
dequeue(next)
    ↓
proc_run(next)
    ↓
下一个进程开始运行
```

need_resched 标志在整个流程中的作用

可以把 `need_resched` 理解为一个 **“延时调度请求（deferred reschedule）”的布尔标志**。  
它并不直接触发进程切换，而是贯穿整个调度流程，用来 **记录“是否需要在合适的时机进行一次调度”**。

其核心作用可以概括为以下三点。

- 1）统一各种“请求调度”的来源

系统中存在多种“希望重新调度”的场景，但它们最终都会汇聚为同一个动作：  
**把 `current->need_resched` 置为 `1`**。

常见来源包括：

- **时钟中断耗尽时间片**
  - 在 `RR_proc_tick` / `stride_proc_tick` 中：
    - `time_slice--`
    - 当时间片用完时，设置  
      ```c
      current->need_resched = 1;
      ```

- **进程主动让出 CPU**
  - `do_yield()` 中直接设置：
    ```c
    current->need_resched = 1;
    ```

- **某些系统调用或内核路径**
  - 当内核判断“当前进程不应该继续运行”时，也会通过设置  
    `need_resched = 1`  
    来请求一次调度。


这样不论“调度请求”来自哪里，内核统一使用 `need_resched` 作为出口，避免了到处直接调用 `schedule()`。


- 2）保证调度发生在“安全点”，而不是中断上下文中

在时钟中断或其他中断上下文中 **直接调用 `schedule()` / `proc_run()` 是危险的**，可能带来以下问题：

- 中断栈、内核栈尚未恢复完成；
- 中断可能嵌套，锁的持有状态复杂；
- 容易破坏内核的不变式。

`need_resched` 的作用正是 **将“请求调度”和“执行调度”解耦**：

- 在中断处理函数或内核关键路径中：
  - 只设置 `need_resched` 标志
  - 不进行任何上下文切换
- 真正的调度：
  - 延迟到trap 收尾（即将返回用户态）
  - 或 idle 循环等明确、安全的位置

因此，`need_resched` 本质上是一种 “延迟调度机制”。


- 3）作为“是否调用 `schedule()`”的统一判断条件

`need_resched` 还是内核中 **触发 `schedule()` 的统一判据**。

主要体现在两个位置：

- **`trap()` 的收尾阶段**
  ```c
  if (!trap_in_kernel(tf) && current->need_resched) {
      schedule();
  }
  ```
  只有在即将从内核态返回用户态时，才检查 need_resched。若当前进程被标记为需要重新调度，则在这一安全点调用 schedule()。

- **`idle()` 循环**
  ```c
  while (1) {
      if (need_resched) {
          schedule();
      }
  }
  ```
  当有新的可运行进程出现时，内核会将 idleproc->need_resched 置为 1。
  idle 进程通过检测该标志，主动进入 schedule()，把 CPU 交给真正的可运行进程。
---
- (3) 调度算法的切换机制：分析如果要添加一个新的调度算法（如stride），需要修改哪些代码？并解释为什么当前的设计使得切换调度算法变得容易。

1. 如果要加一个新调度算法，需要改哪些地方？

以 **stride 调度** 为例，其实只动了这几块：

1. 新增一个调度类实现文件
   - 在 `kern/schedule` 里写一个类似 `default_sched_stride.c` 的文件：
     - 实现一组函数：
       ```c
       new_init
       new_enqueue
       new_dequeue
       new_pick_next
       new_proc_tick
       ```
     - 定义一个全局变量：
       ```c
       struct sched_class new_sched_class = {
           .name = ...,
           .init = new_init,
           ...
       };
       ```
2. 头文件中声明这个调度类  
   - 在 `default_sched.h` 中加一行：
     ```c
     extern struct sched_class new_sched_class;
     ```
3. 在 `sched_init` 里选择它 
   - 在 `labcode/lab6/kern/schedule/sched.c` 中：
     ```c
     // 原来是
     sched_class = &default_sched_class;
     // 要用新算法就改成
     sched_class = &new_sched_class;
     ```
4. 如有需要，扩展数据结构 
   - 新算法需要额外队列/权重时，可以在：
     - `run_queue` 结构（见 `sched.h`）  
     - 或 `proc_struct`（见 `proc.h`）  
       里加字段，然后在 `alloc_proc` / `init` 函数里初始化即可。

> 核心框架代码：`wakeup_proc`、`schedule`、`trap`、`proc_run` 等都不用改。



2. 为什么当前设计让“切换调度算法”很容易？

    1. **有统一接口**  
   - `sched_class` 把一个调度算法抽象成固定的 5 个回调：
     ```
     init / enqueue / dequeue / pick_next / proc_tick
     ```
   - 框架永远只通过这 5 个函数和算法打交道。

    2. **框架和算法解耦**  
   - 框架代码（`schedule`、`wakeup_proc`、`sched_class_proc_tick`）不再写“遍历哪个链表”的具体逻辑，只调用：
     ```c
     sched_class->xxx(...)
     ```
   - 换算法时，只改 `sched_class` 指向谁，框架完全不用动。

    3. **实现局部化**  
   - 新算法几乎都写在自己的 `xxx_sched.c` 里，额外只需要：
     - 在头文件声明
     - 在 `sched_init` 里选用  
   - 改动面小、风险低。

**也就是说**：  
> 因为有 `sched_class` 这一层抽象，调度算法变成了可插拔模块，只要实现一套标准接口再改一行绑定代码，就能完成算法切换。



### 三、练习2：实现 Round Robin 调度算法

#### 问题1：比较一个在lab5和lab6都有, 但是实现不同的函数, 说说为什么要做这个改动, 不做这个改动会出什么问题？

在`kern/schedule/sched.c`中，函数`schedule(void)`被修改，LAB5中如下：
```c
void schedule(void)
{
    bool intr_flag;
    list_entry_t *le, *last;
    struct proc_struct *next = NULL;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        last = (current == idleproc) ? &proc_list : &(current->list_link);
        le = last;
        do
        {
            if ((le = list_next(le)) != &proc_list)
            {
                next = le2proc(le, list_link);
                if (next->state == PROC_RUNNABLE)
                {
                    break;
                }
            }
        } while (le != last);
        if (next == NULL || next->state != PROC_RUNNABLE)
        {
            next = idleproc;
        }
        next->runs++;
        if (next != current)
        {
            proc_run(next);
        }
    }
    local_intr_restore(intr_flag);
}
```

LAB6中：
```c
void schedule(void)
{
    bool intr_flag;
    struct proc_struct *next;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        if (current->state == PROC_RUNNABLE)
        {
            sched_class_enqueue(current);
        }
        if ((next = sched_class_pick_next()) != NULL)
        {
            sched_class_dequeue(next);
        }
        if (next == NULL)
        {
            next = idleproc;
        }
        next->runs++;
        if (next != current)
        {
            proc_run(next);
        }
    }
    local_intr_restore(intr_flag);
}
```

这里在改之前的LAB5，在`schedule`函数中，通过循环遍历`proc_list`，找到第一个状态为`PROC_RUNNABLE`的进程，然后调用`proc_run(next)`切换到该进程。在改之后的LAB6，`schedule`函数中，通过`sched_class_pick_next()`函数找到下一个要运行的进程，然后调用`proc_run(next)`切换到该进程。

因此，这里分别引入了四个函数如下：
```c
static inline void
sched_class_enqueue(struct proc_struct *proc)
{
    if (proc != idleproc)
    {
        sched_class->enqueue(rq, proc);
    }
}

static inline void
sched_class_dequeue(struct proc_struct *proc)
{
    sched_class->dequeue(rq, proc);
}

static inline struct proc_struct *
sched_class_pick_next(void)
{
    return sched_class->pick_next(rq);
}

void sched_class_proc_tick(struct proc_struct *proc)
{
    if (proc != idleproc)
    {
        sched_class->proc_tick(rq, proc);
    }
    else
    {
        proc->need_resched = 1;
    }
}
```

这四个函数构成了调度器框架的核心接口层，它们将具体的调度算法实现与调度框架解耦，使得切换或扩展调度算法变得简单灵活。

`sched_class_enqueue()` 作用是将一个进程加入就绪队列。`sched_class_dequeue()` 将一个进程从就绪队列中移除。`sched_class_pick_next()` 根据调度算法选择下一个应该运行的进程。`sched_class_proc_tick()` 在每个时钟中断（tick）时被调用，用于处理时间片管理。通过这四个接口函数，调度器框架实现了利用`schedule()` 函数负责进程切换的通用流程，并且由 `sched_class` 中的函数指针决定具体的调度策略

如果要实现新的调度算法，只需：
```c
struct sched_class new_sched_class = {
    .name = "new_scheduler",
    .init = new_init,
    .enqueue = new_enqueue,
    .dequeue = new_dequeue,
    .pick_next = new_pick_next,
    .proc_tick = new_proc_tick,
};

// 切换调度算法
sched_class = &new_sched_class;
```

而LAB5没有时间片管理机制，无法在时间片用完时强制切换进程，所以进程可能长期占用 CPU，与此同时，因为我们增加了一个新的数据结构
`run_queue`，每次只遍历可运行的进程，因此可以降低我们的时间复杂度。

```c
struct run_queue
{
    list_entry_t run_list;
    unsigned int proc_num;
    int max_time_slice;
    // For LAB6 ONLY
    skew_heap_entry_t *lab6_run_pool;
};
```


#### 问题2：描述你实现每个函数的具体思路和方法，解释为什么选择特定的链表操作方法。对每个实现函数的关键代码进行解释说明，并解释如何处理边界情况。


Round Robin调度算法核心思想是为每个进程分配固定的时间片，进程按照先进先出（FIFO）的顺序在就绪队列中排队，时间片用完后进程被放到队列尾部，调度器从队列头部选择下一个进程运行。

##### 1. RR_init() - 初始化运行队列

```c
static void
RR_init(struct run_queue *rq)
{
    // LAB6: YOUR CODE
    list_init(&(rq->run_list));  // 初始化运行队列为空链表
    rq->proc_num = 0;             // 初始化进程数量为0
}
```

这个函数负责初始化运行队列的基本结构。通过调用`list_init(&(rq->run_list))`初始化双向链表头节点，使其`prev`和`next`指针都指向自己，形成一个空的循环链表。同时将进程计数器`rq->proc_num`设置为0，表示队列中没有进程。

##### 2. RR_enqueue() - 进程入队

```c
static void
RR_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: YOUR CODE
    assert(list_empty(&(proc->run_link)));      // 确保进程不在任何队列中
    list_add_before(&(rq->run_list), &(proc->run_link));  // 将进程插入队尾部
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
        proc->time_slice = rq->max_time_slice;  // 分配时间片
    }
    proc->rq = rq;                              // 设置进程所属的运行队列
    rq->proc_num ++;                            // 队列中进程数量加1
}
```
进程入队操作需要完成三个核心任务：链表插入、时间片分配和元数据更新。
    
- 首先通过`assert(list_empty(&(proc->run_link)))`检查进程的`run_link`节点是否为空，防止将已经在队列中的进程重复插入导致链表结构破坏。
- 接着调用`list_add_before(&(rq->run_list), &(proc->run_link))`将进程插入队列尾部。这里选择`list_add_before`是因为它会在`head`之前插入`entry`，由于链表是循环的，在头节点之前插入实际上就是插入到队列尾部，这正是FIFO队列所需要的行为。如果使用`list_add`，则会在头节点之后插入，导致新来的进程被优先调度，违反了公平性原则。

- 时间片的分配采用了条件重置策略：当`proc->time_slice == 0`（表示是新进程或时间片已完全用完）或`proc->time_slice > rq->max_time_slice`（异常情况）时，将时间片重置为`rq->max_time_slice`；否则保持原有时间片不变，这就允许被抢占的进程比如因为I/O阻塞而主动让出CPU的进程在下次运行时继续使用剩余的时间片，而不是每次入队都强制重置为最大值。
- 最后设置`proc->rq`指针指向当前运行队列，并递增`rq->proc_num`完成元数据更新。

##### 3. RR_dequeue() - 进程出队

```c
static void
RR_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: YOUR CODE
    assert(!list_empty(&(proc->run_link)) && proc->rq == rq);  // 确保进程在该队列中
    list_del_init(&(proc->run_link));           // 从队列中删除并重新初始化链表节点
    rq->proc_num --;                            // 队列中进程数量减1
}
```

- 出队操作首先通过`assert(!list_empty(&(proc->run_link)) && proc->rq == rq)`确认进程确实在某个队列中，且进程所属的运行队列指针指向当前队列，前者防止对不在队列中的进程执行删除操作，后者防止从错误的队列中删除进程。

- 使用`list_del_init(&(proc->run_link))`将节点已从链表中移除并重新初始化。
- 最后递减`rq->proc_num`完成进程计数的维护。

##### 4. RR_pick_next() - 选择下一个进程
   
```c
static struct proc_struct *
RR_pick_next(struct run_queue *rq)
{
    // LAB6: YOUR CODE
    if (list_empty(&(rq->run_list))) {          // 如果队列为空
        return NULL;                            // 返回NULL
    }
    list_entry_t *le = list_next(&(rq->run_list));  // 获取队列头部的链表点
    struct proc_struct *p = le2proc(le, run_link);  // 通过链表节点获取进指针
    return p;                                   // 返回选中的进程
}
```

- 首先检查`list_empty(&(rq->run_list))`处理队列为空的边界情况，如果队列为空，说明没有可运行进程，则返回`NULL`。

- 如果队列非空，通过`list_next(&(rq->run_list))`获取头节点的下一个节点，这就是队列中的第一个进程节点。
- 然后使用`le2proc(le, run_link)`将链表节点地址转换为进程结构体指针并返回。

##### 5. RR_proc_tick() - 时间片处理
```c
static void
RR_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: YOUR CODE
    if (proc->time_slice > 0) {                 // 如果进程还有剩余时间片
        proc->time_slice --;                    // 时间片减1
    }
    if (proc->time_slice == 0) {                // 如果时间片用完
        proc->need_resched = 1;                 // 设置需要调度标志
    }
}
```

- 这里我们的时间片处理函数在每个时钟中断时被调用，从而管理当前进程的时间片消耗。
- 首先检查`proc->time_slice > 0`，确保进程还有剩余时间，并防止错误的递减操作，比如时间片已经是0时仍然递减导致的整数下溢，只有当时间片大于0时才执行递减操作，确保时间片始终保持在合理范围内。

- 当时间片递减到0时，设置`proc->need_resched = 1`通知调度器需要进行进程切换。

##### 6. 链表操作选择的理由

在整个实现中选择双向循环链表作为就绪队列，由于RR算法的核心操作模式是从队列头部取出进程，在队列尾部插入进程。双向链表对于这两种操作都是O(1)时间复杂度，无需遍历即可完成。

相比之下，如果使用数组实现，虽然索引访问是O(1)，但在头部删除元素需要移动所有后续元素，时间复杂度为O(n)，性能会随进程数量线性下降。

此外，链表的循环结构使得判断队列空和遍历队列的逻辑更加简洁统一。通过一个哨兵头节点（`rq->run_list`），空队列和非空队列的处理逻辑保持一致，不需要特殊判断空指针的情况，减少了边界情况的复杂性。

#### 问题3：展示 make grade 的输出结果，并描述在 QEMU 中观察到的调度现象。

这里我们执行`make grade`，输出内容如下：

```bash
syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab6$ make grade
priority:                (3.0s)
  -check result:                             OK
  -check output:                             OK
Total Score: 50/50
```

说明我们的实现是正确的，执行`make qemu`，在QEMU中观察到的现象如下：

```bash
syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab6$ make qemu

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
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0xc020004a (virtual)
  etext  0xc0205804 (virtual)
  edata  0xc02c2710 (virtual)
  end    0xc02c6bf0 (virtual)
Kernel executable memory footprint: 795KB
DTB Init
HartID: 0
DTB Address: 0x82200000
Physical Memory from DTB:
  Base: 0x0000000080000000
  Size: 0x0000000008000000 (128 MB)
  End:  0x0000000087ffffff
DTB init completed
memory management: default_pmm_manager
physcial memory map:
  memory: 0x08000000, [0x80000000, 0x87ffffff].
vapaofset is 18446744070488326144
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
check_vmm() succeeded.
sched class: RR_scheduler
++ setup timer interrupts
kernel_execve: pid = 2, name = "priority".
set priority to 6
main: fork ok,now need to wait pids.
set priority to 1
set priority to 2
set priority to 3
set priority to 4
set priority to 5
child pid 3, acc 916000, time 2010
child pid 4, acc 880000, time 2010
child pid 5, acc 908000, time 2010
child pid 6, acc 900000, time 2010
child pid 7, acc 900000, time 2010
main: pid 0, acc 916000, time 2010
main: pid 4, acc 880000, time 2010
main: pid 5, acc 908000, time 2010
main: pid 6, acc 900000, time 2010
main: pid 7, acc 900000, time 2010
main: wait pids over
sched result: 1 1 1 1 1
all user-mode processes have quit.
init check memory pass.
kernel panic at kern/process/proc.c:564:
    initproc exit.
```


实验使用的测试程序 `priority.c` 创建了5个子进程进行并发计算。主进程首先将自己的优先级设置为6（`lab6_setpriority(TOTAL + 1)`），然后通过 `fork()` 创建5个子进程，并分别为它们设置优先级1到5。每个子进程执行相同的任务：在一个无限循环中调用 `spin_delay()` 函数进行忙等待，并累加计数器 `acc`。每累加4000次检查一次运行时间，当超过2000毫秒时输出结果并退出。主进程通过 `waitpid()` 等待所有子进程结束，收集它们的退出状态（即最终的累加值），然后计算并输出调度结果。

实验中系统启动后显示使用的调度器是 `RR_scheduler`，即 Round Robin 时间片轮转调度算法。主进程（pid 2）执行了 `priority` 测试程序，该程序创建了5个子进程（pid 3-7）并分别为它们设置了不同的优先级（1-6，主进程为6）。每个进程都执行相同的计算任务，通过累加操作消耗 CPU 时间，最后输出各自的累加值（acc）和运行时间（time）。

从输出可以看到，5个子进程（pid 3-7）在运行约2010毫秒后依次输出结果，它们的累加值分别为：pid 3为916000、pid 4为880000、pid 5为908000、pid 6为900000、pid 7为900000。主进程随后依次确认每个子进程的结果，输出完全相同的累加值和时间。最后程序输出 `"sched result: 1 1 1 1 1"`，这个结果是通过公式 `(status[i] * 2 / status[0] + 1) / 2` 计算得出的，其中 `status[0]` 是第一个子进程的累加值916000。由于所有进程的累加值都非常接近（差距小于4%），计算结果都归一化为1，表明它们获得的CPU时间几乎完全相等。

这说明RR调度算法**完全忽略优先级，绝对公平地分配CPU时间**，尽管主进程和子进程被设置了不同的优先级（1到6），但RR调度器按照固定的时间片轮转，每个进程都严格按照FIFO顺序获得相同的运行机会。

#### 问题4：分析 Round Robin 调度算法的优缺点，讨论如何调整时间片大小来优化系统性能，并解释为什么需要在 RR_proc_tick 中设置 need_resched 标志。



Round Robin 调度算法的最大优点在于**公平性和简单性**。每个进程都获得相等的 CPU 时间片，按照先进先出的顺序轮流执行，不会出现某个进程长期占用 CPU 导致其他进程饥饿的情况，能够保证所有进程都能得到及时响应。算法只需要维护一个 FIFO 队列，时间复杂度为 O(1)，不需要复杂的优先级计算或动态调整。

然而，RR 算法的缺点就是**无法区分进程的重要性**，所有进程一视同仁，无论是关键的系统服务还是普通的后台任务都获得相同的 CPU 时间，这在实际应用中往往不够灵活。其次是**上下文切换开销**，如果时间片设置过小，频繁的进程切换会带来显著的性能损耗，包括保存和恢复寄存器、切换页表、刷新缓存等操作。

从我们`make qemu`的结果也可以看到，即使进程执行相同的任务，累加值仍有差异，这部分性能损失可能就来自于调度开销。除此之外它的**平均周转时间可能较长**，对于短任务来说，RR 不如最短作业优先算法高效，短任务需要等待长任务的时间片执行完才能获得 CPU，导致周转时间增加。

最后，RR 算法**不考虑进程的 I/O 特性**，CPU 密集型进程和 I/O 密集型进程获得相同的时间片，但 I/O 进程往往用不完时间片就会阻塞，这导致资源分配不够合理。

**时间片过小**会导致上下文切换频繁，CPU 大量时间消耗在调度上而非实际工作，系统吞吐量显著下降。

**时间片过大**虽然上下文切换开销小、吞吐量高，但响应时间变长，用户在交互操作时会感到明显延迟。

因此对于不同类型的系统，时间片大小应该有不同的选择，查阅资料，我们得到结论**交互式桌面系统**适合使用 10-50ms 的时间片，既保证了响应速度，又不会造成过多的切换开销；**服务器系统**可以使用 50-100ms 甚至更长的时间片，因为服务器更关注吞吐量而非响应时间；**实时系统**可能需要 1-10ms 的短时间片，以保证任务的及时响应。更先进的优化策略包括**动态调整时间片**，根据系统负载和进程特性自动调整，例如在进程数少时增大时间片以减少切换开销，在进程数多时减小时间片以保证公平性；或者**区分前台和后台进程**，给予交互式前台进程更小的时间片以提高响应速度，给予后台批处理任务更大的时间片以提高吞吐量。

##### need_resched 标志的必要性

我们在 `RR_proc_tick()` 函数中设置 `need_resched = 1` 而不是直接调用 `schedule()` 。这个函数是在**时钟中断的上下文**中被调用的，此时系统处于中断处理程序中，如果在中断处理过程中直接调用 `schedule()` 进行进程切换，**内核状态不一致**，中断处理尚未完成时切换进程可能破坏内核的某些不变量，与此同时，在中断处理中调度可能导致复杂的嵌套中断场景，难以正确处理。

通过设置 `need_resched` 标志，实际的调度决策被推迟到完成了中断处理以后执行。系统已经完成了中断处理，中断也重新使能以后，处于完全可以安全调度的状态。此时检查 `current->need_resched` 标志，如果为 1 则调用 `schedule()` 进行进程切换。

#### 问题5：如果要实现优先级 RR 调度，代码需要如何修改？当前的实现是否支持多核调度？如果不支持，需要如何改进？

我认为主要改动是将就绪队列从单个队列改为多个优先级队列。每个优先级维护一个独立的RR队列，调度时先从最高优先级队列中选择进程，同一优先级内仍然使用RR轮转。并且需要添加优先级字段到进程控制块中，并在调度函数中增加优先级判断逻辑。

除此之外，因为代码中只有一个全局就绪队列和一个调度器实例，所以是单核的。要支持多核，需要为每个CPU核心维护独立的运行队列和调度上下文，或者使用全局队列加锁机制，还需要实现负载均衡，定期在核心之间迁移进程，除此之外要处理好CPU亲和性、缓存一致性等问题，并使用自旋锁或其他同步机制保护共享数据结构。


### 四、扩展练习 Challenge 1: 实现 Stride Scheduling 调度算法

Stride Scheduling调度算法是一种基于优先级的确定性调度算法，核心思想是通过为每个进程维护一个`stride`（步长）值，每次选择`stride`值最小的进程运行，运行后该进程的`stride`值增加`BIG_STRIDE/priority`。这样可以确保高优先级进程获得更多的CPU时间，且CPU时间分配比例严格按照优先级比例进行。为了高效地找到`stride`最小的进程，使用斜堆（skew heap）数据结构来维护就绪队列。

##### 1. stride_init() - 初始化运行队列
```c
static void
stride_init(struct run_queue *rq)
{
     /* LAB6 CHALLENGE 1: YOUR CODE
      * (1) init the ready process list: rq->run_list
      * (2) init the run pool: rq->lab6_run_pool
      * (3) set number of process: rq->proc_num to 0
      */

     list_init(&(rq->run_list));       // 初始化运行队列链表
     rq->lab6_run_pool = NULL;         // 初始化斜堆为空
     rq->proc_num = 0;                 // 初始化进程数量为0
}
```

这个函数负责初始化Stride调度所需的数据结构。与RR调度不同，Stride调度需要维护两个数据结构：一个是用于快速查找的链表`run_list`，另一个是用于按stride值排序的斜堆`lab6_run_pool`。通过调用`list_init(&(rq->run_list))`初始化双向链表，将`lab6_run_pool`设置为NULL表示斜堆为空，同时将进程计数器`rq->proc_num`设置为0。

##### 2. stride_enqueue() - 进程入队
```c
static void
stride_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 CHALLENGE 1: YOUR CODE
      * (1) insert the proc into rq correctly
      * NOTICE: you can use skew_heap or list. Important functions
      *         skew_heap_insert: insert a entry into skew_heap
      *         list_add_before: insert  a entry into the last of list
      * (2) recalculate proc->time_slice
      * (3) set proc->rq pointer to rq
      * (4) increase rq->proc_num
      */
     
     rq->lab6_run_pool = skew_heap_insert(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f);

     assert(list_empty(&(proc->run_link)));
     list_add_before(&(rq->run_list), &(proc->run_link));

     if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
          proc->time_slice = rq->max_time_slice;    // 分配时间片
     }
     proc->rq = rq;                                  // 设置进程所属的运行队列
     rq->proc_num ++;                                // 队列中进程数量加1
}
```

进程入队操作需要同时维护斜堆和链表两个数据结构。

- 首先调用`skew_heap_insert(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f)`将进程插入斜堆。这里使用`proc_stride_comp_f`比较函数，该函数通过计算两个进程的stride差值来确定它们在堆中的相对位置，stride值小的进程会被放置在堆顶附近。

- 然后通过`assert(list_empty(&(proc->run_link)))`确保进程不在任何队列中，并调用`list_add_before(&(rq->run_list), &(proc->run_link))`将进程插入链表尾部。

- 时间片分配策略与RR调度相同：当进程时间片为0或超过最大时间片时，重置为`rq->max_time_slice`；否则保留剩余时间片，允许被抢占的进程继续使用未用完的时间。

- 最后设置`proc->rq`指针并递增`rq->proc_num`完成元数据更新。

##### 3. stride_dequeue() - 进程出队
```c
static void
stride_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 CHALLENGE 1: YOUR CODE
      * (1) remove the proc from rq correctly
      * NOTICE: you can use skew_heap or list. Important functions
      *         skew_heap_remove: remove a entry from skew_heap
      *         list_del_init: remove a entry from the  list
      */

     rq->lab6_run_pool = skew_heap_remove(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f);
     assert(!list_empty(&(proc->run_link)) && proc->rq == rq);
     list_del_init(&(proc->run_link));

     rq->proc_num --;          // 队列中进程数量减1
}
```

出队操作需要同时从斜堆和链表中删除进程。

- 首先调用`skew_heap_remove(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f)`从斜堆中删除指定进程。斜堆的删除操作同样使用`proc_stride_comp_f`比较函数来定位要删除的节点，删除后会自动重新调整堆结构以维护堆的性质。

- 然后通过`assert(!list_empty(&(proc->run_link)) && proc->rq == rq)`确认进程确实在当前队列中，这个断言检查两个条件：进程的链表节点非空，说明在某个队列中，且进程所属队列指针指向当前队列，从而防止从错误的队列删除。

- 使用`list_del_init(&(proc->run_link))`从链表中删除进程节点并重新初始化，最后递减`rq->proc_num`完成进程计数维护。

##### 4. stride_pick_next() - 选择下一个进程
```c
static struct proc_struct *
stride_pick_next(struct run_queue *rq)
{
     /* LAB6 CHALLENGE 1: YOUR CODE
      * (1) get a  proc_struct pointer p  with the minimum value of stride
             (1.1) If using skew_heap, we can use le2proc get the p from rq->lab6_run_pol
             (1.2) If using list, we have to search list to find the p with minimum stride value
      * (2) update p;s stride value: p->lab6_stride
      * (3) return p
      */

     if (rq->lab6_run_pool == NULL)
          return NULL;
     struct proc_struct *p = le2proc(rq->lab6_run_pool, lab6_run_pool);

     if (p->lab6_priority == 0) {
          // 优先级为0时，设置为1，避免除0错误
          p->lab6_stride += BIG_STRIDE;
     } else {
          p->lab6_stride += BIG_STRIDE / p->lab6_priority;
     }
     return p;
}
```

这是Stride调度的核心函数，负责选择下一个要运行的进程并更新其stride值。

- 首先检查`rq->lab6_run_pool == NULL`判断斜堆是否为空，若为空则返回NULL表示没有可运行进程。如果斜堆非空，由于斜堆的性质保证了堆顶元素就是stride值最小的进程，因此可以直接通过`le2proc(rq->lab6_run_pool, lab6_run_pool)`获取堆顶进程，时间复杂度为O(1)，这是使用斜堆的主要优势。

- 选中进程后，需要更新其stride值。这是Stride调度算法的关键步骤：通过`p->lab6_stride += BIG_STRIDE / p->lab6_priority`计算stride增量。`BIG_STRIDE`是一个大常数（定义为0x7FFFFFFF），除以优先级后得到该进程的步长。优先级越高，步长越小，下次被选中的概率就越大，从而获得更多CPU时间。特别处理了`lab6_priority == 0`的情况，直接加上`BIG_STRIDE`避免除零错误，这种情况下进程获得最少的CPU时间。


##### 5. stride_proc_tick() - 时间片处理
```c
static void
stride_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 CHALLENGE 1: YOUR CODE */
     if (proc->time_slice > 0) {          // 如果进程还有剩余时间片
          proc->time_slice --;            // 时间片减1
     }
     if (proc->time_slice == 0) {         // 如果时间片用完
          proc->need_resched = 1;         // 设置需要调度标志
     }
}
```

时间片处理函数在每个时钟中断时被调用，管理当前进程的时间片消耗，实现方式与RR调度完全相同。

- 首先检查`proc->time_slice > 0`确保进程还有剩余时间片，防止时间片为0时继续递减导致的整数下溢。只有当时间片大于0时才执行递减操作，保证时间片始终在合理范围内。

- 当时间片递减到0时，设置`proc->need_resched = 1`通知调度器需要进行进程切换。此时调度器会调用`stride_pick_next()`选择下一个stride值最小的进程运行，被切换出去的进程会重新入队，其stride值已经在上次被选中时更新过，因此会根据新的stride值在队列中重新排序。

##### 6. proc_stride_comp_f() - 斜堆比较函数
```c
static int
proc_stride_comp_f(void *a, void *b)
{
     struct proc_struct *p = le2proc(a, lab6_run_pool);
     struct proc_struct *q = le2proc(b, lab6_run_pool);
     int32_t c = p->lab6_stride - q->lab6_stride;
     if (c > 0)
          return 1;
     else if (c == 0)
          return 0;
     else
          return -1;
}
```

这是斜堆操作所需的比较函数，用于确定两个进程节点在堆中的相对位置。

- 函数接受两个`void*`类型的参数，分别指向斜堆节点，通过`le2proc(a, lab6_run_pool)`和`le2proc(b, lab6_run_pool)`将节点地址转换为进程结构体指针。

- 计算两个进程的stride差值`c = p->lab6_stride - q->lab6_stride`，根据差值返回1（p的stride大于q）、0（相等）或-1（p的stride小于q）。斜堆根据这个比较结果维护最小堆性质，确保stride值最小的进程位于堆顶。

##### 执行结果

这里我们将`sched_init`中的调度方法改为`stride`，并修改`grade.sh`脚本中的`sched class`为`stride_schedule`，如下所示：

```c
void sched_init(void)
{
    list_init(&timer_list);

    // sched_class = &default_sched_class;
    sched_class = &stride_sched_class;

    rq = &__rq;
    rq->max_time_slice = MAX_TIME_SLICE;
    sched_class->init(rq);

    cprintf("sched class: %s\n", sched_class->name);
}
```

```sh
## check now!!
run_test -prog 'priority'      -check default_check             \
        'sched class: stride_scheduler'                         \
        'kernel_execve: pid = 2, name = "priority".'            \
        'main: fork ok,now need to wait pids.'                  \
        'set priority to 5'                                     \
        'set priority to 4'                                     \
        'set priority to 3'                                     \
        'set priority to 2'                                     \
        'set priority to 1'                                     \
        'all user-mode processes have quit.'                    \
        'init check memory pass.'                               \
    ! - 'user panic at .*'
```

执行`make grade`，结果如下：

```bash
syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab6$ make grade
priority:                (3.0s)
  -check result:                             OK
  -check output:                             OK
Total Score: 50/50
```

执行`make qemu`，结果如下：

```bash
syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab6$ make qemu

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
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0xc020004a (virtual)
  etext  0xc0205c90 (virtual)
  edata  0xc02c2710 (virtual)
  end    0xc02c6bf0 (virtual)
Kernel executable memory footprint: 795KB
DTB Init
HartID: 0
DTB Address: 0x82200000
Physical Memory from DTB:
  Base: 0x0000000080000000
  Size: 0x0000000008000000 (128 MB)
  End:  0x0000000087ffffff
DTB init completed
memory management: default_pmm_manager
physcial memory map:
  memory: 0x08000000, [0x80000000, 0x87ffffff].
vapaofset is 18446744070488326144
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
check_vmm() succeeded.
sched class: stride_scheduler
++ setup timer interrupts
kernel_execve: pid = 2, name = "priority".
set priority to 6
main: fork ok,now need to wait pids.
set priority to 5
set priority to 4
set priority to 3
set priority to 2
set priority to 1
child pid 7, acc 1364000, time 2010
child pid 6, acc 1108000, time 2010
child pid 5, acc 896000, time 2010
child pid 4, acc 668000, time 2020
child pid 3, acc 452000, time 2020
main: pid 3, acc 452000, time 2020
main: pid 4, acc 668000, time 2020
main: pid 5, acc 896000, time 2020
main: pid 6, acc 1108000, time 2020
main: pid 0, acc 1364000, time 2020
main: wait pids over
sched result: 1 1 2 2 3
all user-mode processes have quit.
init check memory pass.
kernel panic at kern/process/proc.c:564:
    initproc exit.
```

说明我们的Stride Scheduling 调度算法实现是正确的。

##### 核心机制

我们的Stride Scheduling通过以下的方法实现按优先级比例的CPU时间分配：

1. **Stride值计算**：每个进程维护一个stride值。每次进程被选中运行后，其stride增加`BIG_STRIDE / priority`。优先级越高，增量越小，下次被选中的机会越大。

2. **最小stride选择**：调度器总是选择stride值最小的进程运行。这确保了优先级高的进程（步长小）会被更频繁地选中，而优先级低的进程（步长大）选中频率较低。

3. **斜堆优化**：使用斜堆数据结构将查找最小stride的时间复杂度从O(n)降低到O(1)，插入和删除操作保持O(log n)的效率，显著提升了调度性能。

4. **时间片机制**：虽然stride决定了进程被选中的频率，但每次运行的时间长度仍由时间片控制。时间片用完后触发重新调度，通过stride值选择下一个进程，两种机制相互配合实现了完整的调度策略。

5. **溢出处理**：通过有符号整数比较stride差值，正确处理了stride值可能发生的溢出问题，保证了算法的长期稳定运行。


除此之外，与RR调度相比，Stride Scheduling能够根据进程的重要性（优先级）动态分配CPU时间，实现了更灵活和精确的资源控制，适用于需要服务质量保证的系统场景。

##### 说明/证明每个进程分配到的时间片数目和优先级成正比
Stride算法能保证时间片分配与优先级成正比的核心原因在于其stride值的更新机制，因为每个进程被选中运行后，其stride值会增加BIG_STRIDE除以优先级的结果，这就意味着优先级高的进程每次运行后stride增加得少，而优先级低的进程stride增加得多。

由于调度器总是选择stride值最小的进程运行，这就形成了一个自动平衡的机制，也就是说，如果某个高优先级进程运行次数太少，它的stride值就会一直保持较小，从而被连续选中运行多次，直到stride值追赶上其他进程。相反，如果某个低优先级进程运行次数过多，它的stride值会迅速增大，导致很长时间内都不会被选中。

经过足够长的时间后，系统会达到一个平衡状态，此时所有进程的stride值趋于相近，在这个平衡状态下，假设进程A的优先级是进程B的两倍，那么进程A每运行一次stride只增加进程B的一半，因此进程A必须运行两次才能让stride增长到与进程B运行一次相同的程度，这样就自然地实现了运行次数与优先级成正比的效果。