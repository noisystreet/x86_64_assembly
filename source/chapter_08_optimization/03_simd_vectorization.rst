.. _chapter-08-simd-vectorization:

===============================
SIMD 向量化优化
===============================

第 6 章介绍了 SSE、AVX 和 FMA 指令本身。本节从**优化**的角度出发，讨论如何把一段标量循环改造成 SIMD 向量化版本，以及向量化过程中最容易踩的坑——数据对齐、尾处理、寄存器状态切换和依赖链。

为什么向量化收益巨大
========================

SIMD 的核心思想是**一条指令同时处理多个数据** （Single Instruction, Multiple Data）。以数组求和为例：

.. code-block:: none

   ; 标量版本：一次加一个元素
   ; 处理 8 个 double 需要 8 次 add
   xorpd xmm0, xmm0
   addpd xmm0, [arr + 0*8]
   addpd xmm0, [arr + 1*8]
   addpd xmm0, [arr + 2*8]
   addpd xmm0, [arr + 3*8]
   addpd xmm0, [arr + 4*8]
   addpd xmm0, [arr + 5*8]
   addpd xmm0, [arr + 6*8]
   addpd xmm0, [arr + 7*8]

   ; 向量化版本：一条 vaddpd 同时加 4 个 double
   ; 处理 8 个 double 只需 2 次 vaddpd
   vxorpd ymm0, ymm0, ymm0
   vaddpd ymm0, ymm0, [arr + 0*32]   ; 一次加 4 个
   vaddpd ymm0, ymm0, [arr + 1*32]   ; 再加 4 个

.. note::

   向量化的收益来自**吞吐量**而非延迟：单条 ``vaddpd`` 的延迟和标量 ``addpd`` 差不多，
   但它一次处理 4 个元素，所以**每元素吞吐量**提升约 4 倍（AVX2 的 256 位）或 8 倍（AVX-512 的 512 位）。

向量化循环的基本模式
========================

把标量循环改造成向量化循环，通常遵循「主循环 + 尾处理」的结构：

.. code-block:: none

   ; 目标：对 double 数组求和，N 个元素
   ; rdi = 数组指针，rsi = 元素个数 N
   ; 返回 rax = 和

   ; 主循环：每次处理 4 个 double（AVX2 的 256 位）
   ; 先算出能完整处理的 4 元素块数
   mov rcx, rsi
   shr rcx, 2                 ; rcx = N / 4（完整块数）
   vxorpd ymm0, ymm0, ymm0    ; 累加器清零

   .main_loop:
       test rcx, rcx
       jz   .tail
       vaddpd ymm0, ymm0, [rdi]   ; 一次加 4 个 double
       add rdi, 32                ; 前进 4 个 double（32 字节）
       dec rcx
       jnz .main_loop

   ; 尾处理：处理剩余 0~3 个元素
   .tail:
       mov rcx, rsi
       and rcx, 3                 ; rcx = N % 4
       vxorpd xmm1, xmm1, xmm1    ; 标量累加器
   .tail_loop:
       test rcx, rcx
       jz   .done
       addsd xmm1, [rdi]          ; 一次加 1 个
       add rdi, 8
       dec rcx
       jnz .tail_loop

   .done:
       ; 把 ymm0 的 4 个部分和水平相加
       vextractf128 xmm2, ymm0, 1 ; 高 128 位
       vaddpd xmm0, xmm0, xmm2    ; 低 + 高
       vhaddpd xmm0, xmm0, xmm0   ; 水平相加
       vaddsd xmm0, xmm0, xmm1    ; 加上尾处理结果
       vcvtsd2si rax, xmm0        ; 转回整数（示例）
       vzeroupper                 ; 清理 YMM 高 128 位
       ret

.. caution::

   尾处理是向量化最容易出错的地方。**数组长度不一定能被向量宽度整除** ，
   必须用标量循环处理剩余元素，否则会越界读取。更安全的做法是
   用掩码加载（AVX-512 的 ``{k}`` 掩码）或先处理尾部再进入主循环。

数据对齐：向量化的第一道坎
============================

