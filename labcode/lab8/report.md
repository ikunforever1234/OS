## <center>Lab8实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
---

### 一、练习0：填写已有实验

1. 补充`static struct proc_struct *alloc_proc(void)`的实现，也就是初始化状态的补充。
   
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
            memset(&(proc->context), 0, sizeof(struct context));
            proc->tf = NULL;
            proc->pgdir = boot_pgdir_pa;
            proc->flags = 0;
            memset(proc->name, 0, PROC_NAME_LEN);
            // lab5 add:
            proc->wait_state = 0;
            proc->cptr = proc->optr = proc->yptr = NULL;
            proc->rq = NULL;              // 初始化运行队列为空
            list_init(&(proc->run_link)); // 初始化运行队列的指针
            proc->time_slice = 0;
            proc->lab6_run_pool.left = proc->lab6_run_pool.right = proc->lab6_run_pool.parent = NULL;
            proc->lab6_stride = 0;
            proc->lab6_priority = 0;

            //LAB8 YOUR CODE : (update LAB6 steps)
            proc->filesp = NULL;
            
        }
        return proc;
    }
    ```
    这里补充对`proc_struct`中新增字段`filesp`的初始化，包括进程的一些相关文件信息。
    
    ```c
    struct files_struct {
        struct inode *pwd;      // inode of present working directory
        struct file *fd_array;  // opened files array
        int files_count;        // the number of opened files
        semaphore_t files_sem;  // lock protect sem
    };
    ```

2. 补充`proc_run`的代码，这里需要在调用 `switch_to()` 之前，刷新 TLB。
   ```c
   void proc_run(struct proc_struct *proc)
    {
        if (proc != current)
        {
            struct proc_struct *prev = current;
            bool intr_flag;
            local_intr_save(intr_flag);
            lsatp(proc->pgdir);

            //LAB8 YOUR CODE : (update LAB4 steps)
            flush_tlb();

            current = proc;
            proc->runs++;
            proc->need_resched = 0;
            switch_to(&prev->context, &proc->context);
            local_intr_restore(intr_flag);
        }
    }
    ```

3. 补充`copy_range`。
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

### 二、练习1：完成读文件操作的实现

我们需要补充`sfs_io_nolock`函数，补充过后的函数如下：

```c
static int
sfs_io_nolock(struct sfs_fs *sfs, struct sfs_inode *sin, void *buf, off_t offset, size_t *alenp, bool write) {
    struct sfs_disk_inode *din = sin->din;
    assert(din->type != SFS_TYPE_DIR);
    off_t endpos = offset + *alenp, blkoff;
    *alenp = 0;
	// calculate the Rd/Wr end position
    if (offset < 0 || offset >= SFS_MAX_FILE_SIZE || offset > endpos) {
        return -E_INVAL;
    }
    if (offset == endpos) {
        return 0;
    }
    if (endpos > SFS_MAX_FILE_SIZE) {
        endpos = SFS_MAX_FILE_SIZE;
    }
    if (!write) {
        if (offset >= din->size) {
            return 0;
        }
        if (endpos > din->size) {
            endpos = din->size;
        }
    }

    int (*sfs_buf_op)(struct sfs_fs *sfs, void *buf, size_t len, uint32_t blkno, off_t offset);
    int (*sfs_block_op)(struct sfs_fs *sfs, void *buf, uint32_t blkno, uint32_t nblks);
    if (write) {
        sfs_buf_op = sfs_wbuf, sfs_block_op = sfs_wblock;
    }
    else {
        sfs_buf_op = sfs_rbuf, sfs_block_op = sfs_rblock;
    }

    int ret = 0;
    size_t size, alen = 0;
    uint32_t ino;
    uint32_t blkno = offset / SFS_BLKSIZE;          // The NO. of Rd/Wr begin block
    uint32_t nblks = endpos / SFS_BLKSIZE - blkno;  // The size of Rd/Wr blocks

  //LAB8:EXERCISE1 YOUR CODE HINT: call sfs_bmap_load_nolock, sfs_rbuf, sfs_rblock,etc. read different kind of blocks in file
	
    size_t nbytes = (size_t)(endpos - offset);
    size_t local_blkoff = (size_t)(offset % SFS_BLKSIZE);
    char *data = (char *)buf;

    if (local_blkoff != 0 && nbytes > 0) {
        size_t step = (nblks != 0) ? (SFS_BLKSIZE - local_blkoff) : nbytes;
        if (step > nbytes) step = nbytes;

        if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
            goto out;
        }

        if ((ret = sfs_buf_op(sfs, data, step, ino, (off_t)local_blkoff)) != 0) {
            goto out;
        }

        data += step;
        nbytes -= step;
        alen += step;
        blkno++;
        if (nblks != 0) nblks--;
    }

    while (nbytes >= SFS_BLKSIZE) {
        if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
            goto out;
        }
        if ((ret = sfs_block_op(sfs, data, ino, 1)) != 0) {
            goto out;
        }
        data += SFS_BLKSIZE;
        nbytes -= SFS_BLKSIZE;
        alen += SFS_BLKSIZE;
        blkno++;
        if (nblks != 0) nblks--;
    }
    if (nbytes > 0) {
        if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
            goto out;
        }
        if ((ret = sfs_buf_op(sfs, data, nbytes, ino, 0)) != 0) {
            goto out;
        }
        alen += nbytes;
    }

