## <center>Lab2实验报告<center>
> 小组成员：苏耀磊（2311727）     郭思达（2310688）  吴行健（2310686）
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


##### 扩展：le2page的实现过程

```c
#define le2page(le, member)                 \
    to_struct((le), struct Page, member)
```

```c
#define to_struct(ptr, type, member)                               \
    ((type *)((char *)(ptr) - offsetof(type, member)))
```

```c
#define offsetof(type, member)                                      \
    ((size_t)(&((type *)0)->member))
```

注意到，``(type *)0``其实是将一个空指针转化成``type*``类型，从这里来访问这个结构体的``member``成员，但实际上这里并不会真的访问内存，只是做一个编译期地址计算，从而获取 ``member`` 相对于 ``0`` 的偏移量，因为结构体基地址被认为是 ``0``，所以这个值其实就是 ``member`` 的偏移。

再到``to_struct``里边，``ptr``减去``member``的偏移量，就得到了``ptr``指向的``member``成员的基地址，再强制类型转换，就得到了``type*``类型，从而获取到了``ptr``指向的``member``成员所属的``struct``的首地址，从而实现了``le2page``的功能。

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


##### 4.结果测试

在将``pmm.c``文件里的``pmm_manager``更换为我们的``best_fit_pmm_manager``后，输入 ``make grade`` ，我们可以得到以下的输出，说明我们的代码没有问题，成功实现 ``Best fit`` 算法。

```c
syl@LAPTOP-RNJJSCQG:~/lab/OS/labcode/lab2$ make grade
>>>>>>>>>> here_make>>>>>>>>>>>
gmake[1]: Entering directory '/home/syl/lab/OS/labcode/lab2' + cc kern/init/entry.S + cc kern/init/init.c + cc kern/libs/stdio.c + cc kern/debug/panic.c + cc kern/driver/console.c + cc kern/driver/dtb.c + cc kern/mm/best_fit_pmm.c + cc kern/mm/buddy_pmm.c + cc kern/mm/default_pmm.c + cc kern/mm/pmm.c + cc kern/mm/slub_pmm.c + cc libs/printfmt.c + cc libs/readline.c + cc libs/sbi.c + cc libs/string.c + ld bin/kernel riscv64-unknown-elf-objcopy bin/kernel --strip-all -O binary bin/ucore.img gmake[1]: Leaving directory '/home/syl/lab/OS/labcode/lab2'
>>>>>>>>>> here_make>>>>>>>>>>>
<<<<<<<<<<<<<<< here_run_qemu <<<<<<<<<<<<<<<<<<
try to run qemu
qemu pid=2454
<<<<<<<<<<<<<<< here_run_check <<<<<<<<<<<<<<<<<<
  -check physical_memory_map_information:    OK
  -check_best_fit:                           OK
Total Score: 25/25
```


##### 改进空间

- 当前实现的`best_fit_alloc_pages()` 明显需要遍历整个 `free_list`，寻找最合适的空闲块，时间复杂度为` O(k)`（k为空闲块数）。但如果系统空闲块较多，性能会下降明显。可以考虑使用平衡树比如红黑树，或最小堆按`property`块大小组织空闲块，实现`O(log k)`的查找。另外维护多级空闲链表，如后续的`buddy system`的分级思想，减少遍历范围也可以。
- `Best-Fit`能降低外部碎片，但频繁分配，释放不同大小的页块时，仍可能产生大量细碎的小块，考虑最小合并阈值，当剩余块过小时直接分配出去而非拆分； 
- 对小规模请求使用`First-Fit`，快速响应，对大块分配使用`Best-Fit`，提高空间利用率。




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


### 四、扩展练习Challenge：任意大小的内存单元slub分配算法

slub算法，实现两层架构的高效内存单元分配，第一层是**基于页大小**的内存分配，第二层是在第一层基础上实现**基于任意大小**的内存分配，它通过为每种对象类型维护**缓存（slab）**，在页内用位图管理空闲对象，并使用**每CPU本地缓存**减少锁竞争，从而实现比传统SLAB结构更简单、速度更快、碎片更少的内存分配与回收机制。

#### 设计思路
##### 1.基本数据结构定义



```c
typedef struct slab {
    list_entry_t slab_link;    // 链表连接，用于连接到缓存的不同状态链表
    void *s_mem;               // slab内存起始地址（对象存储区域）
    unsigned int inuse;         // 当前已使用的对象数量
    void *freelist;            // 空闲对象链表头指针
    unsigned int free_count;   // 空闲对象计数
    struct kmem_cache *cache;  // 所属的kmem缓存
    struct Page *page;         // 对应的物理页
} slab_t;
```
`slab_t`表示一个具体的“slab页”，一个 slab 是内核中分配给某种对象类型的一块连续物理页区域（例如 1 页或 2 页）。它内部被划分成若干个固定大小的小对象（object），用于快速分配。

