//Challenge2 2310688 郭思达

#include <pmm.h>
#include <list.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include <memlayout.h>

//宏定义

#define page2kva(page) ({                    \
    struct Page *__page = (page);            \
    uintptr_t __pa = page2pa(__page);        \
    (void *)(__pa + va_pa_offset);           \
})

#define SLUB_CACHE_NAME_LEN 32
#define SLUB_MAX_ORDER 5
#define SLUB_MIN_OBJECT_SIZE 16
#define SLUB_MAX_OBJECT_SIZE (PGSIZE * 4)

//数据类型定义 

// slab结构
typedef struct slab {
    list_entry_t slab_link;
    void *s_mem;
    unsigned int inuse;
    void *freelist;
    unsigned int free_count;
    struct kmem_cache *cache;
    struct Page *page;
} slab_t;

// kmem缓存结构
typedef struct kmem_cache {
    char name[SLUB_CACHE_NAME_LEN];
    size_t object_size;
    size_t actual_size;
    unsigned int align;
    unsigned int objs_per_slab;
    unsigned int order;
    
    list_entry_t slabs_full;
    list_entry_t slabs_partial;
    list_entry_t slabs_free;
    list_entry_t cache_link;
    
    unsigned long num_slabs;
    unsigned long num_objects;
    int initialized;
} kmem_cache_t;

// 全局slub管理器状态
typedef struct slub_manager {
    list_entry_t cache_chain;
    size_t num_caches;
    
    kmem_cache_t *cache_16;
    kmem_cache_t *cache_32;
    kmem_cache_t *cache_64;
    kmem_cache_t *cache_128;
    kmem_cache_t *cache_256;
    kmem_cache_t *cache_512;
    kmem_cache_t *cache_1024;
    kmem_cache_t *cache_2048;
    
    unsigned long total_allocated;
    unsigned long total_freed;
    int init_phase;
} slub_manager_t;

// 全局变量 

static slub_manager_t slub_mgr;
static free_area_t free_area;

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

//辅助宏定义 

#define le2slab(le, member) to_struct((le), slab_t, member)
#define le2cache(le, member) to_struct((le), kmem_cache_t, member)

// 辅助函数 

static size_t slub_calculate_size(size_t size, unsigned int align) {
    if (align > 0) {
        return ROUNDUP(size, align);
    }
    return ROUNDUP(size, sizeof(void *));
}

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

static void *slub_cache_alloc(kmem_cache_t *cache) {
    if (!cache) return NULL;
    
    if (!cache->initialized) {
        slub_cache_init_lazy(cache);
        if (!cache->initialized) {
            return NULL;
        }
    }
    
    slab_t *slab = NULL;
    void *object = NULL;
    
    if (!list_empty(&cache->slabs_partial)) {
        list_entry_t *le = list_next(&cache->slabs_partial);
        slab = le2slab(le, slab_link);
    } 
    else if (!list_empty(&cache->slabs_free)) {
        list_entry_t *le = list_next(&cache->slabs_free);
        slab = le2slab(le, slab_link);
        list_del(le);
        list_add(&cache->slabs_partial, le);
    }
    else {
        slab = slub_alloc_slab(cache);
        if (!slab) {
            return NULL;
        }
        list_add(&cache->slabs_partial, &slab->slab_link);
    }
    
    if (!slab) return NULL;
    
    object = slab->freelist;
    if (!object) return NULL;
    
    slab->freelist = *(void**)object;
    slab->inuse++;
    slab->free_count--;
    
    if (slab->inuse == cache->objs_per_slab) {
        list_del(&slab->slab_link);
        list_add(&cache->slabs_full, &slab->slab_link);
    }
    
    memset(object, 0, cache->object_size);
    slub_mgr.total_allocated += cache->actual_size;
    
    return object;
}

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
    
    if (slab->cache != cache) {
        return;
    }
    
    *(void**)obj = slab->freelist;
    slab->freelist = obj;
    slab->inuse--;
    slab->free_count++;
    
    list_entry_t *le = &slab->slab_link;
    
    if (slab->inuse == 0) {
        list_del(le);
        list_add(&cache->slabs_free, le);
    } else if (slab->inuse == cache->objs_per_slab - 1) {
        list_del(le);
        list_add(&cache->slabs_partial, le);
    }
    
    slub_mgr.total_freed += cache->actual_size;
}

