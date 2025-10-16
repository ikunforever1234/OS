
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
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
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

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
ffffffffc0200050:	3b450513          	addi	a0,a0,948 # ffffffffc0201400 <etext+0x2>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	3be50513          	addi	a0,a0,958 # ffffffffc0201420 <etext+0x22>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	39058593          	addi	a1,a1,912 # ffffffffc02013fe <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	3ca50513          	addi	a0,a0,970 # ffffffffc0201440 <etext+0x42>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	3d650513          	addi	a0,a0,982 # ffffffffc0201460 <etext+0x62>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	0d258593          	addi	a1,a1,210 # ffffffffc0206168 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	3e250513          	addi	a0,a0,994 # ffffffffc0201480 <etext+0x82>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	4bd58593          	addi	a1,a1,1213 # ffffffffc0206567 <end+0x3ff>
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
ffffffffc02000d0:	3d450513          	addi	a0,a0,980 # ffffffffc02014a0 <etext+0xa2>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00006517          	auipc	a0,0x6
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0206018 <free_area>
ffffffffc02000e0:	00006617          	auipc	a2,0x6
ffffffffc02000e4:	08860613          	addi	a2,a2,136 # ffffffffc0206168 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	2fc010ef          	jal	ra,ffffffffc02013ec <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	3d450513          	addi	a0,a0,980 # ffffffffc02014d0 <etext+0xd2>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	487000ef          	jal	ra,ffffffffc0200d92 <pmm_init>

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
ffffffffc0200140:	697000ef          	jal	ra,ffffffffc0200fd6 <vprintfmt>
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
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
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
ffffffffc0200176:	661000ef          	jal	ra,ffffffffc0200fd6 <vprintfmt>
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
ffffffffc02001c2:	00006317          	auipc	t1,0x6
ffffffffc02001c6:	f5e30313          	addi	t1,t1,-162 # ffffffffc0206120 <is_panic>
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
ffffffffc02001f6:	2fe50513          	addi	a0,a0,766 # ffffffffc02014f0 <etext+0xf2>
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
ffffffffc020020c:	2c050513          	addi	a0,a0,704 # ffffffffc02014c8 <etext+0xca>
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
ffffffffc020021c:	13c0106f          	j	ffffffffc0201358 <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	2ee50513          	addi	a0,a0,750 # ffffffffc0201510 <etext+0x112>
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
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	2d050513          	addi	a0,a0,720 # ffffffffc0201520 <etext+0x122>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00006417          	auipc	s0,0x6
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0206008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	2ca50513          	addi	a0,a0,714 # ffffffffc0201530 <etext+0x132>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	2d250513          	addi	a0,a0,722 # ffffffffc0201548 <etext+0x14a>
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
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9d85>
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
ffffffffc0200334:	26890913          	addi	s2,s2,616 # ffffffffc0201598 <etext+0x19a>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	25248493          	addi	s1,s1,594 # ffffffffc0201590 <etext+0x192>
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
ffffffffc0200396:	27e50513          	addi	a0,a0,638 # ffffffffc0201610 <etext+0x212>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	2aa50513          	addi	a0,a0,682 # ffffffffc0201648 <etext+0x24a>
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
ffffffffc02003e2:	18a50513          	addi	a0,a0,394 # ffffffffc0201568 <etext+0x16a>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	787000ef          	jal	ra,ffffffffc0201372 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	7cd000ef          	jal	ra,ffffffffc02013c6 <strncmp>
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
ffffffffc0200490:	719000ef          	jal	ra,ffffffffc02013a8 <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	0fc50513          	addi	a0,a0,252 # ffffffffc02015a0 <etext+0x1a2>
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
ffffffffc0200576:	04e50513          	addi	a0,a0,78 # ffffffffc02015c0 <etext+0x1c2>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	05450513          	addi	a0,a0,84 # ffffffffc02015d8 <etext+0x1da>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	06250513          	addi	a0,a0,98 # ffffffffc02015f8 <etext+0x1fa>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	0a650513          	addi	a0,a0,166 # ffffffffc0201648 <etext+0x24a>
        memory_base = mem_base;
ffffffffc02005aa:	00006797          	auipc	a5,0x6
ffffffffc02005ae:	b687bf23          	sd	s0,-1154(a5) # ffffffffc0206128 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00006797          	auipc	a5,0x6
ffffffffc02005b6:	b767bf23          	sd	s6,-1154(a5) # ffffffffc0206130 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	b6c53503          	ld	a0,-1172(a0) # ffffffffc0206128 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00006517          	auipc	a0,0x6
ffffffffc02005ca:	b6a53503          	ld	a0,-1174(a0) # ffffffffc0206130 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <buddy_init>:
    size_t buddy_pfn = pfn ^ (1 << order);
    return pfn_to_page(buddy_pfn);
}

static void buddy_init(void) {
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0206018 <free_area>
ffffffffc02005d8:	00006717          	auipc	a4,0x6
ffffffffc02005dc:	b4870713          	addi	a4,a4,-1208 # ffffffffc0206120 <is_panic>
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005e0:	e79c                	sd	a5,8(a5)
ffffffffc02005e2:	e39c                	sd	a5,0(a5)
        list_init(&free_list(i));
        nr_free(i) = 0;
ffffffffc02005e4:	0007a823          	sw	zero,16(a5)
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02005e8:	07e1                	addi	a5,a5,24
ffffffffc02005ea:	fee79be3          	bne	a5,a4,ffffffffc02005e0 <buddy_init+0x10>
    }
}
ffffffffc02005ee:	8082                	ret

ffffffffc02005f0 <buddy_alloc_pages>:
}


static struct Page *buddy_alloc_pages(size_t n) {
    int order = 0;
    while ((1U << order) < n) order++;
ffffffffc02005f0:	4785                	li	a5,1
    int order = 0;
ffffffffc02005f2:	4601                	li	a2,0
    while ((1U << order) < n) order++;
ffffffffc02005f4:	00a7fd63          	bgeu	a5,a0,ffffffffc020060e <buddy_alloc_pages+0x1e>
ffffffffc02005f8:	4705                	li	a4,1
ffffffffc02005fa:	2605                	addiw	a2,a2,1
ffffffffc02005fc:	00c717bb          	sllw	a5,a4,a2
ffffffffc0200600:	1782                	slli	a5,a5,0x20
ffffffffc0200602:	9381                	srli	a5,a5,0x20
ffffffffc0200604:	fea7ebe3          	bltu	a5,a0,ffffffffc02005fa <buddy_alloc_pages+0xa>
    int cur_order = order;

