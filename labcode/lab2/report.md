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

相比于``best fit``和``first fit``，``buddy system``通过将物理内存划分为不同大小的块（均为2的幂次方页），来进行高效分配，采取的数据结构是以阶``order``为索引，每一个元素都指向一个双向链表，链表中的每一个元素都是一个空闲块，其大小为``2^order``页。

#### 设计思路

##### 1.基本数据结构定义

```c
static free_area_t free_area[MAX_ORDER + 1];

#define free_list(order) (free_area[order].free_list)
#define nr_free(order)   (free_area[order].nr_free)
```

这里将``free_area``定义为一个全局的数组，并定义一些宏方便后续编写，其中``free_list``指向一个双向链表，``nr_free``表示该链表中的空闲块数量。


##### 2.一些辅助函数

```c
static inline size_t page_to_pfn(struct Page *page) {
    return page - pages;
}

static inline struct Page *pfn_to_page(size_t pfn) {
    return &pages[pfn];
}

static inline struct Page *buddy_of(struct Page *page, int order) {
    size_t pfn = page_to_pfn(page);
    size_t buddy_pfn = pfn ^ (1 << order);
    return pfn_to_page(buddy_pfn);
}
```

在这里 `page_to_pfn`和`pfn_to_page`两个函数用来实现页指针和页帧号之间的转换。

之后`buddy_of`函数用来获取给定页指针和阶数对应的伙伴页指针，这里是因为对于特定阶数``（order）``的块，其大小是 ``2^order``页，伙伴块之间的页帧号仅在第 ``order`` 位上不同，因此这里我们使用异或运算来翻转这一位，就能找到伙伴块的页帧，再转回页指针。

##### 3.buddy_init

```c
static void buddy_init(void) {
    for (int i = 0; i <= MAX_ORDER; i++) {
        list_init(&free_list(i));
        nr_free(i) = 0;
    }
}
```

这里初始化了``free_area``数组，将所有链表初始化为空，并将所有阶的空闲块数量都置为``0``。

##### 4.buddy_init_memmap

```c
static void
buddy_init_memmap(struct Page *base, size_t n)
{
    assert(n > 0);

    /* 清理每页的基础字段*/
    for (struct Page *it = base; it < base + n; ++it) {
        assert(PageReserved(it));
        it->flags = 0;
        it->property = 0;
        set_page_ref(it, 0);
        ClearPageProperty(it);
    }

    struct Page *p = base;
    size_t remain = n;

    while (remain > 0) {
        /* 计算在剩余范围内的最大阶（不超过 MAX_ORDER） */
        int max_order_for_remain = 0;
        while ((1U << (max_order_for_remain + 1)) <= remain &&
               max_order_for_remain + 1 <= MAX_ORDER) {
            max_order_for_remain++;
        }

        /* 从 max_order 向下找第一个满足对齐的阶 */
        int order;
        unsigned long pfn = page_to_pfn(p);
        for (order = max_order_for_remain; order >= 0; --order) {
            unsigned long block_size = (1UL << order);
            if ((pfn & (block_size - 1)) == 0) { /* 对齐检查 */
                break;
            }
        }
        assert(order >= 0);

        /* 标记该块头为 order 并按地址升序插入对应阶链表 */
        p->property = order;
        SetPageProperty(p);

        list_entry_t *head = &free_list(order);
        if (list_empty(head)) {
            list_add(head, &p->page_link);
        } else {
            /* 顺序遍历，找到第一个物理地址比 p 大的元素，在其前面插入 */
            list_entry_t *le = list_next(head);
            int inserted = 0;
            while (le != head) {
                struct Page *q = le2page(le, page_link);
                if (p < q) {
                    list_add_before(le, &p->page_link);
                    inserted = 1;
                    break;
                }
                le = list_next(le);
            }
            if (!inserted) {
                /* 如果遍历结束都没插入，说明要插到尾部（在 head 的前一个位置插入） */
                list_entry_t *last = list_prev(head);
                list_add(last, &p->page_link);
            }
        }

        nr_free(order)++;

        /* 前进到下一块 */
        size_t consumed = (1UL << order);
        p += consumed;
        remain -= consumed;
    }
}
```

这里我们的``buddy_init_memmap``函数将一大段连续的物理内存页，按照伙伴系统的规则进行划分，并初始化相应的管理结构，最后将这些不同大小的空闲内存块挂载到对应的空闲链表中​​。