static void *slub_kmalloc(size_t size) {
    if (size == 0) return NULL;
    
    if (size > SLUB_MAX_OBJECT_SIZE) {
        size_t pages = ROUNDUP(size, PGSIZE) / PGSIZE;
        struct Page *page = alloc_pages(pages);
        return page ? page2kva(page) : NULL;
    }
    
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

static void slub_kfree(void *obj) {
    if (!obj) return;
    
    uintptr_t pa = PADDR(obj);
    struct Page *page = pa2page(pa);
    if (page->property > 1) {
        free_pages(page, page->property);
        return;
    }
    
    kmem_cache_t *caches[] = {
        slub_mgr.cache_16, slub_mgr.cache_32, slub_mgr.cache_64,
        slub_mgr.cache_128, slub_mgr.cache_256, slub_mgr.cache_512,
        slub_mgr.cache_1024, slub_mgr.cache_2048, NULL
    };
    
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
    
    free_pages(page, 1);
}

// 测试函数 


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

static void slub_run_tests(void) {
    cprintf("\n=== Starting SLUB Tests ===\n");
    slub_test_basic();
    slub_test_kmalloc();
    cprintf("=== SLUB Tests Completed ===\n\n");
}

//  PMM接口函数

static void slub_init(void) {
    list_init(&free_list);
    nr_free = 0;
    
    list_init(&slub_mgr.cache_chain);
    slub_mgr.num_caches = 0;
    slub_mgr.total_allocated = 0;
    slub_mgr.total_freed = 0;
    slub_mgr.init_phase = 1;
    
    static kmem_cache_t cache_16, cache_32, cache_64, cache_128;
    static kmem_cache_t cache_256, cache_512, cache_1024, cache_2048;
    
    slub_mgr.cache_16 = slub_cache_create_static("slub-16", 16, 0, &cache_16);
    slub_mgr.cache_32 = slub_cache_create_static("slub-32", 32, 0, &cache_32);
    slub_mgr.cache_64 = slub_cache_create_static("slub-64", 64, 0, &cache_64);
    slub_mgr.cache_128 = slub_cache_create_static("slub-128", 128, 0, &cache_128);
    slub_mgr.cache_256 = slub_cache_create_static("slub-256", 256, 0, &cache_256);
    slub_mgr.cache_512 = slub_cache_create_static("slub-512", 512, 0, &cache_512);
    slub_mgr.cache_1024 = slub_cache_create_static("slub-1024", 1024, 0, &cache_1024);
    slub_mgr.cache_2048 = slub_cache_create_static("slub-2048", 2048, 0, &cache_2048);
    
    slub_mgr.init_phase = 0;
   // cprintf("slub: initialized with %zu caches\n", slub_mgr.num_caches);
}

static void slub_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p++) {
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
        list_entry_t *le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page *page = le2page(le, page_link);
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                list_add(le, &(base->page_link));
            }
        }
    }
}

static struct Page *slub_alloc_pages(size_t n) {
    if (n > 1) {
        if (n > nr_free) {
            return NULL;
        }
        struct Page *page = NULL;
        list_entry_t *le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page *p = le2page(le, page_link);
            if (p->property >= n) {
                page = p;
                break;
            }
        }
        