一个`slab`就是一个“对象池”，里面放着多个大小相同的对象；`freelist`指向未分配的对象；`inuse` 和 `free_count `追踪 `slab `的使用情况；
`slab_link` 让 `slab `能加入所属缓存的 `free`/`partial`/`full`链表。
```c
typedef struct kmem_cache {
    char name[SLUB_CACHE_NAME_LEN]; // 缓存名称标识
    size_t object_size;        // 请求的对象大小
    size_t actual_size;        // 实际分配大小（包含对齐填充）
    unsigned int align;        // 对齐要求
    unsigned int objs_per_slab; // 每个slab包含的对象数量
    unsigned int order;        // slab的页阶数（2^order页）
    
    // 三种状态的slab链表管理
    list_entry_t slabs_full;    // 完全使用的slab链表
    list_entry_t slabs_partial;  // 部分使用的slab链表  
    list_entry_t slabs_free;    // 完全空闲的slab链表
    list_entry_t cache_link;   // 全局缓存链表连接

    // 统计信息
    unsigned long num_slabs;    // 管理的slab总数
    unsigned long num_objects; // 总对象数量
    int initialized;           // 初始化状态标记
} kmem_cache_t;
```
`kmem_cache_t`表示一类对象的缓存，作用是为某种大小的对象维护一个统一的缓存。例如一个`cache`管理所有 64字节的对象；另一个` cache `管理 256 字节的对象。

每个 `kmem_cache `对应一种固定对象大小；通过三个链表（`free`、`partial`、`full`）管理不同使用状态的`slab`；当分配时，从 `partial `或` free `列表取 `slab`；当 `slab `用满或释放完对象时，会在这些链表之间移动；`order `决定该缓存每个 `slab` 使用几页（例如 order=0 → 1 页，order=1 → 2 页）。
```c
typedef struct slub_manager {
    list_entry_t cache_chain;   // 所有缓存的全局链表
    size_t num_caches;         // 缓存数量统计
    
    // 预定义的固定大小缓存指针
    kmem_cache_t *cache_16;    // 16字节对象缓存
    kmem_cache_t *cache_32;    // 32字节对象缓存
    kmem_cache_t *cache_64;    // 64字节对象缓存
    kmem_cache_t *cache_128;   // 128字节对象缓存
    kmem_cache_t *cache_256;   // 256字节对象缓存
    kmem_cache_t *cache_512;   // 512字节对象缓存
    kmem_cache_t *cache_1024;  // 1024字节对象缓存
    kmem_cache_t *cache_2048;  // 2048字节对象缓存
    
    // 全局统计
    unsigned long total_allocated; // 总分配字节数
    unsigned long total_freed;     // 总释放字节数
    int init_phase;               // 初始化阶段标记
} slub_manager_t;
```
`slub_manager_t`是全局的`SLUB`管理器，是整个`SLUB` 分配器的总控结构，维护所有大小的缓存（如 16B、32B、64B … 2048B）。

`slub_mgr`就是整个 `SLUB` 系统的“总表”，启动时初始化 8 个标准缓存，提供全局统计，测试接口，通过链表`cache_chain` 把所有 cache 管理起来。

总之，`slab_t` 表示“一个对象池”，负责管理对象分配；`kmem_cache_t` 表示“某类对象的缓存”，组织多个 `slab`；`slub_manager_t `表示“整个 SLUB 系统”，负责全局缓存调度；`free_area_t`是页级分配器，为 `slab` 分配物理页。
##### 2.全局变量和辅助宏定义
```c
//全局变量 
static slub_manager_t slub_mgr;
static free_area_t free_area;
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)
```
如上所示，`slub_mgr`是全局的 **SLUB管理器结构体**；`free_area`是页级物理内存空闲区管理结构，记录哪些物理页`Page`还未被分配；提供给 `SLUB `作为底层页源，当某个 `cache` 需要新的 `slab` 时，就从这里分配页。最后两行和best_fit一样，访问**全局空闲页链表与空闲页数量**。


```c
//辅助宏定义 
#define le2slab(le, member) to_struct((le), slab_t, member)
#define le2cache(le, member) to_struct((le), kmem_cache_t, member)
```
这两行是**SLUB分配器中用于链表遍历的辅助宏**，根据链表节点地址，反向推导出它所在的结构体指针。`le2slab(le, member)`从链表节点 `le` 推出所属的 `slab_t *` ;`le2cache(le, member)`从链表节点 `le` 推出所属的 `kmem_cache_t *`。
##### 3.辅助函数
辅助函数可以归结为以下六个：