out:
    *alenp = alen;
    if (offset + alen > sin->din->size) {
        sin->din->size = offset + alen;
        sin->dirty = 1;
    }
    return ret;
}
```

`sfs_io_nolock` 函数实现对**普通文件**的无锁字节级读/写操作，调用时传入文件对应的内存 inode `sin`、用户缓冲区 `buf`、起始偏移 `offset`、指向请求长度的 `*alenp` 以及表示读/写的布尔量 `write`。函数把请求的区间 `[offset, offset + *alenp)` 与文件内容进行数据传输，返回时 `*alenp` 被更新为实际传输的字节数，返回值 `ret` 为操作状态码（0 表示成功，其他为错误码）。

- 函数一开始进行参数与边界检查，确保 inode 不是目录类型，并计算 `endpos = offset + *alenp`，随后将 `*alenp` 清零以便累加实际传输量。若 `offset` 为负、超出最大文件大小 `SFS_MAX_FILE_SIZE`、或 `offset > endpos` 则返回 `-E_INVAL`。如果 `offset == endpos` 则认为没有数据要传输直接返回 0。对于读操作，函数还会把 `endpos` 截断到文件当前大小 `din->size`，并在 `offset >= din->size` 时直接返回 0，保证读操作不会越界读取未分配或超出文件末尾的数据；对于写操作，`endpos` 被限制到 `SFS_MAX_FILE_SIZE`，以防写出文件系统允许的最大范围。

- 之后函数根据 `write` 标志选择底层读/写接口。它用两个函数指针 `sfs_buf_op`（用于部分块的带偏移读写）和 `sfs_block_op`（用于整块读写）来抽象读写实现，读操作时分别指向 `sfs_rbuf` 与 `sfs_rblock`，写操作时分别指向 `sfs_wbuf` 与 `sfs_wblock`。

- 函数将要访问的范围分解为块级单元并分别处理首个非对齐块、若干整块以及尾部非对齐块三种情况。通过计算逻辑起始块号 `blkno = offset / SFS_BLKSIZE`，并用 `local_blkoff = offset % SFS_BLKSIZE` 得到在首块内的偏移。待传输的总字节数记为 `nbytes = endpos - offset`，并用 `alen` 累加已完成传输的字节。
  
  - 若首块存在偏移（`local_blkoff != 0`）且仍有数据需要传输，则首先计算本块可传输的字节 `step`（为 `SFS_BLKSIZE - local_blkoff` 与 `nbytes` 的较小值），随后调用 `sfs_bmap_load_nolock` 将逻辑块映射到磁盘块号，再调用 `sfs_buf_op` 按块内偏移读或写 `step` 字节。完成后更新缓冲区指针、剩余字节和块号，进入整块处理阶段。

  - 整块处理阶段通过 `while (nbytes >= SFS_BLKSIZE)` 循环一次处理一个完整块。每次循环都先调用 `sfs_bmap_load_nolock` 完成逻辑块到磁盘块的映射，然后用 `sfs_block_op` 对整块进行读/写操作，最后更新 `data` 指针、`nbytes` 和 `alen`，继续处理下一块。

  - 当整块循环结束后，如果仍有不足一块大小的剩余数据，函数会对尾部非对齐块重复先映射后通过 `sfs_buf_op` 从块起始位置读/写 `nbytes` 字节的操作，从而完成整个区间的传输。无论哪个阶段出现错误，函数都会设置 `ret` 并跳转到统一的 `out` 退出路径，保证 `*alenp` 在退出时被正确回写为已完成的字节数。

在退出处理`out`处，函数将累计的实际传输字节数写回调用者的 `*alenp`，并在写操作导致文件长度扩展时更新 inode 的 `din->size` 并把 `sin->dirty` 置为 1，以标记 inode 元数据已被修改需要后续持久化。


### 三、练习2：完成基于文件系统的执行程序机制的实现

##### 1. `load_icode` 函数

首先我们需要补充在`load_icode` 函数中实现从文件系统加载执行程序到内存并执行的过程。补充代码如下：

```c
static int
load_icode(int fd, int argc, char **kargv)
{
    /* LAB8:EXERCISE2 YOUR CODE  HINT:how to load the file with handler fd  in to process's memory? how to setup argc/argv?*/
    
    if (current->mm != NULL)
    {
        panic("load_icode: current->mm must be empty.\n");
    }

    int ret = -E_NO_MEM;
    struct mm_struct *mm;
    
    //(1) create a new mm for current process
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    
    //(2) create a new PDT, and mm->pgdir= kernel virtual addr of PDT
    if (setup_pgdir(mm) != 0)
    {
        goto bad_pgdir_cleanup_mm;
    }
    
    //(3) copy TEXT/DATA/BSS parts in binary to memory space of process
    struct Page *page;
    
    //(3.1) read raw data content in file and resolve elfhdr
    struct elfhdr __elf, *elf = &__elf;
    if ((ret = load_icode_read(fd, elf, sizeof(struct elfhdr), 0)) != 0)
    {
        goto bad_elf_cleanup_pgdir;
    }
    
    //(3.2) check ELF magic number
    if (elf->e_magic != ELF_MAGIC)
    {
        ret = -E_INVAL_ELF;
        goto bad_elf_cleanup_pgdir;
    }
    
    //(3.3) read raw data content in file and resolve proghdr based on info in elfhdr
    struct proghdr __ph, *ph = &__ph;
    uint32_t vm_flags, perm;
    
    // 循环处理每个程序头
    for (int i = 0; i < elf->e_phnum; i++)
    {
        off_t phoff = elf->e_phoff + sizeof(struct proghdr) * i;
        if ((ret = load_icode_read(fd, ph, sizeof(struct proghdr), phoff)) != 0)
        {
            goto bad_cleanup_mmap;
        }
        
        if (ph->p_type != ELF_PT_LOAD)
        {
            continue;
        }
        if (ph->p_filesz > ph->p_memsz)
        {
            ret = -E_INVAL_ELF;
            goto bad_cleanup_mmap;
        }
        
        //(3.3) call mm_map to build vma related to TEXT/DATA
        vm_flags = 0, perm = PTE_U | PTE_V;
        if (ph->p_flags & ELF_PF_X) vm_flags |= VM_EXEC;
        if (ph->p_flags & ELF_PF_W) vm_flags |= VM_WRITE;
        if (ph->p_flags & ELF_PF_R) vm_flags |= VM_READ;
        
        // modify the perm bits for RISC-V
        if (vm_flags & VM_READ) perm |= PTE_R;
        if (vm_flags & VM_WRITE) perm |= (PTE_W | PTE_R);
        if (vm_flags & VM_EXEC) perm |= PTE_X;
        
        if ((ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL)) != 0)
        {
            goto bad_cleanup_mmap;
        }
        
        //(3.4) call pgdir_alloc_page to allocate page for TEXT/DATA, 
        //      read contents in file and copy them into the new allocated pages
        size_t off, size;
        uintptr_t start = ph->p_va, end, la = ROUNDDOWN(start, PGSIZE);
        
        ret = -E_NO_MEM;
        
        // 复制 TEXT/DATA 段
        end = ph->p_va + ph->p_filesz;
        while (start < end)
        {
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                ret = -E_NO_MEM;
                goto bad_cleanup_mmap;
            }
            off = start - la;
            size = PGSIZE - off;
            la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            
            // 从文件读取数据到页面
            if ((ret = load_icode_read(fd, page2kva(page) + off, size, ph->p_offset + (start - ph->p_va))) != 0)
            {
                goto bad_cleanup_mmap;
            }
            start += size;
        }
        
        //(3.5) call pgdir_alloc_page to allocate pages for BSS, memset zero in these pages
        end = ph->p_va + ph->p_memsz;
        if (start < la)
        {
            /* ph->p_memsz == ph->p_filesz */
            if (start == end)
            {
                continue;
            }
            off = start + PGSIZE - la;
            size = PGSIZE - off;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
            assert((end < la && start == end) || (end >= la && start == la));
        }
        while (start < end)
        {
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                ret = -E_NO_MEM;
                goto bad_cleanup_mmap;
            }
            off = start - la;
            size = PGSIZE - off;
            la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
        }
    }
    
    //(4) build user stack memory
    vm_flags = VM_READ | VM_WRITE | VM_STACK;
    if ((ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, vm_flags, NULL)) != 0)
    {
        goto bad_cleanup_mmap;
    }
    
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 2 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 3 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 4 * PGSIZE, PTE_USER) != NULL);
    
    //(5) set current process's mm, cr3, and set satp reg
    mm_count_inc(mm);
    current->mm = mm;
    current->pgdir = PADDR(mm->pgdir);
    lsatp(PADDR(mm->pgdir));
    
    //(6) setup argc and argv in user stacks
    uint32_t argv_size = 0, i;
    for (i = 0; i < argc; i++)
    {
        argv_size += strnlen(kargv[i], EXEC_MAX_ARG_LEN + 1) + 1;
    }
    
    uintptr_t stacktop = USTACKTOP - (argv_size / sizeof(long) + 1) * sizeof(long);
    char **uargv = (char **)(stacktop - argc * sizeof(char *));
    
    argv_size = 0;
    for (i = 0; i < argc; i++)
    {
        uargv[i] = strcpy((char *)(stacktop + argv_size), kargv[i]);
        argv_size += strnlen(kargv[i], EXEC_MAX_ARG_LEN + 1) + 1;
    }
    
    stacktop = (uintptr_t)uargv - sizeof(int);
    *(int *)stacktop = argc;
    
    //(7) setup trapframe for user environment
    struct trapframe *tf = current->tf;
    uintptr_t sstatus = tf->status;
    memset(tf, 0, sizeof(struct trapframe));
    
    tf->gpr.sp = stacktop;
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

