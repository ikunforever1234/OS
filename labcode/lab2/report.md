## <center>Lab2实验报告<center>
---

### 一、练习1

``first fit``其实就是在需要内存的时候，我们从空闲链表中按照地址升序找到第一个能满足大小需求的空闲块分配出去。

##### 1. default_init

```c
static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
}

```

这里的``free_list``代表一个全局的链表头，是``list_entry_t``类型，用来维护所有的页，转到函数``list_init``的定义

```c
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
}
```

这里可以看到``list_init``的作用其实就是初始化一个循环双向链表。

之后初始化``nr_free``为``0``，表示当前空闲页总数为0。

##### 2. default_init_memmap

```c
static void
default_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }
}
```

这里 ``base`` 指向一段连续空闲页的结构体，也就是我们需要放入刚才初始化的链表的对象，``n``代表空闲页的数量。struct Page定义如下：

```c
struct Page {
    int ref;                        // page frame's reference counter
    uint64_t flags;                 // array of flags that describe the status of the page frame
    unsigned int property;          // the num of free block, used in first fit pm manager
    list_entry_t page_link;         // free list link
};
```

- 首先我们要确保初始化的页数大于``0``，否则存在逻辑错误；然后利用一个指针``p``遍历从``base``开始的``n``个结构体，首先确认这些页处于保留状态，防止重复初始化，之后清空页的标志位``flags``与属性``property``，表示现在这页既不是保留的，也没有被分配，然后使用``set_page_ref``将这页的``ref``属性也设置为``0``。

```c
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
```

- 然后设置块头``base``的``property``为``n``，表示连续空闲块的长度为``n``，然后利用``SetPageProperty(base)``设置页面属性值，之后更新``nr_free``的值，记录现在空闲页的总数。

```c
#define SetPageProperty(page)       ((page)->flags |= (1UL << PG_property))
```

- 在插入部分，首先判断空闲页链表是否为空，如果为空就直接把``base``插入；如果不为空，则需要按照地址的递增顺序进行插入，通过``while ((le = list_next(le)) != &free_list)``遍历整个链表，找到第一个地址比``base``大的块，使用``list_add_before``把``base``插到它前面，如果整个链表中没有比``base``地址大的，使用 ``list_add`` 把``base``插到最后。

```c
static inline void
list_add(list_entry_t *listelm, list_entry_t *elm) {
    list_add_after(listelm, elm);
}
```

```c
static inline void
list_add_before(list_entry_t *listelm, list_entry_t *elm) {
    __list_add(elm, listelm->prev, listelm);
}
```


这样，整个对于空闲链表的维护就完成了。

##### 3. default_alloc_pages(size_t n)


本函数采用 **First Fit算法**，其核心思想是：
> 从空闲页链表的起始位置开始，依次查找第一个能够容纳所请求页数的空闲块，并立即进行分配。

该函数是操作系统物理内存管理的核心部分之一，主要负责将逻辑上的“页请求”映射为实际的物理页资源。

`default_alloc_pages(size_t n)`设计，实现步骤如下：

```c
   assert(n > 0);
    if (n > nr_free) {
        return NULL;
    }
```
- 合法性检查 ：首先判断输入参数 `n` 是否大于 0，然后检查系统中是否存在足够的空闲页数 (`n <= nr_free`)。若空闲页不足，则直接返回空指针 `NULL`，表示分配失败。这样可以保证系统在执行物理页分配前不越界、不分配非法数量页，同时避免链表访问空指针，以及错误拆分。


```c
struct Page *page = NULL;
list_entry_t *le = &free_list;
while ((le = list_next(le)) != &free_list) {
    struct Page *p = le2page(le, page_link);
    if (p->property >= n) {  // 找到满足条件的块
        page = p;
        break;
    }
}
```
- 查找合适的空闲块 : 
`free_list`是内核维护的空闲页双向链表，每个节点代表一块连续的空闲页。
每个块由`struct Page` 结构体表示，其中`property `属性记录该块连续空闲页的数量。使用 `list_next() `宏遍历链表节点，依次检查每个空闲块。遍历空闲页链表 `free_list`，依次检查每个空闲块的 `property` 属性，即记录该块连续空闲页数。当找到第一个 `property >= n` 的块时，说明存在足够空闲页数，可以停止搜索了。