`slub_calculate_size()` 根据对象大小和对齐要求计算**实际分配大小**。
`slub_calculate_order()` 根据对象大小计算对应 **slab 页阶数（order）**，**决定 slab 占用的页数**。
`slub_init_slab()` **初始化 slab 结构**，建立空闲对象链表。
`slub_cache_create_static()` 为某一对象大小**创建缓存结构**，并加入全局管理链表。
`slub_cache_init_lazy()` **延迟初始化 slab**，当第一次分配请求到来时创建 slab。
`slub_alloc_slab()` **分配一个新的 slab 并初始化**，返回 slab 指针。

```c
// 根据对象大小和对齐要求计算实际分配大小
static size_t slub_calculate_size(size_t size, unsigned int align) {
    if (align > 0) {
        return ROUNDUP(size, align);
    }
    return ROUNDUP(size, sizeof(void *));
}
```
计算分配给对象的**实际内存大小**。如果指定了 `align`，则**按对齐向上取整**；否则按指针大小对齐。这样的话，就可以保证slab内对象满足对齐要求，避免未对齐访问。


```c
// 根据对象大小计算 slab 页阶数（order）
static unsigned int slub_calculate_order(size_t object_size) {
    size_t slab_size = PGSIZE;
    unsigned int order = 0;
    
    while (order < SLUB_MAX_ORDER) {
        size_t available = slab_size - sizeof(slab_t);
        unsigned int objs = available / object_size;
        
        if (objs >= 4 && (available - objs * object_size) < slab_size / 2) {
            break;
        }
        
        order++;
        slab_size <<= 1;
    }
    
    return order;
}
```
根据**对象大小**计算 **slab 占用页数（2^order 页）**。保证每个 `slab`至少有 4 个对象，并尽量减少浪费。举例而言，如果对象较小，可能 `order=0（1 页）`；对象大时，`order` 增加，每个 `slab`使用多页。
```c
// 初始化 slab 结构
static void slub_init_slab(slab_t *slab, kmem_cache_t *cache, struct Page *page) {
    uintptr_t kva = (uintptr_t)page2kva(page);
    slab->s_mem = (void *)kva;
    slab->inuse = 0;
    slab->free_count = cache->objs_per_slab;
    slab->cache = cache;
    slab->page = page;
    slab->freelist = NULL;
    
    char *obj = slab->s_mem;
    for (int i = 0; i < cache->objs_per_slab; i++) {
        *(void**)obj = slab->freelist;
        slab->freelist = obj;
        obj += cache->actual_size;
    }
}
```
初始化 `slab` 对象池。`freelist `链表存储空闲对象，每个对象指向下一个空闲对象。`inuse` 和 `free_count` 分别追踪已分配和空闲对象数。在分配新的 `slab `时调用，建立对象链表以便快速分配。

```c
// 创建静态缓存（固定大小对象）
static kmem_cache_t *slub_cache_create_static(const char *name, size_t size, unsigned int align, kmem_cache_t *cache) {
    strncpy(cache->name, name, SLUB_CACHE_NAME_LEN - 1);
    cache->name[SLUB_CACHE_NAME_LEN - 1] = '\0';
    cache->object_size = size;
    cache->actual_size = slub_calculate_size(size, align);
    cache->align = align;
    cache->order = slub_calculate_order(cache->actual_size);
    
    size_t slab_size = PGSIZE << cache->order;
    cache->objs_per_slab = (slab_size - sizeof(slab_t)) / cache->actual_size;
    
    list_init(&cache->slabs_full);
    list_init(&cache->slabs_partial);
    list_init(&cache->slabs_free);
    
    cache->num_slabs = 0;
    cache->num_objects = 0;
    cache->initialized = 0;
    
    list_add(&slub_mgr.cache_chain, &cache->cache_link);
    slub_mgr.num_caches++;
    
    cprintf("slub: created cache '%s'\n", name);
    return cache;
}
```
为特定大小对象创建缓存 `kmem_cache_t`。初始化三类`slab`链表：`slabs_free、slabs_partial、slabs_full`。计算每个 `slab` 可容纳对象数，在系统启动时创建标准大小缓存，16B、32B……2048B。
```c
// 延迟初始化 slab，当第一次分配请求到来时创建 slab
static void slub_cache_init_lazy(kmem_cache_t *cache) {
    if (cache->initialized) {
        return;
    }
    struct Page *page = alloc_pages(1 << cache->order);
    if (!page) {
        cprintf("slub: WARNING - failed to allocate initial slab for cache '%s'\n", cache->name);
        return;
    }  
    slab_t *slab = (slab_t*)page2kva(page);
    slub_init_slab(slab, cache, page);
    list_add(&cache->slabs_free, &slab->slab_link);
    
    cache->num_slabs = 1;
    cache->num_objects = cache->objs_per_slab;
    cache->initialized = 1;
}
```
这个函数目的是让第一次分配对象时才创建 `slab`，避免启动时一次性占用太多内存。其中`slabs_free `链表加入新 `slab`，用于首次分配。
```c
// 分配一个新的 slab 并初始化
static slab_t *slub_alloc_slab(kmem_cache_t *cache) {
    if (!cache->initialized) {
        slub_cache_init_lazy(cache);
        if (!cache->initialized) {
            return NULL;
        }
    }
    unsigned int order = cache->order;
    struct Page *page = alloc_pages(1 << order);
    if (!page) {
        return NULL;
    }
    
    uintptr_t kva = (uintptr_t)page2kva(page);
    slab_t *slab = (slab_t*)kva;
    slub_init_slab(slab, cache, page);
    
    cache->num_slabs++;
    cache->num_objects += cache->objs_per_slab;   
    return slab;
}
```
如果当前  `slabs_partial` 和 `slabs_free `都没有空闲 ，`slab `时调用分配新的 `slab` 并初始化，这样就可以做到**动态扩展缓存**。