这里我们`load_icode` 的总体任务是把由文件描述符 `fd` 指向的 ELF 格式可执行文件加载到当前进程的用户地址空间，建立新的内存管理结构（`mm_struct`）、页表与用户栈，准备好 `argc/argv`，并设置进程的 `trapframe` 以便返回用户态执行。

在开始时我们要求 `current->mm` 为空，也就是不能在已有地址空间的进程上重复加载，出错时通过一系列带标签的清理路径依次释放已分配的资源。

函数首先创建一个新的 `mm_struct`，作为当前进程的用户地址空间描述对象，若内存不足则直接失败返回。随后为该 mm 创建新的页目录，并把 `mm->pgdir` 设置为内核可访问的页目录虚拟地址，如果页目录设置失败，函数会销毁刚创建的 mm 并返回错误。到这里，进程已有了独立的地址空间描述和页表骨架，但具体的虚拟内存区域尚未建立。

接下来函数读取并解析 ELF 头（`elfhdr`），先用 `load_icode_read` 从文件读取 ELF 头并验证 ELF 魔数以确保文件格式正确。若 ELF 头不合法，函数会进入清理逻辑并返回错误。通过 ELF 头的信息，函数按程序头表（program headers）迭代每个段；对于每个 `PT_LOAD` 类型的程序头，会先校验 `p_filesz <= p_memsz`，确保文件段占用不得超过内存段大小，然后根据 `p_flags` 计算该段的虚拟内存权限标志（`VM_READ/VM_WRITE/VM_EXEC`）并转换为页表项需要的权限位，随后调用 `mm_map` 在 mm 中建立对应的 VMA 虚拟内存区域，为该段在进程的地址空间中保留相应的线性区间。

在为每个可加载段建立了 VMA 之后，函数负责把段内容从文件拷贝到实际物理页上。它以页为单位调用 `pgdir_alloc_page(mm->pgdir, la, perm)` 分配物理页并建立页表映射，然后用 `load_icode_read` 从文件读取 `p_filesz` 部分的数据到对应页内的正确偏移。对于段的剩余部分（`p_memsz - p_filesz` 即 BSS 区域），函数在对应页内用 `memset(..., 0, size)` 将其清零以保证未初始化数据为 0。

在所有可加载段处理完毕后，函数为用户栈分配空间。它通过 `mm_map` 建立栈对应的 VMA，并显式通过 `pgdir_alloc_page`分配若干栈顶页以保证初始栈空间可用。随后增加 `mm` 的引用计数并把 `current->mm`、`current->pgdir` 设置为新创建的 mm 并调用 `lsatp(PADDR(mm->pgdir))`把页表根加载到 CPU 的地址转换寄存器中，从而让后续对用户地址的访问按照新页表进行解析。