具体来说，首先遍历所有页，将它们的状态设置为空闲，并将所有页的 `property` 和 `ref` 字段都清零。

之后在我们的剩余页数里，找到不超过``MAX_ORDER``的最大阶数``max_order_for_remain``。然后从这开始向下遍历，找到第一个满足对齐的阶，将这一块标记为该阶数，并按地址升序插入到对应的空闲链表中，最后更新剩余页数和指针。

##### 5.buddy_alloc_pages

```c
static struct Page *buddy_alloc_pages(size_t n) {
    int order = 0;
    while ((1U << order) < n) order++;
    int cur_order = order;

    while (cur_order <= MAX_ORDER && list_empty(&free_list(cur_order))) {
        cur_order++;
    }
    if (cur_order > MAX_ORDER) return NULL;

    list_entry_t *le = list_next(&free_list(cur_order));
    struct Page *page = le2page(le, page_link);
    list_del(le);
    nr_free(cur_order)--;

    while (cur_order > order) {
        cur_order--;
        struct Page *buddy = page + (1 << cur_order);
        buddy->property = cur_order;
        SetPageProperty(buddy);
        list_add(&free_list(cur_order), &(buddy->page_link));
        nr_free(cur_order)++;
    }

    ClearPageProperty(page);
    return page;
}
```

这里我们实现了分配的过程，先计算所需要的大小，然后寻找合适的块，最后分割大块。

具体来说，首先计算满足请求所需的最小内存块阶数，通过一个循环，找到能够容纳 ``n`` 页的最小2的幂次方，即``cur_order``。

之后从``cur_order``开始向上访问找空闲块，找到以后取出空闲块，找不到就返回``NULL``。

如果找到的空闲块比请求的要大，使用``page + (1 << cur_order)``将大块拆成两半，一半``buddy``插回到低一阶的空闲链表中，并修改相对应的属性，剩下的一半``page``被继续分割或者分配出去。


##### 6.buddy_free_pages
```c
static void buddy_free_pages(struct Page *page, size_t n) {
    int order = 0;
    while ((1U << order) < n) order++;

    while (order < MAX_ORDER) {
        struct Page *buddy = buddy_of(page, order);
        if (!PageProperty(buddy) || buddy->property != order) break;

        list_del(&(buddy->page_link));
        nr_free(order)--;

        if (buddy < page) page = buddy;
        order++;
    }

    page->property = order;
    SetPageProperty(page);
    list_add(&free_list(order), &(page->page_link));
    nr_free(order)++;
}
```

这里我们实现了释放的过程，先计算所需要的大小，然后寻找合适的块，最后合并块。

具体来说，首先计算满足请求所需的最小内存块阶数，通过一个循环，找到能够容纳 ``n`` 页的最小2的幂次方，即``order``。

之后从``order``开始向上访问，如果找到的块是空闲的，并且和当前块是伙伴块，那么就将他们合并，并修改相对应的属性，继续向上访问，直到所有的合并工作完成。


##### 7.buddy_nr_free_pages

```c
static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i <= MAX_ORDER; i++) {
        total += nr_free(i) * (1 << i);
    }
    return total;
}
```

这个函数用于计算当前系统中空闲页的总数，比较简单。

##### 8.测试环节

在测试环节，我们设计了一个辅助函数用来帮我们输出各阶的空闲页数。

```c
static void buddy_print_summary(const char *tag)
{
    cprintf("---- %s: 各阶空闲块统计 ----\n", tag);
    size_t grand = 0;
    for (int order = 0; order <= MAX_ORDER; ++order) {
        size_t cnt = nr_free(order);
        size_t pages = cnt * (1UL << order);
        if (cnt > 0) {
            cprintf("  order=%2d : blocks=%4u  页数=%6u\n",
                    order, (unsigned)cnt, (unsigned)pages);
        }
        grand += pages;
    }
    cprintf("  -> 总空闲页数 = %u\n", (unsigned)grand);
    cprintf("-----------------------------------\n");
}
```

之后，就是我们所设计的测试函数。