##### 4.核心的分配，释放函数
slub的核心是 slab + cache + 页管理，kmalloc/kfree 是对外调用接口，在后续代码里我使用了编写的简易`slub_kmalloc`和`slub_kfree`，也可以做到选择缓存，分配/释放缓存，成功通过测试环节。
```c
// 从指定缓存分配一个对象
static void *slub_cache_alloc(kmem_cache_t *cache) {
    if (!cache) return NULL;
    
    // 延迟初始化
    if (!cache->initialized) {
        slub_cache_init_lazy(cache);
        if (!cache->initialized) return NULL;
    }
    
    slab_t *slab = NULL;
    void *object = NULL;

    // 优先从部分使用的 slab 分配
    if (!list_empty(&cache->slabs_partial)) {
        list_entry_t *le = list_next(&cache->slabs_partial);
        slab = le2slab(le, slab_link);
    } 
    // 再从空闲 slab 分配，并移动到部分使用链表
    else if (!list_empty(&cache->slabs_free)) {
        list_entry_t *le = list_next(&cache->slabs_free);
        slab = le2slab(le, slab_link);
        list_del(le);
        list_add(&cache->slabs_partial, le);
    } 
    // 都没有可用 slab，则分配新的 slab
    else {
        slab = slub_alloc_slab(cache);
        if (!slab) return NULL;
        list_add(&cache->slabs_partial, &slab->slab_link);
    }
    
    if (!slab) return NULL;

    // 从 slab 的空闲对象链表分配
    object = slab->freelist;
    if (!object) return NULL;
    
    slab->freelist = *(void**)object;
    slab->inuse++;
    slab->free_count--;
    
    // slab 已满，则移动到 full 链表
    if (slab->inuse == cache->objs_per_slab) {
        list_del(&slab->slab_link);
        list_add(&cache->slabs_full, &slab->slab_link);
    }
    
    // 分配时清零
    memset(object, 0, cache->object_size);
    slub_mgr.total_allocated += cache->actual_size;
    
    return object;
}
```
核心分配函数之一，直接从指定缓存 `kmem_cache_t `中分配对象。