对齐加载（``vmovaps``）比未对齐加载（``vmovups``）更快，且某些指令（如 ``vmovntps`` 非临时存储）**要求**对齐。向量化时必须保证数据对齐：

.. code-block:: none

   section .data
       align 32                    ; AVX2 的 256 位数据建议 32 字节对齐
       vec dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0

   section .text
       vmovaps ymm0, [vec]         ; ✅ 对齐加载（快）
       vmovups ymm1, [rsi]         ; ⚠ 未对齐加载（可能慢，但不会出错）

.. warning::

   如果数据**不能保证** 对齐，使用 ``vmovups``（未对齐加载）是安全的，
   但会损失少量性能。不要为了「对齐」而用 ``vmovaps`` 去读未对齐地址——
   那会触发 **#GP 异常** （General Protection Fault）导致程序崩溃。

   动态分配的内存（如 ``malloc``）通常只保证 16 字节对齐，
   对 AVX2 的 32 字节对齐不够。需要手动对齐分配（如 ``posix_memalign`` 或 ``aligned_alloc``）。

对齐与缓存行的关系
--------------------

.. code-block:: none

   ; 缓存行是 64 字节。对齐到缓存行边界可以避免一个数据跨两个缓存行
   section .data
       align 64                    ; 缓存行对齐
       hot_array times 64 dq 0

   ; 一个 32 字节的 AVX 向量如果跨缓存行边界，
   ; 加载时需要访问两个缓存行，可能多一次内存访问

.. tip::

   对齐到**缓存行** （64 字节）比对齐到**向量宽度** （32 字节）更严格，
   但能避免「一个向量横跨两个缓存行」的额外开销。对热点数据，优先对齐到 64 字节。

循环展开与多累加器
====================

向量化之后，还可以进一步用**多累加器**打破依赖链（呼应第 2 节的 ILP 优化）：

.. code-block:: none

   ; ❌ 单一向量累加器：每次迭代都依赖上一次的 ymm0
   .loop:
       vaddpd ymm0, ymm0, [rdi]    ; 🌩 ymm0 依赖前一次迭代
       add rdi, 32
       dec rcx
       jnz .loop

   ; ✅ 两个累加器：两条独立依赖链，ILP 利用率更高
   vxorpd ymm0, ymm0, ymm0
   vxorpd ymm1, ymm1, ymm1
   shr rcx, 1                      ; 每次处理 8 个 double
   .loop:
       vaddpd ymm0, ymm0, [rdi]        ; 独立链 1
       vaddpd ymm1, ymm1, [rdi + 32]   ; 独立链 2
       add rdi, 64
       dec rcx
       jnz .loop
   vaddpd ymm0, ymm0, ymm1         ; 合并

.. note::

   现代 CPU 的 FMA 单元通常有 2 个（甚至更多），
   单一累加器会让其中一个 FMA 单元闲置。用 2~4 个累加器
   可以充分利用所有 FMA 单元，显著提升吞吐量。

FMA 融合：减少指令数
======================

FMA（Fused Multiply-Add）把「乘 + 加」融合成一条指令，既减少指令数，又避免中间结果的舍入误差：

.. code-block:: none

   ; 计算 y[i] = a * x[i] + y[i]（经典的 SAXPY 操作）
   ; 标量版本：每元素需要 mul + add 两条指令
   ; 向量化 + FMA：每 4 个元素只需一条 vfmadd

   ; rdi = y 指针，rsi = x 指针，rcx = 元素个数
   ; xmm2 = a（广播到 ymm2）
   vbroadcastsd ymm2, [a]          ; ymm2 = [a, a, a, a]

   shr rcx, 2                      ; 每次处理 4 个 double
   .loop:
       vmovupd ymm0, [rsi]         ; 加载 x[i..i+3]
       vmovupd ymm1, [rdi]         ; 加载 y[i..i+3]
       vfmadd231pd ymm1, ymm0, ymm2 ; ymm1 = ymm0 * ymm2 + ymm1
       vmovupd [rdi], ymm1         ; 存回 y
       add rsi, 32
       add rdi, 32
       dec rcx
       jnz .loop

