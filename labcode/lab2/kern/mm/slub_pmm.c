// #include <pmm.h>
// #include <list.h>
// #include <string.h>
// #include <slub_pmm.h>
// #include <stdio.h>

// /* SLUB memory allocator (Simple List-based Unsorted Block) */

// // SLUB内存池的最大数目
// #define MAX_CACHE_SIZE 64

// // 定义缓存池结构体，包含每个缓存池的空闲链表
// struct slub_cache {
//     size_t size;          // 每个块的大小
//     list_entry_t free_list; // 空闲块链表
//     unsigned int nr_free;  // 当前缓存池中的空闲块数量
// };

// // 定义 free_area 数组，每个元素代表一个缓存池
// static struct slub_cache free_area[MAX_CACHE_SIZE];

// // 定义宏来访问特定 order 的 free_list 和 nr_free
// #define free_list(order)   (free_area[order].free_list)
// #define nr_free(order)     (free_area[order].nr_free)

// // 初始化 SLUB 分配器
// static void slub_init(void) {
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         free_area[i].size = (i + 1) * PGSIZE;  // 每个缓存池的大小是 PGSIZE 的倍数
//         list_init(&(free_area[i].free_list));   // 初始化链表
//         free_area[i].nr_free = 0;               // 初始化空闲块数量
//     }
// }


// static void slub_init_memmap(struct Page *base, size_t n) {
//     assert(n > 0);
//     struct Page *p = base;
//     for (; p != base + n; p++) {
//         assert(PageReserved(p));
//         p->flags = 0;
//         p->property = 0;
//         set_page_ref(p, 0);
//     }

//     base->property = n; // 这个property表示这个块有n个连续页面
//     SetPageProperty(base);

//     // 核心修复：计算总字节大小，用于匹配缓存池
//     size_t total_size = n * PGSIZE;

//     cprintf("Initializing memory block at %p with %zu pages (%zu bytes)\n", base, n, total_size);

//     int i;
//     // 方案1：寻找大小完全匹配的缓存池
//     for (i = 0; i < MAX_CACHE_SIZE; i++) {
//         // 使用总字节数进行比较
//         if (total_size == free_area[i].size) {
//             list_add(&free_area[i].free_list, &(base->page_link));
//             free_area[i].nr_free += n;
//             cprintf("Memory block added to cache[%d] of size %zu, total free: %u\n", i, free_area[i].size, free_area[i].nr_free);
//             return; // 找到后立即返回
//         }
//     }

//     // 方案2（更健壮）：如果找不到精确匹配，则寻找第一个足够大的缓存池
//     for (i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (free_area[i].size >= total_size) {
//             list_add(&free_area[i].free_list, &(base->page_link));
//             free_area[i].nr_free += n;
//             cprintf("Memory block added to larger cache[%d] of size %zu, total free: %u\n", i, free_area[i].size, free_area[i].nr_free);
//             return;
//         }
//     }

//     // 如果执行到这里，说明真的没找到合适的缓存池
//     cprintf("Warning: No suitable cache found for memory block of size %zu pages (%zu bytes)\n", n, total_size);
// }

// // 修正后的分配逻辑
// static struct Page* slub_alloc_pages(size_t n) {
//     assert(n > 0);
    
//     size_t required_size = n * PGSIZE;
//     struct slub_cache *cache = NULL;
    