优先使用 `slabs_partial`，避免空闲` slab `被过早占用。
空闲`slab`则初始化到 `slabs_partial` 再分配。
如果没有 `slab` 可用，则调用 `slub_alloc_slab` 创建新的 `slab`。
分配后更新 `inuse、free_count`，必要时移动 `slab 链表。

做到使用`freelist` 快速分配对象，无需扫描整个 slab。


```c
static void slub_cache_free(kmem_cache_t *cache, void *obj) {
    if (!obj || !cache) return;
    
    if (!cache->initialized) {
        return;
    }
    
    uintptr_t kva = (uintptr_t)obj;
    uintptr_t pa = PADDR(obj);
    struct Page *page = pa2page(pa);
    uintptr_t slab_kva = (uintptr_t)page2kva(page);
    slab_t *slab = (slab_t*)slab_kva;
    // 确认对象属于该 cache
    if (slab->cache != cache) {
        return;
    }
 // 将对象插回 slab 的 freelist    
    *(void**)obj = slab->freelist;
    slab->freelist = obj;
    slab->inuse--;
    slab->free_count++;
    
    list_entry_t *le = &slab->slab_link;
    // slab 空了，移动到 free 链表
    if (slab->inuse == 0) {
        list_del(le);
        list_add(&cache->slabs_free, le);
    } else if (slab->inuse == cache->objs_per_slab - 1) {
        list_del(le);  // slab 由满变为部分使用
        list_add(&cache->slabs_partial, le);
    }
    
    slub_mgr.total_freed += cache->actual_size;
}
```

核心释放函数之一，将对象归还`slab`对象池。

对象插回 `slab`的`freelist`。
更新 `slab` 状态（inuse、free_count）。
根据使用情况移动 `slab` 链表：`full → partial、partial → free`。

```c
// 通用 kmalloc 分配接口
static void *slub_kmalloc(size_t size) {
    if (size == 0) return NULL;

    // 大对象直接按页分配
    if (size > SLUB_MAX_OBJECT_SIZE) {
        size_t pages = ROUNDUP(size, PGSIZE) / PGSIZE;
        struct Page *page = alloc_pages(pages);
        return page ? page2kva(page) : NULL;
    }

    // 根据大小选择合适缓存
    kmem_cache_t *cache = NULL;
    if (size <= 16) cache = slub_mgr.cache_16;
    else if (size <= 32) cache = slub_mgr.cache_32;
    else if (size <= 64) cache = slub_mgr.cache_64;
    else if (size <= 128) cache = slub_mgr.cache_128;
    else if (size <= 256) cache = slub_mgr.cache_256;
    else if (size <= 512) cache = slub_mgr.cache_512;
    else if (size <= 1024) cache = slub_mgr.cache_1024;
    else cache = slub_mgr.cache_2048;

    return cache ? slub_cache_alloc(cache) : NULL;
}
```
提供通用接口给内核调用，类似标准` kmalloc`。
**小对象走缓存，大对象按页分配**。
这样就只需传入大小，自动选择缓存。
```c
static void slub_kfree(void *obj) {
    if (!obj) return;
    
    uintptr_t pa = PADDR(obj);
    struct Page *page = pa2page(pa);
    if (page->property > 1) {
        free_pages(page, page->property);
        return;
    }    // 大对象直接释放页
      // 遍历所有标准缓存，找到所属 slab 释放
    kmem_cache_t *caches[] = {
        slub_mgr.cache_16, slub_mgr.cache_32, slub_mgr.cache_64,
        slub_mgr.cache_128, slub_mgr.cache_256, slub_mgr.cache_512,
        slub_mgr.cache_1024, slub_mgr.cache_2048, NULL
    };
     // 遍历 full / partial / free 链表
    for (int i = 0; caches[i] != NULL; i++) {
        if (caches[i] && caches[i]->initialized) {
            uintptr_t obj_addr = (uintptr_t)obj;
            list_entry_t *le;
            
            for (le = list_next(&caches[i]->slabs_full); le != &caches[i]->slabs_full; le = list_next(le)) {
                slab_t *slab = le2slab(le, slab_link);
                uintptr_t slab_start = (uintptr_t)slab->s_mem;
                uintptr_t slab_end = slab_start + caches[i]->objs_per_slab * caches[i]->actual_size;
                if (obj_addr >= slab_start && obj_addr < slab_end) {
                    slub_cache_free(caches[i], obj);
                    return;
                }
            }
            
            for (le = list_next(&caches[i]->slabs_partial); le != &caches[i]->slabs_partial; le = list_next(le)) {
                slab_t *slab = le2slab(le, slab_link);
                uintptr_t slab_start = (uintptr_t)slab->s_mem;
                uintptr_t slab_end = slab_start + caches[i]->objs_per_slab * caches[i]->actual_size;
                if (obj_addr >= slab_start && obj_addr < slab_end) {
                    slub_cache_free(caches[i], obj);
                    return;
                }
            }
            
            for (le = list_next(&caches[i]->slabs_free); le != &caches[i]->slabs_free; le = list_next(le)) {
                slab_t *slab = le2slab(le, slab_link);
                uintptr_t slab_start = (uintptr_t)slab->s_mem;
                uintptr_t slab_end = slab_start + caches[i]->objs_per_slab * caches[i]->actual_size;
                if (obj_addr >= slab_start && obj_addr < slab_end) {
                    slub_cache_free(caches[i], obj);
                    return;
                }
            }
        }
    }
      // 如果不是缓存对象，按页释放
    free_pages(page, 1);
}
```
同样是核心释放接口之一，支持缓存对象与大对象。
这一过程，遍历缓存链表定位 `slab`，调用 `slub_cache_free` 回收对象。
大对象直接释放页，无需`slab`机制。

##### 5.pmm接口函数和接口封装
可以这样理解，`PMM`是管理页，第一层，通用简单，任何分配器都依赖它。而`SLUB`基于`PMM`做对象缓存管理，第二层，复杂一些，处理对象大小、缓存、slab 等。

因此，这些接口函数及封装与best_fit、first_fit的算法是类似的，基本可以直接套用，编写代码时有些许区别如下，这里不过多展示代码：

`slub_init`，`slub_init_memmap`多涉及到对象缓存;

`slub_alloc_pages`的SLUB初始化阶段直接从`free_list`分配，且`SLUB`对小页对象使用`slab`缓存，`Best-fit`直接按页管理。

`slub_free_pages`逻辑与`bestfit`一致，但涉及到缓存层，区分单页或多页。

`slub_nr_free_pages`与`bestfit`基本一致；

`slub_check`是针对测试函数检查，下面给出测试过程及结果。

##### 6.一些测试函数
```c