.. tip::

   ``vfmadd231pd`` 的 ``231`` 表示：结果 = 源2 * 源3 + 源1（dest 也参与累加）。
   这种「累加式」FMA 特别适合 SAXPY、矩阵乘法等需要累加的场景，
   因为它天然避免了额外的寄存器复制。

   FMA 的另一个好处是**精度**：中间乘积不单独舍入，只在最后舍入一次，
   比「先乘后加」更精确。

vzeroupper：AVX 与 SSE 混用的关键
====================================

第 6 章提到过，在 AVX 和 SSE 指令之间混用时必须用 ``vzeroupper`` 清理 YMM 高 128 位。在向量化优化中，这一点尤其重要：

.. code-block:: none

   ; 一个向量化函数返回后，调用者可能还在用 SSE
   vectorized_func:
       vaddpd ymm0, ymm0, [rdi]
       ; ... 向量化计算 ...
       vzeroupper                  ; ✅ 清理 YMM 高 128 位
       ret

   ; 调用者（可能用 SSE 编译）
   caller:
       call vectorized_func
       movaps xmm3, [val]          ; 如果没有 vzeroupper，这条会慢 ~50 周期

.. warning::

   在**返回调用者之前**始终执行 ``vzeroupper``。如果调用者是用 SSE 编译的
   （例如 C 代码默认只生成 SSE 指令），而你的汇编函数用了 AVX 却没清理，
   调用者的每条 SSE 指令都会触发隐式状态切换，性能可能下降**数十倍**。

   ``vzeroupper`` 本身代价极低（约 1 周期），是「花小钱省大钱」的典型。

编译器自动向量化 vs 手写汇编
================================

现代编译器（GCC/Clang 的 ``-O3`` / ``-mavx2`` / ``-mfma``）能自动向量化很多循环。手写汇编前，先确认编译器是否已经做得好：

.. code-block:: none

   ; C 代码
   ; void saxpy(double *y, const double *x, double a, size_t n) {
   ;     for (size_t i = 0; i < n; i++)
   ;         y[i] = a * x[i] + y[i];
   ; }

   ; 编译：gcc -O3 -mavx2 -mfma -S saxpy.c
   ; 编译器会自动生成 vfmadd231pd 循环

.. list-table:: 编译器自动向量化 vs 手写汇编
   :header-rows: 1

   * - 维度
     - 编译器自动向量化
     - 手写汇编
   * - 开发效率
     - 高（写 C 即可）
     - 低（逐指令编写）
   * - 可移植性
     - 高（换 CPU 重新编译）
     - 低（需为不同 ISA 写多版本）
   * - 性能上限
     - 高（多数场景足够）
     - 更高（可做编译器做不到的优化）
   * - 适用场景
     - 常规数据并行循环
     - 特殊数据布局、自定义指令序列、极致调优

.. caution::

   手写汇编的**真正价值**在于编译器**无法**自动做的优化：
   - 特殊的数据布局（如 AoS → SoA 转换）
   - 跨函数/跨模块的全局优化
   - 利用领域知识（如已知数组长度、已知对齐）
   - 编译器向量化失败的情况（如指针别名、复杂控制流）

   如果只是「把编译器已经向量化得很好的循环重写一遍」，通常得不偿失。

向量化失败的常见原因
======================

编译器无法向量化一个循环时，通常是因为以下原因。手写汇编时也要注意：

.. list-table::
   :header-rows: 1

   * - 原因
     - 说明
     - 对策
   * - 指针别名（Aliasing）
     - 编译器不确定两个指针是否指向同一内存
     - 用 ``restrict`` 关键字（C）或手写汇编
   * - 循环依赖
     - 迭代之间数据有依赖（如 ``a[i] = a[i-1] + 1``）
     - 改写算法或使用前缀和技巧
   * - 非连续访问
     - 跨步访问（如矩阵转置）
     - 用 gather（AVX2）或重新组织数据布局
   * - 数据依赖分支
     - 循环内有数据相关的条件分支
     - 用掩码操作（AVX-512）或分支消除
   * - 函数调用
     - 循环内调用无法内联的函数
     - 内联或改写