//     // 寻找合适的缓存池
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (free_area[i].size >= required_size) {
//             cache = &free_area[i];
//             break;
//         }
//     }
    
//     if (cache == NULL || cache->nr_free == 0) {
//         cprintf("No cache found or no free pages for size: %zu bytes\n", required_size);
//         return NULL;
//     }
    
//     // 直接从空闲链表中获取页面
//     if (!list_empty(&cache->free_list)) {
//         list_entry_t *le = list_next(&cache->free_list);
//         struct Page *page = le2page(le, page_link);
        
//         list_del(le);
//         cache->nr_free--;
//         ClearPageProperty(page);
        
//         cprintf("Allocated %zu pages from cache[%zu], nr_free: %u\n", 
//                n, cache->size, cache->nr_free);
//         return page;
//     }
    
//     return NULL;
// }



// // 释放页面，并将其归还到相应的缓存池
// static void slub_free_pages(struct Page *base, size_t n) {
//     assert(n > 0);
//     struct Page *p = base;
//     for (; p != base + n; p++) {
//         assert(!PageReserved(p) && !PageProperty(p));
//         p->flags = 0;
//         set_page_ref(p, 0);
//     }

//     base->property = n;
//     SetPageProperty(base);

//     // 更新 nr_free 时，应该访问相应缓存池的 nr_free
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (base->property == free_area[i].size) {
//             free_area[i].nr_free += n;
//             break;
//         }
//     }

//     // 将释放的页面添加回合适的缓存池
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (base->property == free_area[i].size) {
//             list_add(&free_area[i].free_list, &(base->page_link));
//             break;
//         }
//     }

//     // 合并相邻的空闲块
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (base->property == free_area[i].size) {
//             list_entry_t *le = list_prev(&(base->page_link));
//             if (le != &free_area[i].free_list) {
//                 p = le2page(le, page_link);
//                 if (p + p->property == base) {
//                     p->property += base->property;
//                     ClearPageProperty(base);
//                     list_del(&(base->page_link));
//                     base = p;
//                 }
//             }

//             le = list_next(&(base->page_link));
//             if (le != &free_area[i].free_list) {
//                 p = le2page(le, page_link);
//                 if (base + base->property == p) {
//                     base->property += p->property;
//                     ClearPageProperty(p);
//                     list_del(&(p->page_link));
//                 }
//             }
//             break;
//         }
//     }
// }

// // 获取当前空闲的页数
// static size_t slub_nr_free_pages(void) {
//     size_t total_free = 0;
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         total_free += free_area[i].nr_free;
//     }
//     return total_free;
// }

// // SLUB 检查
// static void slub_check(void) {
//     // 类似于 basic_check，检查内存分配和释放是否正确
//     struct Page *p0, *p1, *p2;
//     p0 = p1 = p2 = NULL;
//     assert((p0 = slub_alloc_pages(1)) != NULL);
//     assert((p1 = slub_alloc_pages(1)) != NULL);
//     assert((p2 = slub_alloc_pages(1)) != NULL);

//     assert(p0 != p1 && p0 != p2 && p1 != p2);
//     assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

//     slub_free_pages(p0, 1);
//     slub_free_pages(p1, 1);
//     slub_free_pages(p2, 1);

//     assert(slub_nr_free_pages() == 3);
// }

// const struct pmm_manager slub_pmm_manager = {
//     .name = "slub_pmm_manager",
//     .init = slub_init,
//     .init_memmap = slub_init_memmap,
//     .alloc_pages = slub_alloc_pages,
//     .free_pages = slub_free_pages,
//     .nr_free_pages = slub_nr_free_pages,
//     .check = slub_check,
// };




// #include <pmm.h>
// #include <list.h>
// #include <string.h>
// #include <slub_pmm.h>
// #include <stdio.h>

// #define MAX_CACHE_SIZE 64  // 定义缓存池的最大数量
// #define PGSIZE 4096        // 页大小

// // 定义缓存池结构体，包含每个缓存池的空闲链表
// struct slub_cache {
//     size_t size;             // 每个块的大小
//     list_entry_t free_list;  // 空闲块链表
//     unsigned int nr_free;    // 当前缓存池中的空闲块数量
// };

// // 定义 free_area 数组，每个元素代表一个缓存池
// static struct slub_cache free_area[MAX_CACHE_SIZE];

// // 宏定义：访问特定 order 的 free_list 和 nr_free
// #define free_list(order)   (free_area[order].free_list)
// #define nr_free(order)     (free_area[order].nr_free)


// // SLUB 分配器初始化
// static void slub_init(void) {
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         free_area[i].size = (i + 1) * PGSIZE;  // 每个缓存池的大小是 PGSIZE 的倍数
//         list_init(&(free_area[i].free_list));   // 初始化链表
//         free_area[i].nr_free = 0;               // 初始化空闲块数量
//     }
// }

// // 初始化内存映射，将内存块组织成 Slab 形式
// static void slub_init_memmap(struct Page *base, size_t n) {
//     assert(n > 0);  // 确保 n 大于 0

//     // 清理每个页面的基础字段
//     for (struct Page *it = base; it < base + n; ++it) {
//         assert(PageReserved(it));  // 确保页面已标记为预留
//         it->flags = 0;
//         it->property = 0;
//         set_page_ref(it, 0);  // 设置引用计数为 0
//         ClearPageProperty(it);  // 清除页面的属性
//     }

//     struct Page *p = base;
//     size_t remain = n;

//     // 遍历每个页面块，按需要将其分配到缓存池
//     while (remain > 0) {
//         // 根据 n 和 PGSIZE 确定块大小
//         size_t block_size = PGSIZE;  // 默认页面大小为一个块

//         // 查找匹配的缓存池
//         int cache_index = -1;
//         for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//             if (free_area[i].size == block_size) {
//                 cache_index = i;
//                 break;
//             }
//         }

//         if (cache_index == -1) {
//             cprintf("Warning: No suitable cache found for block size %zu\n", block_size);
//             remain = 0;
//             continue;
//         }

//         // 将该内存块加入对应的缓存池
//         struct slub_cache *cache = &free_area[cache_index];
//         list_entry_t *head = &cache->free_list;
//         if (list_empty(head)) {
//             list_add(head, &p->page_link);
//         } else {
//             // 按地址顺序插入
//             list_entry_t *le = list_next(head);
//             int inserted = 0;
//             while (le != head) {
//                 struct Page *q = le2page(le, page_link);
//                 if (p < q) {
//                     list_add_before(le, &p->page_link);
//                     inserted = 1;
//                     break;
//                 }
//                 le = list_next(le);
//             }
//             if (!inserted) {
//                 list_entry_t *last = list_prev(head);
//                 list_add(last, &p->page_link);
//             }
//         }

//         cache->nr_free++;  // 更新空闲块数量

//         // 更新剩余的块数和指向下一个块
//         size_t consumed = block_size / PGSIZE;  // 一个块大小对应的页面数量
//         p += consumed;
//         remain -= consumed;
//     }

//     cprintf("Initialized memory block at %p with %zu pages\n", base, n);

//     // 调试输出
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         cprintf("Cache[%d] has %u free pages\n", i, free_area[i].nr_free);
//     }
// }



// // 分配页面，使用 SLUB 管理
// static struct Page* slub_alloc_pages(size_t n) {
//     assert(n > 0);

//     // 找到合适大小的缓存池
//     struct slub_cache *cache = NULL;
//     size_t request_size = n * PGSIZE;  // 请求的总内存大小（单位是字节）

//     // 查找合适的缓存池
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (free_area[i].size >= request_size) {
//             cache = &free_area[i];
//             break;
//         }
//     }

//     if (cache == NULL) {
//         cprintf("No cache found for requested size: %zu\n", request_size);
//         return NULL;  // 如果没有找到合适的缓存池
//     }

//     cprintf("Cache[%d] has %u free pages, requested: %zu\n", cache->size, cache->nr_free, n);

//     if (cache->nr_free < n) {
//         cprintf("Not enough free pages in cache[%d], requested: %zu, available: %u\n", cache->size, n, cache->nr_free);
//         return NULL;  // 如果缓存池中的空闲块数量不足
//     }

//     // 从缓存池中分配内存
//     struct Page *page = NULL;
//     list_entry_t *le = list_next(&cache->free_list);  
//     while (le != &cache->free_list) {
//         struct Page *p = le2page(le, page_link);
//         if (p->property >= n) {
//             page = p;
//             break;
//         }
//         le = list_next(le);
//     }

//     if (page != NULL) {
//         list_entry_t *prev = list_prev(&(page->page_link));
//         list_del(&(page->page_link));

//         if (page->property > n) {
//             struct Page *p = page + n;
//             p->property = page->property - n;
//             SetPageProperty(p);
//             list_add(prev, &(p->page_link));  
//         }

//         cache->nr_free -= n;
//         ClearPageProperty(page);

//         cprintf("Allocated %zu pages from cache[%d], nr_free: %u\n", n, cache->size, cache->nr_free);
//     } else {
//         cprintf("No suitable free block found in cache[%d] for %zu pages\n", cache->size, n);
//     }

//     return page;
// }


// // 释放页面，并将其归还到相应的缓存池
// static void slub_free_pages(struct Page *base, size_t n) {
//     assert(n > 0);
//     struct Page *p = base;
//     for (; p != base + n; p++) {
//         assert(!PageReserved(p) && !PageProperty(p));
//         p->flags = 0;
//         set_page_ref(p, 0);
//     }

//     base->property = n;
//     SetPageProperty(base);

//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (base->property == free_area[i].size) {
//             free_area[i].nr_free += n;
//             break;
//         }
//     }

//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         if (base->property == free_area[i].size) {
//             list_add(&free_area[i].free_list, &(base->page_link));
//             break;
//         }
//     }
// }

// // 获取当前空闲的页数
// static size_t slub_nr_free_pages(void) {
//     size_t total_free = 0;
//     for (int i = 0; i < MAX_CACHE_SIZE; i++) {
//         total_free += free_area[i].nr_free;
//     }
//     return total_free;
// }

// // SLUB 检查
// static void slub_check(void) {
//     struct Page *p0, *p1, *p2;
//     p0 = p1 = p2 = NULL;

//     // 分配三个页面
//     assert((p0 = slub_alloc_pages(1)) != NULL);
//     assert((p1 = slub_alloc_pages(1)) != NULL);
//     assert((p2 = slub_alloc_pages(1)) != NULL);

//     // 确保它们是不同的
//     assert(p0 != p1 && p0 != p2 && p1 != p2);
//     assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

//     // 释放三个页面
//     slub_free_pages(p0, 1);
//     slub_free_pages(p1, 1);
//     slub_free_pages(p2, 1);

//     // 检查空闲页面数是否正确
//     assert(slub_nr_free_pages() == 3);
// }

// // 定义 SLUB 管理器
// const struct pmm_manager slub_pmm_manager = {
//     .name = "slub_pmm_manager",
//     .init = slub_init,
//     .init_memmap = slub_init_memmap,
//     .alloc_pages = slub_alloc_pages,
//     .free_pages = slub_free_pages,
//     .nr_free_pages = slub_nr_free_pages,
//     .check = slub_check,
// };


#include <pmm.h>
#include <list.h>
#include <string.h>
#include <slub_pmm.h>
#include <stdio.h>

#include <pmm.h>
#include <list.h>
#include <string.h>

#define MAX_SLAB_SIZE 128  // 假设最大slab缓存区大小为128

typedef struct slab {
    struct list_entry page_link;   // 链接到slab链表
    size_t free_pages;             // 当前slab中空闲页的数量
    size_t total_pages;            // 当前slab的总页数
    struct Page *pages;            // slab中存储的页面
} slab_t;

static slab_t slab_caches[MAX_SLAB_SIZE];

static void slab_init(void) {
    memset(slab_caches, 0, sizeof(slab_caches));
}

static void slab_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    
    slab_t *slab = &slab_caches[0];  // 简化处理，假设只使用一个 slab 缓存区
    slab->pages = base;
    slab->total_pages = n;
    slab->free_pages = n;

    // 初始化每个页
    struct Page *p = base;
    for (size_t i = 0; i < n; i++, p++) {
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }
    list_add(&slab->page_link, &(base->page_link));
}

static struct Page *slab_alloc_page(struct Page *base, size_t n) {
    slab_t *slab = &slab_caches[0];  // 假设我们始终从第一个 slab 中分配内存
    if (slab->free_pages == 0) {
        return NULL;  // 如果没有空闲页，返回NULL
    }

    struct Page *page = slab->pages + (slab->total_pages - slab->free_pages);
    slab->free_pages--;
    page->flags = PG_reserved;
    page->property = 0;
    set_page_ref(page, 0);
    return page;
}

static void slab_free_page(struct Page *base, size_t n) {
    slab_t *slab = &slab_caches[0];  // 假设我们始终从第一个 slab 中释放内存
    slab->free_pages++;
    base->flags = 0;
    set_page_ref(base, 0);
}

static size_t slab_nr_free_pages(struct Page *base, size_t n) {
    slab_t *slab = &slab_caches[0];  // 假设我们始终从第一个 slab 获取空闲页数
    return slab->free_pages;
}

static void slab_check(struct Page *base, size_t n) {
    // 检查SLUB缓存的正确性
    slab_t *slab = &slab_caches[0];  // 假设我们始终检查第一个 slab
    struct Page *page = slab->pages;
    size_t free_count = 0;

    for (size_t i = 0; i < slab->total_pages; i++, page++) {
        if (page->flags == 0) {
            free_count++;
        }
    }

    assert(free_count == slab->free_pages);
}

const struct pmm_manager slub_pmm_manager = {
    .name = "slub_pmm_manager",
    .init = slab_init,
    .init_memmap = slab_init_memmap,
    .alloc_pages = slab_alloc_page,
    .free_pages = slab_free_page,
    .nr_free_pages = slab_nr_free_pages,
    .check = slab_check,
};