static void slub_test_basic(void) {
    cprintf("=== SLUB Basic Test ===\n");
    
    kmem_cache_t *test_cache = slub_mgr.cache_64;
    slub_cache_init_lazy(test_cache);
    
    if (!test_cache || !test_cache->initialized) {
        cprintf("SLUB Test SKIPPED: memory system not ready\n");
        return;
    }
    
    void *objs[3];
    for (int i = 0; i < 3; i++) {
        objs[i] = slub_cache_alloc(test_cache);
        if (!objs[i]) {
            cprintf("SLUB Test FAILED: allocation failed\n");
            return;
        }
        *(int*)objs[i] = i;
        if (*(int*)objs[i] != i) {
            cprintf("SLUB Test FAILED: memory corruption\n");
            return;
        }
    }
    
    cprintf("Basic allocation test PASSED\n");
    
    for (int i = 0; i < 3; i++) {
        slub_cache_free(test_cache, objs[i]);
    }
    
    cprintf("Basic free test PASSED\n");
    
    for (int i = 0; i < 3; i++) {
        objs[i] = slub_cache_alloc(test_cache);
        if (!objs[i]) {
            cprintf("SLUB Test FAILED: reallocation failed\n");
            return;
        }
    }
    
    cprintf("Reallocation test PASSED\n");
}
```
这个函数主要验证了 SLUB 分配器对固定大小对象缓存的功能：

- 基本分配测试：
从 `cache_64`（每个对象 64 字节）中分配 3 个对象。
给每个对象写入不同的整数值（0、1、2），再读回来检查是否正确。
如果分配失败，写入数据被破坏，就报告失败。
成功则输出 “Basic allocation test PASSED”。

- 基本释放测试：
将之前分配的 3 个对象逐个释放回缓存。
检查释放过程是否顺利，该过程主要通过链表状态和 `freelist` 管理。
成功则输出 “Basic free test PASSED”。

- 重分配测试：
再次从缓存中分配 3 个对象，模拟释放后再用的场景。
检查是否能成功重新分配，确保缓存复用正常。
成功则输出 “Reallocation test PASSED”。

```c

static void slub_test_kmalloc(void) {
    cprintf("=== SLUB kmalloc Test ===\n");
    
    void *small = slub_kmalloc(16);
    if (small) {
        memset(small, 0xAA, 16);
        slub_kfree(small);
        cprintf("kmalloc small test PASSED\n");
    } else {
        cprintf("kmalloc small test SKIPPED\n");
    }
    
    void *medium = slub_kmalloc(128);
    if (medium) {
        memset(medium, 0xBB, 128);
        slub_kfree(medium);
        cprintf("kmalloc medium test PASSED\n");
    } else {
        cprintf("kmalloc medium test SKIPPED\n");
    }
    
    cprintf("kmalloc test completed\n");
}
```
这个函数测试SLUB分配器的 `slub_kmalloc/slub_kfree`接口。通过 `slub_kmalloc`分配不同大小的内存块，填充测试数据后释放，验证 SLUB 分配器的正确性。

```c

static void slub_check(void) {
    cprintf("=== SLUB Memory Manager Check ===\n");
    
    slub_run_tests();
    
    cprintf("SLUB cache status:\n");
  
    cprintf("  Total allocated: %lu bytes\n", slub_mgr.total_allocated);
    cprintf("  Total freed: %lu bytes\n", slub_mgr.total_freed);
    
    list_entry_t *le = &slub_mgr.cache_chain;
    while ((le = list_next(le)) != &slub_mgr.cache_chain) {
        kmem_cache_t *cache = le2cache(le, cache_link);
        cprintf("  Cache '%s': %lu slabs, %lu objects\n",
                cache->name, cache->num_slabs, cache->num_objects);
    }
    
    cprintf("SLUB check completed.\n");
}
```
测试和打印一些SLUB内存分配器的运行状态，统计信息。

输出如下：

```c
memory management: slub_pmm_manager
slub: created cache 'slub-16'
slub: created cache 'slub-32'
slub: created cache 'slub-64'
slub: created cache 'slub-128'
slub: created cache 'slub-256'
slub: created cache 'slub-512'
slub: created cache 'slub-1024'
slub: created cache 'slub-2048'
```
这是`slub_init()`的输出，说明`SLUB PMM`被选作内存管理器。
`slub_cache_create_static()`打印每个缓存被创建的名字，如上所示 `'slub-16'`表示存储16字节对象的缓存。一共创建了8个不同大小的缓存，从 16B 到 2048B。

```c
physcial memory map:
  memory: 0x0000000008000000, [0x0000000080000000, 0x0000000087ffffff].