.. code-block:: none

   ; 循环依赖的例子：无法直接向量化
   ; a[i] = a[i-1] + 1  （每个元素依赖前一个）
   ; 这种「串行前缀」需要特殊处理（如并行前缀和算法）

   ; 非连续访问的例子：矩阵转置
   ; 访问 matrix[i][j] 时，j 方向是连续的，i 方向是跨步的
   ; 转置后按行访问才能向量化

数据布局：AoS 与 SoA
======================

向量化对数据布局非常敏感。两种常见布局：

.. code-block:: none

   ; AoS（Array of Structures）：结构体数组
   ; struct Point { float x, y, z; };
   ; Point points[N];
   ; 内存布局：x0 y0 z0 x1 y1 z1 x2 y2 z2 ...
   ; 要处理所有 x 坐标时，元素间隔 12 字节，无法直接向量化

   ; SoA（Structure of Arrays）：数组的结构体
   ; float xs[N], ys[N], zs[N];
   ; 内存布局：x0 x1 x2 ... y0 y1 y2 ... z0 z1 z2 ...
   ; 要处理所有 x 坐标时，元素连续，可以直接向量化

.. code-block:: none

   ; AoS 布局：处理 x 坐标需要 gather（慢）
   ; 每个 x 元素间隔 12 字节（3 个 float）
   ; 无法用连续加载，只能用 vgatherdps 或标量循环

   ; SoA 布局：处理 x 坐标是连续加载（快）
   ; vmovups ymm0, [xs + rdi]   ; 一次加载 8 个 x

.. tip::

   对「按字段批量处理」的场景（如物理引擎同时更新所有粒子的 x、y、z），
   **SoA 布局** 通常比 AoS 快得多。代价是代码可读性稍差、缓存局部性
   在「按单个对象访问」时变差。选择哪种布局取决于访问模式。

向量化优化总结
================

.. list-table::
   :header-rows: 1

   * - 技巧
     - 收益
     - 关键点
   * - 主循环 + 尾处理
     - 高
     - 处理数组长度不能被向量宽度整除的情况
   * - 数据对齐
     - 中-高
     - 对齐到 32 字节（向量）或 64 字节（缓存行）
   * - 多累加器
     - 中-高
     - 打破依赖链，充分利用多个 FMA 单元
   * - FMA 融合
     - 中-高
     - 减少指令数，提升精度
   * - vzeroupper
     - 高（避免数十倍惩罚）
     - 返回前清理 YMM 高 128 位
   * - SoA 数据布局
     - 高
     - 按字段批量处理时优先 SoA
   * - 编译器自动向量化
     - 高（省力）
     - 先让编译器做，再考虑手写

.. warning::

   向量化优化的**前提**是先用 ``perf`` 确认热点确实在数据并行循环上。
   如果热点是内存带宽受限（而非计算受限），向量化可能收益有限——
   此时优化内存访问模式（缓存友好、预取）比向量化更有效。

练习题
========

1. 编写一个对 ``double`` 数组求和的函数，分别实现标量版本和 AVX2 向量化版本
   （主循环 + 尾处理），用 ``perf stat`` 对比两者的 IPC 和运行时间。

2. 将求和循环改为 2 个累加器，再改为 4 个累加器，观察 IPC 的变化。
   解释为什么累加器越多，IPC 越高（直到达到 FMA 单元数量上限）。

3. 实现 SAXPY（``y[i] = a * x[i] + y[i]``）的三种版本：
   标量、向量化（``vmulpd`` + ``vaddpd``）、FMA（``vfmadd231pd``），
   对比指令数和运行时间。

4. 用 ``gcc -O3 -mavx2 -mfma -S`` 编译一个简单的求和循环，
   观察编译器生成的向量化代码，找出它用了哪些 SIMD 指令。

5. 构造一个「编译器无法向量化」的循环（如带指针别名的循环），
   然后手写汇编向量化版本，对比性能差异，体会手写汇编的价值。