    while (cur_order <= MAX_ORDER && list_empty(&free_list(cur_order))) {
ffffffffc0200608:	47a9                	li	a5,10
ffffffffc020060a:	0ac7c863          	blt	a5,a2,ffffffffc02006ba <buddy_alloc_pages+0xca>
ffffffffc020060e:	00161713          	slli	a4,a2,0x1
ffffffffc0200612:	9732                	add	a4,a4,a2
ffffffffc0200614:	00006697          	auipc	a3,0x6
ffffffffc0200618:	a0468693          	addi	a3,a3,-1532 # ffffffffc0206018 <free_area>
ffffffffc020061c:	070e                	slli	a4,a4,0x3
ffffffffc020061e:	9736                	add	a4,a4,a3
    int order = 0;
ffffffffc0200620:	87b2                	mv	a5,a2
    while (cur_order <= MAX_ORDER && list_empty(&free_list(cur_order))) {
ffffffffc0200622:	45ad                	li	a1,11
ffffffffc0200624:	a029                	j	ffffffffc020062e <buddy_alloc_pages+0x3e>
        cur_order++;
ffffffffc0200626:	2785                	addiw	a5,a5,1
    while (cur_order <= MAX_ORDER && list_empty(&free_list(cur_order))) {
ffffffffc0200628:	0761                	addi	a4,a4,24
ffffffffc020062a:	08b78863          	beq	a5,a1,ffffffffc02006ba <buddy_alloc_pages+0xca>
 * list_empty - tests whether a list is empty
 * @list:       the list to test.
 * */
static inline bool
list_empty(list_entry_t *list) {
    return list->next == list;
ffffffffc020062e:	00873883          	ld	a7,8(a4)
ffffffffc0200632:	fee88ae3          	beq	a7,a4,ffffffffc0200626 <buddy_alloc_pages+0x36>
    if (cur_order > MAX_ORDER) return NULL;

    list_entry_t *le = list_next(&free_list(cur_order));
    struct Page *page = le2page(le, page_link);
    list_del(le);
    nr_free(cur_order)--;
ffffffffc0200636:	00179713          	slli	a4,a5,0x1
ffffffffc020063a:	973e                	add	a4,a4,a5
ffffffffc020063c:	070e                	slli	a4,a4,0x3
ffffffffc020063e:	00e68533          	add	a0,a3,a4
    __list_del(listelm->prev, listelm->next);
ffffffffc0200642:	0008b303          	ld	t1,0(a7)
ffffffffc0200646:	0088b803          	ld	a6,8(a7)
ffffffffc020064a:	490c                	lw	a1,16(a0)
ffffffffc020064c:	1721                	addi	a4,a4,-24
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020064e:	01033423          	sd	a6,8(t1)
    next->prev = prev;
ffffffffc0200652:	00683023          	sd	t1,0(a6)
ffffffffc0200656:	35fd                	addiw	a1,a1,-1
ffffffffc0200658:	c90c                	sw	a1,16(a0)
ffffffffc020065a:	96ba                	add	a3,a3,a4
    struct Page *page = le2page(le, page_link);
ffffffffc020065c:	fe888513          	addi	a0,a7,-24

    while (cur_order > order) {
        cur_order--;
        struct Page *buddy = page + (1 << cur_order);
ffffffffc0200660:	4e05                	li	t3,1
    while (cur_order > order) {
ffffffffc0200662:	04f65663          	bge	a2,a5,ffffffffc02006ae <buddy_alloc_pages+0xbe>
        cur_order--;
ffffffffc0200666:	fff7871b          	addiw	a4,a5,-1
        struct Page *buddy = page + (1 << cur_order);
ffffffffc020066a:	00ee15bb          	sllw	a1,t3,a4
ffffffffc020066e:	00259793          	slli	a5,a1,0x2
ffffffffc0200672:	97ae                	add	a5,a5,a1
ffffffffc0200674:	078e                	slli	a5,a5,0x3
ffffffffc0200676:	97aa                	add	a5,a5,a0
        buddy->property = cur_order;
        SetPageProperty(buddy);
ffffffffc0200678:	0087b803          	ld	a6,8(a5)
    __list_add(elm, listelm, listelm->next);
ffffffffc020067c:	0086b303          	ld	t1,8(a3)
        buddy->property = cur_order;
ffffffffc0200680:	cb98                	sw	a4,16(a5)
        SetPageProperty(buddy);
ffffffffc0200682:	00286813          	ori	a6,a6,2
        list_add(&free_list(cur_order), &(buddy->page_link));
        nr_free(cur_order)++;
ffffffffc0200686:	4a8c                	lw	a1,16(a3)
        SetPageProperty(buddy);
ffffffffc0200688:	0107b423          	sd	a6,8(a5)
        list_add(&free_list(cur_order), &(buddy->page_link));
ffffffffc020068c:	01878813          	addi	a6,a5,24
    prev->next = next->prev = elm;
ffffffffc0200690:	01033023          	sd	a6,0(t1)
ffffffffc0200694:	0106b423          	sd	a6,8(a3)
    elm->prev = prev;
ffffffffc0200698:	ef94                	sd	a3,24(a5)
    elm->next = next;
ffffffffc020069a:	0267b023          	sd	t1,32(a5)
        nr_free(cur_order)++;
ffffffffc020069e:	0015879b          	addiw	a5,a1,1
ffffffffc02006a2:	ca9c                	sw	a5,16(a3)
        cur_order--;
ffffffffc02006a4:	0007079b          	sext.w	a5,a4
    while (cur_order > order) {
ffffffffc02006a8:	16a1                	addi	a3,a3,-24
ffffffffc02006aa:	fac79ee3          	bne	a5,a2,ffffffffc0200666 <buddy_alloc_pages+0x76>
    }

    ClearPageProperty(page);
ffffffffc02006ae:	ff08b783          	ld	a5,-16(a7)
ffffffffc02006b2:	9bf5                	andi	a5,a5,-3
ffffffffc02006b4:	fef8b823          	sd	a5,-16(a7)
    return page;
ffffffffc02006b8:	8082                	ret
    if (cur_order > MAX_ORDER) return NULL;
ffffffffc02006ba:	4501                	li	a0,0
}
ffffffffc02006bc:	8082                	ret

ffffffffc02006be <buddy_free_pages>:

static void buddy_free_pages(struct Page *page, size_t n) {
    int order = 0;
    while ((1U << order) < n) order++;
ffffffffc02006be:	4785                	li	a5,1
    int order = 0;
ffffffffc02006c0:	4601                	li	a2,0
    while ((1U << order) < n) order++;
ffffffffc02006c2:	00b7fd63          	bgeu	a5,a1,ffffffffc02006dc <buddy_free_pages+0x1e>
ffffffffc02006c6:	4705                	li	a4,1
ffffffffc02006c8:	2605                	addiw	a2,a2,1
ffffffffc02006ca:	00c717bb          	sllw	a5,a4,a2
ffffffffc02006ce:	1782                	slli	a5,a5,0x20
ffffffffc02006d0:	9381                	srli	a5,a5,0x20
ffffffffc02006d2:	feb7ebe3          	bltu	a5,a1,ffffffffc02006c8 <buddy_free_pages+0xa>

    while (order < MAX_ORDER) {
ffffffffc02006d6:	47a5                	li	a5,9
ffffffffc02006d8:	0ac7ca63          	blt	a5,a2,ffffffffc020078c <buddy_free_pages+0xce>
ffffffffc02006dc:	00161593          	slli	a1,a2,0x1
ffffffffc02006e0:	95b2                	add	a1,a1,a2
ffffffffc02006e2:	00006e97          	auipc	t4,0x6
ffffffffc02006e6:	936e8e93          	addi	t4,t4,-1738 # ffffffffc0206018 <free_area>
ffffffffc02006ea:	058e                	slli	a1,a1,0x3
    return page - pages;
ffffffffc02006ec:	00006897          	auipc	a7,0x6
ffffffffc02006f0:	a548b883          	ld	a7,-1452(a7) # ffffffffc0206140 <pages>
ffffffffc02006f4:	95f6                	add	a1,a1,t4
ffffffffc02006f6:	00002e17          	auipc	t3,0x2
ffffffffc02006fa:	9e2e3e03          	ld	t3,-1566(t3) # ffffffffc02020d8 <error_string+0x38>
    size_t buddy_pfn = pfn ^ (1 << order);
ffffffffc02006fe:	4305                	li	t1,1
    while (order < MAX_ORDER) {
ffffffffc0200700:	4f29                	li	t5,10
ffffffffc0200702:	a02d                	j	ffffffffc020072c <buddy_free_pages+0x6e>
        struct Page *buddy = buddy_of(page, order);
        if (!PageProperty(buddy) || buddy->property != order) break;
ffffffffc0200704:	4b98                	lw	a4,16(a5)
ffffffffc0200706:	05071663          	bne	a4,a6,ffffffffc0200752 <buddy_free_pages+0x94>
    __list_del(listelm->prev, listelm->next);
ffffffffc020070a:	0187b803          	ld	a6,24(a5)
ffffffffc020070e:	7394                	ld	a3,32(a5)

        list_del(&(buddy->page_link));
        nr_free(order)--;
ffffffffc0200710:	4998                	lw	a4,16(a1)

        if (buddy < page) page = buddy;
        order++;
ffffffffc0200712:	2605                	addiw	a2,a2,1
    prev->next = next;
ffffffffc0200714:	00d83423          	sd	a3,8(a6)
    next->prev = prev;
ffffffffc0200718:	0106b023          	sd	a6,0(a3)
        nr_free(order)--;
ffffffffc020071c:	377d                	addiw	a4,a4,-1
ffffffffc020071e:	c998                	sw	a4,16(a1)
        if (buddy < page) page = buddy;
ffffffffc0200720:	00a7f363          	bgeu	a5,a0,ffffffffc0200726 <buddy_free_pages+0x68>
ffffffffc0200724:	853e                	mv	a0,a5
    while (order < MAX_ORDER) {
ffffffffc0200726:	05e1                	addi	a1,a1,24
ffffffffc0200728:	07e60063          	beq	a2,t5,ffffffffc0200788 <buddy_free_pages+0xca>
    return page - pages;
ffffffffc020072c:	41150733          	sub	a4,a0,a7
ffffffffc0200730:	870d                	srai	a4,a4,0x3
ffffffffc0200732:	03c706b3          	mul	a3,a4,t3
    size_t buddy_pfn = pfn ^ (1 << order);
ffffffffc0200736:	00c317bb          	sllw	a5,t1,a2
ffffffffc020073a:	0006081b          	sext.w	a6,a2
ffffffffc020073e:	00f6c733          	xor	a4,a3,a5
    return &pages[pfn];
ffffffffc0200742:	00271793          	slli	a5,a4,0x2
ffffffffc0200746:	97ba                	add	a5,a5,a4
ffffffffc0200748:	078e                	slli	a5,a5,0x3
ffffffffc020074a:	97c6                	add	a5,a5,a7
        if (!PageProperty(buddy) || buddy->property != order) break;
ffffffffc020074c:	6798                	ld	a4,8(a5)
ffffffffc020074e:	8b09                	andi	a4,a4,2
ffffffffc0200750:	fb55                	bnez	a4,ffffffffc0200704 <buddy_free_pages+0x46>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200752:	00161793          	slli	a5,a2,0x1
ffffffffc0200756:	963e                	add	a2,a2,a5
ffffffffc0200758:	060e                	slli	a2,a2,0x3
    }

    page->property = order;
    SetPageProperty(page);
ffffffffc020075a:	651c                	ld	a5,8(a0)
ffffffffc020075c:	9eb2                	add	t4,t4,a2
ffffffffc020075e:	008eb703          	ld	a4,8(t4)
ffffffffc0200762:	0027e793          	ori	a5,a5,2
ffffffffc0200766:	e51c                	sd	a5,8(a0)
    page->property = order;
ffffffffc0200768:	01052823          	sw	a6,16(a0)
    list_add(&free_list(order), &(page->page_link));
    nr_free(order)++;
ffffffffc020076c:	010ea783          	lw	a5,16(t4)
    list_add(&free_list(order), &(page->page_link));
ffffffffc0200770:	01850693          	addi	a3,a0,24
    prev->next = next->prev = elm;
ffffffffc0200774:	e314                	sd	a3,0(a4)
ffffffffc0200776:	00deb423          	sd	a3,8(t4)
    elm->next = next;
ffffffffc020077a:	f118                	sd	a4,32(a0)
    elm->prev = prev;
ffffffffc020077c:	01d53c23          	sd	t4,24(a0)
    nr_free(order)++;
ffffffffc0200780:	2785                	addiw	a5,a5,1
ffffffffc0200782:	00fea823          	sw	a5,16(t4)
}
ffffffffc0200786:	8082                	ret
ffffffffc0200788:	4829                	li	a6,10
ffffffffc020078a:	b7e1                	j	ffffffffc0200752 <buddy_free_pages+0x94>
        if (!PageProperty(buddy) || buddy->property != order) break;
ffffffffc020078c:	0006081b          	sext.w	a6,a2
ffffffffc0200790:	00006e97          	auipc	t4,0x6
ffffffffc0200794:	888e8e93          	addi	t4,t4,-1912 # ffffffffc0206018 <free_area>
ffffffffc0200798:	bf6d                	j	ffffffffc0200752 <buddy_free_pages+0x94>

ffffffffc020079a <buddy_nr_free_pages>:

static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc020079a:	00006697          	auipc	a3,0x6
ffffffffc020079e:	88e68693          	addi	a3,a3,-1906 # ffffffffc0206028 <free_area+0x10>
ffffffffc02007a2:	4701                	li	a4,0
    size_t total = 0;
ffffffffc02007a4:	4501                	li	a0,0
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02007a6:	462d                	li	a2,11
        total += nr_free(i) * (1 << i);
ffffffffc02007a8:	429c                	lw	a5,0(a3)
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02007aa:	06e1                	addi	a3,a3,24
        total += nr_free(i) * (1 << i);
ffffffffc02007ac:	00e797bb          	sllw	a5,a5,a4
ffffffffc02007b0:	1782                	slli	a5,a5,0x20
ffffffffc02007b2:	9381                	srli	a5,a5,0x20
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02007b4:	2705                	addiw	a4,a4,1
        total += nr_free(i) * (1 << i);
ffffffffc02007b6:	953e                	add	a0,a0,a5
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc02007b8:	fec718e3          	bne	a4,a2,ffffffffc02007a8 <buddy_nr_free_pages+0xe>
    }
    return total;
}
ffffffffc02007bc:	8082                	ret

ffffffffc02007be <buddy_print_summary>:


static void buddy_print_summary(const char *tag)
{
ffffffffc02007be:	7139                	addi	sp,sp,-64
ffffffffc02007c0:	85aa                	mv	a1,a0
    cprintf("---- %s: 各阶空闲块统计 ----\n", tag);
ffffffffc02007c2:	00001517          	auipc	a0,0x1
ffffffffc02007c6:	e9e50513          	addi	a0,a0,-354 # ffffffffc0201660 <etext+0x262>
{
ffffffffc02007ca:	f822                	sd	s0,48(sp)
ffffffffc02007cc:	f426                	sd	s1,40(sp)
ffffffffc02007ce:	ec4e                	sd	s3,24(sp)
ffffffffc02007d0:	e852                	sd	s4,16(sp)
ffffffffc02007d2:	e456                	sd	s5,8(sp)
ffffffffc02007d4:	fc06                	sd	ra,56(sp)
ffffffffc02007d6:	f04a                	sd	s2,32(sp)
ffffffffc02007d8:	00006497          	auipc	s1,0x6
ffffffffc02007dc:	85048493          	addi	s1,s1,-1968 # ffffffffc0206028 <free_area+0x10>
    cprintf("---- %s: 各阶空闲块统计 ----\n", tag);
ffffffffc02007e0:	96dff0ef          	jal	ra,ffffffffc020014c <cprintf>
    size_t grand = 0;
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc02007e4:	4401                	li	s0,0
    size_t grand = 0;
ffffffffc02007e6:	4981                	li	s3,0
        size_t cnt = nr_free(order);
        size_t pages = cnt * (1UL << order);
        if (cnt > 0) {
            cprintf("  order=%2d : blocks=%4u  页数=%6u\n",
ffffffffc02007e8:	00001a97          	auipc	s5,0x1
ffffffffc02007ec:	ea0a8a93          	addi	s5,s5,-352 # ffffffffc0201688 <etext+0x28a>
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc02007f0:	4a2d                	li	s4,11
ffffffffc02007f2:	a029                	j	ffffffffc02007fc <buddy_print_summary+0x3e>
ffffffffc02007f4:	2405                	addiw	s0,s0,1
                    order, (unsigned)cnt, (unsigned)pages);
        }
        grand += pages;
ffffffffc02007f6:	99ca                	add	s3,s3,s2
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc02007f8:	03440463          	beq	s0,s4,ffffffffc0200820 <buddy_print_summary+0x62>
        size_t cnt = nr_free(order);
ffffffffc02007fc:	4090                	lw	a2,0(s1)
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc02007fe:	04e1                	addi	s1,s1,24
        size_t cnt = nr_free(order);
ffffffffc0200800:	02061793          	slli	a5,a2,0x20
ffffffffc0200804:	9381                	srli	a5,a5,0x20
        size_t pages = cnt * (1UL << order);
ffffffffc0200806:	00879933          	sll	s2,a5,s0
        if (cnt > 0) {
ffffffffc020080a:	d7ed                	beqz	a5,ffffffffc02007f4 <buddy_print_summary+0x36>
            cprintf("  order=%2d : blocks=%4u  页数=%6u\n",
ffffffffc020080c:	85a2                	mv	a1,s0
ffffffffc020080e:	0009069b          	sext.w	a3,s2
ffffffffc0200812:	8556                	mv	a0,s5
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc0200814:	2405                	addiw	s0,s0,1
            cprintf("  order=%2d : blocks=%4u  页数=%6u\n",
ffffffffc0200816:	937ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        grand += pages;
ffffffffc020081a:	99ca                	add	s3,s3,s2
    for (int order = 0; order <= MAX_ORDER; ++order) {
ffffffffc020081c:	ff4410e3          	bne	s0,s4,ffffffffc02007fc <buddy_print_summary+0x3e>
    }
    cprintf("  -> 总空闲页数 = %u\n", (unsigned)grand);
ffffffffc0200820:	0009859b          	sext.w	a1,s3
ffffffffc0200824:	00001517          	auipc	a0,0x1
ffffffffc0200828:	e8c50513          	addi	a0,a0,-372 # ffffffffc02016b0 <etext+0x2b2>
ffffffffc020082c:	921ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("-----------------------------------\n");
}
ffffffffc0200830:	7442                	ld	s0,48(sp)
ffffffffc0200832:	70e2                	ld	ra,56(sp)
ffffffffc0200834:	74a2                	ld	s1,40(sp)
ffffffffc0200836:	7902                	ld	s2,32(sp)
ffffffffc0200838:	69e2                	ld	s3,24(sp)
ffffffffc020083a:	6a42                	ld	s4,16(sp)
ffffffffc020083c:	6aa2                	ld	s5,8(sp)
    cprintf("-----------------------------------\n");
ffffffffc020083e:	00001517          	auipc	a0,0x1
ffffffffc0200842:	e9250513          	addi	a0,a0,-366 # ffffffffc02016d0 <etext+0x2d2>
}
ffffffffc0200846:	6121                	addi	sp,sp,64
    cprintf("-----------------------------------\n");
ffffffffc0200848:	b211                	j	ffffffffc020014c <cprintf>

ffffffffc020084a <buddy_system_check>:

//     cprintf("====== buddy_basic_check 完成 ======\n\n");
// }

static void buddy_system_check(void)
{
ffffffffc020084a:	7139                	addi	sp,sp,-64
    cprintf("\n========== BUDDY 检测开始 ==========\n");
ffffffffc020084c:	00001517          	auipc	a0,0x1
ffffffffc0200850:	eac50513          	addi	a0,a0,-340 # ffffffffc02016f8 <etext+0x2fa>
{
ffffffffc0200854:	f822                	sd	s0,48(sp)
ffffffffc0200856:	f426                	sd	s1,40(sp)
ffffffffc0200858:	fc06                	sd	ra,56(sp)
ffffffffc020085a:	f04a                	sd	s2,32(sp)
ffffffffc020085c:	ec4e                	sd	s3,24(sp)
ffffffffc020085e:	e852                	sd	s4,16(sp)
ffffffffc0200860:	e456                	sd	s5,8(sp)
ffffffffc0200862:	00005417          	auipc	s0,0x5
ffffffffc0200866:	7c640413          	addi	s0,s0,1990 # ffffffffc0206028 <free_area+0x10>
    cprintf("\n========== BUDDY 检测开始 ==========\n");
ffffffffc020086a:	8e3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    size_t total = 0;
ffffffffc020086e:	4481                	li	s1,0
    cprintf("\n========== BUDDY 检测开始 ==========\n");
ffffffffc0200870:	86a2                	mv	a3,s0
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200872:	4701                	li	a4,0
ffffffffc0200874:	462d                	li	a2,11
        total += nr_free(i) * (1 << i);
ffffffffc0200876:	429c                	lw	a5,0(a3)
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200878:	06e1                	addi	a3,a3,24
        total += nr_free(i) * (1 << i);
ffffffffc020087a:	00e797bb          	sllw	a5,a5,a4
ffffffffc020087e:	1782                	slli	a5,a5,0x20
ffffffffc0200880:	9381                	srli	a5,a5,0x20
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200882:	2705                	addiw	a4,a4,1
        total += nr_free(i) * (1 << i);
ffffffffc0200884:	94be                	add	s1,s1,a5
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200886:	fec718e3          	bne	a4,a2,ffffffffc0200876 <buddy_system_check+0x2c>

    /* 初始总空闲页数 */
    size_t total_init = buddy_nr_free_pages();
    cprintf("初始化：总空闲页数 = %u\n", (unsigned)total_init);
ffffffffc020088a:	0004899b          	sext.w	s3,s1
ffffffffc020088e:	85ce                	mv	a1,s3
ffffffffc0200890:	00001517          	auipc	a0,0x1
ffffffffc0200894:	e9850513          	addi	a0,a0,-360 # ffffffffc0201728 <etext+0x32a>
ffffffffc0200898:	8b5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("初始化状态");
ffffffffc020089c:	00001517          	auipc	a0,0x1
ffffffffc02008a0:	eb450513          	addi	a0,a0,-332 # ffffffffc0201750 <etext+0x352>
ffffffffc02008a4:	f1bff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 1) 分配 3 个相同大小的块并释放 */
    cprintf("\n[场景1] 分配/回收8页块示例\n");
ffffffffc02008a8:	00001517          	auipc	a0,0x1
ffffffffc02008ac:	eb850513          	addi	a0,a0,-328 # ffffffffc0201760 <etext+0x362>
ffffffffc02008b0:	89dff0ef          	jal	ra,ffffffffc020014c <cprintf>
    struct Page *a = alloc_pages(8);
ffffffffc02008b4:	4521                	li	a0,8
ffffffffc02008b6:	4c4000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc02008ba:	8aaa                	mv	s5,a0
    struct Page *b = alloc_pages(8);
ffffffffc02008bc:	4521                	li	a0,8
ffffffffc02008be:	4bc000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc02008c2:	8a2a                	mv	s4,a0
    struct Page *c = alloc_pages(8);
ffffffffc02008c4:	4521                	li	a0,8
ffffffffc02008c6:	4b4000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc02008ca:	892a                	mv	s2,a0
    cprintf("分配结果：a=%p  b=%p  c=%p\n", a, b, c);
ffffffffc02008cc:	86aa                	mv	a3,a0
ffffffffc02008ce:	8652                	mv	a2,s4
ffffffffc02008d0:	85d6                	mv	a1,s5
ffffffffc02008d2:	00001517          	auipc	a0,0x1
ffffffffc02008d6:	eb650513          	addi	a0,a0,-330 # ffffffffc0201788 <etext+0x38a>
ffffffffc02008da:	873ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    assert(a != b && b!=c && a != c);
ffffffffc02008de:	2b4a8663          	beq	s5,s4,ffffffffc0200b8a <buddy_system_check+0x340>
ffffffffc02008e2:	2b2a0463          	beq	s4,s2,ffffffffc0200b8a <buddy_system_check+0x340>
ffffffffc02008e6:	2b2a8263          	beq	s5,s2,ffffffffc0200b8a <buddy_system_check+0x340>
    assert(a != b && a != c && b != c);
    buddy_print_summary("场景1: 分配后");
ffffffffc02008ea:	00001517          	auipc	a0,0x1
ffffffffc02008ee:	f1650513          	addi	a0,a0,-234 # ffffffffc0201800 <etext+0x402>
ffffffffc02008f2:	ecdff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    free_pages(a, 8);
ffffffffc02008f6:	45a1                	li	a1,8
ffffffffc02008f8:	8556                	mv	a0,s5
ffffffffc02008fa:	48c000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("释放 a(8页)\n");
ffffffffc02008fe:	00001517          	auipc	a0,0x1
ffffffffc0200902:	f1a50513          	addi	a0,a0,-230 # ffffffffc0201818 <etext+0x41a>
ffffffffc0200906:	847ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景1: 释放 a 后");
ffffffffc020090a:	00001517          	auipc	a0,0x1
ffffffffc020090e:	f1e50513          	addi	a0,a0,-226 # ffffffffc0201828 <etext+0x42a>
ffffffffc0200912:	eadff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    free_pages(b, 8);
ffffffffc0200916:	45a1                	li	a1,8
ffffffffc0200918:	8552                	mv	a0,s4
ffffffffc020091a:	46c000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("释放 b(8页)\n");
ffffffffc020091e:	00001517          	auipc	a0,0x1
ffffffffc0200922:	f2250513          	addi	a0,a0,-222 # ffffffffc0201840 <etext+0x442>
ffffffffc0200926:	827ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景1: 释放 b 后");
ffffffffc020092a:	00001517          	auipc	a0,0x1
ffffffffc020092e:	f2650513          	addi	a0,a0,-218 # ffffffffc0201850 <etext+0x452>
ffffffffc0200932:	e8dff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    free_pages(c, 8);
ffffffffc0200936:	45a1                	li	a1,8
ffffffffc0200938:	854a                	mv	a0,s2
ffffffffc020093a:	44c000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("释放 c(8页)\n");
ffffffffc020093e:	00001517          	auipc	a0,0x1
ffffffffc0200942:	f2a50513          	addi	a0,a0,-214 # ffffffffc0201868 <etext+0x46a>
ffffffffc0200946:	807ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景1: 释放 c 后");
ffffffffc020094a:	00001517          	auipc	a0,0x1
ffffffffc020094e:	f2e50513          	addi	a0,a0,-210 # ffffffffc0201878 <etext+0x47a>
ffffffffc0200952:	e6dff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 2) 分配1页 */
    cprintf("\n[场景2] 分配/回收1页\n");
ffffffffc0200956:	00001517          	auipc	a0,0x1
ffffffffc020095a:	f3a50513          	addi	a0,a0,-198 # ffffffffc0201890 <etext+0x492>
ffffffffc020095e:	feeff0ef          	jal	ra,ffffffffc020014c <cprintf>
    struct Page *pmin = alloc_pages(1);
ffffffffc0200962:	4505                	li	a0,1
ffffffffc0200964:	416000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200968:	892a                	mv	s2,a0
    assert(pmin);
ffffffffc020096a:	24050063          	beqz	a0,ffffffffc0200baa <buddy_system_check+0x360>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020096e:	00005617          	auipc	a2,0x5
ffffffffc0200972:	7d263603          	ld	a2,2002(a2) # ffffffffc0206140 <pages>
ffffffffc0200976:	40c50633          	sub	a2,a0,a2
ffffffffc020097a:	00001797          	auipc	a5,0x1
ffffffffc020097e:	75e7b783          	ld	a5,1886(a5) # ffffffffc02020d8 <error_string+0x38>
ffffffffc0200982:	860d                	srai	a2,a2,0x3
ffffffffc0200984:	02f60633          	mul	a2,a2,a5
ffffffffc0200988:	00001797          	auipc	a5,0x1
ffffffffc020098c:	7587b783          	ld	a5,1880(a5) # ffffffffc02020e0 <nbase>
    cprintf("分配 1 页 -> %p, 物理地址 pa=0x%016lx\n", pmin, page2pa(pmin));
ffffffffc0200990:	85aa                	mv	a1,a0
ffffffffc0200992:	00001517          	auipc	a0,0x1
ffffffffc0200996:	f2650513          	addi	a0,a0,-218 # ffffffffc02018b8 <etext+0x4ba>
ffffffffc020099a:	963e                	add	a2,a2,a5
ffffffffc020099c:	0632                	slli	a2,a2,0xc
ffffffffc020099e:	faeff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景2: 分配 1 页 后");
ffffffffc02009a2:	00001517          	auipc	a0,0x1
ffffffffc02009a6:	f4650513          	addi	a0,a0,-186 # ffffffffc02018e8 <etext+0x4ea>
ffffffffc02009aa:	e15ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>
    free_pages(pmin, 1);
ffffffffc02009ae:	4585                	li	a1,1
ffffffffc02009b0:	854a                	mv	a0,s2
ffffffffc02009b2:	3d4000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("释放 1 页完毕\n");
ffffffffc02009b6:	00001517          	auipc	a0,0x1
ffffffffc02009ba:	f5250513          	addi	a0,a0,-174 # ffffffffc0201908 <etext+0x50a>
ffffffffc02009be:	f8eff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景2: 释放 1 页 后");
ffffffffc02009c2:	00001517          	auipc	a0,0x1
ffffffffc02009c6:	f5e50513          	addi	a0,a0,-162 # ffffffffc0201920 <etext+0x522>
ffffffffc02009ca:	df5ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 3) 分配较大的块 */
    cprintf("\n[场景3] 较大分配/回收\n");
ffffffffc02009ce:	00001517          	auipc	a0,0x1
ffffffffc02009d2:	f7250513          	addi	a0,a0,-142 # ffffffffc0201940 <etext+0x542>
ffffffffc02009d6:	f76ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    size_t try_big = total_init / 32;
    if (try_big == 0) try_big = 1;
ffffffffc02009da:	47fd                	li	a5,31
ffffffffc02009dc:	1697f763          	bgeu	a5,s1,ffffffffc0200b4a <buddy_system_check+0x300>
    size_t try_big = total_init / 32;
ffffffffc02009e0:	0054da13          	srli	s4,s1,0x5
    struct Page *pbig = alloc_pages(try_big);
ffffffffc02009e4:	8552                	mv	a0,s4
ffffffffc02009e6:	394000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
    if (pbig) {
        cprintf("成功分配大块 %u 页 -> %p\n", (unsigned)try_big, pbig);
ffffffffc02009ea:	000a0a9b          	sext.w	s5,s4
    struct Page *pbig = alloc_pages(try_big);
ffffffffc02009ee:	892a                	mv	s2,a0
    if (pbig) {
ffffffffc02009f0:	16050563          	beqz	a0,ffffffffc0200b5a <buddy_system_check+0x310>
        cprintf("成功分配大块 %u 页 -> %p\n", (unsigned)try_big, pbig);
ffffffffc02009f4:	862a                	mv	a2,a0
ffffffffc02009f6:	85d6                	mv	a1,s5
ffffffffc02009f8:	00001517          	auipc	a0,0x1
ffffffffc02009fc:	f6850513          	addi	a0,a0,-152 # ffffffffc0201960 <etext+0x562>
ffffffffc0200a00:	f4cff0ef          	jal	ra,ffffffffc020014c <cprintf>
        buddy_print_summary("场景3: 大块分配后");
ffffffffc0200a04:	00001517          	auipc	a0,0x1
ffffffffc0200a08:	f8450513          	addi	a0,a0,-124 # ffffffffc0201988 <etext+0x58a>
ffffffffc0200a0c:	db3ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>
        free_pages(pbig, try_big);
ffffffffc0200a10:	85d2                	mv	a1,s4
ffffffffc0200a12:	854a                	mv	a0,s2
ffffffffc0200a14:	372000ef          	jal	ra,ffffffffc0200d86 <free_pages>
        cprintf("释放大块 %u 页 完成\n", (unsigned)try_big);
ffffffffc0200a18:	85d6                	mv	a1,s5
ffffffffc0200a1a:	00001517          	auipc	a0,0x1
ffffffffc0200a1e:	f8e50513          	addi	a0,a0,-114 # ffffffffc02019a8 <etext+0x5aa>
ffffffffc0200a22:	f2aff0ef          	jal	ra,ffffffffc020014c <cprintf>
        buddy_print_summary("场景3: 释放大块后");
ffffffffc0200a26:	00001517          	auipc	a0,0x1
ffffffffc0200a2a:	fa250513          	addi	a0,a0,-94 # ffffffffc02019c8 <etext+0x5ca>
ffffffffc0200a2e:	d91ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>
    } else {
        cprintf("无法分配大块 %u 页（这可能因为内存不足或对齐原因），跳过后续大块断言。\n", (unsigned)try_big);
    }

    /* 4) 分配多个不等大小的块、释放部分，然后尝试再次分配 */
    cprintf("\n[场景4] 分配多个不等大小的块、释放部分，然后尝试再次分配\n");
ffffffffc0200a32:	00001517          	auipc	a0,0x1
ffffffffc0200a36:	02650513          	addi	a0,a0,38 # ffffffffc0201a58 <etext+0x65a>
ffffffffc0200a3a:	f12ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    struct Page *x1 = alloc_pages(16);
ffffffffc0200a3e:	4541                	li	a0,16
ffffffffc0200a40:	33a000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200a44:	8aaa                	mv	s5,a0
    struct Page *x2 = alloc_pages(32);
ffffffffc0200a46:	02000513          	li	a0,32
ffffffffc0200a4a:	330000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200a4e:	892a                	mv	s2,a0
    struct Page *x3 = alloc_pages(16);
ffffffffc0200a50:	4541                	li	a0,16
ffffffffc0200a52:	328000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200a56:	8a2a                	mv	s4,a0
    cprintf("分配 x1(16)=%p x2(32)=%p x3(16)=%p\n", x1, x2, x3);
ffffffffc0200a58:	86aa                	mv	a3,a0
ffffffffc0200a5a:	864a                	mv	a2,s2
ffffffffc0200a5c:	85d6                	mv	a1,s5
ffffffffc0200a5e:	00001517          	auipc	a0,0x1
ffffffffc0200a62:	05250513          	addi	a0,a0,82 # ffffffffc0201ab0 <etext+0x6b2>
ffffffffc0200a66:	ee6ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    assert(x1 && x2 && x3);
ffffffffc0200a6a:	100a8063          	beqz	s5,ffffffffc0200b6a <buddy_system_check+0x320>
ffffffffc0200a6e:	0e090e63          	beqz	s2,ffffffffc0200b6a <buddy_system_check+0x320>
ffffffffc0200a72:	0e0a0c63          	beqz	s4,ffffffffc0200b6a <buddy_system_check+0x320>

    buddy_print_summary("场景4: 初始分配后");
ffffffffc0200a76:	00001517          	auipc	a0,0x1
ffffffffc0200a7a:	07250513          	addi	a0,a0,114 # ffffffffc0201ae8 <etext+0x6ea>
ffffffffc0200a7e:	d41ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 释放 x2，使中间出现空洞 */
    free_pages(x2, 32);
ffffffffc0200a82:	02000593          	li	a1,32
ffffffffc0200a86:	854a                	mv	a0,s2
ffffffffc0200a88:	2fe000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("释放 x2(32页)，中间产生空洞\n");
ffffffffc0200a8c:	00001517          	auipc	a0,0x1
ffffffffc0200a90:	07c50513          	addi	a0,a0,124 # ffffffffc0201b08 <etext+0x70a>
ffffffffc0200a94:	eb8ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景4: 释放 x2 后");
ffffffffc0200a98:	00001517          	auipc	a0,0x1
ffffffffc0200a9c:	09850513          	addi	a0,a0,152 # ffffffffc0201b30 <etext+0x732>
ffffffffc0200aa0:	d1fff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 尝试分配一个 32 页块（应该能复用 x2 区域） */
    struct Page *y = alloc_pages(32);
ffffffffc0200aa4:	02000513          	li	a0,32
ffffffffc0200aa8:	2d2000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200aac:	892a                	mv	s2,a0
    cprintf("再次尝试分配 32 页 -> %p (期待为之前 x2 的位置或其它合适位置)\n", y);
ffffffffc0200aae:	85aa                	mv	a1,a0
ffffffffc0200ab0:	00001517          	auipc	a0,0x1
ffffffffc0200ab4:	09850513          	addi	a0,a0,152 # ffffffffc0201b48 <etext+0x74a>
ffffffffc0200ab8:	e94ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    assert(y != NULL);
ffffffffc0200abc:	10090763          	beqz	s2,ffffffffc0200bca <buddy_system_check+0x380>
    buddy_print_summary("场景4: 再次分配 32 页 后");
ffffffffc0200ac0:	00001517          	auipc	a0,0x1
ffffffffc0200ac4:	0f050513          	addi	a0,a0,240 # ffffffffc0201bb0 <etext+0x7b2>
ffffffffc0200ac8:	cf7ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>

    /* 清理 */
    free_pages(x1, 16);
ffffffffc0200acc:	45c1                	li	a1,16
ffffffffc0200ace:	8556                	mv	a0,s5
ffffffffc0200ad0:	2b6000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    free_pages(x3, 16);
ffffffffc0200ad4:	45c1                	li	a1,16
ffffffffc0200ad6:	8552                	mv	a0,s4
ffffffffc0200ad8:	2ae000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    free_pages(y, 32);
ffffffffc0200adc:	02000593          	li	a1,32
ffffffffc0200ae0:	854a                	mv	a0,s2
ffffffffc0200ae2:	2a4000ef          	jal	ra,ffffffffc0200d86 <free_pages>
    cprintf("场景4: 释放所有分配块，恢复初始碎片\n");
ffffffffc0200ae6:	00001517          	auipc	a0,0x1
ffffffffc0200aea:	0f250513          	addi	a0,a0,242 # ffffffffc0201bd8 <etext+0x7da>
ffffffffc0200aee:	e5eff0ef          	jal	ra,ffffffffc020014c <cprintf>
    buddy_print_summary("场景4: 清理后");
ffffffffc0200af2:	00001517          	auipc	a0,0x1
ffffffffc0200af6:	11e50513          	addi	a0,a0,286 # ffffffffc0201c10 <etext+0x812>
ffffffffc0200afa:	cc5ff0ef          	jal	ra,ffffffffc02007be <buddy_print_summary>
    size_t total = 0;
ffffffffc0200afe:	4901                	li	s2,0
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200b00:	4701                	li	a4,0
ffffffffc0200b02:	46ad                	li	a3,11
        total += nr_free(i) * (1 << i);
ffffffffc0200b04:	401c                	lw	a5,0(s0)
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200b06:	0461                	addi	s0,s0,24
        total += nr_free(i) * (1 << i);
ffffffffc0200b08:	00e797bb          	sllw	a5,a5,a4
ffffffffc0200b0c:	1782                	slli	a5,a5,0x20
ffffffffc0200b0e:	9381                	srli	a5,a5,0x20
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200b10:	2705                	addiw	a4,a4,1
        total += nr_free(i) * (1 << i);
ffffffffc0200b12:	993e                	add	s2,s2,a5
    for (int i = 0; i <= MAX_ORDER; i++) {
ffffffffc0200b14:	fed718e3          	bne	a4,a3,ffffffffc0200b04 <buddy_system_check+0x2ba>

    /* 结束检查：总空闲页数不应少于初始值（考虑实现不会“丢页”） */
    size_t total_end = buddy_nr_free_pages();
    cprintf("\n检测完成：初始总空闲页=%u, 结束总空闲页=%u\n", (unsigned)total_init, (unsigned)total_end);
ffffffffc0200b18:	0009061b          	sext.w	a2,s2
ffffffffc0200b1c:	85ce                	mv	a1,s3
ffffffffc0200b1e:	00001517          	auipc	a0,0x1
ffffffffc0200b22:	10a50513          	addi	a0,a0,266 # ffffffffc0201c28 <etext+0x82a>
ffffffffc0200b26:	e26ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    assert(total_end >= total_init); /* 实现上通常应相等；用 >= 更稳健以防一些实现细节差异 */
ffffffffc0200b2a:	0c996063          	bltu	s2,s1,ffffffffc0200bea <buddy_system_check+0x3a0>

    cprintf("========== BUDDY 检测结束（全部断言通过） ==========\n\n");
}
ffffffffc0200b2e:	7442                	ld	s0,48(sp)
ffffffffc0200b30:	70e2                	ld	ra,56(sp)
ffffffffc0200b32:	74a2                	ld	s1,40(sp)
ffffffffc0200b34:	7902                	ld	s2,32(sp)
ffffffffc0200b36:	69e2                	ld	s3,24(sp)
ffffffffc0200b38:	6a42                	ld	s4,16(sp)
ffffffffc0200b3a:	6aa2                	ld	s5,8(sp)
    cprintf("========== BUDDY 检测结束（全部断言通过） ==========\n\n");
ffffffffc0200b3c:	00001517          	auipc	a0,0x1
ffffffffc0200b40:	14450513          	addi	a0,a0,324 # ffffffffc0201c80 <etext+0x882>
}
ffffffffc0200b44:	6121                	addi	sp,sp,64
    cprintf("========== BUDDY 检测结束（全部断言通过） ==========\n\n");
ffffffffc0200b46:	e06ff06f          	j	ffffffffc020014c <cprintf>
    if (try_big == 0) try_big = 1;
ffffffffc0200b4a:	4a05                	li	s4,1
    struct Page *pbig = alloc_pages(try_big);
ffffffffc0200b4c:	8552                	mv	a0,s4
ffffffffc0200b4e:	22c000ef          	jal	ra,ffffffffc0200d7a <alloc_pages>
ffffffffc0200b52:	4a85                	li	s5,1
ffffffffc0200b54:	892a                	mv	s2,a0
    if (pbig) {
ffffffffc0200b56:	e8051fe3          	bnez	a0,ffffffffc02009f4 <buddy_system_check+0x1aa>
        cprintf("无法分配大块 %u 页（这可能因为内存不足或对齐原因），跳过后续大块断言。\n", (unsigned)try_big);
ffffffffc0200b5a:	85d6                	mv	a1,s5
ffffffffc0200b5c:	00001517          	auipc	a0,0x1
ffffffffc0200b60:	e8c50513          	addi	a0,a0,-372 # ffffffffc02019e8 <etext+0x5ea>
ffffffffc0200b64:	de8ff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200b68:	b5e9                	j	ffffffffc0200a32 <buddy_system_check+0x1e8>
    assert(x1 && x2 && x3);
ffffffffc0200b6a:	00001697          	auipc	a3,0x1
ffffffffc0200b6e:	f6e68693          	addi	a3,a3,-146 # ffffffffc0201ad8 <etext+0x6da>
ffffffffc0200b72:	00001617          	auipc	a2,0x1
ffffffffc0200b76:	c5e60613          	addi	a2,a2,-930 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200b7a:	11a00593          	li	a1,282
ffffffffc0200b7e:	00001517          	auipc	a0,0x1
ffffffffc0200b82:	c6a50513          	addi	a0,a0,-918 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200b86:	e3cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(a != b && b!=c && a != c);
ffffffffc0200b8a:	00001697          	auipc	a3,0x1
ffffffffc0200b8e:	c2668693          	addi	a3,a3,-986 # ffffffffc02017b0 <etext+0x3b2>
ffffffffc0200b92:	00001617          	auipc	a2,0x1
ffffffffc0200b96:	c3e60613          	addi	a2,a2,-962 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200b9a:	0eb00593          	li	a1,235
ffffffffc0200b9e:	00001517          	auipc	a0,0x1
ffffffffc0200ba2:	c4a50513          	addi	a0,a0,-950 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200ba6:	e1cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(pmin);
ffffffffc0200baa:	00001697          	auipc	a3,0x1
ffffffffc0200bae:	d0668693          	addi	a3,a3,-762 # ffffffffc02018b0 <etext+0x4b2>
ffffffffc0200bb2:	00001617          	auipc	a2,0x1
ffffffffc0200bb6:	c1e60613          	addi	a2,a2,-994 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200bba:	0fe00593          	li	a1,254
ffffffffc0200bbe:	00001517          	auipc	a0,0x1
ffffffffc0200bc2:	c2a50513          	addi	a0,a0,-982 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200bc6:	dfcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(y != NULL);
ffffffffc0200bca:	00001697          	auipc	a3,0x1
ffffffffc0200bce:	fd668693          	addi	a3,a3,-42 # ffffffffc0201ba0 <etext+0x7a2>
ffffffffc0200bd2:	00001617          	auipc	a2,0x1
ffffffffc0200bd6:	bfe60613          	addi	a2,a2,-1026 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200bda:	12600593          	li	a1,294
ffffffffc0200bde:	00001517          	auipc	a0,0x1
ffffffffc0200be2:	c0a50513          	addi	a0,a0,-1014 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200be6:	ddcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total_end >= total_init); /* 实现上通常应相等；用 >= 更稳健以防一些实现细节差异 */
ffffffffc0200bea:	00001697          	auipc	a3,0x1
ffffffffc0200bee:	07e68693          	addi	a3,a3,126 # ffffffffc0201c68 <etext+0x86a>
ffffffffc0200bf2:	00001617          	auipc	a2,0x1
ffffffffc0200bf6:	bde60613          	addi	a2,a2,-1058 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200bfa:	13300593          	li	a1,307
ffffffffc0200bfe:	00001517          	auipc	a0,0x1
ffffffffc0200c02:	bea50513          	addi	a0,a0,-1046 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200c06:	dbcff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200c0a <buddy_init_memmap>:
{
ffffffffc0200c0a:	1141                	addi	sp,sp,-16
ffffffffc0200c0c:	e406                	sd	ra,8(sp)
ffffffffc0200c0e:	e022                	sd	s0,0(sp)
    assert(n > 0);
ffffffffc0200c10:	14058563          	beqz	a1,ffffffffc0200d5a <buddy_init_memmap+0x150>
    for (struct Page *it = base; it < base + n; ++it) {
ffffffffc0200c14:	00259693          	slli	a3,a1,0x2
ffffffffc0200c18:	96ae                	add	a3,a3,a1
ffffffffc0200c1a:	068e                	slli	a3,a3,0x3
ffffffffc0200c1c:	96aa                	add	a3,a3,a0
ffffffffc0200c1e:	87aa                	mv	a5,a0
ffffffffc0200c20:	02d57063          	bgeu	a0,a3,ffffffffc0200c40 <buddy_init_memmap+0x36>
        assert(PageReserved(it));
ffffffffc0200c24:	6798                	ld	a4,8(a5)
ffffffffc0200c26:	8b05                	andi	a4,a4,1
ffffffffc0200c28:	10070963          	beqz	a4,ffffffffc0200d3a <buddy_init_memmap+0x130>
        it->flags = 0;
ffffffffc0200c2c:	0007b423          	sd	zero,8(a5)
        it->property = 0;
ffffffffc0200c30:	0007a823          	sw	zero,16(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200c34:	0007a023          	sw	zero,0(a5)
    for (struct Page *it = base; it < base + n; ++it) {
ffffffffc0200c38:	02878793          	addi	a5,a5,40
ffffffffc0200c3c:	fed7e4e3          	bltu	a5,a3,ffffffffc0200c24 <buddy_init_memmap+0x1a>
    return page - pages;
ffffffffc0200c40:	00005f17          	auipc	t5,0x5
ffffffffc0200c44:	500f3f03          	ld	t5,1280(t5) # ffffffffc0206140 <pages>
ffffffffc0200c48:	00001e97          	auipc	t4,0x1
ffffffffc0200c4c:	490ebe83          	ld	t4,1168(t4) # ffffffffc02020d8 <error_string+0x38>
        while ((1U << (max_order_for_remain + 1)) <= remain &&
ffffffffc0200c50:	4885                	li	a7,1
ffffffffc0200c52:	432d                	li	t1,11
            if ((pfn & (block_size - 1)) == 0) { /* 对齐检查 */
ffffffffc0200c54:	567d                	li	a2,-1
        list_entry_t *head = &free_list(order);
ffffffffc0200c56:	00005e17          	auipc	t3,0x5
ffffffffc0200c5a:	3c2e0e13          	addi	t3,t3,962 # ffffffffc0206018 <free_area>
        p += consumed;
ffffffffc0200c5e:	02800293          	li	t0,40
        size_t consumed = (1UL << order);
ffffffffc0200c62:	4f85                	li	t6,1
        int max_order_for_remain = 0;
ffffffffc0200c64:	4701                	li	a4,0
        while ((1U << (max_order_for_remain + 1)) <= remain &&
ffffffffc0200c66:	87ba                	mv	a5,a4
ffffffffc0200c68:	2705                	addiw	a4,a4,1
ffffffffc0200c6a:	00e896bb          	sllw	a3,a7,a4
ffffffffc0200c6e:	1682                	slli	a3,a3,0x20
ffffffffc0200c70:	9281                	srli	a3,a3,0x20
ffffffffc0200c72:	00d5e563          	bltu	a1,a3,ffffffffc0200c7c <buddy_init_memmap+0x72>
ffffffffc0200c76:	fe6718e3          	bne	a4,t1,ffffffffc0200c66 <buddy_init_memmap+0x5c>
ffffffffc0200c7a:	47a9                	li	a5,10
    return page - pages;
ffffffffc0200c7c:	41e506b3          	sub	a3,a0,t5
ffffffffc0200c80:	868d                	srai	a3,a3,0x3
ffffffffc0200c82:	03d686b3          	mul	a3,a3,t4
            if ((pfn & (block_size - 1)) == 0) { /* 对齐检查 */
ffffffffc0200c86:	00f61733          	sll	a4,a2,a5
ffffffffc0200c8a:	fff74713          	not	a4,a4
ffffffffc0200c8e:	8f75                	and	a4,a4,a3
ffffffffc0200c90:	c705                	beqz	a4,ffffffffc0200cb8 <buddy_init_memmap+0xae>
        for (order = max_order_for_remain; order >= 0; --order) {
ffffffffc0200c92:	37fd                	addiw	a5,a5,-1
ffffffffc0200c94:	fec799e3          	bne	a5,a2,ffffffffc0200c86 <buddy_init_memmap+0x7c>
        assert(order >= 0);
ffffffffc0200c98:	00001697          	auipc	a3,0x1
ffffffffc0200c9c:	05068693          	addi	a3,a3,80 # ffffffffc0201ce8 <etext+0x8ea>
ffffffffc0200ca0:	00001617          	auipc	a2,0x1
ffffffffc0200ca4:	b3060613          	addi	a2,a2,-1232 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200ca8:	04700593          	li	a1,71
ffffffffc0200cac:	00001517          	auipc	a0,0x1
ffffffffc0200cb0:	b3c50513          	addi	a0,a0,-1220 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200cb4:	d0eff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        list_entry_t *head = &free_list(order);
ffffffffc0200cb8:	00179813          	slli	a6,a5,0x1
ffffffffc0200cbc:	00f806b3          	add	a3,a6,a5
        SetPageProperty(p);
ffffffffc0200cc0:	00853383          	ld	t2,8(a0)
        list_entry_t *head = &free_list(order);
ffffffffc0200cc4:	068e                	slli	a3,a3,0x3
ffffffffc0200cc6:	96f2                	add	a3,a3,t3
    return list->next == list;
ffffffffc0200cc8:	6698                	ld	a4,8(a3)
        SetPageProperty(p);
ffffffffc0200cca:	0023e393          	ori	t2,t2,2
        p->property = order;
ffffffffc0200cce:	c91c                	sw	a5,16(a0)
        SetPageProperty(p);
ffffffffc0200cd0:	00753423          	sd	t2,8(a0)
            list_add(head, &p->page_link);
ffffffffc0200cd4:	01850413          	addi	s0,a0,24
        if (list_empty(head)) {
ffffffffc0200cd8:	02e69963          	bne	a3,a4,ffffffffc0200d0a <buddy_init_memmap+0x100>
    prev->next = next->prev = elm;
ffffffffc0200cdc:	e280                	sd	s0,0(a3)
ffffffffc0200cde:	e680                	sd	s0,8(a3)
    elm->next = next;
ffffffffc0200ce0:	f114                	sd	a3,32(a0)
    elm->prev = prev;
ffffffffc0200ce2:	ed14                	sd	a3,24(a0)
        nr_free(order)++;
ffffffffc0200ce4:	983e                	add	a6,a6,a5
ffffffffc0200ce6:	080e                	slli	a6,a6,0x3
ffffffffc0200ce8:	9872                	add	a6,a6,t3
ffffffffc0200cea:	01082703          	lw	a4,16(a6)
        size_t consumed = (1UL << order);
ffffffffc0200cee:	00ff96b3          	sll	a3,t6,a5
        remain -= consumed;
ffffffffc0200cf2:	8d95                	sub	a1,a1,a3
        nr_free(order)++;
ffffffffc0200cf4:	2705                	addiw	a4,a4,1
        p += consumed;
ffffffffc0200cf6:	00f297b3          	sll	a5,t0,a5
        nr_free(order)++;
ffffffffc0200cfa:	00e82823          	sw	a4,16(a6)
        p += consumed;
ffffffffc0200cfe:	953e                	add	a0,a0,a5
    while (remain > 0) {
ffffffffc0200d00:	f1b5                	bnez	a1,ffffffffc0200c64 <buddy_init_memmap+0x5a>
}
ffffffffc0200d02:	60a2                	ld	ra,8(sp)
ffffffffc0200d04:	6402                	ld	s0,0(sp)
ffffffffc0200d06:	0141                	addi	sp,sp,16
ffffffffc0200d08:	8082                	ret
                struct Page *q = le2page(le, page_link);
ffffffffc0200d0a:	fe870393          	addi	t2,a4,-24
                if (p < q) {
ffffffffc0200d0e:	02756063          	bltu	a0,t2,ffffffffc0200d2e <buddy_init_memmap+0x124>
    return listelm->next;
ffffffffc0200d12:	6718                	ld	a4,8(a4)
            while (le != head) {
ffffffffc0200d14:	fee69be3          	bne	a3,a4,ffffffffc0200d0a <buddy_init_memmap+0x100>
    return listelm->prev;
ffffffffc0200d18:	00f80733          	add	a4,a6,a5
ffffffffc0200d1c:	070e                	slli	a4,a4,0x3
ffffffffc0200d1e:	9772                	add	a4,a4,t3
ffffffffc0200d20:	6318                	ld	a4,0(a4)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200d22:	6714                	ld	a3,8(a4)
    prev->next = next->prev = elm;
ffffffffc0200d24:	e280                	sd	s0,0(a3)
ffffffffc0200d26:	e700                	sd	s0,8(a4)
    elm->next = next;
ffffffffc0200d28:	f114                	sd	a3,32(a0)
    elm->prev = prev;
ffffffffc0200d2a:	ed18                	sd	a4,24(a0)
}
ffffffffc0200d2c:	bf65                	j	ffffffffc0200ce4 <buddy_init_memmap+0xda>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200d2e:	6314                	ld	a3,0(a4)
    prev->next = next->prev = elm;
ffffffffc0200d30:	e300                	sd	s0,0(a4)
ffffffffc0200d32:	e680                	sd	s0,8(a3)
    elm->next = next;
ffffffffc0200d34:	f118                	sd	a4,32(a0)
    elm->prev = prev;
ffffffffc0200d36:	ed14                	sd	a3,24(a0)
            if (!inserted) {
ffffffffc0200d38:	b775                	j	ffffffffc0200ce4 <buddy_init_memmap+0xda>
        assert(PageReserved(it));
ffffffffc0200d3a:	00001697          	auipc	a3,0x1
ffffffffc0200d3e:	f9668693          	addi	a3,a3,-106 # ffffffffc0201cd0 <etext+0x8d2>
ffffffffc0200d42:	00001617          	auipc	a2,0x1
ffffffffc0200d46:	a8e60613          	addi	a2,a2,-1394 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200d4a:	02c00593          	li	a1,44
ffffffffc0200d4e:	00001517          	auipc	a0,0x1
ffffffffc0200d52:	a9a50513          	addi	a0,a0,-1382 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200d56:	c6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200d5a:	00001697          	auipc	a3,0x1
ffffffffc0200d5e:	f6e68693          	addi	a3,a3,-146 # ffffffffc0201cc8 <etext+0x8ca>
ffffffffc0200d62:	00001617          	auipc	a2,0x1
ffffffffc0200d66:	a6e60613          	addi	a2,a2,-1426 # ffffffffc02017d0 <etext+0x3d2>
ffffffffc0200d6a:	02800593          	li	a1,40
ffffffffc0200d6e:	00001517          	auipc	a0,0x1
ffffffffc0200d72:	a7a50513          	addi	a0,a0,-1414 # ffffffffc02017e8 <etext+0x3ea>
ffffffffc0200d76:	c4cff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200d7a <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200d7a:	00005797          	auipc	a5,0x5
ffffffffc0200d7e:	3ce7b783          	ld	a5,974(a5) # ffffffffc0206148 <pmm_manager>
ffffffffc0200d82:	6f9c                	ld	a5,24(a5)
ffffffffc0200d84:	8782                	jr	a5

ffffffffc0200d86 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200d86:	00005797          	auipc	a5,0x5
ffffffffc0200d8a:	3c27b783          	ld	a5,962(a5) # ffffffffc0206148 <pmm_manager>
ffffffffc0200d8e:	739c                	ld	a5,32(a5)
ffffffffc0200d90:	8782                	jr	a5

ffffffffc0200d92 <pmm_init>:
    pmm_manager = &buddy_pmm_manager;
ffffffffc0200d92:	00001797          	auipc	a5,0x1
ffffffffc0200d96:	f7e78793          	addi	a5,a5,-130 # ffffffffc0201d10 <buddy_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200d9a:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200d9c:	7179                	addi	sp,sp,-48
ffffffffc0200d9e:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200da0:	00001517          	auipc	a0,0x1
ffffffffc0200da4:	fa850513          	addi	a0,a0,-88 # ffffffffc0201d48 <buddy_pmm_manager+0x38>
    pmm_manager = &buddy_pmm_manager;
ffffffffc0200da8:	00005417          	auipc	s0,0x5
ffffffffc0200dac:	3a040413          	addi	s0,s0,928 # ffffffffc0206148 <pmm_manager>
void pmm_init(void) {
ffffffffc0200db0:	f406                	sd	ra,40(sp)
ffffffffc0200db2:	ec26                	sd	s1,24(sp)
ffffffffc0200db4:	e44e                	sd	s3,8(sp)
ffffffffc0200db6:	e84a                	sd	s2,16(sp)
ffffffffc0200db8:	e052                	sd	s4,0(sp)
    pmm_manager = &buddy_pmm_manager;
ffffffffc0200dba:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200dbc:	b90ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0200dc0:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200dc2:	00005497          	auipc	s1,0x5
ffffffffc0200dc6:	39e48493          	addi	s1,s1,926 # ffffffffc0206160 <va_pa_offset>
    pmm_manager->init();
ffffffffc0200dca:	679c                	ld	a5,8(a5)
ffffffffc0200dcc:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200dce:	57f5                	li	a5,-3
ffffffffc0200dd0:	07fa                	slli	a5,a5,0x1e
ffffffffc0200dd2:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0200dd4:	fe8ff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200dd8:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc0200dda:	fecff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_size == 0) {
ffffffffc0200dde:	14050d63          	beqz	a0,ffffffffc0200f38 <pmm_init+0x1a6>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200de2:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0200de4:	00001517          	auipc	a0,0x1
ffffffffc0200de8:	fac50513          	addi	a0,a0,-84 # ffffffffc0201d90 <buddy_pmm_manager+0x80>
ffffffffc0200dec:	b60ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0200df0:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0200df4:	864e                	mv	a2,s3
ffffffffc0200df6:	fffa0693          	addi	a3,s4,-1
ffffffffc0200dfa:	85ca                	mv	a1,s2
ffffffffc0200dfc:	00001517          	auipc	a0,0x1
ffffffffc0200e00:	fac50513          	addi	a0,a0,-84 # ffffffffc0201da8 <buddy_pmm_manager+0x98>
ffffffffc0200e04:	b48ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200e08:	c80007b7          	lui	a5,0xc8000
ffffffffc0200e0c:	8652                	mv	a2,s4
ffffffffc0200e0e:	0d47e463          	bltu	a5,s4,ffffffffc0200ed6 <pmm_init+0x144>
ffffffffc0200e12:	00006797          	auipc	a5,0x6
ffffffffc0200e16:	35578793          	addi	a5,a5,853 # ffffffffc0207167 <end+0xfff>
ffffffffc0200e1a:	757d                	lui	a0,0xfffff
ffffffffc0200e1c:	8d7d                	and	a0,a0,a5
ffffffffc0200e1e:	8231                	srli	a2,a2,0xc
ffffffffc0200e20:	00005797          	auipc	a5,0x5
ffffffffc0200e24:	30c7bc23          	sd	a2,792(a5) # ffffffffc0206138 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0200e28:	00005797          	auipc	a5,0x5
ffffffffc0200e2c:	30a7bc23          	sd	a0,792(a5) # ffffffffc0206140 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200e30:	000807b7          	lui	a5,0x80
ffffffffc0200e34:	002005b7          	lui	a1,0x200
ffffffffc0200e38:	02f60563          	beq	a2,a5,ffffffffc0200e62 <pmm_init+0xd0>
ffffffffc0200e3c:	00261593          	slli	a1,a2,0x2
ffffffffc0200e40:	00c586b3          	add	a3,a1,a2
ffffffffc0200e44:	fec007b7          	lui	a5,0xfec00
ffffffffc0200e48:	97aa                	add	a5,a5,a0
ffffffffc0200e4a:	068e                	slli	a3,a3,0x3
ffffffffc0200e4c:	96be                	add	a3,a3,a5
ffffffffc0200e4e:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc0200e50:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200e52:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f9ec0>
        SetPageReserved(pages + i);
ffffffffc0200e56:	00176713          	ori	a4,a4,1
ffffffffc0200e5a:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0200e5e:	fef699e3          	bne	a3,a5,ffffffffc0200e50 <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200e62:	95b2                	add	a1,a1,a2
ffffffffc0200e64:	fec006b7          	lui	a3,0xfec00
ffffffffc0200e68:	96aa                	add	a3,a3,a0
ffffffffc0200e6a:	058e                	slli	a1,a1,0x3
ffffffffc0200e6c:	96ae                	add	a3,a3,a1
ffffffffc0200e6e:	c02007b7          	lui	a5,0xc0200
ffffffffc0200e72:	0af6e763          	bltu	a3,a5,ffffffffc0200f20 <pmm_init+0x18e>
ffffffffc0200e76:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc0200e78:	77fd                	lui	a5,0xfffff
ffffffffc0200e7a:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200e7e:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc0200e80:	04b6ee63          	bltu	a3,a1,ffffffffc0200edc <pmm_init+0x14a>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc0200e84:	601c                	ld	a5,0(s0)
ffffffffc0200e86:	7b9c                	ld	a5,48(a5)
ffffffffc0200e88:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0200e8a:	00001517          	auipc	a0,0x1
ffffffffc0200e8e:	fa650513          	addi	a0,a0,-90 # ffffffffc0201e30 <buddy_pmm_manager+0x120>
ffffffffc0200e92:	abaff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0200e96:	00004597          	auipc	a1,0x4
ffffffffc0200e9a:	16a58593          	addi	a1,a1,362 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc0200e9e:	00005797          	auipc	a5,0x5
ffffffffc0200ea2:	2ab7bd23          	sd	a1,698(a5) # ffffffffc0206158 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200ea6:	c02007b7          	lui	a5,0xc0200
ffffffffc0200eaa:	0af5e363          	bltu	a1,a5,ffffffffc0200f50 <pmm_init+0x1be>
ffffffffc0200eae:	6090                	ld	a2,0(s1)
}
ffffffffc0200eb0:	7402                	ld	s0,32(sp)
ffffffffc0200eb2:	70a2                	ld	ra,40(sp)
ffffffffc0200eb4:	64e2                	ld	s1,24(sp)
ffffffffc0200eb6:	6942                	ld	s2,16(sp)
ffffffffc0200eb8:	69a2                	ld	s3,8(sp)
ffffffffc0200eba:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0200ebc:	40c58633          	sub	a2,a1,a2
ffffffffc0200ec0:	00005797          	auipc	a5,0x5
ffffffffc0200ec4:	28c7b823          	sd	a2,656(a5) # ffffffffc0206150 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200ec8:	00001517          	auipc	a0,0x1
ffffffffc0200ecc:	f8850513          	addi	a0,a0,-120 # ffffffffc0201e50 <buddy_pmm_manager+0x140>
}
ffffffffc0200ed0:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200ed2:	a7aff06f          	j	ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0200ed6:	c8000637          	lui	a2,0xc8000
ffffffffc0200eda:	bf25                	j	ffffffffc0200e12 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc0200edc:	6705                	lui	a4,0x1
ffffffffc0200ede:	177d                	addi	a4,a4,-1
ffffffffc0200ee0:	96ba                	add	a3,a3,a4
ffffffffc0200ee2:	8efd                	and	a3,a3,a5
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0200ee4:	00c6d793          	srli	a5,a3,0xc
ffffffffc0200ee8:	02c7f063          	bgeu	a5,a2,ffffffffc0200f08 <pmm_init+0x176>
    pmm_manager->init_memmap(base, n);
ffffffffc0200eec:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc0200eee:	fff80737          	lui	a4,0xfff80
ffffffffc0200ef2:	973e                	add	a4,a4,a5
ffffffffc0200ef4:	00271793          	slli	a5,a4,0x2
ffffffffc0200ef8:	97ba                	add	a5,a5,a4
ffffffffc0200efa:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc0200efc:	8d95                	sub	a1,a1,a3
ffffffffc0200efe:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0200f00:	81b1                	srli	a1,a1,0xc
ffffffffc0200f02:	953e                	add	a0,a0,a5
ffffffffc0200f04:	9702                	jalr	a4
}
ffffffffc0200f06:	bfbd                	j	ffffffffc0200e84 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0200f08:	00001617          	auipc	a2,0x1
ffffffffc0200f0c:	ef860613          	addi	a2,a2,-264 # ffffffffc0201e00 <buddy_pmm_manager+0xf0>
ffffffffc0200f10:	06a00593          	li	a1,106
ffffffffc0200f14:	00001517          	auipc	a0,0x1
ffffffffc0200f18:	f0c50513          	addi	a0,a0,-244 # ffffffffc0201e20 <buddy_pmm_manager+0x110>
ffffffffc0200f1c:	aa6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0200f20:	00001617          	auipc	a2,0x1
ffffffffc0200f24:	eb860613          	addi	a2,a2,-328 # ffffffffc0201dd8 <buddy_pmm_manager+0xc8>
ffffffffc0200f28:	05f00593          	li	a1,95
ffffffffc0200f2c:	00001517          	auipc	a0,0x1
ffffffffc0200f30:	e5450513          	addi	a0,a0,-428 # ffffffffc0201d80 <buddy_pmm_manager+0x70>
ffffffffc0200f34:	a8eff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("DTB memory info not available");
ffffffffc0200f38:	00001617          	auipc	a2,0x1
ffffffffc0200f3c:	e2860613          	addi	a2,a2,-472 # ffffffffc0201d60 <buddy_pmm_manager+0x50>
ffffffffc0200f40:	04700593          	li	a1,71
ffffffffc0200f44:	00001517          	auipc	a0,0x1
ffffffffc0200f48:	e3c50513          	addi	a0,a0,-452 # ffffffffc0201d80 <buddy_pmm_manager+0x70>
ffffffffc0200f4c:	a76ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200f50:	86ae                	mv	a3,a1
ffffffffc0200f52:	00001617          	auipc	a2,0x1
ffffffffc0200f56:	e8660613          	addi	a2,a2,-378 # ffffffffc0201dd8 <buddy_pmm_manager+0xc8>
ffffffffc0200f5a:	07a00593          	li	a1,122
ffffffffc0200f5e:	00001517          	auipc	a0,0x1
ffffffffc0200f62:	e2250513          	addi	a0,a0,-478 # ffffffffc0201d80 <buddy_pmm_manager+0x70>
ffffffffc0200f66:	a5cff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200f6a <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0200f6a:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200f6e:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0200f70:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200f74:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0200f76:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0200f7a:	f022                	sd	s0,32(sp)
ffffffffc0200f7c:	ec26                	sd	s1,24(sp)
ffffffffc0200f7e:	e84a                	sd	s2,16(sp)
ffffffffc0200f80:	f406                	sd	ra,40(sp)
ffffffffc0200f82:	e44e                	sd	s3,8(sp)
ffffffffc0200f84:	84aa                	mv	s1,a0
ffffffffc0200f86:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0200f88:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0200f8c:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0200f8e:	03067e63          	bgeu	a2,a6,ffffffffc0200fca <printnum+0x60>
ffffffffc0200f92:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0200f94:	00805763          	blez	s0,ffffffffc0200fa2 <printnum+0x38>
ffffffffc0200f98:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0200f9a:	85ca                	mv	a1,s2
ffffffffc0200f9c:	854e                	mv	a0,s3
ffffffffc0200f9e:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0200fa0:	fc65                	bnez	s0,ffffffffc0200f98 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200fa2:	1a02                	slli	s4,s4,0x20
ffffffffc0200fa4:	00001797          	auipc	a5,0x1
ffffffffc0200fa8:	eec78793          	addi	a5,a5,-276 # ffffffffc0201e90 <buddy_pmm_manager+0x180>
ffffffffc0200fac:	020a5a13          	srli	s4,s4,0x20
ffffffffc0200fb0:	9a3e                	add	s4,s4,a5
}
ffffffffc0200fb2:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200fb4:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0200fb8:	70a2                	ld	ra,40(sp)
ffffffffc0200fba:	69a2                	ld	s3,8(sp)
ffffffffc0200fbc:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200fbe:	85ca                	mv	a1,s2
ffffffffc0200fc0:	87a6                	mv	a5,s1
}
ffffffffc0200fc2:	6942                	ld	s2,16(sp)
ffffffffc0200fc4:	64e2                	ld	s1,24(sp)
ffffffffc0200fc6:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0200fc8:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0200fca:	03065633          	divu	a2,a2,a6
ffffffffc0200fce:	8722                	mv	a4,s0
ffffffffc0200fd0:	f9bff0ef          	jal	ra,ffffffffc0200f6a <printnum>
ffffffffc0200fd4:	b7f9                	j	ffffffffc0200fa2 <printnum+0x38>

ffffffffc0200fd6 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0200fd6:	7119                	addi	sp,sp,-128
ffffffffc0200fd8:	f4a6                	sd	s1,104(sp)
ffffffffc0200fda:	f0ca                	sd	s2,96(sp)
ffffffffc0200fdc:	ecce                	sd	s3,88(sp)
ffffffffc0200fde:	e8d2                	sd	s4,80(sp)
ffffffffc0200fe0:	e4d6                	sd	s5,72(sp)
ffffffffc0200fe2:	e0da                	sd	s6,64(sp)
ffffffffc0200fe4:	fc5e                	sd	s7,56(sp)
ffffffffc0200fe6:	f06a                	sd	s10,32(sp)
ffffffffc0200fe8:	fc86                	sd	ra,120(sp)
ffffffffc0200fea:	f8a2                	sd	s0,112(sp)
ffffffffc0200fec:	f862                	sd	s8,48(sp)
ffffffffc0200fee:	f466                	sd	s9,40(sp)
ffffffffc0200ff0:	ec6e                	sd	s11,24(sp)
ffffffffc0200ff2:	892a                	mv	s2,a0
ffffffffc0200ff4:	84ae                	mv	s1,a1
ffffffffc0200ff6:	8d32                	mv	s10,a2
ffffffffc0200ff8:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0200ffa:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0200ffe:	5b7d                	li	s6,-1
ffffffffc0201000:	00001a97          	auipc	s5,0x1
ffffffffc0201004:	ec4a8a93          	addi	s5,s5,-316 # ffffffffc0201ec4 <buddy_pmm_manager+0x1b4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201008:	00001b97          	auipc	s7,0x1
ffffffffc020100c:	098b8b93          	addi	s7,s7,152 # ffffffffc02020a0 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201010:	000d4503          	lbu	a0,0(s10)
ffffffffc0201014:	001d0413          	addi	s0,s10,1
ffffffffc0201018:	01350a63          	beq	a0,s3,ffffffffc020102c <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc020101c:	c121                	beqz	a0,ffffffffc020105c <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc020101e:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201020:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201022:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201024:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201028:	ff351ae3          	bne	a0,s3,ffffffffc020101c <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020102c:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201030:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201034:	4c81                	li	s9,0
ffffffffc0201036:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201038:	5c7d                	li	s8,-1
ffffffffc020103a:	5dfd                	li	s11,-1
ffffffffc020103c:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201040:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201042:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201046:	0ff5f593          	zext.b	a1,a1
ffffffffc020104a:	00140d13          	addi	s10,s0,1
ffffffffc020104e:	04b56263          	bltu	a0,a1,ffffffffc0201092 <vprintfmt+0xbc>
ffffffffc0201052:	058a                	slli	a1,a1,0x2
ffffffffc0201054:	95d6                	add	a1,a1,s5
ffffffffc0201056:	4194                	lw	a3,0(a1)
ffffffffc0201058:	96d6                	add	a3,a3,s5
ffffffffc020105a:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc020105c:	70e6                	ld	ra,120(sp)
ffffffffc020105e:	7446                	ld	s0,112(sp)
ffffffffc0201060:	74a6                	ld	s1,104(sp)
ffffffffc0201062:	7906                	ld	s2,96(sp)
ffffffffc0201064:	69e6                	ld	s3,88(sp)
ffffffffc0201066:	6a46                	ld	s4,80(sp)
ffffffffc0201068:	6aa6                	ld	s5,72(sp)
ffffffffc020106a:	6b06                	ld	s6,64(sp)
ffffffffc020106c:	7be2                	ld	s7,56(sp)
ffffffffc020106e:	7c42                	ld	s8,48(sp)
ffffffffc0201070:	7ca2                	ld	s9,40(sp)
ffffffffc0201072:	7d02                	ld	s10,32(sp)
ffffffffc0201074:	6de2                	ld	s11,24(sp)
ffffffffc0201076:	6109                	addi	sp,sp,128
ffffffffc0201078:	8082                	ret
            padc = '0';
ffffffffc020107a:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc020107c:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201080:	846a                	mv	s0,s10
ffffffffc0201082:	00140d13          	addi	s10,s0,1
ffffffffc0201086:	fdd6059b          	addiw	a1,a2,-35
ffffffffc020108a:	0ff5f593          	zext.b	a1,a1
ffffffffc020108e:	fcb572e3          	bgeu	a0,a1,ffffffffc0201052 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201092:	85a6                	mv	a1,s1
ffffffffc0201094:	02500513          	li	a0,37
ffffffffc0201098:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc020109a:	fff44783          	lbu	a5,-1(s0)
ffffffffc020109e:	8d22                	mv	s10,s0
ffffffffc02010a0:	f73788e3          	beq	a5,s3,ffffffffc0201010 <vprintfmt+0x3a>
ffffffffc02010a4:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02010a8:	1d7d                	addi	s10,s10,-1
ffffffffc02010aa:	ff379de3          	bne	a5,s3,ffffffffc02010a4 <vprintfmt+0xce>
ffffffffc02010ae:	b78d                	j	ffffffffc0201010 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02010b0:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02010b4:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02010b8:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc02010ba:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc02010be:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02010c2:	02d86463          	bltu	a6,a3,ffffffffc02010ea <vprintfmt+0x114>
                ch = *fmt;
ffffffffc02010c6:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc02010ca:	002c169b          	slliw	a3,s8,0x2
ffffffffc02010ce:	0186873b          	addw	a4,a3,s8
ffffffffc02010d2:	0017171b          	slliw	a4,a4,0x1
ffffffffc02010d6:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc02010d8:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc02010dc:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc02010de:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc02010e2:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02010e6:	fed870e3          	bgeu	a6,a3,ffffffffc02010c6 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc02010ea:	f40ddce3          	bgez	s11,ffffffffc0201042 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc02010ee:	8de2                	mv	s11,s8
ffffffffc02010f0:	5c7d                	li	s8,-1
ffffffffc02010f2:	bf81                	j	ffffffffc0201042 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc02010f4:	fffdc693          	not	a3,s11
ffffffffc02010f8:	96fd                	srai	a3,a3,0x3f
ffffffffc02010fa:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02010fe:	00144603          	lbu	a2,1(s0)
ffffffffc0201102:	2d81                	sext.w	s11,s11
ffffffffc0201104:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201106:	bf35                	j	ffffffffc0201042 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201108:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020110c:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201110:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201112:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201114:	bfd9                	j	ffffffffc02010ea <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201116:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201118:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020111c:	01174463          	blt	a4,a7,ffffffffc0201124 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201120:	1a088e63          	beqz	a7,ffffffffc02012dc <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201124:	000a3603          	ld	a2,0(s4)
ffffffffc0201128:	46c1                	li	a3,16
ffffffffc020112a:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc020112c:	2781                	sext.w	a5,a5
ffffffffc020112e:	876e                	mv	a4,s11
ffffffffc0201130:	85a6                	mv	a1,s1
ffffffffc0201132:	854a                	mv	a0,s2
ffffffffc0201134:	e37ff0ef          	jal	ra,ffffffffc0200f6a <printnum>
            break;
ffffffffc0201138:	bde1                	j	ffffffffc0201010 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc020113a:	000a2503          	lw	a0,0(s4)
ffffffffc020113e:	85a6                	mv	a1,s1
ffffffffc0201140:	0a21                	addi	s4,s4,8
ffffffffc0201142:	9902                	jalr	s2
            break;
ffffffffc0201144:	b5f1                	j	ffffffffc0201010 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201146:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201148:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020114c:	01174463          	blt	a4,a7,ffffffffc0201154 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201150:	18088163          	beqz	a7,ffffffffc02012d2 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201154:	000a3603          	ld	a2,0(s4)
ffffffffc0201158:	46a9                	li	a3,10
ffffffffc020115a:	8a2e                	mv	s4,a1
ffffffffc020115c:	bfc1                	j	ffffffffc020112c <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020115e:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201162:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201164:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201166:	bdf1                	j	ffffffffc0201042 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201168:	85a6                	mv	a1,s1
ffffffffc020116a:	02500513          	li	a0,37
ffffffffc020116e:	9902                	jalr	s2
            break;
ffffffffc0201170:	b545                	j	ffffffffc0201010 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201172:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201176:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201178:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020117a:	b5e1                	j	ffffffffc0201042 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc020117c:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020117e:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201182:	01174463          	blt	a4,a7,ffffffffc020118a <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201186:	14088163          	beqz	a7,ffffffffc02012c8 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc020118a:	000a3603          	ld	a2,0(s4)
ffffffffc020118e:	46a1                	li	a3,8
ffffffffc0201190:	8a2e                	mv	s4,a1
ffffffffc0201192:	bf69                	j	ffffffffc020112c <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201194:	03000513          	li	a0,48
ffffffffc0201198:	85a6                	mv	a1,s1
ffffffffc020119a:	e03e                	sd	a5,0(sp)
ffffffffc020119c:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc020119e:	85a6                	mv	a1,s1
ffffffffc02011a0:	07800513          	li	a0,120
ffffffffc02011a4:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02011a6:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02011a8:	6782                	ld	a5,0(sp)
ffffffffc02011aa:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02011ac:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02011b0:	bfb5                	j	ffffffffc020112c <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02011b2:	000a3403          	ld	s0,0(s4)
ffffffffc02011b6:	008a0713          	addi	a4,s4,8
ffffffffc02011ba:	e03a                	sd	a4,0(sp)
ffffffffc02011bc:	14040263          	beqz	s0,ffffffffc0201300 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02011c0:	0fb05763          	blez	s11,ffffffffc02012ae <vprintfmt+0x2d8>
ffffffffc02011c4:	02d00693          	li	a3,45
ffffffffc02011c8:	0cd79163          	bne	a5,a3,ffffffffc020128a <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02011cc:	00044783          	lbu	a5,0(s0)
ffffffffc02011d0:	0007851b          	sext.w	a0,a5
ffffffffc02011d4:	cf85                	beqz	a5,ffffffffc020120c <vprintfmt+0x236>
ffffffffc02011d6:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02011da:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02011de:	000c4563          	bltz	s8,ffffffffc02011e8 <vprintfmt+0x212>
ffffffffc02011e2:	3c7d                	addiw	s8,s8,-1
ffffffffc02011e4:	036c0263          	beq	s8,s6,ffffffffc0201208 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc02011e8:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02011ea:	0e0c8e63          	beqz	s9,ffffffffc02012e6 <vprintfmt+0x310>
ffffffffc02011ee:	3781                	addiw	a5,a5,-32
ffffffffc02011f0:	0ef47b63          	bgeu	s0,a5,ffffffffc02012e6 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc02011f4:	03f00513          	li	a0,63
ffffffffc02011f8:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02011fa:	000a4783          	lbu	a5,0(s4)
ffffffffc02011fe:	3dfd                	addiw	s11,s11,-1
ffffffffc0201200:	0a05                	addi	s4,s4,1
ffffffffc0201202:	0007851b          	sext.w	a0,a5
ffffffffc0201206:	ffe1                	bnez	a5,ffffffffc02011de <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201208:	01b05963          	blez	s11,ffffffffc020121a <vprintfmt+0x244>
ffffffffc020120c:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc020120e:	85a6                	mv	a1,s1
ffffffffc0201210:	02000513          	li	a0,32
ffffffffc0201214:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201216:	fe0d9be3          	bnez	s11,ffffffffc020120c <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020121a:	6a02                	ld	s4,0(sp)
ffffffffc020121c:	bbd5                	j	ffffffffc0201010 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc020121e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201220:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201224:	01174463          	blt	a4,a7,ffffffffc020122c <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201228:	08088d63          	beqz	a7,ffffffffc02012c2 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc020122c:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201230:	0a044d63          	bltz	s0,ffffffffc02012ea <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201234:	8622                	mv	a2,s0
ffffffffc0201236:	8a66                	mv	s4,s9
ffffffffc0201238:	46a9                	li	a3,10
ffffffffc020123a:	bdcd                	j	ffffffffc020112c <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc020123c:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201240:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201242:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201244:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201248:	8fb5                	xor	a5,a5,a3
ffffffffc020124a:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020124e:	02d74163          	blt	a4,a3,ffffffffc0201270 <vprintfmt+0x29a>
ffffffffc0201252:	00369793          	slli	a5,a3,0x3
ffffffffc0201256:	97de                	add	a5,a5,s7
ffffffffc0201258:	639c                	ld	a5,0(a5)
ffffffffc020125a:	cb99                	beqz	a5,ffffffffc0201270 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020125c:	86be                	mv	a3,a5
ffffffffc020125e:	00001617          	auipc	a2,0x1
ffffffffc0201262:	c6260613          	addi	a2,a2,-926 # ffffffffc0201ec0 <buddy_pmm_manager+0x1b0>
ffffffffc0201266:	85a6                	mv	a1,s1
ffffffffc0201268:	854a                	mv	a0,s2
ffffffffc020126a:	0ce000ef          	jal	ra,ffffffffc0201338 <printfmt>
ffffffffc020126e:	b34d                	j	ffffffffc0201010 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201270:	00001617          	auipc	a2,0x1
ffffffffc0201274:	c4060613          	addi	a2,a2,-960 # ffffffffc0201eb0 <buddy_pmm_manager+0x1a0>
ffffffffc0201278:	85a6                	mv	a1,s1
ffffffffc020127a:	854a                	mv	a0,s2
ffffffffc020127c:	0bc000ef          	jal	ra,ffffffffc0201338 <printfmt>
ffffffffc0201280:	bb41                	j	ffffffffc0201010 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201282:	00001417          	auipc	s0,0x1
ffffffffc0201286:	c2640413          	addi	s0,s0,-986 # ffffffffc0201ea8 <buddy_pmm_manager+0x198>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020128a:	85e2                	mv	a1,s8
ffffffffc020128c:	8522                	mv	a0,s0
ffffffffc020128e:	e43e                	sd	a5,8(sp)
ffffffffc0201290:	0fc000ef          	jal	ra,ffffffffc020138c <strnlen>
ffffffffc0201294:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201298:	01b05b63          	blez	s11,ffffffffc02012ae <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc020129c:	67a2                	ld	a5,8(sp)
ffffffffc020129e:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02012a2:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02012a4:	85a6                	mv	a1,s1
ffffffffc02012a6:	8552                	mv	a0,s4
ffffffffc02012a8:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02012aa:	fe0d9ce3          	bnez	s11,ffffffffc02012a2 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02012ae:	00044783          	lbu	a5,0(s0)
ffffffffc02012b2:	00140a13          	addi	s4,s0,1
ffffffffc02012b6:	0007851b          	sext.w	a0,a5
ffffffffc02012ba:	d3a5                	beqz	a5,ffffffffc020121a <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02012bc:	05e00413          	li	s0,94
ffffffffc02012c0:	bf39                	j	ffffffffc02011de <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02012c2:	000a2403          	lw	s0,0(s4)
ffffffffc02012c6:	b7ad                	j	ffffffffc0201230 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc02012c8:	000a6603          	lwu	a2,0(s4)
ffffffffc02012cc:	46a1                	li	a3,8
ffffffffc02012ce:	8a2e                	mv	s4,a1
ffffffffc02012d0:	bdb1                	j	ffffffffc020112c <vprintfmt+0x156>
ffffffffc02012d2:	000a6603          	lwu	a2,0(s4)
ffffffffc02012d6:	46a9                	li	a3,10
ffffffffc02012d8:	8a2e                	mv	s4,a1
ffffffffc02012da:	bd89                	j	ffffffffc020112c <vprintfmt+0x156>
ffffffffc02012dc:	000a6603          	lwu	a2,0(s4)
ffffffffc02012e0:	46c1                	li	a3,16
ffffffffc02012e2:	8a2e                	mv	s4,a1
ffffffffc02012e4:	b5a1                	j	ffffffffc020112c <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc02012e6:	9902                	jalr	s2
ffffffffc02012e8:	bf09                	j	ffffffffc02011fa <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc02012ea:	85a6                	mv	a1,s1
ffffffffc02012ec:	02d00513          	li	a0,45
ffffffffc02012f0:	e03e                	sd	a5,0(sp)
ffffffffc02012f2:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc02012f4:	6782                	ld	a5,0(sp)
ffffffffc02012f6:	8a66                	mv	s4,s9
ffffffffc02012f8:	40800633          	neg	a2,s0
ffffffffc02012fc:	46a9                	li	a3,10
ffffffffc02012fe:	b53d                	j	ffffffffc020112c <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201300:	03b05163          	blez	s11,ffffffffc0201322 <vprintfmt+0x34c>
ffffffffc0201304:	02d00693          	li	a3,45
ffffffffc0201308:	f6d79de3          	bne	a5,a3,ffffffffc0201282 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020130c:	00001417          	auipc	s0,0x1
ffffffffc0201310:	b9c40413          	addi	s0,s0,-1124 # ffffffffc0201ea8 <buddy_pmm_manager+0x198>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201314:	02800793          	li	a5,40
ffffffffc0201318:	02800513          	li	a0,40
ffffffffc020131c:	00140a13          	addi	s4,s0,1
ffffffffc0201320:	bd6d                	j	ffffffffc02011da <vprintfmt+0x204>
ffffffffc0201322:	00001a17          	auipc	s4,0x1
ffffffffc0201326:	b87a0a13          	addi	s4,s4,-1145 # ffffffffc0201ea9 <buddy_pmm_manager+0x199>
ffffffffc020132a:	02800513          	li	a0,40
ffffffffc020132e:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201332:	05e00413          	li	s0,94
ffffffffc0201336:	b565                	j	ffffffffc02011de <vprintfmt+0x208>

ffffffffc0201338 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201338:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc020133a:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020133e:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201340:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201342:	ec06                	sd	ra,24(sp)
ffffffffc0201344:	f83a                	sd	a4,48(sp)
ffffffffc0201346:	fc3e                	sd	a5,56(sp)
ffffffffc0201348:	e0c2                	sd	a6,64(sp)
ffffffffc020134a:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020134c:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020134e:	c89ff0ef          	jal	ra,ffffffffc0200fd6 <vprintfmt>
}
ffffffffc0201352:	60e2                	ld	ra,24(sp)
ffffffffc0201354:	6161                	addi	sp,sp,80
ffffffffc0201356:	8082                	ret

ffffffffc0201358 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201358:	4781                	li	a5,0
ffffffffc020135a:	00005717          	auipc	a4,0x5
ffffffffc020135e:	cb673703          	ld	a4,-842(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201362:	88ba                	mv	a7,a4
ffffffffc0201364:	852a                	mv	a0,a0
ffffffffc0201366:	85be                	mv	a1,a5
ffffffffc0201368:	863e                	mv	a2,a5
ffffffffc020136a:	00000073          	ecall
ffffffffc020136e:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201370:	8082                	ret

ffffffffc0201372 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201372:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201376:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201378:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc020137a:	cb81                	beqz	a5,ffffffffc020138a <strlen+0x18>
        cnt ++;
ffffffffc020137c:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc020137e:	00a707b3          	add	a5,a4,a0
ffffffffc0201382:	0007c783          	lbu	a5,0(a5)
ffffffffc0201386:	fbfd                	bnez	a5,ffffffffc020137c <strlen+0xa>
ffffffffc0201388:	8082                	ret
    }
    return cnt;
}
ffffffffc020138a:	8082                	ret

ffffffffc020138c <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020138c:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc020138e:	e589                	bnez	a1,ffffffffc0201398 <strnlen+0xc>
ffffffffc0201390:	a811                	j	ffffffffc02013a4 <strnlen+0x18>
        cnt ++;
ffffffffc0201392:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201394:	00f58863          	beq	a1,a5,ffffffffc02013a4 <strnlen+0x18>
ffffffffc0201398:	00f50733          	add	a4,a0,a5
ffffffffc020139c:	00074703          	lbu	a4,0(a4)
ffffffffc02013a0:	fb6d                	bnez	a4,ffffffffc0201392 <strnlen+0x6>
ffffffffc02013a2:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc02013a4:	852e                	mv	a0,a1
ffffffffc02013a6:	8082                	ret

ffffffffc02013a8 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02013a8:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02013ac:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02013b0:	cb89                	beqz	a5,ffffffffc02013c2 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc02013b2:	0505                	addi	a0,a0,1
ffffffffc02013b4:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02013b6:	fee789e3          	beq	a5,a4,ffffffffc02013a8 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02013ba:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc02013be:	9d19                	subw	a0,a0,a4
ffffffffc02013c0:	8082                	ret
ffffffffc02013c2:	4501                	li	a0,0
ffffffffc02013c4:	bfed                	j	ffffffffc02013be <strcmp+0x16>

ffffffffc02013c6 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02013c6:	c20d                	beqz	a2,ffffffffc02013e8 <strncmp+0x22>
ffffffffc02013c8:	962e                	add	a2,a2,a1
ffffffffc02013ca:	a031                	j	ffffffffc02013d6 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc02013cc:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02013ce:	00e79a63          	bne	a5,a4,ffffffffc02013e2 <strncmp+0x1c>
ffffffffc02013d2:	00b60b63          	beq	a2,a1,ffffffffc02013e8 <strncmp+0x22>
ffffffffc02013d6:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc02013da:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02013dc:	fff5c703          	lbu	a4,-1(a1)
ffffffffc02013e0:	f7f5                	bnez	a5,ffffffffc02013cc <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02013e2:	40e7853b          	subw	a0,a5,a4
}
ffffffffc02013e6:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02013e8:	4501                	li	a0,0
ffffffffc02013ea:	8082                	ret

ffffffffc02013ec <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc02013ec:	ca01                	beqz	a2,ffffffffc02013fc <memset+0x10>
ffffffffc02013ee:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc02013f0:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc02013f2:	0785                	addi	a5,a5,1
ffffffffc02013f4:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc02013f8:	fec79de3          	bne	a5,a2,ffffffffc02013f2 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc02013fc:	8082                	ret