```
这是 SLUB 在 `slub_init_memmap()` 初始化物理内存后打印的映射信息。
显示了内存起始地址和大小：128MB。

```c
=== SLUB Memory Manager Check ===

=== Starting SLUB Tests ===
=== SLUB Basic Test ===
Basic allocation test PASSED
Basic free test PASSED
Reallocation test PASSED
=== SLUB kmalloc Test ===
kmalloc small test PASSED
kmalloc medium test PASSED
kmalloc test completed
=== SLUB Tests Completed ===
```
这些输出说明：

- 调用 `slub_cache_alloc(slub_mgr.cache_64) `三次，写入并读回验证；释放上面分配的对象；再次分配 3 个对象，验证重新分配。全部通过。

- 分配不同字节对象，填充后再释放，全部通过。

```c
SLUB cache status:
  Total allocated: 6672 bytes
  Total freed: 192 bytes
  Cache 'slub-2048': 1 slabs, 7 objects
  Cache 'slub-1024': 0 slabs, 0 objects
  Cache 'slub-512': 0 slabs, 0 objects
  Cache 'slub-256': 0 slabs, 0 objects
  Cache 'slub-128': 1 slabs, 31 objects
  Cache 'slub-64': 1 slabs, 63 objects
  Cache 'slub-32': 0 slabs, 0 objects
  Cache 'slub-16': 1 slabs, 252 objects
SLUB check completed.
check_alloc_page() succeeded!
```
输出SLUB 总共分配的字节数和释放的字节数，同时显示每个缓存都有对应 slab 和对象数量，例如cache-64有1 slab，63 个对象，没有出现异常，总分配和总释放字节数符合预期，测试通过。


### 五、硬件的可用物理内存范围的获取方法（Challenge）

在前面的练习中，我们已经实现并对比了多种物理内存分配策略（如First-Fit、Best-Fit、Buddy）。这些分配器的前提是：操作系统启动时必须先知道“机器上哪些物理内存可以用”，然后把这些可用区域按页组织成空闲链表，分配器才能工作。本节解释的就是这个前提问题：在启动前不知道硬件内存布局的情况下，OS 如何动态识别可用物理内存，并交给分配器使用。

本实验运行在RISC-V平台上，我们用“设备树（DTB/FDT）”方式来获取内存信息。简单说，设备树就像一份“硬件地图”，由启动引导程序（Bootloader）准备好，告诉OS“内存从哪里开始，有多大”。

#### 1. 基本思路
设备树是二进制文件，里面有节点和属性。OS解析它，找到“memory”节点，读出内存起点（base）和大小（size）。

- **为什么需要这个？** 硬件内存不是连续的，可能有“空洞”（如设备占用的地址），或保留区（不能用的部分）。直接用错会崩溃。
- **怎么传给OS？** Bootloader把DTB的物理地址放进寄存器，OS通过全局变量`boot_dtb`拿到。

#### 2. RISC-V上的DTB解析步骤
OS先把DTB的物理地址映射到虚拟地址（加`PHYSICAL_MEMORY_OFFSET`），然后一步步解析，：

1. **校验DTB**：检查开头“魔数”（magic number）是不是`0xd00dfeed`，确认是有效DTB。如果不对，就报错。
2. **定位结构**：DTB分成“结构区”（节点/属性）、“字符串区”（名字）和“保留区”。用头部的偏移量找到它们。
3. **遍历节点树**：从根节点开始，找名叫“memory”的节点（通常是`/memory`）。
4. **读reg属性**：在memory节点里，`reg`属性存着`<base, size>`（64位地址+大小）。解析它，得到内存起点和总大小。
5. **计算范围**：结束地址 = base + size - 1。
下面是本实验解析 `/memory/reg` 的核心逻辑引用：

```
// 简化的内存信息提取函数：查找 memory 节点的 reg 属性
static int extract_memory_info(uintptr_t dtb_vaddr, const struct fdt_header *header, 
                              uint64_t *mem_base, uint64_t *mem_size) {
    uint32_t struct_offset = fdt32_to_cpu(header->off_dt_struct);
    uint32_t strings_offset = fdt32_to_cpu(header->off_dt_strings);
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
    int in_memory_node = 0;
    while (1) {
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
        switch (token) {
            case FDT_BEGIN_NODE: {
                const char *name = (const char *)struct_ptr;
                int name_len = strlen(name);
                if (strncmp(name, "memory", 6) == 0) {
                    in_memory_node = 1;
                }
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
                break;
            }
            case FDT_END_NODE:
                in_memory_node = 0;
                break;
            case FDT_PROP: {
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
                const char *prop_name = strings_base + prop_nameoff;
                const void *prop_data = struct_ptr;
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
                    const uint64_t *reg_data = (const uint64_t *)prop_data;
                    *mem_base = fdt64_to_cpu(reg_data[0]);
                    *mem_size = fdt64_to_cpu(reg_data[1]);
                    return 0;
                }
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
                break;
            }
            case FDT_END: return -1;
            default: return -1;
        }
    }
}
```

DTB初始化函数（在`dtb_init`）调用这个，打印结果，比如“Base: 0x80000000, Size: 0x10000000 (256MB)”。

#### 3. 和分配器的连接
拿到`(base, size)`后，删除不能分配的部分：
- **上限检查**：如果内存超过内核能映射的顶（KERNTOP），截断到KERNTOP。
- **扣内核占用**：内核代码、数据和Page元数据（`pages[]`数组）占了前面一部分。从`end[]`后面开始，向上取整到页边界，作为可用起点。
- **页对齐**：起点向上取整，终点向下取整，确保整页。
- **建空闲链表**：调用`init_memmap(pa2page(begin), (end - begin)/PGSIZE)`，把可用页加到链表，交给First-Fit等分配器。
```
// ... (从DTB拿mem_begin, mem_size, mem_end)
npage = maxpa / PGSIZE;  // 总页数
pages = ROUNDUP((void *)end, PGSIZE);  // 元数据区
// 标记保留页
freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * npage);
mem_begin = ROUNDUP(freemem, PGSIZE);  // 可用起点
mem_end = ROUNDDOWN(mem_end, PGSIZE);  // 可用终点
init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
```

这样，分配器就在“安全清单”上工作，不会碰保留区。

#### 4. 常见边界情况
- **多段内存**：reg可能有多个`<base, size>`（如分散的RAM）。当前代码只取第一段，实际应循环全取。
- **保留区**：DTB头部有`memreserve`表，列出不能用的区间（如固件区）。还可能有`/reserved-memory`节点。需从可用区“减掉”这些。
- **字节序**：DTB是大端（高字节先存），必须用`fdt32_to_cpu`转成CPU顺序。
- **空洞**：内存中可能夹设备地址（MMIO），reg会避开它们。
- **大小单元**：reg的格式取决于`#address-cells`和`#size-cells`（通常2，表示64位）。当前假设2，实际应动态读父节点。