```c
list_entry_t* prev = list_prev(&(page->page_link));
list_del(&(page->page_link));

if (page->property > n) {
    struct Page *p = page + n;
    p->property = page->property - n;
    SetPageProperty(p);
    list_add(prev, &(p->page_link));
}
```
- 分两个情况，若找到的空闲块大小与需求完全相等，则直接从链表中删除该块并返回；  若该块大于所需页数，则需要将其拆分为两部分：
  - 前 `n` 页分配给请求方；
  - 剩余部分仍作为空闲块，重新插入链表中以备后续使用。

  同时更新剩余块的 `property` 值，同时需要重新设置页属性标志位。
```c
    nr_free -= n;
    ClearPageProperty(page);
}
return page;
```
- 分配完成后，需更新全局空闲页统计量 `nr_free`，清除已分配页的 `PageProperty` 标志，防止重复管理。最后返回分配块的首地址指针。

---




##### 4. `default_free_pages(struct Page *base, size_t n)`
```c
static void
default_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    nr_free += n;

    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }

    list_entry_t* le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (p + p->property == base) {
            p->property += base->property;
            ClearPageProperty(base);
            list_del(&(base->page_link));
            base = p;
        }
    }

    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (base + base->property == p) {
            base->property += p->property;
            ClearPageProperty(p);
            list_del(&(p->page_link));
        }
    }
}
```
- 作用：释放连续页，按地址有序插入并尝试与前后相邻块合并，维护 `nr_free`。

##### 5.default_nr_free_pages

```c
static size_t
default_nr_free_pages(void) {
    return nr_free;
}
```

这个函数很简单，用来获取空闲页数``nr_free``。

##### 6.basic_check

```c
static void
basic_check(void) {
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

    assert(page2pa(p0) < npage * PGSIZE);
    assert(page2pa(p1) < npage * PGSIZE);
    assert(page2pa(p2) < npage * PGSIZE);

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    assert(alloc_page() == NULL);

    free_page(p0);
    free_page(p1);
    free_page(p2);
    assert(nr_free == 3);

    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(alloc_page() == NULL);

    free_page(p0);
    assert(!list_empty(&free_list));

    struct Page *p;
    assert((p = alloc_page()) == p0);
    assert(alloc_page() == NULL);

    assert(nr_free == 0);
    free_list = free_list_store;
    nr_free = nr_free_store;

    free_page(p);
    free_page(p1);
    free_page(p2);
}
```

这个函数用来检查上所述的内存分配算法。
- 首先调用 ``alloc_page()`` 分别分配三个页面，确保都能成功分配，之后检查三个页面的指针互不相同、引用计数``ref``为``0``以及物理地址确保在内存范围以内，之后备份当前的 ``free_list`` 和 ``nr_free``，清空空闲链表，设置空闲页数为``0``，确保再次分配页面时，应该失败返回 ``NULL``。
- 之后使用``free_page``释放三个页面，检查``nr_free`` 恢复为 3，再次申请页面，能够重新得到刚才的3页，并且无法成功申请第4页。
- 之后释放``p0``，检查空闲链表不为空，再次分配时应当拿回 ``p0``，最后检查空闲页数是否回到 ``0``。
- 最后恢复原来的 ``free_list`` 和 ``nr_free``，释放所有页面，保证测试不会破坏全局状态。


##### 7.default_check

```c
static void
default_check(void) {
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
        count ++, total += p->property;
    }
    assert(total == nr_free_pages());

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
    assert(p0 != NULL);
    assert(!PageProperty(p0));

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
    assert(alloc_pages(4) == NULL);
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
    assert((p1 = alloc_pages(3)) != NULL);
    assert(alloc_page() == NULL);
    assert(p0 + 2 == p1);

    p2 = p0 + 1;
    free_page(p0);
    free_pages(p1, 3);
    assert(PageProperty(p0) && p0->property == 1);
    assert(PageProperty(p1) && p1->property == 3);

    assert((p0 = alloc_page()) == p2 - 1);
    free_page(p0);
    assert((p0 = alloc_pages(2)) == p2 + 1);

    free_pages(p0, 2);
    free_page(p2);

    assert((p0 = alloc_pages(5)) != NULL);
    assert(alloc_page() == NULL);

    assert(nr_free == 0);
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
    }
    assert(count == 0);
    assert(total == 0);
}
```