栈上 `argc/argv` 的设置由函数先计算所有参数字符串的总长度，然后在栈顶下方计算出字符串区的起始位置 `stacktop`，在该区域依次拷贝各个 `kargv` 字符串，并在前面为 `char *` 指针数组 `uargv` 留出空间，将每个 `uargv[i]` 指向对应的字符串位置。最后把 `argc`推到 `uargv` 前面的位置，调整 `tf->gpr.sp`指向最终的栈顶，保证用户态程序能够按常规约定读取 `argc/argv`。这里使用的字符串拷贝和指针设置都是在新地址空间语义下完成的，因此写入的是用户虚拟地址空间中的内容。

在准备就绪后，函数清空并初始化当前进程的 `trapframe`：保存原来的 `status` 字段以保留某些 supervisor 标志，再把 trapframe 清零并设置通用寄存器 `sp` 为用户栈指针、`epc` 为 ELF 的入口点 `e_entry`，并根据原来的 `sstatus` 修改 `tf->status`，将 `SSTATUS_SPP` 清为用户态并设置 `SSTATUS_SPIE` 使用户态返回时能够正确开启中断。这样一旦调度器把 CPU 切到该进程并执行 sret，处理器就会从 `epc` 开始以用户态上下文运行用户程序。

如果在段加载或页分配过程中发生错误，会跳转到 `bad_cleanup_mmap`，调用 `exit_mmap(mm)` 回收已经建立的映射，随后依次调用 `put_pgdir(mm)`、`mm_destroy(mm)` 以释放页目录和 mm 结构，最后返回相应错误码。



##### 2. `do_fork()`函数

之后，我们需要改写`do_fork`函数。

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
    // LAB8:EXERCISE2 YOUR CODE  HINT:how to copy the fs in parent's proc_struct?
    
    // 分配 PCB
    if ((proc = alloc_proc()) == NULL)
        goto fork_out;

    // 设置父子关系（child->parent = current）并确保 current 的 wait_state 为 0
    proc->parent = current;
    current->wait_state = 0;
    
    // 分配内核栈
    if (setup_kstack(proc) != 0)
        goto bad_fork_cleanup_proc;

    // 复制 mm 信息（内核线程不用处理）
    if (copy_mm(clone_flags, proc) != 0)
        goto bad_fork_cleanup_kstack;

    // 设置 trapframe & context
    copy_thread(proc, stack, tf);

    // lab8
    if(copy_files(clone_flags, proc) != 0)
    {
        goto bad_fork_cleanup_fs;
    }

    // 分配唯一 PID
    proc->pid = get_pid();

    hash_proc(proc);

    set_links(proc);

    // 成为 RUNNABLE
    wakeup_proc(proc);

    ret = proc->pid;
    
fork_out:
    return ret;

bad_fork_cleanup_fs: // for LAB8
    put_files(proc);
bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}
```


`do_fork` 的任务是为当前进程创建一个子进程，完成子进程 PCB 的分配与初始化、内核栈分配、地址空间复制或共享、寄存器/陷入帧（trapframe）与内核上下文设置、文件描述表的复制，以及把子进程投入可运行状态并返回子进程的 PID。

函数首先检查系统能否创建更多进程即`nr_process >= MAX_PROCESS`，随后调用 `alloc_proc()` 分配并初始化新的 `proc_struct`，若失败直接返回。紧接着把新进程的 `parent` 设为 `current`，并将 `current->wait_state` 置 0，这样父进程的等待状态被清除以便后续可能的等待行为正确进行。接下来调用 `setup_kstack(proc)` 为子进程分配内核栈，若分配失败会通过 `bad_fork_cleanup_proc` 跳转并释放已分配的 `proc` 结构。

之后又由 `copy_mm(clone_flags, proc)` 完成地址空间的处理，为子进程复制一份父进程的内存描述与页表。若 `copy_mm` 失败，则会回退到释放内核栈与 `proc` 的清理路径。

`copy_mm`函数如下，它用来为子进程建立合适的虚拟地址空间描述结构：

```c
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    struct mm_struct *mm, *oldmm = current->mm;

    /* current is a kernel thread */
    if (oldmm == NULL)
    {
        return 0;
    }
    if (clone_flags & CLONE_VM)
    {
        mm = oldmm;
        goto good_mm;
    }
    int ret = -E_NO_MEM;
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    if (setup_pgdir(mm) != 0)
    {
        goto bad_pgdir_cleanup_mm;
    }
    lock_mm(oldmm);
    {
        ret = dup_mmap(mm, oldmm);
    }
    unlock_mm(oldmm);

    if (ret != 0)
    {
        goto bad_dup_cleanup_mmap;
    }

good_mm:
    mm_count_inc(mm);
    proc->mm = mm;
    proc->pgdir = PADDR(mm->pgdir);
    return 0;
bad_dup_cleanup_mmap:
    exit_mmap(mm);
    put_pgdir(mm);
bad_pgdir_cleanup_mm:
    mm_destroy(mm);
