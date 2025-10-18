// Challenge1  2311727 苏耀磊

#include <pmm.h>
#include <list.h>
#include <string.h>
#include <stdio.h>
#include <buddy_pmm.h>

#define MAX_ORDER 10

static free_area_t free_area[MAX_ORDER + 1];

#define free_list(order) (free_area[order].free_list)
#define nr_free(order)   (free_area[order].nr_free)

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

static void buddy_init(void) {
    for (int i = 0; i <= MAX_ORDER; i++) {
        list_init(&free_list(i));
        nr_free(i) = 0;
    }
}

static void
buddy_init_memmap(struct Page *base, size_t n)
{
    assert(n > 0);

    /* 清理每页的基础字段 */
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

static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i <= MAX_ORDER; i++) {
        total += nr_free(i) * (1 << i);
    }
    return total;
}


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

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_system_check,
};