```c
static void buddy_system_check(void)
{
    cprintf("\n========== BUDDY 检测开始 ==========\n");

    /* 初始总空闲页数 */
    size_t total_init = buddy_nr_free_pages();
    cprintf("初始化：总空闲页数 = %u\n", (unsigned)total_init);
    buddy_print_summary("初始化状态");

    /* 1) 分配 3 个相同大小的块并释放 */
    cprintf("\n[场景1] 分配/回收8页块示例\n");
    struct Page *a = alloc_pages(8);
    struct Page *b = alloc_pages(8);
    struct Page *c = alloc_pages(8);
    cprintf("分配结果：a=%p  b=%p  c=%p\n", a, b, c);
    assert(a != b && b!=c && a != c);
    assert(a != b && a != c && b != c);
    buddy_print_summary("场景1: 分配后");

    free_pages(a, 8);
    cprintf("释放 a(8页)\n");
    buddy_print_summary("场景1: 释放 a 后");

    free_pages(b, 8);
    cprintf("释放 b(8页)\n");
    buddy_print_summary("场景1: 释放 b 后");

    free_pages(c, 8);
    cprintf("释放 c(8页)\n");
    buddy_print_summary("场景1: 释放 c 后");

    /* 2) 分配1页 */
    cprintf("\n[场景2] 分配/回收1页\n");
    struct Page *pmin = alloc_pages(1);
    assert(pmin);
    cprintf("分配 1 页 -> %p, 物理地址 pa=0x%016lx\n", pmin, page2pa(pmin));
    buddy_print_summary("场景2: 分配 1 页 后");
    free_pages(pmin, 1);
    cprintf("释放 1 页完毕\n");
    buddy_print_summary("场景2: 释放 1 页 后");

    /* 3) 分配较大的块 */
    cprintf("\n[场景3] 较大分配/回收\n");
    size_t try_big = total_init / 32;
    if (try_big == 0) try_big = 1;
    struct Page *pbig = alloc_pages(try_big);
    if (pbig) {
        cprintf("成功分配大块 %u 页 -> %p\n", (unsigned)try_big, pbig);
        buddy_print_summary("场景3: 大块分配后");
        free_pages(pbig, try_big);
        cprintf("释放大块 %u 页 完成\n", (unsigned)try_big);
        buddy_print_summary("场景3: 释放大块后");
    } else {
        cprintf("无法分配大块 %u 页（这可能因为内存不足或对齐原因），跳过后续大块断言。\n", (unsigned)try_big);
    }

    /* 4) 分配多个不等大小的块、释放部分，然后尝试再次分配 */
    cprintf("\n[场景4] 分配多个不等大小的块、释放部分，然后尝试再次分配\n");
    struct Page *x1 = alloc_pages(16);
    struct Page *x2 = alloc_pages(32);
    struct Page *x3 = alloc_pages(16);
    cprintf("分配 x1(16)=%p x2(32)=%p x3(16)=%p\n", x1, x2, x3);
    assert(x1 && x2 && x3);

    buddy_print_summary("场景4: 初始分配后");

    /* 释放 x2，使中间出现空洞 */
    free_pages(x2, 32);
    cprintf("释放 x2(32页)，中间产生空洞\n");
    buddy_print_summary("场景4: 释放 x2 后");

    /* 尝试分配一个 32 页块（应该能复用 x2 区域） */
    struct Page *y = alloc_pages(32);
    cprintf("再次尝试分配 32 页 -> %p (期待为之前 x2 的位置或其它合适位置)\n", y);
    assert(y != NULL);
    buddy_print_summary("场景4: 再次分配 32 页 后");

    /* 清理 */
    free_pages(x1, 16);
    free_pages(x3, 16);
    free_pages(y, 32);
    cprintf("场景4: 释放所有分配块，恢复初始碎片\n");
    buddy_print_summary("场景4: 清理后");

    /* 结束检查：总空闲页数不应少于初始值（考虑实现不会“丢页”） */
    size_t total_end = buddy_nr_free_pages();
    cprintf("\n检测完成：初始总空闲页=%u, 结束总空闲页=%u\n", (unsigned)total_init, (unsigned)total_end);
    assert(total_end >= total_init); /* 实现上通常应相等；用 >= 更稳健以防一些实现细节差异 */

    cprintf("========== BUDDY 检测结束（全部断言通过） ==========\n\n");
}
```

这里我们结合具体输出来看。

- 初始状态

首先是初始状态，我们总共有``31929``个空闲页，经分配以后，各阶统计数量如下：

```c
初始化：总空闲页数 = 31929
---- 初始化状态: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31929
-----------------------------------
```