bad_mm:
    return ret;
}
```

`copy_thread(proc, stack, tf)` 将父进程传入的 `tf`（trapframe）以及内核入口点/上下文信息复制到新进程的内核栈上，为随后的上下文切换和返回用户态做好准备。在完成基本上下文设置之后，调用 `copy_files(clone_flags, proc)`复制文件描述表，若此步失败，会进入 `bad_fork_cleanup_fs` 清理路径，该路径会释放文件表（`put_files(proc)`）、内核栈（`put_kstack(proc)`）和 `proc` 结构，保证不会泄漏资源。函数随后通过 `get_pid()` 为子进程分配一个唯一 PID，并把该 PID 存入 `proc->pid`。

`copy_files`函数如下，它用来为子进程建立合适的文件描述符表结构：

```c
static int
copy_files(uint32_t clone_flags, struct proc_struct *proc)
{
    struct files_struct *filesp, *old_filesp = current->filesp;
    assert(old_filesp != NULL);

    if (clone_flags & CLONE_FS)
    {
        filesp = old_filesp;
        goto good_files_struct;
    }

    int ret = -E_NO_MEM;
    if ((filesp = files_create()) == NULL)
    {
        goto bad_files_struct;
    }

    if ((ret = dup_files(filesp, old_filesp)) != 0)
    {
        goto bad_dup_cleanup_fs;
    }

good_files_struct:
    files_count_inc(filesp);
    proc->filesp = filesp;
    return 0;

bad_dup_cleanup_fs:
    files_destroy(filesp);
bad_files_struct:
    return ret;
}
```

之后代码调用 `hash_proc(proc)`将进程加入进程集合，接着调用 `set_links(proc)`。`set_links` 应负责把 `proc` 加入到全局进程链表并建立父子关系链表，把进程加入全局结构后，调用 `wakeup_proc(proc)` 将子进程状态设置为 `PROC_RUNNABLE`，使其可以被调度器选中运行。函数最终将子进程的 PID 作为返回值 `ret`，并在正常路径返回该 PID。

最后的错误处理采用了分层的 goto 清理方式：若在复制文件表阶段失败，走 `bad_fork_cleanup_fs`，会调用 `put_files(proc)` 回收文件表资源并继续释放内核栈与 `proc`；若在早期步骤失败，会按相反顺序释放已分配的资源。


#### 结果验证

这里我们执行 `make grade`，输出内容如下：

```bash
Leaving directory '/home/syl/lab/OS/labcode/lab8'
  -sh execve:                                OK
  -user sh :                                 OK
Total Score: 100/100
```

执行make qemu，得到sh用户程序的执行界面如下：

```bash
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
  etext  0xc020b478 (virtual)
  edata  0xc0291060 (virtual)
  end    0xc0296910 (virtual)
Kernel executable memory footprint: 603KB
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
Page table directory switch succeeded!
Kernel stack guardians set succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
check_vmm() succeeded.
sched class: RR_scheduler
Initrd: 0xc0214010 - 0xc021bd0f, size: 0x00007d00
Initrd: 0xc021bd10 - 0xc029100f, size: 0x00075300
sfs: mount: 'simple file system' (106/11/117)
vfs: mount disk0.
++ setup timer interrupts
kernel_execve: pid = 2, name = "sh".
user sh is running!!!
$ 
```

这里我们在这个界面执行`hello`和`sleep`两个测试程序，运行结果如下：

```bash
sched class: RR_scheduler
Initrd: 0xc0214010 - 0xc021bd0f, size: 0x00007d00
Initrd: 0xc021bd10 - 0xc029100f, size: 0x00075300
sfs: mount: 'simple file system' (106/11/117)
vfs: mount disk0.
++ setup timer interrupts
kernel_execve: pid = 2, name = "sh".
user sh is running!!!

Hello world!!.
I am process 3.
hello pass.

sleep 1 x 100 slices.
sleep 2 x 100 slices.
sleep 3 x 100 slices.
sleep 4 x 100 slices.
sleep 5 x 100 slices.
sleep 6 x 100 slices.
sleep 7 x 100 slices.
sleep 8 x 100 slices.
sleep 9 x 100 slices.
sleep 10 x 100 slices.
use 10010 msecs.
sleep pass.
$ sfs: cleanup: 'simple file system' (106/11/117)
all user-mode processes have quit.
init check memory pass.
kernel panic at kern/process/proc.c:643:
    initproc exit.
```

这说明我们能够在用户界面上成功执行程序，我们的实现是正确的。

### lab8-扩展练习 Challenge1：完成基于“UNIX的PIPE机制”的设计方案

如果要在ucore里加入UNIX的管道（Pipe）机制，至少需要定义哪些数据结构和接口？（接口给出语义即可，不必具体实现。数据结构的设计应当给出一个（或多个）具体的C语言struct定义。在网络上查找相关的Linux资料和实现，请在实验报告中给出设计实现”UNIX的PIPE机制“的概要设方案，你的设计应当体现出对可能出现的同步互斥问题的处理。）


##### PIPE机制设计方案

1. 与现有 ucore/lab8 的关系

lab8 已经在下列位置预留了管道接口：

用户态：
```c
file.h 中声明 int pipe(int *fd_store);
```     
内核系统调用层：
```c
sysfile.h 中有 int sysfile_pipe(int *fd_store);
sysfile.c:309 中 sysfile_pipe 目前返回 -E_UNIMP
```
文件抽象层：
```c
file.h:33-45 中有 int file_pipe(int fd[]);
```

因此，一个合理的设计是：在“内核 `pipe` 对象 + `VFS/file` 层封装 + `sysfile` 层桥接 + 用户态接口”四个层次上完成设计。



2. 核心数据结构设计


(1) 内核管道对象：环形缓冲区 + 同步原语

```c
#define PIPE_BUF_SIZE 4096

struct pipe {
    char *buf;              // 环形缓冲区
    size_t size;            // 缓冲区大小，一般为 PIPE_BUF_SIZE
    size_t read_pos;        // 下一个读位置
    size_t write_pos;       // 下一个写位置
    size_t data_count;      // 当前缓冲区内的有效字节数

    int readers;            // 打开的读端数量
    int writers;            // 打开的写端数量

    // 互斥锁，用于保护上述共享变量
    struct mutex lock;      // 保护 read_pos/write_pos/data_count/readers/writers

    // 等待队列或信号量，用于实现阻塞读/写
    wait_queue_t read_queue;    // 读进程在此睡眠（等待数据到来）
    wait_queue_t write_queue;   // 写进程在此睡眠（等待缓冲区有空闲）
};
```
该结构体是 `ucore` 中实现 `UNIX`管道的核心对象。所有读/写系统调用最终都围绕同一个 `struct pipe` 实例进行操作。

(2)与 `file/inode` 的关联方式

为把 `pipe` 融入已有 `VFS/文件接口`，需要在 `struct file` 或 `struct inode` 中加入对 `pipe` 的引用。两种典型方式：

- 方案 A：扩展 file 结构，引入类型和私有数据指针

```c
enum file_type {
    FILE_NONE,
    FILE_REG,
    FILE_DIR,
    FILE_PIPE,      // 新增：管道类型
    FILE_DEVICE,
    // ...
};

