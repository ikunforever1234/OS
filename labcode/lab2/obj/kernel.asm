
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00005297          	auipc	t0,0x5
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0205000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00005297          	auipc	t0,0x5
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0205008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02042b7          	lui	t0,0xc0204
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0204137          	lui	sp,0xc0204

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	14450513          	addi	a0,a0,324 # ffffffffc0201190 <etext>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	14e50513          	addi	a0,a0,334 # ffffffffc02011b0 <etext+0x20>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	12258593          	addi	a1,a1,290 # ffffffffc0201190 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	15a50513          	addi	a0,a0,346 # ffffffffc02011d0 <etext+0x40>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00005597          	auipc	a1,0x5
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0205018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	16650513          	addi	a0,a0,358 # ffffffffc02011f0 <etext+0x60>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00005597          	auipc	a1,0x5
ffffffffc020009a:	7ca58593          	addi	a1,a1,1994 # ffffffffc0205860 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	17250513          	addi	a0,a0,370 # ffffffffc0201210 <etext+0x80>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	bb558593          	addi	a1,a1,-1099 # ffffffffc0205c5f <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	16450513          	addi	a0,a0,356 # ffffffffc0201230 <etext+0xa0>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00005517          	auipc	a0,0x5
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0205018 <free_area>
ffffffffc02000e0:	00005617          	auipc	a2,0x5
ffffffffc02000e4:	78060613          	addi	a2,a2,1920 # ffffffffc0205860 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	08e010ef          	jal	ra,ffffffffc020117e <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	16450513          	addi	a0,a0,356 # ffffffffc0201260 <etext+0xd0>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	4c4000ef          	jal	ra,ffffffffc02005d0 <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	429000ef          	jal	ra,ffffffffc0200d68 <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0204028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	3f3000ef          	jal	ra,ffffffffc0200d68 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00005317          	auipc	t1,0x5
ffffffffc02001c6:	65630313          	addi	t1,t1,1622 # ffffffffc0205818 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	08e50513          	addi	a0,a0,142 # ffffffffc0201280 <etext+0xf0>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	05050513          	addi	a0,a0,80 # ffffffffc0201258 <etext+0xc8>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	6cf0006f          	j	ffffffffc02010ea <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	07e50513          	addi	a0,a0,126 # ffffffffc02012a0 <etext+0x110>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00005597          	auipc	a1,0x5
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0205000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	06050513          	addi	a0,a0,96 # ffffffffc02012b0 <etext+0x120>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00005417          	auipc	s0,0x5
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0205008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	05a50513          	addi	a0,a0,90 # ffffffffc02012c0 <etext+0x130>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	06250513          	addi	a0,a0,98 # ffffffffc02012d8 <etext+0x148>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfeda68d>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	ff890913          	addi	s2,s2,-8 # ffffffffc0201328 <etext+0x198>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	fe248493          	addi	s1,s1,-30 # ffffffffc0201320 <etext+0x190>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	00e50513          	addi	a0,a0,14 # ffffffffc02013a0 <etext+0x210>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	03a50513          	addi	a0,a0,58 # ffffffffc02013d8 <etext+0x248>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	f1a50513          	addi	a0,a0,-230 # ffffffffc02012f8 <etext+0x168>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	519000ef          	jal	ra,ffffffffc0201104 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	55f000ef          	jal	ra,ffffffffc0201158 <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	4ab000ef          	jal	ra,ffffffffc020113a <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	e8c50513          	addi	a0,a0,-372 # ffffffffc0201330 <etext+0x1a0>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	dde50513          	addi	a0,a0,-546 # ffffffffc0201350 <etext+0x1c0>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	de450513          	addi	a0,a0,-540 # ffffffffc0201368 <etext+0x1d8>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	df250513          	addi	a0,a0,-526 # ffffffffc0201388 <etext+0x1f8>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	e3650513          	addi	a0,a0,-458 # ffffffffc02013d8 <etext+0x248>
        memory_base = mem_base;
ffffffffc02005aa:	00005797          	auipc	a5,0x5
ffffffffc02005ae:	2687bb23          	sd	s0,630(a5) # ffffffffc0205820 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00005797          	auipc	a5,0x5
ffffffffc02005b6:	2767bb23          	sd	s6,630(a5) # ffffffffc0205828 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00005517          	auipc	a0,0x5
ffffffffc02005c0:	26453503          	ld	a0,612(a0) # ffffffffc0205820 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00005517          	auipc	a0,0x5
ffffffffc02005ca:	26253503          	ld	a0,610(a0) # ffffffffc0205828 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <pmm_init>:

static void check_alloc_page(void);

// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
    pmm_manager = &slub_pmm_manager;
ffffffffc02005d0:	00001797          	auipc	a5,0x1
ffffffffc02005d4:	29878793          	addi	a5,a5,664 # ffffffffc0201868 <slub_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005d8:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02005da:	7179                	addi	sp,sp,-48
ffffffffc02005dc:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005de:	00001517          	auipc	a0,0x1
ffffffffc02005e2:	e1250513          	addi	a0,a0,-494 # ffffffffc02013f0 <etext+0x260>
    pmm_manager = &slub_pmm_manager;
ffffffffc02005e6:	00005417          	auipc	s0,0x5
ffffffffc02005ea:	25a40413          	addi	s0,s0,602 # ffffffffc0205840 <pmm_manager>
void pmm_init(void) {
ffffffffc02005ee:	f406                	sd	ra,40(sp)
ffffffffc02005f0:	ec26                	sd	s1,24(sp)
ffffffffc02005f2:	e44e                	sd	s3,8(sp)
ffffffffc02005f4:	e84a                	sd	s2,16(sp)
ffffffffc02005f6:	e052                	sd	s4,0(sp)
    pmm_manager = &slub_pmm_manager;
ffffffffc02005f8:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005fa:	b53ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc02005fe:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200600:	00005497          	auipc	s1,0x5
ffffffffc0200604:	25848493          	addi	s1,s1,600 # ffffffffc0205858 <va_pa_offset>
    pmm_manager->init();
ffffffffc0200608:	679c                	ld	a5,8(a5)
ffffffffc020060a:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc020060c:	57f5                	li	a5,-3
ffffffffc020060e:	07fa                	slli	a5,a5,0x1e
ffffffffc0200610:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0200612:	fabff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200616:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc0200618:	fafff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_size == 0) {
ffffffffc020061c:	14050c63          	beqz	a0,ffffffffc0200774 <pmm_init+0x1a4>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200620:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0200622:	00001517          	auipc	a0,0x1
ffffffffc0200626:	e1650513          	addi	a0,a0,-490 # ffffffffc0201438 <etext+0x2a8>
ffffffffc020062a:	b23ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc020062e:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0200632:	864e                	mv	a2,s3
ffffffffc0200634:	fffa0693          	addi	a3,s4,-1
ffffffffc0200638:	85ca                	mv	a1,s2
ffffffffc020063a:	00001517          	auipc	a0,0x1
ffffffffc020063e:	e1650513          	addi	a0,a0,-490 # ffffffffc0201450 <etext+0x2c0>
ffffffffc0200642:	b0bff0ef          	jal	ra,ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200646:	c80007b7          	lui	a5,0xc8000
ffffffffc020064a:	8652                	mv	a2,s4
ffffffffc020064c:	0d47e363          	bltu	a5,s4,ffffffffc0200712 <pmm_init+0x142>
ffffffffc0200650:	00006797          	auipc	a5,0x6
ffffffffc0200654:	20f78793          	addi	a5,a5,527 # ffffffffc020685f <end+0xfff>
ffffffffc0200658:	757d                	lui	a0,0xfffff
ffffffffc020065a:	8d7d                	and	a0,a0,a5
ffffffffc020065c:	8231                	srli	a2,a2,0xc
ffffffffc020065e:	00005797          	auipc	a5,0x5
ffffffffc0200662:	1cc7b923          	sd	a2,466(a5) # ffffffffc0205830 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0200666:	00005797          	auipc	a5,0x5
ffffffffc020066a:	1ca7b923          	sd	a0,466(a5) # ffffffffc0205838 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc020066e:	000807b7          	lui	a5,0x80
ffffffffc0200672:	002005b7          	lui	a1,0x200
ffffffffc0200676:	02f60563          	beq	a2,a5,ffffffffc02006a0 <pmm_init+0xd0>
ffffffffc020067a:	00261593          	slli	a1,a2,0x2
ffffffffc020067e:	00c586b3          	add	a3,a1,a2
ffffffffc0200682:	fec007b7          	lui	a5,0xfec00
ffffffffc0200686:	97aa                	add	a5,a5,a0
ffffffffc0200688:	068e                	slli	a3,a3,0x3
ffffffffc020068a:	96be                	add	a3,a3,a5
ffffffffc020068c:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc020068e:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200690:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9fa7c8>
        SetPageReserved(pages + i);
ffffffffc0200694:	00176713          	ori	a4,a4,1
ffffffffc0200698:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc020069c:	fef699e3          	bne	a3,a5,ffffffffc020068e <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006a0:	95b2                	add	a1,a1,a2
ffffffffc02006a2:	fec006b7          	lui	a3,0xfec00
ffffffffc02006a6:	96aa                	add	a3,a3,a0
ffffffffc02006a8:	058e                	slli	a1,a1,0x3
ffffffffc02006aa:	96ae                	add	a3,a3,a1
ffffffffc02006ac:	c02007b7          	lui	a5,0xc0200
ffffffffc02006b0:	0af6e663          	bltu	a3,a5,ffffffffc020075c <pmm_init+0x18c>
ffffffffc02006b4:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02006b6:	77fd                	lui	a5,0xfffff
ffffffffc02006b8:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02006bc:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc02006be:	04b6ed63          	bltu	a3,a1,ffffffffc0200718 <pmm_init+0x148>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02006c2:	601c                	ld	a5,0(s0)
ffffffffc02006c4:	7b9c                	ld	a5,48(a5)
ffffffffc02006c6:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02006c8:	00001517          	auipc	a0,0x1
ffffffffc02006cc:	e1050513          	addi	a0,a0,-496 # ffffffffc02014d8 <etext+0x348>
ffffffffc02006d0:	a7dff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02006d4:	00004597          	auipc	a1,0x4
ffffffffc02006d8:	92c58593          	addi	a1,a1,-1748 # ffffffffc0204000 <boot_page_table_sv39>
ffffffffc02006dc:	00005797          	auipc	a5,0x5
ffffffffc02006e0:	16b7ba23          	sd	a1,372(a5) # ffffffffc0205850 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc02006e4:	c02007b7          	lui	a5,0xc0200
ffffffffc02006e8:	0af5e263          	bltu	a1,a5,ffffffffc020078c <pmm_init+0x1bc>
ffffffffc02006ec:	6090                	ld	a2,0(s1)
}
ffffffffc02006ee:	7402                	ld	s0,32(sp)
ffffffffc02006f0:	70a2                	ld	ra,40(sp)
ffffffffc02006f2:	64e2                	ld	s1,24(sp)
ffffffffc02006f4:	6942                	ld	s2,16(sp)
ffffffffc02006f6:	69a2                	ld	s3,8(sp)
ffffffffc02006f8:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc02006fa:	40c58633          	sub	a2,a1,a2
ffffffffc02006fe:	00005797          	auipc	a5,0x5
ffffffffc0200702:	14c7b523          	sd	a2,330(a5) # ffffffffc0205848 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200706:	00001517          	auipc	a0,0x1
ffffffffc020070a:	df250513          	addi	a0,a0,-526 # ffffffffc02014f8 <etext+0x368>
}
ffffffffc020070e:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200710:	bc35                	j	ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200712:	c8000637          	lui	a2,0xc8000
ffffffffc0200716:	bf2d                	j	ffffffffc0200650 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0200718:	6705                	lui	a4,0x1
ffffffffc020071a:	177d                	addi	a4,a4,-1
ffffffffc020071c:	96ba                	add	a3,a3,a4
ffffffffc020071e:	8efd                	and	a3,a3,a5
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0200720:	00c6d793          	srli	a5,a3,0xc
ffffffffc0200724:	02c7f063          	bgeu	a5,a2,ffffffffc0200744 <pmm_init+0x174>
    pmm_manager->init_memmap(base, n);