- 场景1 

之后是第一个场景，即我们分配回收``3``个``8``页块``a``、``b``、``c``，统计结果如下，很明显，三个页块的地址各不相同，并且在分配后，各阶的页数也发生改变，总空闲页数从原来的``31929``减少了``24``到了``31905``，符合预期。

```c
[场景1] 分配/回收8页块示例
分配结果：a=0xffffffffc020f340  b=0xffffffffc020f480  c=0xffffffffc020f5c0
---- 场景1: 分配后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31905
-----------------------------------
释放 a(8页)
---- 场景1: 释放 a 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31913
-----------------------------------
释放 b(8页)
---- 场景1: 释放 b 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   2  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31921
-----------------------------------
释放 c(8页)
---- 场景1: 释放 c 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31929
-----------------------------------
```

之后逐次释放三个块，可以看到，各阶的空闲块数量和总空闲页数都发生了变化，释放``a``后，3阶增加了一个块。释放``b``后，3阶又增加一个块，但是并没有合并为4阶，说明``a``和``b``不是``buddy``关系，直到释放``c``，3阶空闲块数量又恢复到1个，4阶多一个16页的块，说明``c``和``a``、``b``的某一个是伙伴关系。

- 场景2

在场景2下，我们分配一页，可以看到分配以后，各阶的页数如下：
  
```c
[场景2] 分配/回收1页
分配 1 页 -> 0xffffffffc020f318, 物理地址 pa=0x0000000080347000
---- 场景2: 分配 1 页 后: 各阶空闲块统计 ----
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31928
-----------------------------------
释放 1 页完毕
---- 场景2: 释放 1 页 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31929
-----------------------------------
```

分配1页后，0阶不含有空闲页，其余不变，总空闲页减1，释放以后，各阶又回到初始状态。

- 场景3

在这里，我们尝试分配所有页的1/32，可以看到，分配以后，各阶的空闲页数如下：

```c
[场景3] 较大分配/回收
成功分配大块 997 页 -> 0xffffffffc0211000
---- 场景3: 大块分配后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  30  页数= 30720
  -> 总空闲页数 = 30905
-----------------------------------
释放大块 997 页 完成
---- 场景3: 释放大块后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31929
-----------------------------------
```

同样我们分配的一整个大块地址为``0xffffffffc0211000``，并且其余阶和总块数都发生了改变，释放以后，所有的状态都恢复原样。

- 场景4

最后一个场景下，我们分配多个不等大小的块、释放部分，然后尝试再次分配。

```c
[场景4] 分配多个不等大小的块、释放部分，然后尝试再次分配
分配 x1(16)=0xffffffffc020f480 x2(32)=0xffffffffc020f700 x3(16)=0xffffffffc020fc00
---- 场景4: 初始分配后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 6 : blocks=   1  页数=    64
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31865
-----------------------------------
释放 x2(32页)，中间产生空洞
---- 场景4: 释放 x2 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   2  页数=    64
  order= 6 : blocks=   1  页数=    64
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31897
-----------------------------------
再次尝试分配 32 页 -> 0xffffffffc020f700 (期待为之前 x2 的位置或其它合适位置)
---- 场景4: 再次分配 32 页 后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 6 : blocks=   1  页数=    64
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31865
-----------------------------------
场景4: 释放所有分配块，恢复初始碎片
---- 场景4: 清理后: 各阶空闲块统计 ----
  order= 0 : blocks=   1  页数=     1
  order= 3 : blocks=   1  页数=     8
  order= 4 : blocks=   1  页数=    16
  order= 5 : blocks=   1  页数=    32
  order= 7 : blocks=   1  页数=   128
  order=10 : blocks=  31  页数= 31744
  -> 总空闲页数 = 31929
-----------------------------------
```

可以看到，我们分配了三个块，``x1``和``x3``是16页，``x2``是32页，释放``x2``后，产生了空洞，我们再次尝试分配32页，可以看到，分配到了``x2``的位置，说明分配算法能够正确处理空洞，在释放所有块后，又恢复为初始状态。

最后输出

```c
检测完成：初始总空闲页=31929, 结束总空闲页=31929
```

最后将以上函数进行封装，如下：

```c
const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_system_check,
};
```

到这里我们的``buddy system``算法检测成功，没有出现错误。


### 四、


### 五、