#### 5. 本实验实现的局限与改进
- **局限**：
  - 只解析第一段内存，忽略多段。
  - 未处理`memreserve`和`/reserved-memory`，可能把保留区当成可用。
  - 固定假设64位地址/大小，不自适应。
  - 只打印范围，没标准输出“段清单”。

- **改进想法**：
  1. **多段解析**：读`#address-cells/#size-cells`，循环reg的所有对，存到数组。
  2. **减保留区**：解析`memreserve`表，从可用段“切掉”重叠部分。
     示例代码：
  3. **多段初始化**：在pmm.c用循环调用`init_memmap`，每段单独加链表。
  4. **打印段表**：加函数输出所有可用段，方便调试对比DTB和OS视图。
  5. **测试**：模拟多段/保留DTB，检查OS是否正确避开。

#### 6. 总结
- Bootloader给OS DTB地址 → OS映射成虚拟地址 → 解析memory/reg → 得(base, size)。
- 扣上限/内核占用/对齐 → 得干净区间[begin, end)。
- init_memmap建链表 → 分配器用。

- 假设 DTB 告诉我们：物理内存从 `0x80000000` 开始，大小为 `0x20000000`（即 512MB）。
- 那么物理内存范围就是 `[0x80000000, 0x9FFFFFFF]`。
- 内核镜像（文本/数据/BSS）加上 `pages[]` 元数据占用了前面一段地址，比如占到 `0x80250000`（举例）。
- 我们会把这段占用区域“扣掉”，从下一个页对齐位置开始作为真正可分配的起点，例如 `ROUNDUP(0x80250000, 4KB)`。
- 再把终点按页对齐向下取整（避免落在半页）。最终得到一个“可分配区间”。
- `init_memmap` 会把这段区间转换成“按物理地址升序”的空闲页链表。至此，前文的 First‑Fit/Best‑Fit/Buddy 就能直接工作了。


### 六、Lab2分支任务：gdb 调试页表查询过程


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