ffffffffc0200728:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020072a:	fff80737          	lui	a4,0xfff80
ffffffffc020072e:	973e                	add	a4,a4,a5
ffffffffc0200730:	00271793          	slli	a5,a4,0x2
ffffffffc0200734:	97ba                	add	a5,a5,a4
ffffffffc0200736:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc0200738:	8d95                	sub	a1,a1,a3
ffffffffc020073a:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc020073c:	81b1                	srli	a1,a1,0xc
ffffffffc020073e:	953e                	add	a0,a0,a5
ffffffffc0200740:	9702                	jalr	a4
}
ffffffffc0200742:	b741                	j	ffffffffc02006c2 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0200744:	00001617          	auipc	a2,0x1
ffffffffc0200748:	d6460613          	addi	a2,a2,-668 # ffffffffc02014a8 <etext+0x318>
ffffffffc020074c:	06a00593          	li	a1,106
ffffffffc0200750:	00001517          	auipc	a0,0x1
ffffffffc0200754:	d7850513          	addi	a0,a0,-648 # ffffffffc02014c8 <etext+0x338>
ffffffffc0200758:	a6bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc020075c:	00001617          	auipc	a2,0x1
ffffffffc0200760:	d2460613          	addi	a2,a2,-732 # ffffffffc0201480 <etext+0x2f0>
ffffffffc0200764:	06000593          	li	a1,96
ffffffffc0200768:	00001517          	auipc	a0,0x1
ffffffffc020076c:	cc050513          	addi	a0,a0,-832 # ffffffffc0201428 <etext+0x298>
ffffffffc0200770:	a53ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("DTB memory info not available");
ffffffffc0200774:	00001617          	auipc	a2,0x1
ffffffffc0200778:	c9460613          	addi	a2,a2,-876 # ffffffffc0201408 <etext+0x278>
ffffffffc020077c:	04800593          	li	a1,72
ffffffffc0200780:	00001517          	auipc	a0,0x1
ffffffffc0200784:	ca850513          	addi	a0,a0,-856 # ffffffffc0201428 <etext+0x298>
ffffffffc0200788:	a3bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc020078c:	86ae                	mv	a3,a1
ffffffffc020078e:	00001617          	auipc	a2,0x1
ffffffffc0200792:	cf260613          	addi	a2,a2,-782 # ffffffffc0201480 <etext+0x2f0>
ffffffffc0200796:	07b00593          	li	a1,123
ffffffffc020079a:	00001517          	auipc	a0,0x1
ffffffffc020079e:	c8e50513          	addi	a0,a0,-882 # ffffffffc0201428 <etext+0x298>
ffffffffc02007a2:	a21ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02007a6 <slub_init>:
#define nr_free(order)     (free_area[order].nr_free)


// SLUB 分配器初始化
static void slub_init(void) {
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007a6:	00005797          	auipc	a5,0x5
ffffffffc02007aa:	87a78793          	addi	a5,a5,-1926 # ffffffffc0205020 <free_area+0x8>
ffffffffc02007ae:	00005617          	auipc	a2,0x5
ffffffffc02007b2:	07260613          	addi	a2,a2,114 # ffffffffc0205820 <memory_base>
static void slub_init(void) {
ffffffffc02007b6:	6705                	lui	a4,0x1
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007b8:	6685                	lui	a3,0x1
        free_area[i].size = (i + 1) * PGSIZE;  // 每个缓存池的大小是 PGSIZE 的倍数
ffffffffc02007ba:	fee7bc23          	sd	a4,-8(a5)
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02007be:	e79c                	sd	a5,8(a5)
ffffffffc02007c0:	e39c                	sd	a5,0(a5)
        list_init(&(free_area[i].free_list));   // 初始化链表
        free_area[i].nr_free = 0;               // 初始化空闲块数量
ffffffffc02007c2:	0007a823          	sw	zero,16(a5)
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007c6:	02078793          	addi	a5,a5,32
ffffffffc02007ca:	9736                	add	a4,a4,a3
ffffffffc02007cc:	fec797e3          	bne	a5,a2,ffffffffc02007ba <slub_init+0x14>
    }
}
ffffffffc02007d0:	8082                	ret

ffffffffc02007d2 <slub_nr_free_pages>:
}

// 获取当前空闲的页数
static size_t slub_nr_free_pages(void) {
    size_t total_free = 0;
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007d2:	00005797          	auipc	a5,0x5
ffffffffc02007d6:	85e78793          	addi	a5,a5,-1954 # ffffffffc0205030 <free_area+0x18>
ffffffffc02007da:	00005697          	auipc	a3,0x5
ffffffffc02007de:	05668693          	addi	a3,a3,86 # ffffffffc0205830 <npage>
    size_t total_free = 0;
ffffffffc02007e2:	4501                	li	a0,0
        total_free += free_area[i].nr_free;
ffffffffc02007e4:	0007e703          	lwu	a4,0(a5)
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007e8:	02078793          	addi	a5,a5,32
        total_free += free_area[i].nr_free;
ffffffffc02007ec:	953a                	add	a0,a0,a4
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02007ee:	fed79be3          	bne	a5,a3,ffffffffc02007e4 <slub_nr_free_pages+0x12>
    }
    return total_free;
}
ffffffffc02007f2:	8082                	ret