        if (page != NULL) {
            list_entry_t *prev = list_prev(&(page->page_link));
            list_del(&(page->page_link));
            if (page->property > n) {
                struct Page *p = page + n;
                p->property = page->property - n;
                SetPageProperty(p);
                list_add(prev, &(p->page_link));
            }
            nr_free -= n;
            ClearPageProperty(page);
        }
        return page;
    }
    
    if (slub_mgr.init_phase) {
        if (1 > nr_free) {
            return NULL;
        }
        struct Page *page = NULL;
        list_entry_t *le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page *p = le2page(le, page_link);
            if (p->property >= 1) {
                page = p;
                break;
            }
        }
        
        if (page != NULL) {
            list_entry_t *prev = list_prev(&(page->page_link));
            list_del(&(page->page_link));
            if (page->property > 1) {
                struct Page *p = page + 1;
                p->property = page->property - 1;
                SetPageProperty(p);
                list_add(prev, &(p->page_link));
            }
            nr_free -= 1;
            ClearPageProperty(page);
        }
        return page;
    }
    
    void *vaddr = slub_kmalloc(PGSIZE);
    if (!vaddr) return NULL;
    
    uintptr_t pa = PADDR(vaddr);
    struct Page *page = pa2page(pa);
    ClearPageProperty(page);
    SetPageReserved(page);
    page->property = 1;
    
    return page;
}

static void slub_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    
    if (n > 1) {
        struct Page *p = base;
        for (; p != base + n; p++) {
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
            list_entry_t *le = &free_list;
            while ((le = list_next(le)) != &free_list) {
                struct Page *page = le2page(le, page_link);
                if (base < page) {
                    list_add_before(le, &(base->page_link));
                    break;
                } else if (list_next(le) == &free_list) {
                    list_add(le, &(base->page_link));
                }
            }
        }
        
        list_entry_t *le = list_prev(&(base->page_link));
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
    } else {
        if (!slub_mgr.init_phase) {
            void *vaddr = page2kva(base);
            slub_kfree(vaddr);
        } else {
            struct Page *p = base;
            assert(!PageReserved(p) && !PageProperty(p));
            p->flags = 0;
            set_page_ref(p, 0);
            base->property = 1;
            SetPageProperty(base);
            nr_free += 1;
            
            if (list_empty(&free_list)) {
                list_add(&free_list, &(base->page_link));
            } else {
                list_entry_t *le = &free_list;
                while ((le = list_next(le)) != &free_list) {
                    struct Page *page = le2page(le, page_link);
                    if (base < page) {
                        list_add_before(le, &(base->page_link));
                        break;
                    } else if (list_next(le) == &free_list) {
                        list_add(le, &(base->page_link));
                    }
                }
            }
        }
    }
}

static size_t slub_nr_free_pages(void) {
    return nr_free;
}

static void slub_check(void) {
    cprintf("=== SLUB Memory Manager Check ===\n");
    
    slub_run_tests();
    
    cprintf("SLUB cache status:\n");
   // cprintf("  Total caches: %zu\n", slub_mgr.num_caches);
    cprintf("  Total allocated: %lu bytes\n", slub_mgr.total_allocated);
    cprintf("  Total freed: %lu bytes\n", slub_mgr.total_freed);
    
    list_entry_t *le = &slub_mgr.cache_chain;
    while ((le = list_next(le)) != &slub_mgr.cache_chain) {
        kmem_cache_t *cache = le2cache(le, cache_link);
        cprintf("  Cache '%s': %lu slabs, %lu objects\n",
                cache->name, cache->num_slabs, cache->num_objects);
    }
    
   // cprintf("Free pages: %zu\n", nr_free);
    cprintf("SLUB check completed.\n");
}

//  PMM管理器定义 

const struct pmm_manager slub_pmm_manager = {
    .name = "slub_pmm_manager",
    .init = slub_init,
    .init_memmap = slub_init_memmap,
    .alloc_pages = slub_alloc_pages,
    .free_pages = slub_free_pages,
    .nr_free_pages = slub_nr_free_pages,
    .check = slub_check,
};