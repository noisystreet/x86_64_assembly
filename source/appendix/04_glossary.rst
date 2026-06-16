.. _appendix-glossary:

==========
术语表
==========

.. glossary::
   :sorted:

   ABI（Application Binary Interface）
     应用程序二进制接口。定义了函数调用约定、寄存器使用规则、栈布局、
     数据对齐等底层规范。x86_64 Linux 使用 System V AMD64 ABI。

   ALU（Arithmetic Logic Unit）
     算术逻辑单元。CPU 中执行加减乘除、位运算等操作的硬件单元。

   ASLR（Address Space Layout Randomization）
     地址空间布局随机化。操作系统将程序各段加载到随机地址的安全机制。

   AVX（Advanced Vector Extensions）
     高级向量扩展。x86_64 的 SIMD 指令集，使用 256 位 YMM 寄存器。
     由 Sandy Bridge 微架构引入。

   AVX-512
     AVX 的进一步扩展，使用 512 位 ZMM 寄存器和掩码寄存器。
     提供更宽的 SIMD 数据路径和更多新指令。

   BSS（Block Started by Symbol）
     存放未初始化的全局/静态变量的段。程序加载时由内核清零。

   Branch Prediction（分支预测）
     CPU 猜测条件跳转方向的硬件机制。预测失败会导致流水线冲刷，
     损失 10-20 个周期。

   Cache Line（缓存行）
     缓存与内存之间数据传输的最小单位，x86_64 中固定为 64 字节。

   Calling Convention（调用约定）
     规定函数如何传递参数、如何返回值的规则。
     System V AMD64 ABI 使用 RDI、RSI、RDX、RCX、R8、R9 传递前 6 个整数参数。

   CC（Condition Code，条件码）
     RFLAGS 寄存器中记录上一条指令执行结果的标志位，
     包括 ZF（零标志）、SF（符号标志）、CF（进位标志）、OF（溢出标志）等。

   Context Switch（上下文切换）
     操作系统暂停当前进程、恢复另一个进程执行的过程。
     涉及寄存器保存/恢复、TLB 刷新等开销。

   CPI（Cycles Per Instruction）
     平均每条指令所需的时钟周期数。衡量 CPU 执行效率的重要指标。

   DMA（Direct Memory Access）
     直接内存访问。允许硬件设备绕过 CPU 直接读写内存，
     大幅减少中断次数。

   Endianness（字节序）
     多字节数据在内存中的排列方式。x86_64 使用小端序（Little-Endian），
     即最低有效字节存储在最低地址。

   GOT（Global Offset Table）
     全局偏移表。PIE 程序和共享库中用于地址无关代码的跳转表。

   ILP（Instruction-Level Parallelism，指令级并行）
     CPU 在一个周期内发射多条指令的能力。依赖超标量和乱序执行。

   IPC（Instructions Per Cycle）
     每周期执行的指令数。与 CPI 互为倒数，衡量 CPU 利用效率。

   L1 / L2 / L3 Cache（一级/二级/三级缓存）
     CPU 内部的高速缓存层次结构。L1 最快（~4 周期）、容量最小（32 KB）；
     L3 最慢（~40 周期）、容量最大（8-32 MB），所有核心共享。

   LEA（Load Effective Address）
     加载有效地址指令。计算内存操作数的地址并将其存入寄存器，
     常用于地址计算和算术优化。

   Little-Endian（小端序）
     :term:`Endianness（字节序）` 的一种。

   MESI Protocol
     缓存一致性协议。确保多核 CPU 中各核心的缓存数据一致。
     MESI 代表 Modified、Exclusive、Shared、Invalid 四种状态。

   MMU（Memory Management Unit）
     内存管理单元。负责虚拟地址到物理地址的转换（通过页表），
     以及内存访问权限检查。

   NASM（Netwide Assembler）
     x86/x86_64 平台的自由汇编器，使用 Intel 语法。
     本教程主要使用的汇编器。

   Page Fault（缺页异常）
     程序访问尚未加载到物理内存的虚拟页面时触发的异常。
     操作系统负责从磁盘加载页面。

   Page Table（页表）
     由 MMU 使用的多级数据结构，将虚拟地址映射到物理地址。
     x86_64 使用 4 级页表（未来支持 5 级）。

   PC（Program Counter，程序计数器）
     指向下一条待执行指令的寄存器。x86_64 中称为 RIP。

   PIE（Position-Independent Executable）
     位置无关可执行程序。代码中的地址在加载时重定位，
     是 ASLR 实现的基础。

   Pipelining（流水线）
     将指令执行分解为取指、译码、执行、访存、提交等多个阶段，
     各阶段并行处理不同指令，提高吞吐量。

   RAX / RBX / RCX / RDX
     x86_64 的通用寄存器。RAX 常用于累加和函数返回值，
     RCX 用于计数，RDX 用于 I/O 操作。

   RBP（Base Pointer）
     基址指针寄存器。传统上用于保存栈帧基址，
     编译器优化后常被当作通用寄存器使用。

   RFLAGS
     状态标志寄存器。记录算术/逻辑运算的结果属性（零、符号、进位、溢出等）
     和控制标志（中断使能、方向标志）。

   RIP（Instruction Pointer）
     指令指针寄存器。指向当前正在执行的指令地址。
     在 64 位模式下通过 ``lea rax, [rip + offset]`` 实现位置无关编码。

   RSP（Stack Pointer）
     栈指针寄存器。始终指向当前栈顶（最低地址）。
     ``push`` 减 8，``pop`` 加 8。

   SIMD（Single Instruction, Multiple Data）
     单指令多数据。一条指令同时对多个数据执行相同操作。
     x86_64 中的实现包括 MMX、SSE/SSE2、AVX/AVX-512。

   SSE / SSE2（Streaming SIMD Extensions）
     流式 SIMD 扩展。使用 128 位 XMM 寄存器，
     支持单精度（SSE）和双精度（SSE2）浮点运算。

   Superscalar（超标量）
     CPU 在一个时钟周期内发射多条指令到不同执行单元的能力。
     现代 x86_64 CPU 通常每周期发射 4-6 条 µop。

   System V AMD64 ABI
     x86_64 Linux/Unix 系统使用的标准调用约定和二进制接口规范。
     本教程所有示例遵循此规范。

   TLB（Translation Lookaside Buffer）
     转译后备缓冲区。缓存虚拟地址到物理地址的映射结果，
     避免每次访存都遍历页表。TLB 未命中代价极高（数百周期）。

   µop（Micro-operation，微操作）
     复杂 CISC 指令在译码阶段被拆分成的简单内部操作。
     现代 x86_64 CPU 本质上是在内部执行 µop 的 RISC 处理器。

   Writeback（写回）
     指令执行的最后阶段，将计算结果提交到寄存器文件。
     同时在此阶段确认分支预测是否正确。

   XMM / YMM / ZMM
     SIMD 寄存器类型。XMM = 128 位（SSE），
     YMM = 256 位（AVX），ZMM = 512 位（AVX-512）。
     AVX-512 中 ZMM0-ZMM31 共 32 个寄存器。

   乱序执行（Out-of-Order Execution）
     CPU 不按程序顺序执行指令，而是按数据就绪情况调度，
     最大化执行单元利用率。

   缓存命中 / 缓存未命中（Cache Hit / Cache Miss）
     所需数据在缓存中称为命中，不在则称为未命中。
     未命中需要从下级缓存或主存加载数据，代价高。

   虚拟地址 / 物理地址（Virtual Address / Physical Address）
     程序使用的地址是虚拟地址（48 位），
     由 MMU 通过页表转换为实际的内存物理地址。

   页（Page）
     虚拟内存管理的最小单位。x86_64 默认页大小为 4 KB，
     也支持 2 MB（大页）和 1 GB（巨页）。

   栈帧（Stack Frame）
     函数调用时在栈上分配的局部区域，用于保存局部变量、
     返回地址和调用者寄存器。帧指针 RBP（可选）标记帧的边界。