这个函数与上面的basic_check类似，也是在对内存分配器进行测试，这里不再赘述。


##### 8.default_pmm_manager

```c
const struct pmm_manager default_pmm_manager = {
    .name = "default_pmm_manager",
    .init = default_init,
    .init_memmap = default_init_memmap,
    .alloc_pages = default_alloc_pages,
    .free_pages = default_free_pages,
    .nr_free_pages = default_nr_free_pages,
    .check = default_check,
};
```

这里相当于把我们上面实现的所有内容封装成一个结构体，类似于管理器，从而方便内核调用。

- ``.name``用来指定管理器的名称
- ``.init``用来指定初始化链表的函数
- ``.init_memmap``指定初始化空闲页面的函数
- ``.alloc_pages``指定分配页面的函数
- ``.free_pages``指定一个用来释放页面的函数
- ``.nr_free_pages``指定获取nr_free的函数
- ``.check``用来指定检测函数

##### 程序在进行物理内存分配的过程

先使用``default_init``来初始化一个双向循环链表存放空闲页，之后使用``default_init_memmap``对某个空闲内存块进行初始化，并放到合适的位置，需要分配内存时使用``default_alloc_pages``，当需要释放内存时使用``default_free_pages``，当然，也可以使用``default_nr_free_pages``获取空闲页的数量。


##### 改进空间

- 对于``default_init_memmap``，插入空闲页时采用线性遍历的方式，时间复杂度为``O(n)``，可以考虑采用平衡树结构来提高检索效率，但是这样的话，因为树状结构实现比较复杂，维护比较困难，而且内核的空闲块不多，链表已经足够快，所以这种方案显然不太现实，或许可以考虑引入并发来优化，或者采用引入更多统计信息的方法，方便后续分配策略。
- 使用多链表分级管理，按块大小维护多个空闲链表，减少遍历时间
- 在频繁分配的场景下，考虑采用延迟合并策略（Lazy Coalescing），减少 free_pages() 时的链表维护开销，提升整体响应速度。



### 二、练习2


##### 1.best_fit_init_memmap

``best_fit_init_memmap``在初始化空闲页，实现原理与``first fit``相同，因此可以直接复用，这里不再赘述。



##### 2.best_fit_alloc_pages(size_t n)

本函数 `best_fit_alloc_pages(size_t n)` 实现了 **Best Fit物理内存分配算法**。主要功能是从当前的空闲物理页链表中，选择**最小的但仍能满足请求的连续空闲块**进行分配，从而尽量减少外部碎片。  

完整源码是：
```c
best_fit_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > nr_free) {
        return NULL;
    }

    struct Page *page = NULL;
    list_entry_t *le = &free_list;
    size_t min_size = nr_free + 1;   // 初始化为一个大于所有空闲块大小的值

    // 遍历整个空闲链表，寻找最合适的块
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        if (p->property >= n && p->property < min_size) {
            page = p;
            min_size = p->property;  // 记录最小合适块大小
        }
    }

    // 如果找到合适的块，则进行分配
    if (page != NULL) {
        list_entry_t *prev = list_prev(&(page->page_link));
        list_del(&(page->page_link));

        // 如果当前块比需要的还大，则拆分
        if (page->property > n) {
            struct Page *p = page + n;
            p->property = page->property - n;
            SetPageProperty(p);
            list_add(prev, &(p->page_link));  // 把剩余部分重新插入空闲链表
        }

        nr_free -= n;
        ClearPageProperty(page);
    }

    return page;
}
```
整体思路在default_alloc_pages(size_t n)的基础上进行，大体上保持相同，主要是修改了**选择连续空闲块**这个核心过程，而**合法性检查，分配拆分，状态更新**同default_alloc_pages(size_t n)一样，这里主要讲一下不同之处，其余就不过多阐述。设计思路如下：