struct file {
    enum {
        FD_NONE, FD_INIT, FD_OPENED, FD_CLOSED,
    } status;
    bool readable;
    bool writable;
    int fd;
    off_t pos;
    struct inode *node;
    int open_count;

    enum file_type type;    // 区分普通文件 / 管道 / 设备
    void *private_data;     // 对于管道，这里指向 struct pipe
};
```

- 方案 B：在 `inode` 中为 `FIFO/pipe` 单独留一个指针，如 `struct pipe *i_pipe;`，`struct file` 通过 `node` 间接访问（更接近 Linux 的 `pipe_inode_info` 设计）


3. 内部接口设计与语义

(1) 管道对象的创建与销毁

```c
struct pipe *pipe_create(void);
/*
 * 语义：
 *  - 分配并初始化一个 struct pipe 对象
 *  - 分配 PIPE_BUF_SIZE 大小的缓冲区
 *  - 初始化 read_pos/write_pos/data_count/readers/writers
 *  - 初始化 lock、read_queue、write_queue
 *  - 返回指针或错误码（如返回 NULL 表示失败）
 */

void pipe_release(struct pipe *p);
/*
 * 语义：
 *  - 在 readers == 0 && writers == 0 时释放 struct pipe 和缓冲区
 *  - 不再有人引用该管道时由文件关闭流程调用
 */
```

(2)管道读写的内部操作

```c
ssize_t pipe_read(struct pipe *p, void *buf, size_t len, bool non_block);
/*
 * 语义：
 *  - 若缓冲区有数据，则复制 min(len, data_count) 字节到用户缓冲区
 *  - 若缓冲区为空：
 *      * 若 writers > 0：
 *            - 若 non_block = false，则当前进程加入 p->read_queue 睡眠
 *            - 若 non_block = true，则立即返回 -E_AGAIN（非阻塞读）
 *      * 若 writers == 0：表示写端全部关闭，返回 0（EOF）
 *  - 读成功后更新 read_pos / data_count，唤醒 write_queue 中等待写缓冲区空间的进程
 */

ssize_t pipe_write(struct pipe *p, const void *buf, size_t len, bool non_block);
/*
 * 语义：
 *  - 若缓冲区有空闲空间，则复制尽可能多的数据（效果接近环形缓冲）
 *  - 若缓冲区已满：
 *      * 若 readers > 0：
 *            - 若 non_block = false，则当前进程加入 p->write_queue 睡眠
 *            - 若 non_block = true，则立即返回 -E_AGAIN（非阻塞写）
 *      * 若 readers == 0：无读者，返回 -EPIPE（可选择触发 SIGPIPE）
 *  - 写成功后更新 write_pos / data_count，唤醒 read_queue 中等待数据的进程
 *  - 可以约定：对长度 <= PIPE_BUF_SIZE 的写操作在中间不可被其他进程插入（原子性保证）
 */
```

(3)管道端点关闭语义
```c
void pipe_close(struct pipe *p, bool is_read_end);
/*
 * 语义：
 *  - 若 is_read_end 为 true，则 readers--；否则 writers--
 *  - 若 readers 或 writers 计数变化，应唤醒对端等待队列：
 *      * readers 变为 0 时，唤醒所有 write_queue，使其返回 -EPIPE
 *      * writers 变为 0 时，唤醒所有 read_queue，使其读到 EOF (0)
 *  - 若 readers == 0 且 writers == 0，调用 pipe_release 彻底销毁管道对象
 */
```


4. 与 `file/sysfile/用户态`接口的衔接

(1) 文件层：`file_pipe`
```c
int file_pipe(int fd[2]);
/*
 * 语义：
 *  - 在当前进程的文件描述符表中分配两项 fd[0], fd[1]
 *  - 调用 pipe_create() 创建一个 struct pipe 对象 p
 *  - 初始化两个 struct file 结构：
 *        f_read:
 *          type = FILE_PIPE
 *          readable = 1, writable = 0
 *          private_data = p
 *          p->readers++
 *        f_write:
 *          type = FILE_PIPE
 *          readable = 0, writable = 1
 *          private_data = p
 *          p->writers++
 *  - 将两者插入进程的 fd 表，并返回 0 或负错误码
 */
```


普通的 `file_read/file_write` 在发现 `file->type == FILE_PIPE` 时，不再走 `VFS/inode` 的读写，而是转调 `pipe_read/pipe_write`：

```c
int file_read(int fd, void *base, size_t len, size_t *copied_store);
/*
 * 若 file->type == FILE_PIPE：
 *    调用 pipe_read(file->private_data, base, len, 是否非阻塞)
 * 否则走原有的 inode 读路径
 */

int file_write(int fd, void *base, size_t len, size_t *copied_store);
/*
 * 若 file->type == FILE_PIPE：
 *    调用 pipe_write(...)
 * 否则走原有普通文件写路径
 */
```


(2)系统调用层：`sysfile_pipe`
```c
int sysfile_pipe(int *fd_store);
/*
 * 语义：
 *  - 从用户空间拷贝 fd_store 数组（长度 2）
 *  - 调用 file_pipe 内核函数创建管道并获得内核中的 fd[0], fd[1]
 *  - 将这两个整数写回用户空间的 fd_store
 *  - 返回 0 或负错误码
 */