ffffffffc02007f4 <slub_alloc_pages>:
static struct Page* slub_alloc_pages(size_t n) {
ffffffffc02007f4:	7179                	addi	sp,sp,-48
ffffffffc02007f6:	f406                	sd	ra,40(sp)
ffffffffc02007f8:	f022                	sd	s0,32(sp)
ffffffffc02007fa:	ec26                	sd	s1,24(sp)
ffffffffc02007fc:	e84a                	sd	s2,16(sp)
ffffffffc02007fe:	e44e                	sd	s3,8(sp)
    assert(n > 0);
ffffffffc0200800:	12050863          	beqz	a0,ffffffffc0200930 <slub_alloc_pages+0x13c>
ffffffffc0200804:	00005917          	auipc	s2,0x5
ffffffffc0200808:	81490913          	addi	s2,s2,-2028 # ffffffffc0205018 <free_area>
ffffffffc020080c:	84aa                	mv	s1,a0
    size_t request_size = n * PGSIZE;  // 请求的总内存大小（单位是字节）
ffffffffc020080e:	00c51693          	slli	a3,a0,0xc
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200812:	874a                	mv	a4,s2
ffffffffc0200814:	4781                	li	a5,0
ffffffffc0200816:	04000613          	li	a2,64
ffffffffc020081a:	a031                	j	ffffffffc0200826 <slub_alloc_pages+0x32>
ffffffffc020081c:	2785                	addiw	a5,a5,1
ffffffffc020081e:	02070713          	addi	a4,a4,32 # 1020 <kern_entry-0xffffffffc01fefe0>
ffffffffc0200822:	0ec78e63          	beq	a5,a2,ffffffffc020091e <slub_alloc_pages+0x12a>
        if (free_area[i].size >= request_size) {
ffffffffc0200826:	630c                	ld	a1,0(a4)
ffffffffc0200828:	fed5eae3          	bltu	a1,a3,ffffffffc020081c <slub_alloc_pages+0x28>
            cache = &free_area[i];
ffffffffc020082c:	00579413          	slli	s0,a5,0x5
ffffffffc0200830:	008909b3          	add	s3,s2,s0
    cprintf("Cache[%d] has %u free pages, requested: %zu\n", cache->size, cache->nr_free, n);
ffffffffc0200834:	0189a603          	lw	a2,24(s3)
ffffffffc0200838:	86a6                	mv	a3,s1
ffffffffc020083a:	00001517          	auipc	a0,0x1
ffffffffc020083e:	d3650513          	addi	a0,a0,-714 # ffffffffc0201570 <etext+0x3e0>
ffffffffc0200842:	90bff0ef          	jal	ra,ffffffffc020014c <cprintf>
    if (cache->nr_free < n) {
ffffffffc0200846:	0189a683          	lw	a3,24(s3)
ffffffffc020084a:	02069793          	slli	a5,a3,0x20
ffffffffc020084e:	9381                	srli	a5,a5,0x20
ffffffffc0200850:	0a97ec63          	bltu	a5,s1,ffffffffc0200908 <slub_alloc_pages+0x114>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200854:	0109b783          	ld	a5,16(s3)
    while (le != &cache->free_list) {
ffffffffc0200858:	00840593          	addi	a1,s0,8
ffffffffc020085c:	95ca                	add	a1,a1,s2
ffffffffc020085e:	08b78263          	beq	a5,a1,ffffffffc02008e2 <slub_alloc_pages+0xee>
        if (p->property >= n) {
ffffffffc0200862:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200866:	853e                	mv	a0,a5
ffffffffc0200868:	679c                	ld	a5,8(a5)
ffffffffc020086a:	02071613          	slli	a2,a4,0x20
ffffffffc020086e:	9201                	srli	a2,a2,0x20
ffffffffc0200870:	fe9667e3          	bltu	a2,s1,ffffffffc020085e <slub_alloc_pages+0x6a>
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200874:	610c                	ld	a1,0(a0)
        struct Page *p = le2page(le, page_link);
ffffffffc0200876:	fe850993          	addi	s3,a0,-24
            p->property = page->property - n;
ffffffffc020087a:	0004881b          	sext.w	a6,s1
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020087e:	e59c                	sd	a5,8(a1)
    next->prev = prev;
ffffffffc0200880:	e38c                	sd	a1,0(a5)
        if (page->property > n) {
ffffffffc0200882:	02c4ec63          	bltu	s1,a2,ffffffffc02008ba <slub_alloc_pages+0xc6>
        ClearPageProperty(page);
ffffffffc0200886:	ff053703          	ld	a4,-16(a0)
        cache->nr_free -= n;
ffffffffc020088a:	008907b3          	add	a5,s2,s0
        cprintf("Allocated %zu pages from cache[%d], nr_free: %u\n", n, cache->size, cache->nr_free);
ffffffffc020088e:	6390                	ld	a2,0(a5)
        cache->nr_free -= n;
ffffffffc0200890:	410686bb          	subw	a3,a3,a6
ffffffffc0200894:	cf94                	sw	a3,24(a5)
        ClearPageProperty(page);
ffffffffc0200896:	9b75                	andi	a4,a4,-3
ffffffffc0200898:	fee53823          	sd	a4,-16(a0)
        cprintf("Allocated %zu pages from cache[%d], nr_free: %u\n", n, cache->size, cache->nr_free);
ffffffffc020089c:	85a6                	mv	a1,s1
ffffffffc020089e:	00001517          	auipc	a0,0x1
ffffffffc02008a2:	d4a50513          	addi	a0,a0,-694 # ffffffffc02015e8 <etext+0x458>
ffffffffc02008a6:	8a7ff0ef          	jal	ra,ffffffffc020014c <cprintf>
}
ffffffffc02008aa:	70a2                	ld	ra,40(sp)
ffffffffc02008ac:	7402                	ld	s0,32(sp)
ffffffffc02008ae:	64e2                	ld	s1,24(sp)
ffffffffc02008b0:	6942                	ld	s2,16(sp)
ffffffffc02008b2:	854e                	mv	a0,s3
ffffffffc02008b4:	69a2                	ld	s3,8(sp)
ffffffffc02008b6:	6145                	addi	sp,sp,48
ffffffffc02008b8:	8082                	ret
            struct Page *p = page + n;
ffffffffc02008ba:	00249613          	slli	a2,s1,0x2
ffffffffc02008be:	9626                	add	a2,a2,s1
ffffffffc02008c0:	060e                	slli	a2,a2,0x3
ffffffffc02008c2:	964e                	add	a2,a2,s3
            SetPageProperty(p);
ffffffffc02008c4:	00863883          	ld	a7,8(a2)
            p->property = page->property - n;
ffffffffc02008c8:	4107073b          	subw	a4,a4,a6
ffffffffc02008cc:	ca18                	sw	a4,16(a2)
            SetPageProperty(p);
ffffffffc02008ce:	0028e713          	ori	a4,a7,2
ffffffffc02008d2:	e618                	sd	a4,8(a2)
            list_add(prev, &(p->page_link));  
ffffffffc02008d4:	01860713          	addi	a4,a2,24
    prev->next = next->prev = elm;
ffffffffc02008d8:	e398                	sd	a4,0(a5)
ffffffffc02008da:	e598                	sd	a4,8(a1)
    elm->next = next;
ffffffffc02008dc:	f21c                	sd	a5,32(a2)
    elm->prev = prev;
ffffffffc02008de:	ee0c                	sd	a1,24(a2)
}
ffffffffc02008e0:	b75d                	j	ffffffffc0200886 <slub_alloc_pages+0x92>
        cprintf("No suitable free block found in cache[%d] for %zu pages\n", cache->size, n);
ffffffffc02008e2:	008907b3          	add	a5,s2,s0
ffffffffc02008e6:	638c                	ld	a1,0(a5)
ffffffffc02008e8:	8626                	mv	a2,s1
ffffffffc02008ea:	00001517          	auipc	a0,0x1
ffffffffc02008ee:	d3650513          	addi	a0,a0,-714 # ffffffffc0201620 <etext+0x490>
ffffffffc02008f2:	85bff0ef          	jal	ra,ffffffffc020014c <cprintf>
}
ffffffffc02008f6:	70a2                	ld	ra,40(sp)
ffffffffc02008f8:	7402                	ld	s0,32(sp)
        cprintf("No suitable free block found in cache[%d] for %zu pages\n", cache->size, n);
ffffffffc02008fa:	4981                	li	s3,0
}
ffffffffc02008fc:	64e2                	ld	s1,24(sp)
ffffffffc02008fe:	6942                	ld	s2,16(sp)
ffffffffc0200900:	854e                	mv	a0,s3
ffffffffc0200902:	69a2                	ld	s3,8(sp)
ffffffffc0200904:	6145                	addi	sp,sp,48
ffffffffc0200906:	8082                	ret
        cprintf("Not enough free pages in cache[%d], requested: %zu, available: %u\n", cache->size, n, cache->nr_free);
ffffffffc0200908:	0009b583          	ld	a1,0(s3)
ffffffffc020090c:	8626                	mv	a2,s1
ffffffffc020090e:	00001517          	auipc	a0,0x1
ffffffffc0200912:	c9250513          	addi	a0,a0,-878 # ffffffffc02015a0 <etext+0x410>
ffffffffc0200916:	837ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        return NULL;  // 如果缓存池中的空闲块数量不足
ffffffffc020091a:	4981                	li	s3,0
ffffffffc020091c:	b779                	j	ffffffffc02008aa <slub_alloc_pages+0xb6>
        cprintf("No cache found for requested size: %zu\n", request_size);
ffffffffc020091e:	85b6                	mv	a1,a3
ffffffffc0200920:	00001517          	auipc	a0,0x1
ffffffffc0200924:	d4050513          	addi	a0,a0,-704 # ffffffffc0201660 <etext+0x4d0>
ffffffffc0200928:	825ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        return NULL;  // 如果没有找到合适的缓存池
ffffffffc020092c:	4981                	li	s3,0
ffffffffc020092e:	bfb5                	j	ffffffffc02008aa <slub_alloc_pages+0xb6>
    assert(n > 0);
ffffffffc0200930:	00001697          	auipc	a3,0x1
ffffffffc0200934:	c0868693          	addi	a3,a3,-1016 # ffffffffc0201538 <etext+0x3a8>
ffffffffc0200938:	00001617          	auipc	a2,0x1
ffffffffc020093c:	c0860613          	addi	a2,a2,-1016 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200940:	14a00593          	li	a1,330
ffffffffc0200944:	00001517          	auipc	a0,0x1
ffffffffc0200948:	c1450513          	addi	a0,a0,-1004 # ffffffffc0201558 <etext+0x3c8>
ffffffffc020094c:	877ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200950 <slub_free_pages.part.0>:
    for (; p != base + n; p++) {
ffffffffc0200950:	00259793          	slli	a5,a1,0x2
ffffffffc0200954:	97ae                	add	a5,a5,a1
ffffffffc0200956:	078e                	slli	a5,a5,0x3
ffffffffc0200958:	00f506b3          	add	a3,a0,a5
ffffffffc020095c:	87aa                	mv	a5,a0
ffffffffc020095e:	00d50d63          	beq	a0,a3,ffffffffc0200978 <slub_free_pages.part.0+0x28>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200962:	6798                	ld	a4,8(a5)
ffffffffc0200964:	8b0d                	andi	a4,a4,3
ffffffffc0200966:	e751                	bnez	a4,ffffffffc02009f2 <slub_free_pages.part.0+0xa2>
        p->flags = 0;
ffffffffc0200968:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc020096c:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200970:	02878793          	addi	a5,a5,40
ffffffffc0200974:	fed797e3          	bne	a5,a3,ffffffffc0200962 <slub_free_pages.part.0+0x12>
    SetPageProperty(base);
ffffffffc0200978:	651c                	ld	a5,8(a0)
ffffffffc020097a:	00004717          	auipc	a4,0x4
ffffffffc020097e:	69e70713          	addi	a4,a4,1694 # ffffffffc0205018 <free_area>
    base->property = n;
ffffffffc0200982:	0005831b          	sext.w	t1,a1
    SetPageProperty(base);
ffffffffc0200986:	0027e793          	ori	a5,a5,2
ffffffffc020098a:	02059613          	slli	a2,a1,0x20
ffffffffc020098e:	e51c                	sd	a5,8(a0)
    base->property = n;
ffffffffc0200990:	00652823          	sw	t1,16(a0)
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200994:	9201                	srli	a2,a2,0x20
    SetPageProperty(base);
ffffffffc0200996:	88ba                	mv	a7,a4
ffffffffc0200998:	86ba                	mv	a3,a4
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc020099a:	4781                	li	a5,0
ffffffffc020099c:	04000813          	li	a6,64
ffffffffc02009a0:	a031                	j	ffffffffc02009ac <slub_free_pages.part.0+0x5c>
ffffffffc02009a2:	2785                	addiw	a5,a5,1
ffffffffc02009a4:	02068693          	addi	a3,a3,32
ffffffffc02009a8:	01078b63          	beq	a5,a6,ffffffffc02009be <slub_free_pages.part.0+0x6e>
        if (base->property == free_area[i].size) {
ffffffffc02009ac:	628c                	ld	a1,0(a3)
ffffffffc02009ae:	fec59ae3          	bne	a1,a2,ffffffffc02009a2 <slub_free_pages.part.0+0x52>
            free_area[i].nr_free += n;
ffffffffc02009b2:	0796                	slli	a5,a5,0x5
ffffffffc02009b4:	97c6                	add	a5,a5,a7
ffffffffc02009b6:	4f94                	lw	a3,24(a5)
ffffffffc02009b8:	006686bb          	addw	a3,a3,t1
ffffffffc02009bc:	cf94                	sw	a3,24(a5)
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc02009be:	4781                	li	a5,0
ffffffffc02009c0:	04000593          	li	a1,64
ffffffffc02009c4:	a031                	j	ffffffffc02009d0 <slub_free_pages.part.0+0x80>
ffffffffc02009c6:	2785                	addiw	a5,a5,1
ffffffffc02009c8:	02070713          	addi	a4,a4,32
ffffffffc02009cc:	02b78263          	beq	a5,a1,ffffffffc02009f0 <slub_free_pages.part.0+0xa0>
        if (base->property == free_area[i].size) {
ffffffffc02009d0:	6314                	ld	a3,0(a4)
ffffffffc02009d2:	fed61ae3          	bne	a2,a3,ffffffffc02009c6 <slub_free_pages.part.0+0x76>
    __list_add(elm, listelm, listelm->next);
ffffffffc02009d6:	0796                	slli	a5,a5,0x5
ffffffffc02009d8:	00f886b3          	add	a3,a7,a5
ffffffffc02009dc:	6a98                	ld	a4,16(a3)
            list_add(&free_area[i].free_list, &(base->page_link));
ffffffffc02009de:	01850613          	addi	a2,a0,24
ffffffffc02009e2:	07a1                	addi	a5,a5,8
    prev->next = next->prev = elm;
ffffffffc02009e4:	e310                	sd	a2,0(a4)
ffffffffc02009e6:	ea90                	sd	a2,16(a3)
ffffffffc02009e8:	97c6                	add	a5,a5,a7
    elm->next = next;
ffffffffc02009ea:	f118                	sd	a4,32(a0)
    elm->prev = prev;
ffffffffc02009ec:	ed1c                	sd	a5,24(a0)
}
ffffffffc02009ee:	8082                	ret
ffffffffc02009f0:	8082                	ret
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc02009f2:	1141                	addi	sp,sp,-16
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02009f4:	00001697          	auipc	a3,0x1
ffffffffc02009f8:	c9468693          	addi	a3,a3,-876 # ffffffffc0201688 <etext+0x4f8>
ffffffffc02009fc:	00001617          	auipc	a2,0x1
ffffffffc0200a00:	b4460613          	addi	a2,a2,-1212 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200a04:	18c00593          	li	a1,396
ffffffffc0200a08:	00001517          	auipc	a0,0x1
ffffffffc0200a0c:	b5050513          	addi	a0,a0,-1200 # ffffffffc0201558 <etext+0x3c8>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc0200a10:	e406                	sd	ra,8(sp)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200a12:	fb0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200a16 <slub_free_pages>:
    assert(n > 0);
ffffffffc0200a16:	c191                	beqz	a1,ffffffffc0200a1a <slub_free_pages+0x4>
ffffffffc0200a18:	bf25                	j	ffffffffc0200950 <slub_free_pages.part.0>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc0200a1a:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200a1c:	00001697          	auipc	a3,0x1
ffffffffc0200a20:	b1c68693          	addi	a3,a3,-1252 # ffffffffc0201538 <etext+0x3a8>
ffffffffc0200a24:	00001617          	auipc	a2,0x1
ffffffffc0200a28:	b1c60613          	addi	a2,a2,-1252 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200a2c:	18900593          	li	a1,393
ffffffffc0200a30:	00001517          	auipc	a0,0x1
ffffffffc0200a34:	b2850513          	addi	a0,a0,-1240 # ffffffffc0201558 <etext+0x3c8>
static void slub_free_pages(struct Page *base, size_t n) {
ffffffffc0200a38:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200a3a:	f88ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200a3e <slub_check>:

// SLUB 检查
static void slub_check(void) {
ffffffffc0200a3e:	1101                	addi	sp,sp,-32
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;

    // 分配三个页面
    assert((p0 = slub_alloc_pages(1)) != NULL);
ffffffffc0200a40:	4505                	li	a0,1
static void slub_check(void) {
ffffffffc0200a42:	ec06                	sd	ra,24(sp)
ffffffffc0200a44:	e822                	sd	s0,16(sp)
ffffffffc0200a46:	e426                	sd	s1,8(sp)
ffffffffc0200a48:	e04a                	sd	s2,0(sp)
    assert((p0 = slub_alloc_pages(1)) != NULL);
ffffffffc0200a4a:	dabff0ef          	jal	ra,ffffffffc02007f4 <slub_alloc_pages>
ffffffffc0200a4e:	c141                	beqz	a0,ffffffffc0200ace <slub_check+0x90>
ffffffffc0200a50:	892a                	mv	s2,a0
    assert((p1 = slub_alloc_pages(1)) != NULL);
ffffffffc0200a52:	4505                	li	a0,1
ffffffffc0200a54:	da1ff0ef          	jal	ra,ffffffffc02007f4 <slub_alloc_pages>
ffffffffc0200a58:	84aa                	mv	s1,a0
ffffffffc0200a5a:	10050a63          	beqz	a0,ffffffffc0200b6e <slub_check+0x130>
    assert((p2 = slub_alloc_pages(1)) != NULL);
ffffffffc0200a5e:	4505                	li	a0,1
ffffffffc0200a60:	d95ff0ef          	jal	ra,ffffffffc02007f4 <slub_alloc_pages>
ffffffffc0200a64:	842a                	mv	s0,a0
ffffffffc0200a66:	0e050463          	beqz	a0,ffffffffc0200b4e <slub_check+0x110>

    // 确保它们是不同的
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200a6a:	0c990263          	beq	s2,s1,ffffffffc0200b2e <slub_check+0xf0>
ffffffffc0200a6e:	0ca90063          	beq	s2,a0,ffffffffc0200b2e <slub_check+0xf0>
ffffffffc0200a72:	0aa48e63          	beq	s1,a0,ffffffffc0200b2e <slub_check+0xf0>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200a76:	00092783          	lw	a5,0(s2)
ffffffffc0200a7a:	ebd1                	bnez	a5,ffffffffc0200b0e <slub_check+0xd0>
ffffffffc0200a7c:	409c                	lw	a5,0(s1)
ffffffffc0200a7e:	ebc1                	bnez	a5,ffffffffc0200b0e <slub_check+0xd0>
ffffffffc0200a80:	411c                	lw	a5,0(a0)
ffffffffc0200a82:	e7d1                	bnez	a5,ffffffffc0200b0e <slub_check+0xd0>
    assert(n > 0);
ffffffffc0200a84:	4585                	li	a1,1
ffffffffc0200a86:	854a                	mv	a0,s2
ffffffffc0200a88:	ec9ff0ef          	jal	ra,ffffffffc0200950 <slub_free_pages.part.0>
ffffffffc0200a8c:	4585                	li	a1,1
ffffffffc0200a8e:	8526                	mv	a0,s1
ffffffffc0200a90:	ec1ff0ef          	jal	ra,ffffffffc0200950 <slub_free_pages.part.0>
ffffffffc0200a94:	4585                	li	a1,1
ffffffffc0200a96:	8522                	mv	a0,s0
ffffffffc0200a98:	eb9ff0ef          	jal	ra,ffffffffc0200950 <slub_free_pages.part.0>
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200a9c:	00004797          	auipc	a5,0x4
ffffffffc0200aa0:	59478793          	addi	a5,a5,1428 # ffffffffc0205030 <free_area+0x18>
ffffffffc0200aa4:	00005617          	auipc	a2,0x5
ffffffffc0200aa8:	d8c60613          	addi	a2,a2,-628 # ffffffffc0205830 <npage>
    size_t total_free = 0;
ffffffffc0200aac:	4701                	li	a4,0
        total_free += free_area[i].nr_free;
ffffffffc0200aae:	0007e683          	lwu	a3,0(a5)
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200ab2:	02078793          	addi	a5,a5,32
        total_free += free_area[i].nr_free;
ffffffffc0200ab6:	9736                	add	a4,a4,a3
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200ab8:	fef61be3          	bne	a2,a5,ffffffffc0200aae <slub_check+0x70>
    slub_free_pages(p0, 1);
    slub_free_pages(p1, 1);
    slub_free_pages(p2, 1);

    // 检查空闲页面数是否正确
    assert(slub_nr_free_pages() == 3);
ffffffffc0200abc:	478d                	li	a5,3
ffffffffc0200abe:	02f71863          	bne	a4,a5,ffffffffc0200aee <slub_check+0xb0>
}
ffffffffc0200ac2:	60e2                	ld	ra,24(sp)
ffffffffc0200ac4:	6442                	ld	s0,16(sp)
ffffffffc0200ac6:	64a2                	ld	s1,8(sp)
ffffffffc0200ac8:	6902                	ld	s2,0(sp)
ffffffffc0200aca:	6105                	addi	sp,sp,32
ffffffffc0200acc:	8082                	ret
    assert((p0 = slub_alloc_pages(1)) != NULL);
ffffffffc0200ace:	00001697          	auipc	a3,0x1
ffffffffc0200ad2:	be268693          	addi	a3,a3,-1054 # ffffffffc02016b0 <etext+0x520>
ffffffffc0200ad6:	00001617          	auipc	a2,0x1
ffffffffc0200ada:	a6a60613          	addi	a2,a2,-1430 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200ade:	1b200593          	li	a1,434
ffffffffc0200ae2:	00001517          	auipc	a0,0x1
ffffffffc0200ae6:	a7650513          	addi	a0,a0,-1418 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200aea:	ed8ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(slub_nr_free_pages() == 3);
ffffffffc0200aee:	00001697          	auipc	a3,0x1
ffffffffc0200af2:	ca268693          	addi	a3,a3,-862 # ffffffffc0201790 <etext+0x600>
ffffffffc0200af6:	00001617          	auipc	a2,0x1
ffffffffc0200afa:	a4a60613          	addi	a2,a2,-1462 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200afe:	1c000593          	li	a1,448
ffffffffc0200b02:	00001517          	auipc	a0,0x1
ffffffffc0200b06:	a5650513          	addi	a0,a0,-1450 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200b0a:	eb8ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200b0e:	00001697          	auipc	a3,0x1
ffffffffc0200b12:	c4268693          	addi	a3,a3,-958 # ffffffffc0201750 <etext+0x5c0>
ffffffffc0200b16:	00001617          	auipc	a2,0x1
ffffffffc0200b1a:	a2a60613          	addi	a2,a2,-1494 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200b1e:	1b800593          	li	a1,440
ffffffffc0200b22:	00001517          	auipc	a0,0x1
ffffffffc0200b26:	a3650513          	addi	a0,a0,-1482 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200b2a:	e98ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200b2e:	00001697          	auipc	a3,0x1
ffffffffc0200b32:	bfa68693          	addi	a3,a3,-1030 # ffffffffc0201728 <etext+0x598>
ffffffffc0200b36:	00001617          	auipc	a2,0x1
ffffffffc0200b3a:	a0a60613          	addi	a2,a2,-1526 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200b3e:	1b700593          	li	a1,439
ffffffffc0200b42:	00001517          	auipc	a0,0x1
ffffffffc0200b46:	a1650513          	addi	a0,a0,-1514 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200b4a:	e78ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = slub_alloc_pages(1)) != NULL);
ffffffffc0200b4e:	00001697          	auipc	a3,0x1
ffffffffc0200b52:	bb268693          	addi	a3,a3,-1102 # ffffffffc0201700 <etext+0x570>
ffffffffc0200b56:	00001617          	auipc	a2,0x1
ffffffffc0200b5a:	9ea60613          	addi	a2,a2,-1558 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200b5e:	1b400593          	li	a1,436
ffffffffc0200b62:	00001517          	auipc	a0,0x1
ffffffffc0200b66:	9f650513          	addi	a0,a0,-1546 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200b6a:	e58ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = slub_alloc_pages(1)) != NULL);
ffffffffc0200b6e:	00001697          	auipc	a3,0x1
ffffffffc0200b72:	b6a68693          	addi	a3,a3,-1174 # ffffffffc02016d8 <etext+0x548>
ffffffffc0200b76:	00001617          	auipc	a2,0x1
ffffffffc0200b7a:	9ca60613          	addi	a2,a2,-1590 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200b7e:	1b300593          	li	a1,435
ffffffffc0200b82:	00001517          	auipc	a0,0x1
ffffffffc0200b86:	9d650513          	addi	a0,a0,-1578 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200b8a:	e38ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200b8e <slub_init_memmap>:
static void slub_init_memmap(struct Page *base, size_t n) {
ffffffffc0200b8e:	7179                	addi	sp,sp,-48
ffffffffc0200b90:	f406                	sd	ra,40(sp)
ffffffffc0200b92:	f022                	sd	s0,32(sp)
ffffffffc0200b94:	ec26                	sd	s1,24(sp)
ffffffffc0200b96:	e84a                	sd	s2,16(sp)
ffffffffc0200b98:	e44e                	sd	s3,8(sp)
    assert(n > 0);  // 确保 n 大于 0
ffffffffc0200b9a:	14058163          	beqz	a1,ffffffffc0200cdc <slub_init_memmap+0x14e>
    for (struct Page *it = base; it < base + n; ++it) {
ffffffffc0200b9e:	00259693          	slli	a3,a1,0x2
ffffffffc0200ba2:	96ae                	add	a3,a3,a1
ffffffffc0200ba4:	068e                	slli	a3,a3,0x3
ffffffffc0200ba6:	96aa                	add	a3,a3,a0
ffffffffc0200ba8:	84ae                	mv	s1,a1
ffffffffc0200baa:	842a                	mv	s0,a0
ffffffffc0200bac:	87aa                	mv	a5,a0
ffffffffc0200bae:	02d57063          	bgeu	a0,a3,ffffffffc0200bce <slub_init_memmap+0x40>
        assert(PageReserved(it));  // 确保页面已标记为预留
ffffffffc0200bb2:	6798                	ld	a4,8(a5)
ffffffffc0200bb4:	8b05                	andi	a4,a4,1
ffffffffc0200bb6:	10070363          	beqz	a4,ffffffffc0200cbc <slub_init_memmap+0x12e>
        it->flags = 0;
ffffffffc0200bba:	0007b423          	sd	zero,8(a5)
        it->property = 0;
ffffffffc0200bbe:	0007a823          	sw	zero,16(a5)
ffffffffc0200bc2:	0007a023          	sw	zero,0(a5)
    for (struct Page *it = base; it < base + n; ++it) {
ffffffffc0200bc6:	02878793          	addi	a5,a5,40
ffffffffc0200bca:	fed7e4e3          	bltu	a5,a3,ffffffffc0200bb2 <slub_init_memmap+0x24>
        for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200bce:	8f26                	mv	t5,s1
ffffffffc0200bd0:	8322                	mv	t1,s0
ffffffffc0200bd2:	00004e97          	auipc	t4,0x4
ffffffffc0200bd6:	446e8e93          	addi	t4,t4,1094 # ffffffffc0205018 <free_area>
            if (free_area[i].size == block_size) {
ffffffffc0200bda:	6805                	lui	a6,0x1
        for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200bdc:	04000893          	li	a7,64
ffffffffc0200be0:	00004717          	auipc	a4,0x4
ffffffffc0200be4:	43870713          	addi	a4,a4,1080 # ffffffffc0205018 <free_area>
ffffffffc0200be8:	4781                	li	a5,0
ffffffffc0200bea:	a031                	j	ffffffffc0200bf6 <slub_init_memmap+0x68>
ffffffffc0200bec:	2785                	addiw	a5,a5,1
ffffffffc0200bee:	02070713          	addi	a4,a4,32
ffffffffc0200bf2:	0b178d63          	beq	a5,a7,ffffffffc0200cac <slub_init_memmap+0x11e>
            if (free_area[i].size == block_size) {
ffffffffc0200bf6:	6314                	ld	a3,0(a4)
ffffffffc0200bf8:	ff069ae3          	bne	a3,a6,ffffffffc0200bec <slub_init_memmap+0x5e>
        list_entry_t *head = &cache->free_list;
ffffffffc0200bfc:	0796                	slli	a5,a5,0x5
    return list->next == list;
ffffffffc0200bfe:	00fe85b3          	add	a1,t4,a5
ffffffffc0200c02:	6998                	ld	a4,16(a1)
ffffffffc0200c04:	00878693          	addi	a3,a5,8
ffffffffc0200c08:	96f6                	add	a3,a3,t4
ffffffffc0200c0a:	01830613          	addi	a2,t1,24
        if (list_empty(head)) {
ffffffffc0200c0e:	06e69563          	bne	a3,a4,ffffffffc0200c78 <slub_init_memmap+0xea>
    prev->next = next->prev = elm;
ffffffffc0200c12:	e290                	sd	a2,0(a3)
ffffffffc0200c14:	e990                	sd	a2,16(a1)
    elm->next = next;
ffffffffc0200c16:	02d33023          	sd	a3,32(t1)
    elm->prev = prev;
ffffffffc0200c1a:	00d33c23          	sd	a3,24(t1)
        cache->nr_free++;  // 更新空闲块数量
ffffffffc0200c1e:	97f6                	add	a5,a5,t4
ffffffffc0200c20:	4f98                	lw	a4,24(a5)
        remain -= consumed;
ffffffffc0200c22:	1f7d                	addi	t5,t5,-1
        p += consumed;
ffffffffc0200c24:	02830313          	addi	t1,t1,40
        cache->nr_free++;  // 更新空闲块数量
ffffffffc0200c28:	2705                	addiw	a4,a4,1
ffffffffc0200c2a:	cf98                	sw	a4,24(a5)
    while (remain > 0) {
ffffffffc0200c2c:	fa0f1ae3          	bnez	t5,ffffffffc0200be0 <slub_init_memmap+0x52>
    cprintf("Initialized memory block at %p with %zu pages\n", base, n);
ffffffffc0200c30:	8626                	mv	a2,s1
ffffffffc0200c32:	85a2                	mv	a1,s0
ffffffffc0200c34:	00001517          	auipc	a0,0x1
ffffffffc0200c38:	b9450513          	addi	a0,a0,-1132 # ffffffffc02017c8 <etext+0x638>
ffffffffc0200c3c:	d10ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200c40:	00004497          	auipc	s1,0x4
ffffffffc0200c44:	3f048493          	addi	s1,s1,1008 # ffffffffc0205030 <free_area+0x18>
ffffffffc0200c48:	4401                	li	s0,0
        cprintf("Cache[%d] has %u free pages\n", i, free_area[i].nr_free);
ffffffffc0200c4a:	00001997          	auipc	s3,0x1
ffffffffc0200c4e:	bae98993          	addi	s3,s3,-1106 # ffffffffc02017f8 <etext+0x668>
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200c52:	04000913          	li	s2,64
        cprintf("Cache[%d] has %u free pages\n", i, free_area[i].nr_free);
ffffffffc0200c56:	4090                	lw	a2,0(s1)
ffffffffc0200c58:	85a2                	mv	a1,s0
ffffffffc0200c5a:	854e                	mv	a0,s3
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200c5c:	2405                	addiw	s0,s0,1
        cprintf("Cache[%d] has %u free pages\n", i, free_area[i].nr_free);
ffffffffc0200c5e:	ceeff0ef          	jal	ra,ffffffffc020014c <cprintf>
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
ffffffffc0200c62:	02048493          	addi	s1,s1,32
ffffffffc0200c66:	ff2418e3          	bne	s0,s2,ffffffffc0200c56 <slub_init_memmap+0xc8>
}
ffffffffc0200c6a:	70a2                	ld	ra,40(sp)
ffffffffc0200c6c:	7402                	ld	s0,32(sp)
ffffffffc0200c6e:	64e2                	ld	s1,24(sp)
ffffffffc0200c70:	6942                	ld	s2,16(sp)
ffffffffc0200c72:	69a2                	ld	s3,8(sp)
ffffffffc0200c74:	6145                	addi	sp,sp,48
ffffffffc0200c76:	8082                	ret
                struct Page *q = le2page(le, page_link);
ffffffffc0200c78:	fe870e13          	addi	t3,a4,-24
                if (p < q) {
ffffffffc0200c7c:	03c36063          	bltu	t1,t3,ffffffffc0200c9c <slub_init_memmap+0x10e>
    return listelm->next;
ffffffffc0200c80:	6718                	ld	a4,8(a4)
            while (le != head) {
ffffffffc0200c82:	fee69be3          	bne	a3,a4,ffffffffc0200c78 <slub_init_memmap+0xea>
    return listelm->prev;
ffffffffc0200c86:	00fe8733          	add	a4,t4,a5
ffffffffc0200c8a:	6718                	ld	a4,8(a4)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200c8c:	6714                	ld	a3,8(a4)
    prev->next = next->prev = elm;
ffffffffc0200c8e:	e290                	sd	a2,0(a3)
ffffffffc0200c90:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200c92:	02d33023          	sd	a3,32(t1)
    elm->prev = prev;
ffffffffc0200c96:	00e33c23          	sd	a4,24(t1)
}
ffffffffc0200c9a:	b751                	j	ffffffffc0200c1e <slub_init_memmap+0x90>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200c9c:	6314                	ld	a3,0(a4)
    prev->next = next->prev = elm;
ffffffffc0200c9e:	e310                	sd	a2,0(a4)
ffffffffc0200ca0:	e690                	sd	a2,8(a3)
    elm->next = next;
ffffffffc0200ca2:	02e33023          	sd	a4,32(t1)
    elm->prev = prev;
ffffffffc0200ca6:	00d33c23          	sd	a3,24(t1)
            if (!inserted) {
ffffffffc0200caa:	bf95                	j	ffffffffc0200c1e <slub_init_memmap+0x90>
            cprintf("Warning: No suitable cache found for block size %zu\n", block_size);
ffffffffc0200cac:	6585                	lui	a1,0x1
ffffffffc0200cae:	00001517          	auipc	a0,0x1
ffffffffc0200cb2:	b6a50513          	addi	a0,a0,-1174 # ffffffffc0201818 <etext+0x688>
ffffffffc0200cb6:	c96ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    while (remain > 0) {
ffffffffc0200cba:	bf9d                	j	ffffffffc0200c30 <slub_init_memmap+0xa2>
        assert(PageReserved(it));  // 确保页面已标记为预留
ffffffffc0200cbc:	00001697          	auipc	a3,0x1
ffffffffc0200cc0:	af468693          	addi	a3,a3,-1292 # ffffffffc02017b0 <etext+0x620>
ffffffffc0200cc4:	00001617          	auipc	a2,0x1
ffffffffc0200cc8:	87c60613          	addi	a2,a2,-1924 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200ccc:	10000593          	li	a1,256
ffffffffc0200cd0:	00001517          	auipc	a0,0x1
ffffffffc0200cd4:	88850513          	addi	a0,a0,-1912 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200cd8:	ceaff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);  // 确保 n 大于 0
ffffffffc0200cdc:	00001697          	auipc	a3,0x1
ffffffffc0200ce0:	85c68693          	addi	a3,a3,-1956 # ffffffffc0201538 <etext+0x3a8>
ffffffffc0200ce4:	00001617          	auipc	a2,0x1
ffffffffc0200ce8:	85c60613          	addi	a2,a2,-1956 # ffffffffc0201540 <etext+0x3b0>
ffffffffc0200cec:	0fc00593          	li	a1,252
ffffffffc0200cf0:	00001517          	auipc	a0,0x1
ffffffffc0200cf4:	86850513          	addi	a0,a0,-1944 # ffffffffc0201558 <etext+0x3c8>
ffffffffc0200cf8:	ccaff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200cfc <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0200cfc:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200d00:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0200d02:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200d06:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0200d08:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200d0c:	f022                	sd	s0,32(sp)
ffffffffc0200d0e:	ec26                	sd	s1,24(sp)
ffffffffc0200d10:	e84a                	sd	s2,16(sp)
ffffffffc0200d12:	f406                	sd	ra,40(sp)
ffffffffc0200d14:	e44e                	sd	s3,8(sp)
ffffffffc0200d16:	84aa                	mv	s1,a0
ffffffffc0200d18:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0200d1a:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0200d1e:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0200d20:	03067e63          	bgeu	a2,a6,ffffffffc0200d5c <printnum+0x60>
ffffffffc0200d24:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0200d26:	00805763          	blez	s0,ffffffffc0200d34 <printnum+0x38>
ffffffffc0200d2a:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0200d2c:	85ca                	mv	a1,s2
ffffffffc0200d2e:	854e                	mv	a0,s3
ffffffffc0200d30:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0200d32:	fc65                	bnez	s0,ffffffffc0200d2a <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200d34:	1a02                	slli	s4,s4,0x20
ffffffffc0200d36:	00001797          	auipc	a5,0x1
ffffffffc0200d3a:	b6a78793          	addi	a5,a5,-1174 # ffffffffc02018a0 <slub_pmm_manager+0x38>
ffffffffc0200d3e:	020a5a13          	srli	s4,s4,0x20
ffffffffc0200d42:	9a3e                	add	s4,s4,a5
}
ffffffffc0200d44:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200d46:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0200d4a:	70a2                	ld	ra,40(sp)
ffffffffc0200d4c:	69a2                	ld	s3,8(sp)
ffffffffc0200d4e:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200d50:	85ca                	mv	a1,s2
ffffffffc0200d52:	87a6                	mv	a5,s1
}
ffffffffc0200d54:	6942                	ld	s2,16(sp)
ffffffffc0200d56:	64e2                	ld	s1,24(sp)
ffffffffc0200d58:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200d5a:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0200d5c:	03065633          	divu	a2,a2,a6
ffffffffc0200d60:	8722                	mv	a4,s0
ffffffffc0200d62:	f9bff0ef          	jal	ra,ffffffffc0200cfc <printnum>
ffffffffc0200d66:	b7f9                	j	ffffffffc0200d34 <printnum+0x38>

ffffffffc0200d68 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0200d68:	7119                	addi	sp,sp,-128
ffffffffc0200d6a:	f4a6                	sd	s1,104(sp)
ffffffffc0200d6c:	f0ca                	sd	s2,96(sp)
ffffffffc0200d6e:	ecce                	sd	s3,88(sp)
ffffffffc0200d70:	e8d2                	sd	s4,80(sp)
ffffffffc0200d72:	e4d6                	sd	s5,72(sp)
ffffffffc0200d74:	e0da                	sd	s6,64(sp)
ffffffffc0200d76:	fc5e                	sd	s7,56(sp)
ffffffffc0200d78:	f06a                	sd	s10,32(sp)
ffffffffc0200d7a:	fc86                	sd	ra,120(sp)
ffffffffc0200d7c:	f8a2                	sd	s0,112(sp)
ffffffffc0200d7e:	f862                	sd	s8,48(sp)
ffffffffc0200d80:	f466                	sd	s9,40(sp)
ffffffffc0200d82:	ec6e                	sd	s11,24(sp)
ffffffffc0200d84:	892a                	mv	s2,a0
ffffffffc0200d86:	84ae                	mv	s1,a1
ffffffffc0200d88:	8d32                	mv	s10,a2
ffffffffc0200d8a:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200d8c:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0200d90:	5b7d                	li	s6,-1
ffffffffc0200d92:	00001a97          	auipc	s5,0x1
ffffffffc0200d96:	b42a8a93          	addi	s5,s5,-1214 # ffffffffc02018d4 <slub_pmm_manager+0x6c>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0200d9a:	00001b97          	auipc	s7,0x1
ffffffffc0200d9e:	d16b8b93          	addi	s7,s7,-746 # ffffffffc0201ab0 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200da2:	000d4503          	lbu	a0,0(s10)
ffffffffc0200da6:	001d0413          	addi	s0,s10,1
ffffffffc0200daa:	01350a63          	beq	a0,s3,ffffffffc0200dbe <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0200dae:	c121                	beqz	a0,ffffffffc0200dee <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0200db0:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200db2:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0200db4:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200db6:	fff44503          	lbu	a0,-1(s0)
ffffffffc0200dba:	ff351ae3          	bne	a0,s3,ffffffffc0200dae <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200dbe:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0200dc2:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0200dc6:	4c81                	li	s9,0
ffffffffc0200dc8:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0200dca:	5c7d                	li	s8,-1
ffffffffc0200dcc:	5dfd                	li	s11,-1
ffffffffc0200dce:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0200dd2:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200dd4:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0200dd8:	0ff5f593          	zext.b	a1,a1
ffffffffc0200ddc:	00140d13          	addi	s10,s0,1
ffffffffc0200de0:	04b56263          	bltu	a0,a1,ffffffffc0200e24 <vprintfmt+0xbc>
ffffffffc0200de4:	058a                	slli	a1,a1,0x2
ffffffffc0200de6:	95d6                	add	a1,a1,s5
ffffffffc0200de8:	4194                	lw	a3,0(a1)
ffffffffc0200dea:	96d6                	add	a3,a3,s5
ffffffffc0200dec:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0200dee:	70e6                	ld	ra,120(sp)
ffffffffc0200df0:	7446                	ld	s0,112(sp)
ffffffffc0200df2:	74a6                	ld	s1,104(sp)
ffffffffc0200df4:	7906                	ld	s2,96(sp)
ffffffffc0200df6:	69e6                	ld	s3,88(sp)
ffffffffc0200df8:	6a46                	ld	s4,80(sp)
ffffffffc0200dfa:	6aa6                	ld	s5,72(sp)
ffffffffc0200dfc:	6b06                	ld	s6,64(sp)
ffffffffc0200dfe:	7be2                	ld	s7,56(sp)
ffffffffc0200e00:	7c42                	ld	s8,48(sp)
ffffffffc0200e02:	7ca2                	ld	s9,40(sp)
ffffffffc0200e04:	7d02                	ld	s10,32(sp)
ffffffffc0200e06:	6de2                	ld	s11,24(sp)
ffffffffc0200e08:	6109                	addi	sp,sp,128
ffffffffc0200e0a:	8082                	ret
            padc = '0';
ffffffffc0200e0c:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0200e0e:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200e12:	846a                	mv	s0,s10
ffffffffc0200e14:	00140d13          	addi	s10,s0,1
ffffffffc0200e18:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0200e1c:	0ff5f593          	zext.b	a1,a1
ffffffffc0200e20:	fcb572e3          	bgeu	a0,a1,ffffffffc0200de4 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0200e24:	85a6                	mv	a1,s1
ffffffffc0200e26:	02500513          	li	a0,37
ffffffffc0200e2a:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0200e2c:	fff44783          	lbu	a5,-1(s0)
ffffffffc0200e30:	8d22                	mv	s10,s0
ffffffffc0200e32:	f73788e3          	beq	a5,s3,ffffffffc0200da2 <vprintfmt+0x3a>
ffffffffc0200e36:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0200e3a:	1d7d                	addi	s10,s10,-1
ffffffffc0200e3c:	ff379de3          	bne	a5,s3,ffffffffc0200e36 <vprintfmt+0xce>
ffffffffc0200e40:	b78d                	j	ffffffffc0200da2 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0200e42:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0200e46:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200e4a:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0200e4c:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0200e50:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0200e54:	02d86463          	bltu	a6,a3,ffffffffc0200e7c <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0200e58:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0200e5c:	002c169b          	slliw	a3,s8,0x2
ffffffffc0200e60:	0186873b          	addw	a4,a3,s8
ffffffffc0200e64:	0017171b          	slliw	a4,a4,0x1
ffffffffc0200e68:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0200e6a:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0200e6e:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0200e70:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0200e74:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0200e78:	fed870e3          	bgeu	a6,a3,ffffffffc0200e58 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0200e7c:	f40ddce3          	bgez	s11,ffffffffc0200dd4 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0200e80:	8de2                	mv	s11,s8
ffffffffc0200e82:	5c7d                	li	s8,-1
ffffffffc0200e84:	bf81                	j	ffffffffc0200dd4 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0200e86:	fffdc693          	not	a3,s11
ffffffffc0200e8a:	96fd                	srai	a3,a3,0x3f
ffffffffc0200e8c:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200e90:	00144603          	lbu	a2,1(s0)
ffffffffc0200e94:	2d81                	sext.w	s11,s11
ffffffffc0200e96:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0200e98:	bf35                	j	ffffffffc0200dd4 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0200e9a:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200e9e:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0200ea2:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200ea4:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0200ea6:	bfd9                	j	ffffffffc0200e7c <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0200ea8:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0200eaa:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0200eae:	01174463          	blt	a4,a7,ffffffffc0200eb6 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0200eb2:	1a088e63          	beqz	a7,ffffffffc020106e <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0200eb6:	000a3603          	ld	a2,0(s4)
ffffffffc0200eba:	46c1                	li	a3,16
ffffffffc0200ebc:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0200ebe:	2781                	sext.w	a5,a5
ffffffffc0200ec0:	876e                	mv	a4,s11
ffffffffc0200ec2:	85a6                	mv	a1,s1
ffffffffc0200ec4:	854a                	mv	a0,s2
ffffffffc0200ec6:	e37ff0ef          	jal	ra,ffffffffc0200cfc <printnum>
            break;
ffffffffc0200eca:	bde1                	j	ffffffffc0200da2 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0200ecc:	000a2503          	lw	a0,0(s4)
ffffffffc0200ed0:	85a6                	mv	a1,s1
ffffffffc0200ed2:	0a21                	addi	s4,s4,8
ffffffffc0200ed4:	9902                	jalr	s2
            break;
ffffffffc0200ed6:	b5f1                	j	ffffffffc0200da2 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0200ed8:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0200eda:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0200ede:	01174463          	blt	a4,a7,ffffffffc0200ee6 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0200ee2:	18088163          	beqz	a7,ffffffffc0201064 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0200ee6:	000a3603          	ld	a2,0(s4)
ffffffffc0200eea:	46a9                	li	a3,10
ffffffffc0200eec:	8a2e                	mv	s4,a1
ffffffffc0200eee:	bfc1                	j	ffffffffc0200ebe <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200ef0:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0200ef4:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200ef6:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0200ef8:	bdf1                	j	ffffffffc0200dd4 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0200efa:	85a6                	mv	a1,s1
ffffffffc0200efc:	02500513          	li	a0,37
ffffffffc0200f00:	9902                	jalr	s2
            break;
ffffffffc0200f02:	b545                	j	ffffffffc0200da2 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200f04:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0200f08:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0200f0a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0200f0c:	b5e1                	j	ffffffffc0200dd4 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0200f0e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0200f10:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0200f14:	01174463          	blt	a4,a7,ffffffffc0200f1c <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0200f18:	14088163          	beqz	a7,ffffffffc020105a <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0200f1c:	000a3603          	ld	a2,0(s4)
ffffffffc0200f20:	46a1                	li	a3,8
ffffffffc0200f22:	8a2e                	mv	s4,a1
ffffffffc0200f24:	bf69                	j	ffffffffc0200ebe <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0200f26:	03000513          	li	a0,48
ffffffffc0200f2a:	85a6                	mv	a1,s1
ffffffffc0200f2c:	e03e                	sd	a5,0(sp)
ffffffffc0200f2e:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0200f30:	85a6                	mv	a1,s1
ffffffffc0200f32:	07800513          	li	a0,120
ffffffffc0200f36:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0200f38:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0200f3a:	6782                	ld	a5,0(sp)
ffffffffc0200f3c:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0200f3e:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0200f42:	bfb5                	j	ffffffffc0200ebe <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0200f44:	000a3403          	ld	s0,0(s4)
ffffffffc0200f48:	008a0713          	addi	a4,s4,8
ffffffffc0200f4c:	e03a                	sd	a4,0(sp)
ffffffffc0200f4e:	14040263          	beqz	s0,ffffffffc0201092 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0200f52:	0fb05763          	blez	s11,ffffffffc0201040 <vprintfmt+0x2d8>
ffffffffc0200f56:	02d00693          	li	a3,45
ffffffffc0200f5a:	0cd79163          	bne	a5,a3,ffffffffc020101c <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0200f5e:	00044783          	lbu	a5,0(s0)
ffffffffc0200f62:	0007851b          	sext.w	a0,a5
ffffffffc0200f66:	cf85                	beqz	a5,ffffffffc0200f9e <vprintfmt+0x236>
ffffffffc0200f68:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0200f6c:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0200f70:	000c4563          	bltz	s8,ffffffffc0200f7a <vprintfmt+0x212>
ffffffffc0200f74:	3c7d                	addiw	s8,s8,-1
ffffffffc0200f76:	036c0263          	beq	s8,s6,ffffffffc0200f9a <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0200f7a:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0200f7c:	0e0c8e63          	beqz	s9,ffffffffc0201078 <vprintfmt+0x310>
ffffffffc0200f80:	3781                	addiw	a5,a5,-32
ffffffffc0200f82:	0ef47b63          	bgeu	s0,a5,ffffffffc0201078 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0200f86:	03f00513          	li	a0,63
ffffffffc0200f8a:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0200f8c:	000a4783          	lbu	a5,0(s4)
ffffffffc0200f90:	3dfd                	addiw	s11,s11,-1
ffffffffc0200f92:	0a05                	addi	s4,s4,1
ffffffffc0200f94:	0007851b          	sext.w	a0,a5
ffffffffc0200f98:	ffe1                	bnez	a5,ffffffffc0200f70 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0200f9a:	01b05963          	blez	s11,ffffffffc0200fac <vprintfmt+0x244>
ffffffffc0200f9e:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0200fa0:	85a6                	mv	a1,s1
ffffffffc0200fa2:	02000513          	li	a0,32
ffffffffc0200fa6:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0200fa8:	fe0d9be3          	bnez	s11,ffffffffc0200f9e <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0200fac:	6a02                	ld	s4,0(sp)
ffffffffc0200fae:	bbd5                	j	ffffffffc0200da2 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0200fb0:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0200fb2:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0200fb6:	01174463          	blt	a4,a7,ffffffffc0200fbe <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0200fba:	08088d63          	beqz	a7,ffffffffc0201054 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0200fbe:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0200fc2:	0a044d63          	bltz	s0,ffffffffc020107c <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0200fc6:	8622                	mv	a2,s0
ffffffffc0200fc8:	8a66                	mv	s4,s9
ffffffffc0200fca:	46a9                	li	a3,10
ffffffffc0200fcc:	bdcd                	j	ffffffffc0200ebe <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0200fce:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0200fd2:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0200fd4:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0200fd6:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0200fda:	8fb5                	xor	a5,a5,a3
ffffffffc0200fdc:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0200fe0:	02d74163          	blt	a4,a3,ffffffffc0201002 <vprintfmt+0x29a>
ffffffffc0200fe4:	00369793          	slli	a5,a3,0x3
ffffffffc0200fe8:	97de                	add	a5,a5,s7
ffffffffc0200fea:	639c                	ld	a5,0(a5)
ffffffffc0200fec:	cb99                	beqz	a5,ffffffffc0201002 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0200fee:	86be                	mv	a3,a5
ffffffffc0200ff0:	00001617          	auipc	a2,0x1
ffffffffc0200ff4:	8e060613          	addi	a2,a2,-1824 # ffffffffc02018d0 <slub_pmm_manager+0x68>
ffffffffc0200ff8:	85a6                	mv	a1,s1
ffffffffc0200ffa:	854a                	mv	a0,s2
ffffffffc0200ffc:	0ce000ef          	jal	ra,ffffffffc02010ca <printfmt>
ffffffffc0201000:	b34d                	j	ffffffffc0200da2 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201002:	00001617          	auipc	a2,0x1
ffffffffc0201006:	8be60613          	addi	a2,a2,-1858 # ffffffffc02018c0 <slub_pmm_manager+0x58>
ffffffffc020100a:	85a6                	mv	a1,s1
ffffffffc020100c:	854a                	mv	a0,s2
ffffffffc020100e:	0bc000ef          	jal	ra,ffffffffc02010ca <printfmt>
ffffffffc0201012:	bb41                	j	ffffffffc0200da2 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201014:	00001417          	auipc	s0,0x1
ffffffffc0201018:	8a440413          	addi	s0,s0,-1884 # ffffffffc02018b8 <slub_pmm_manager+0x50>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020101c:	85e2                	mv	a1,s8
ffffffffc020101e:	8522                	mv	a0,s0
ffffffffc0201020:	e43e                	sd	a5,8(sp)
ffffffffc0201022:	0fc000ef          	jal	ra,ffffffffc020111e <strnlen>
ffffffffc0201026:	40ad8dbb          	subw	s11,s11,a0
ffffffffc020102a:	01b05b63          	blez	s11,ffffffffc0201040 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc020102e:	67a2                	ld	a5,8(sp)
ffffffffc0201030:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201034:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201036:	85a6                	mv	a1,s1
ffffffffc0201038:	8552                	mv	a0,s4
ffffffffc020103a:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020103c:	fe0d9ce3          	bnez	s11,ffffffffc0201034 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201040:	00044783          	lbu	a5,0(s0)
ffffffffc0201044:	00140a13          	addi	s4,s0,1
ffffffffc0201048:	0007851b          	sext.w	a0,a5
ffffffffc020104c:	d3a5                	beqz	a5,ffffffffc0200fac <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020104e:	05e00413          	li	s0,94
ffffffffc0201052:	bf39                	j	ffffffffc0200f70 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201054:	000a2403          	lw	s0,0(s4)
ffffffffc0201058:	b7ad                	j	ffffffffc0200fc2 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc020105a:	000a6603          	lwu	a2,0(s4)
ffffffffc020105e:	46a1                	li	a3,8
ffffffffc0201060:	8a2e                	mv	s4,a1
ffffffffc0201062:	bdb1                	j	ffffffffc0200ebe <vprintfmt+0x156>
ffffffffc0201064:	000a6603          	lwu	a2,0(s4)
ffffffffc0201068:	46a9                	li	a3,10
ffffffffc020106a:	8a2e                	mv	s4,a1
ffffffffc020106c:	bd89                	j	ffffffffc0200ebe <vprintfmt+0x156>
ffffffffc020106e:	000a6603          	lwu	a2,0(s4)
ffffffffc0201072:	46c1                	li	a3,16
ffffffffc0201074:	8a2e                	mv	s4,a1
ffffffffc0201076:	b5a1                	j	ffffffffc0200ebe <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201078:	9902                	jalr	s2
ffffffffc020107a:	bf09                	j	ffffffffc0200f8c <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc020107c:	85a6                	mv	a1,s1
ffffffffc020107e:	02d00513          	li	a0,45
ffffffffc0201082:	e03e                	sd	a5,0(sp)
ffffffffc0201084:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201086:	6782                	ld	a5,0(sp)
ffffffffc0201088:	8a66                	mv	s4,s9
ffffffffc020108a:	40800633          	neg	a2,s0
ffffffffc020108e:	46a9                	li	a3,10
ffffffffc0201090:	b53d                	j	ffffffffc0200ebe <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201092:	03b05163          	blez	s11,ffffffffc02010b4 <vprintfmt+0x34c>
ffffffffc0201096:	02d00693          	li	a3,45
ffffffffc020109a:	f6d79de3          	bne	a5,a3,ffffffffc0201014 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020109e:	00001417          	auipc	s0,0x1
ffffffffc02010a2:	81a40413          	addi	s0,s0,-2022 # ffffffffc02018b8 <slub_pmm_manager+0x50>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02010a6:	02800793          	li	a5,40
ffffffffc02010aa:	02800513          	li	a0,40
ffffffffc02010ae:	00140a13          	addi	s4,s0,1
ffffffffc02010b2:	bd6d                	j	ffffffffc0200f6c <vprintfmt+0x204>
ffffffffc02010b4:	00001a17          	auipc	s4,0x1
ffffffffc02010b8:	805a0a13          	addi	s4,s4,-2043 # ffffffffc02018b9 <slub_pmm_manager+0x51>
ffffffffc02010bc:	02800513          	li	a0,40
ffffffffc02010c0:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02010c4:	05e00413          	li	s0,94
ffffffffc02010c8:	b565                	j	ffffffffc0200f70 <vprintfmt+0x208>

ffffffffc02010ca <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02010ca:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc02010cc:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02010d0:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02010d2:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02010d4:	ec06                	sd	ra,24(sp)
ffffffffc02010d6:	f83a                	sd	a4,48(sp)
ffffffffc02010d8:	fc3e                	sd	a5,56(sp)
ffffffffc02010da:	e0c2                	sd	a6,64(sp)
ffffffffc02010dc:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc02010de:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02010e0:	c89ff0ef          	jal	ra,ffffffffc0200d68 <vprintfmt>
}
ffffffffc02010e4:	60e2                	ld	ra,24(sp)
ffffffffc02010e6:	6161                	addi	sp,sp,80
ffffffffc02010e8:	8082                	ret

ffffffffc02010ea <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02010ea:	4781                	li	a5,0
ffffffffc02010ec:	00004717          	auipc	a4,0x4
ffffffffc02010f0:	f2473703          	ld	a4,-220(a4) # ffffffffc0205010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02010f4:	88ba                	mv	a7,a4
ffffffffc02010f6:	852a                	mv	a0,a0
ffffffffc02010f8:	85be                	mv	a1,a5
ffffffffc02010fa:	863e                	mv	a2,a5
ffffffffc02010fc:	00000073          	ecall
ffffffffc0201100:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201102:	8082                	ret

ffffffffc0201104 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201104:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201108:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc020110a:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc020110c:	cb81                	beqz	a5,ffffffffc020111c <strlen+0x18>
        cnt ++;
ffffffffc020110e:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201110:	00a707b3          	add	a5,a4,a0
ffffffffc0201114:	0007c783          	lbu	a5,0(a5)
ffffffffc0201118:	fbfd                	bnez	a5,ffffffffc020110e <strlen+0xa>
ffffffffc020111a:	8082                	ret
    }
    return cnt;
}
ffffffffc020111c:	8082                	ret

ffffffffc020111e <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020111e:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201120:	e589                	bnez	a1,ffffffffc020112a <strnlen+0xc>
ffffffffc0201122:	a811                	j	ffffffffc0201136 <strnlen+0x18>
        cnt ++;
ffffffffc0201124:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201126:	00f58863          	beq	a1,a5,ffffffffc0201136 <strnlen+0x18>
ffffffffc020112a:	00f50733          	add	a4,a0,a5
ffffffffc020112e:	00074703          	lbu	a4,0(a4)
ffffffffc0201132:	fb6d                	bnez	a4,ffffffffc0201124 <strnlen+0x6>
ffffffffc0201134:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201136:	852e                	mv	a0,a1
ffffffffc0201138:	8082                	ret

ffffffffc020113a <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020113a:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020113e:	0005c703          	lbu	a4,0(a1) # 1000 <kern_entry-0xffffffffc01ff000>
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201142:	cb89                	beqz	a5,ffffffffc0201154 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201144:	0505                	addi	a0,a0,1
ffffffffc0201146:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201148:	fee789e3          	beq	a5,a4,ffffffffc020113a <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020114c:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201150:	9d19                	subw	a0,a0,a4
ffffffffc0201152:	8082                	ret
ffffffffc0201154:	4501                	li	a0,0
ffffffffc0201156:	bfed                	j	ffffffffc0201150 <strcmp+0x16>

ffffffffc0201158 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201158:	c20d                	beqz	a2,ffffffffc020117a <strncmp+0x22>
ffffffffc020115a:	962e                	add	a2,a2,a1
ffffffffc020115c:	a031                	j	ffffffffc0201168 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc020115e:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201160:	00e79a63          	bne	a5,a4,ffffffffc0201174 <strncmp+0x1c>
ffffffffc0201164:	00b60b63          	beq	a2,a1,ffffffffc020117a <strncmp+0x22>
ffffffffc0201168:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc020116c:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020116e:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201172:	f7f5                	bnez	a5,ffffffffc020115e <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201174:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201178:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020117a:	4501                	li	a0,0
ffffffffc020117c:	8082                	ret

ffffffffc020117e <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc020117e:	ca01                	beqz	a2,ffffffffc020118e <memset+0x10>
ffffffffc0201180:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201182:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201184:	0785                	addi	a5,a5,1
ffffffffc0201186:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc020118a:	fec79de3          	bne	a5,a2,ffffffffc0201184 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020118e:	8082                	ret