```c
struct Page *page = NULL;
list_entry_t *le = &free_list;
size_t min_size = nr_free + 1;  // 初始化为大于所有空闲块的值，后续用来比较

while ((le = list_next(le)) != &free_list) {
    struct Page *p = le2page(le, page_link);
    if (p->property >= n && p->property < min_size) {
        page = p;            // 记录最小合适块，多了比较过程
        min_size = p->property; //记录最小的
    }
}
```
条件` p->property >= n`确保当前块容量足够；条件` p->property < min_size`确保当前块比之前找到的候选块更“紧凑”也就是更小；循环结束后，page 指向整个链表中**最小但够用的**空闲块。

整体上也是遍历空闲页链表 `free_list`，依次检查每个空闲块的 `property` 属性，即记录该块连续空闲页数。`default_alloc_pages(size_t n)`是当找到第一个 `property >= n` 的块时停止，而`best_fit_alloc_pages(size_t n)`是选择满足以上请求外，且最小的空闲块，减少外部碎片，就可以停止搜索了。

对于分配释放的原理，使用后续的 `best_fit_free_pages(struct Page *base, size_t n) ` 完成即可。






##### 3. best_fit_free_pages
###### 1. 作用概述
- **功能**: 释放从 `base` 起的连续 `n` 个物理页，将其作为一个空闲块插入到按物理地址升序维护的 `free_list` 中，并尝试与前/后相邻空闲块合并；更新全局空闲页计数 `nr_free`。
- **定位**: 释放阶段与具体适配策略（Best-Fit/First-Fit）无强耦合，但其正确性直接影响后续 Best-Fit 分配的碎片度与命中质量。

###### 2. 关键不变量与数据结构
- **空闲块头页**: 仅空闲块的“头页”置 `PG_property`，其 `property` 表示该空闲块的连续页数；块内其他页不置此标志，`property=0`。
- **链表有序**: `free_list` 始终按物理地址从小到大排列，便于恒定代价的相邻性判断与合并。
- **计数一致性**: `nr_free` 必须等于链上所有空闲块头页 `property` 的和。
###### 3. best_fit_free_pages实现过程
- 校验与逐页清理（不可为保留页/空闲头；清标志与引用计数）
```c
static void
best_fit_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
```

- 设置当前页块的头页属性与全局空闲页计数
```c
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
```
```c
    /*LAB2 EXERCISE 2: YOUR CODE*/ 
    // 具体来说就是设置当前页块的属性为释放的页块数、并标记为空闲块头、最后增加 nr_free 的值
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
```

- 将释放的空闲块按地址有序插入 `free_list`
```c
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            // 1. 若 base < page：插到它前面并 break
            // 2. 若已到链表尾：插到尾部
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }
```
有序插入保证 `free_list` 按物理地址递增，便于随后进行相邻性判断与合并。

- 与前驱空闲块相邻则向左合并（维持最左页为头）
```c
    list_entry_t* le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        /*LAB2 EXERCISE 2: YOUR CODE*/ 
        // 若 p 的尾恰与 base 相邻：合并到 p，更新 p->property，清 base 的 Property，删链表节点，并把 base 指回 p
        if (p + p->property == base) {
            p->property += base->property;
            ClearPageProperty(base);
            list_del(&(base->page_link));
            base = p;
        }
    }
```

- 与后继空闲块相邻则向右合并
```c
    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        if (base + base->property == p) {
            base->property += p->property;
            ClearPageProperty(p);
            list_del(&(p->page_link));
        }
    }
}
```
合并策略采用“先左后右”，保持合并后块的头页为最左端页，仅在一个头页上维护正确的 `property`。

###### 4. 关键点与正确性
- **顺序“先左后右”**：保证合并后块的头页稳定为最左端页，仅维护一个头页的 `property`。
- **严格相邻性**：基于指针算术的页连续性检查（`p + p->property == base` 或 `base + base->property == p`）。
- **状态一致性**：释放前断言页非 `PageReserved`/`PageProperty`；释放后仅在头页设置 `PG_property` 与 `property=n`。

###### 5. 复杂度与影响
- 插入链表有序位置需要 O(k) 扫描（k 为空闲块数）；合并检查与操作为 O(1)。
- 充分合并可降低外部碎片，使 Best-Fit 在分配时更容易找到“刚好合适”的最小块。







### 三、扩展练习Challenge：buddy system（伙伴系统）分配算法