```
用户态 pipe(int fd[2]) 则只是对 sys_pipe 的简单封装。



##### 同步与互斥问题的处理

- 互斥：

    - 所有对 `read_pos/write_pos/data_count/readers/writers` 的访问必须在 `p->lock` 保护下进行，防止多 CPU 或抢占导致的竞态。
    - 对 `wait_queue` 的操作（加入队列、唤醒）也应在持锁或至少在一致的时序下完成，避免“睡死”或“漏唤醒”。

- 同步（阻塞语义）：

    - 读阻塞：缓冲区为空且仍有 `writers` 时，读者睡眠在 `read_queue` 上，直到有 `writer` 写入数据并唤醒。
    - 写阻塞：缓冲区满且仍有 `readers` 时，写者睡眠在 `write_queue` 上，直到 `reader` 读走部分数据并唤醒。
    - 端点关闭的传播：
        - 最后一个 `writer` 关闭时，所有阻塞在 `read_queue` 的读者应被唤醒，之后看到 `writers == 0 && data_count == 0`，返回 0（EOF）。
        - 最后一个 `reader` 关闭时，所有阻塞在 `write_queue` 的写者被唤醒，写调用返回 -EPIPE，表示“管道破裂”。
- 多读者/多写者：

    - `readers` 与 `writers` 计数可以支持多个进程同时 `dup` 或 `fork` 后共享一个管道端点。
    - 必须保证对 `struct pipe` 的访问在任意数量的并发读写下都保持一致性（互斥锁保证）。

##### 命名管道mkfifo的简要扩展思路


- 在 `VFS` 中引入 `FIFO` 类型的 `inode（类似 S_IFIFO）`，其 `inode` 中包含一个 `struct pipe *i_pipe` 指针。
- 第一次 `open` 一个 `FIFO` 时，若 `i_pipe == NULL` 则创建一个新的 `struct pipe`。
- `open` 语义：
    - 仅读打开 `FIFO` 时，若当前没有 `writer`，可阻塞直到有 `writer` 打开。
    - 仅写打开 `FIFO` 时，若当前没有 `reader`，可阻塞直到有 `reader` 打开。
- 之后对该 `FIFO` 的 `read/write` 与匿名管道完全相同，均转调 `pipe_read/pipe_write`。



### lab8-扩展练习 Challenge2：完成基于“UNIX的软连接和硬连接机制”的设计方案
设计目标：
- 硬连接（hard link）：在同一个文件系统里，让两个不同的路径指向同一个 inode，系统要正确维护这个 inode 的链接计数 `nlinks`；
- 软连接（symbolic link / symlink）：创建一个特殊文件，里面保存了目标路径字符串，读取 symlink 可以得到这个字符串（用 `readlink`）。

#### 一、磁盘和内存中要有哪些数据结构

1) 磁盘 inode：

```c
/* 已存在：kern/fs/sfs/sfs.h */
struct sfs_disk_inode {
    uint32_t size;    /* 文件大小（字节），对 symlink 表示目标字符串长度 */
    uint16_t type;    /* SFS_TYPE_FILE / SFS_TYPE_DIR / SFS_TYPE_LINK */
    uint16_t nlinks;  /* 硬连接数 */
    uint32_t blocks;  /* 数据块数 */
    uint32_t direct[SFS_NDIRECT];
    uint32_t indirect;
// 除了这些还要有：
    #define SFS_TYPE_FILE   1     /* 普通文件 */
    #define SFS_TYPE_DIR    2     /* 目录 */
    #define SFS_TYPE_LINK   3     /* 符号链接（新增）*/

};
```
nlinks记录硬连接数，SFS_TYPE_LINK表示符号链接类型，符号链接内容存储在数据块中，与普通文件存储方式相同。

2) 内存中的 inode：

```c
struct sfs_inode {
    struct sfs_disk_inode *din;  /* 磁盘inode缓存 */
    uint32_t ino;                /* inode编号 */
    bool dirty;                  /* 脏标记 */
    int reclaim_count;           /* 回收计数 */
    semaphore_t sem;             /* 互斥信号量 */
    list_entry_t inode_link;     /* 链表节点 */
    list_entry_t hash_link;      /* 哈希节点 */
    
    char *link_target_cache;     /* 缓存目标路径 */
    uint32_t cache_valid;        /* 缓存有效性标记 */
};
```
link_target_cache缓存可避免频繁读取磁盘，sem信号量保护inode并发访问，dirty标记确保数据一致性。

#### 二、需要给用户/上层调用的接口
- VFS接口
```c
/* 创建硬连接 */
int vfs_link(const char *oldpath, const char *newpath) {
    // 设计思路：
    // 1. 查找oldpath对应的inode（源文件）
    // 2. 检查：源文件存在、不是目录、与目标在同一文件系统
    // 3. 在newpath的父目录中创建目录项，指向源inode
    // 4. 源inode的nlinks计数加1
    // 5. 返回成功/错误
}

/* 创建符号链接 */
int vfs_symlink(const char *target, const char *linkpath) {
    // 设计思路：
    // 1. 解析linkpath的父目录和文件名
    // 2. 创建新inode，类型为SFS_TYPE_LINK
    // 3. 将target字符串写入inode的数据块
    // 4. 在父目录中创建目录项指向新inode
    // 5. 返回成功/错误
}

/* 读取符号链接 */
ssize_t vfs_readlink(const char *path, char *buf, size_t bufsiz) {
    // 设计思路：
    // 1. 查找path对应的inode
    // 2. 检查inode类型是否为SFS_TYPE_LINK
    // 3. 读取inode数据块中的目标路径到buf
    // 4. 返回读取的字节数
}

/* 删除链接（硬连接或符号链接） */
int vfs_unlink(const char *path) {
    // 设计思路：
    // 1. 查找path的父目录和文件名
    // 2. 从父目录中删除该目录项
    // 3. 对应的inode的nlinks减1
    // 4. 如果nlinks为0且没有进程引用，则释放inode
    // 5. 返回成功/错误
}
```


#### 三、SFS接口
```c
static int sfs_dirent_link_nolock(struct sfs_fs *sfs,
                                 struct sfs_inode *dir_sin,
                                 int slot,
                                 uint32_t ino,
                                 const char *name) {
    // 设计思路：
    // 1. 在目录数据块中找到一个空闲slot
    // 2. 写入目录项：文件名 + inode编号
    // 3. 标记目录inode为脏
    // 4. 返回成功/错误
    // 注意：调用者需持有适当的锁
}

/* 创建符号链接inode */
static int sfs_create_symlink_inode(struct sfs_fs *sfs,
                                   const char *target,
                                   uint32_t *ino_store) {
    // 设计思路：
    // 1. 分配空闲inode编号
    // 2. 初始化磁盘inode：type=SFS_TYPE_LINK, nlinks=1
    // 3. 分配数据块，写入target字符串
    // 4. 设置inode的size为target长度
    // 5. 返回分配的inode编号
}

/* 增加inode链接计数 */
static void sfs_inc_nlinks(struct sfs_inode *sin) {
    // 设计思路：
    // 1. 在持有sin->sem的情况下操作
    // 2. sin->din->nlinks++
    // 3. sin->dirty = 1
}

/* 减少inode链接计数 */
static int sfs_dec_nlinks(struct sfs_inode *sin) {
    // 设计思路：
    // 1. 在持有sin->sem的情况下操作
    // 2. sin->din->nlinks--
    // 3. sin->dirty = 1
    // 4. 如果nlinks为0，标记为待回收
    // 5. 返回新的链接计数
}
```


#### 四、并发、同步互斥设计

1.这个部分有几个场景：

1）多个进程同时创建指向同一文件的硬连接
显然对同一个文件的硬连接创建需要串行化，需要使用文件系统级锁保护整个硬连接操作，按固定顺序获取源inode锁和目标目录锁，避免死锁

2）一个进程删除链接，同时另一个进程创建新链接
时间线：
t0: 进程A开始删除 "/b/link1"
t1: 进程B开始创建 "/b/link1"（新文件）
t2: 进程A完成目录项删除，但inode还未回收
t3: 进程B尝试创建同名目录项

需要使用目录锁保护目录项操作实现延迟释放：inode引用计数为0时，不立即回收，等待安全时机。采用两阶段删除：先标记为删除，再实际回收。

3）符号链接读取与更新的并发
进程A：readlink("/symlink")  // 读取符号链接内容
进程B：symlink("/new/target", "/symlink")  // 更新符号链接
进程C：open("/symlink")  // 通过符号链接打开文件

使用读写锁：允许多个读取者，但写入需要独占
原子更新：符号链接内容更新应该原子完成
循环检测：解析符号链接时限制最大深度

为了避免这些事情需要以下处理：
自顶向下获取锁，同级锁按标识符升序获取，释放锁按相反顺序。

```c
void link_operation(struct sfs_inode *dir_sin, struct sfs_inode *target_sin) {
    // 1. 获取文件系统锁
    lock_sfs_fs(sfs);
    
    // 2. 按inode编号升序获取锁
    uint32_t ino1 = dir_sin->ino, ino2 = target_sin->ino;
    if (ino1 < ino2) {
        lock_sin(dir_sin);
        lock_sin(target_sin);
    } else if (ino1 > ino2) {
        lock_sin(target_sin);
        lock_sin(dir_sin);
    } else {
        // 特殊情况处理
        lock_sin(dir_sin);
    }
    
    // 3. 执行操作
    
    // 4. 按相反顺序释放锁
    if (ino1 < ino2) {
        unlock_sin(target_sin);
        unlock_sin(dir_sin);
    } else if (ino1 > ino2) {
        unlock_sin(dir_sin);
        unlock_sin(target_sin);
    } else {
        unlock_sin(dir_sin);
    }
    unlock_sfs_fs(sfs);
}
```

2.原子性操作
1）为了确保操作的原子性，要么全部成功，要么全部失败，我们采用两阶段提交：
- 检查所有前提条件（权限、空间、约束等），分配所需资源（inode、数据块），验证所有操作可以执行。
- 获取所有必要的锁，执行实际修改，如果成功：更新内存状态；如果失败：回滚。之后释放所有锁。

2）然后还是之前的CoW，Copy-on-Write
- 读取目录块到新分配的内存缓冲区，在新缓冲区中修改目录项，分配新的磁盘块，将新缓冲区写入新磁盘块，更新inode的数据块指针（指向新块），延迟释放旧磁盘块。

```c
int atomic_link_operation(struct sfs_fs *sfs, ...) {
    int ret;
    // 阶段1：准备（不提交）
    // - 分配资源（inode、数据块）
    // - 写入目录项到临时缓冲区
    // - 记录undo日志
    
    // 阶段2：提交（原子操作）
    lock_sfs_fs(sfs);
    // 按顺序获取所有需要的锁
    // 执行实际写入操作
    if (成功) {
        // 提交：更新内存状态
        // 标记inode为脏
        ret = 0;
    } else {
        // 回滚
        ret = -EIO;
    }
    // 释放所有锁
    
    return ret;
}
```

#### 五、循环检测
- 软链接可以指向目录，这可能导致循环引用问题
/symlink1 -> /dir1
/dir1/symlink2 -> /symlink1
当解析 /symlink1 时，会形成：
/symlink1 → /dir1 → /dir1/symlink2 → /symlink1 → ...
这就是无限循环了，栈直接爆炸了，因此还要设计循环检测
```c
struct path_resolve_state {
    uint32_t visited_inodes[SFS_MAX_LINK_DEPTH];  // 已访问的inode记录
    int depth;                                    // 当前递归深度
    bool is_absolute;                             // 是否绝对路径
    char *resolved_path;                          // 已解析的路径
    size_t resolved_len;                          // 已解析路径长度
};

/* 符号链接解析函数（带循环检测） */
static int sfs_resolve_symlink(struct sfs_fs *sfs,
                              struct sfs_inode *sin,
                              char *buf,
                              size_t bufsize,
                              struct path_resolve_state *state) {
    // 1. 检查递归深度
    if (state->depth >= SFS_MAX_LINK_DEPTH) {
        return -ELOOP;  // 符号链接嵌套过深
    }
    
    // 2. 检查循环引用
    for (int i = 0; i < state->depth; i++) {
        if (state->visited_inodes[i] == sin->ino) {
            return -ELOOP;  // 检测到循环
        }
    }
    
    // 3. 记录当前inode
    state->visited_inodes[state->depth] = sin->ino;
    state->depth++;
    
    // 4. 读取符号链接内容
    // ... 读取操作 ...
    
    // 5. 递归解析新路径
    // ... 递归调用 ...
}
```
通过限制最大解析深度并使用inode访问记录来检测循环，能够有效避免无限递归、栈溢出和资源耗尽的问题。

