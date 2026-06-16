.. _chapter-06-avx:

===============================
AVX 指令集
===============================

AVX（Advanced Vector Extensions）是 SSE 的继任者，将 SIMD 寄存器从 128 位扩展到 256 位（YMM 寄存器），
并引入了三操作数指令编码（VEX 前缀），减少了对寄存器的破坏。

上一节介绍的 SSE 用一个 ``addps`` 就能同时加 4 个 ``float``。但如果你有 **8 个** ``float`` 要同时处理呢？你得拆成两条 ``addps``，还要手动处理中间结果。这就是 AVX 要解决的问题——**把 SIMD 数据路径翻倍**。

但 AVX 不只是更宽的寄存器。它还引入了一个更重要的改进：**VEX 前缀和三操作数编码**。在 SSE 中，``addps xmm0, xmm1`` 会覆盖 xmm0（两操作数，破坏性）。在 AVX 中，``vmulps ymm0, ymm1, ymm2`` 将结果写入 ymm0，ymm1 和 ymm2 保持不变（三操作数，非破坏性）。这意味著 **AVX 代码可以保留更多的中间结果在寄存器中**，减少了不必要的寄存器复制，编译器也因此可以生成更高效的代码。

两个实际的场景：

- **科学计算**：处理 256 位宽的双精度数组时，AVX 一次处理 4 个 ``double``，吞吐量是 SSE 的 2 倍
- **音视频处理**：4K 视频的像素流、音频的 FFT 变换，每帧数据量大且高度并行，AVX 可以显著减少循环次数

YMM 寄存器
===============

AVX 引入了 16 个 256 位寄存器（``ymm0`` ~ ``ymm15``），与 XMM 寄存器重叠（``xmm0`` 是 ``ymm0`` 的低 128 位）。

.. code-block:: text

   ; YMM 寄存器布局（256 位）
   ; ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
   ; │ 32   │ 32   │ 32   │ 32   │ 32   │ 32   │ 32   │ 32   │  ← 8 个单精度 float
   ; └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
   ; ┌─────────┬─────────┬─────────┬─────────┐
   ; │ 64      │ 64      │ 64      │ 64      │  ← 4 个双精度 double
   ; └─────────┴─────────┴─────────┴─────────┘

.. warning::

   在 AVX 和 SSE 指令之间混用时，必须使用 ``vzeroupper`` 指令清除 YMM 寄存器的高 128 位，
   否则会有性能惩罚（状态切换导致 ``movaps`` 等 SSE 指令变慢）。

VEX 编码与三操作数指令
==========================

AVX 使用 VEX 前缀编码，允许指令指定三个操作数：**不破坏源寄存器**。

.. code-block:: none

   ; SSE（两操作数，破坏性）
   mulps xmm0, xmm1              ; xmm0 = xmm0 * xmm1（xmm0 被覆盖）

   ; AVX（三操作数，非破坏性）
   vmulps ymm0, ymm1, ymm2       ; ymm0 = ymm1 * ymm2（ymm1, ymm2 不变）

   ; 更多示例
   vaddps  ymm0, ymm1, ymm2      ; ymm0 = ymm1 + ymm2
   vsubps  ymm0, ymm1, ymm2      ; ymm0 = ymm1 - ymm2
   vmulps  ymm0, ymm1, ymm2      ; ymm0 = ymm1 * ymm2
   vdivps  ymm0, ymm1, ymm2      ; ymm0 = ymm1 / ymm2
   vaddpd  ymm0, ymm1, ymm2      ; 双精度加法

.. note::

   三操作数编码减少了寄存器复制操作（编译器不再需要 ``movaps`` 来保存副本），
   同时也简化了手写汇编。

数据传送
============

.. code-block:: none

   section .data
       align 32                    ; AVX 的 256 位数据建议 32 字节对齐
       vec dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0

   section .text
       ; 对齐加载（32 字节）
       vmovaps ymm0, [vec]         ; ymm0 = [1.0 ... 8.0]

       ; 未对齐加载
       vmovups ymm1, [rsi]

       ; 广播
       vbroadcastss ymm2, [scalar] ; ymm2 的所有元素设为 scalar

       ; 存储
       vmovaps [rdi], ymm0

SSE 指令的 AVX 版本
=======================

几乎所有 SSE 指令都有对应的 AVX 版本（加 ``v`` 前缀）：

.. list-table::
   :header-rows: 1

   * - SSE
     - AVX
     - 说明
   * - ``movaps``
     - ``vmovaps``
     - 对齐加载/存储
   * - ``addps``
     - ``vaddps``
     - packed 加法
   * - ``mulps``
     - ``vmulps``
     - packed 乘法
   * - ``haddps``
     - ``vhaddps``
     - 水平加法
   * - ``cvtss2si``
     - ``vcvtss2si``
     - 类型转换

AVX2 新增功能
=================

AVX2（Haswell 及以后）进一步扩展了 AVX：

.. code-block:: none

   ; 整数 SIMD 操作
   vpaddb  ymm0, ymm1, ymm2       ; 字节整数加法
   vpaddw  ymm0, ymm1, ymm2       ; 字整数加法
   vpaddd  ymm0, ymm1, ymm2       ; 双字整数加法

   ; 收集（Gather）操作——非连续内存加载
   ; vgatherdps dest, [base + index*scale], mask
   ; 从不同地址分散加载浮点数
   vgatherdps ymm0, [rdi + ymm1*4], ymm2

   ; 排列（Permute）操作
   vpermps ymm0, ymm1, ymm2       ; 根据 ymm1 的索引重排 ymm2

AVX 与 SSE 混用的性能陷阱
=============================

.. code-block:: none

   ; 在同一个函数中混用 SSE 和 AVX
   func:
       vaddps ymm0, ymm1, ymm2    ; AVX 操作
       ; ...
       movaps xmm3, [val]          ; SSE 操作

       ; ⚠ 在没有 vzeroupper 的情况下从 AVX 切到 SSE
       ; 会导致隐式的状态切换，每次 movaps 代价 ~50 周期

       vzeroupper                  ; ✅ 清除 ymm 高 128 位
       movaps xmm3, [val]          ; ✅ 现在 SSE 操作是快的

       ret

.. warning::

   在返回调用者前，始终考虑执行 ``vzeroupper``。如果调用者使用 SSE 而你的函数使用了 AVX，
   不执行 ``vzeroupper`` 会导致调用者的 SSE 代码变慢数十倍。

AVX-512 简介
================

AVX-512 将 SIMD 寄存器进一步扩展到 :strong:`512 位`\ （ZMM 寄存器），并引入了:strong:`掩码寄存器`\ 和更多新指令。

ZMM 寄存器与掩码寄存器
-------------------------

.. code-block:: text

   ; ZMM 寄存器布局（512 位）
   ; ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
   ; │ 64   │ 64   │ 64   │ 64   │ 64   │ 64   │ 64   │ 64   │  ← 8 个双精度
   ; └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
   ; ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
   ; │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │32  │  ← 16 个单精度
   ; └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘

   ; 寄存器重叠关系
   ; zmm0 的低 256 位 = ymm0
   ; zmm0 的低 128 位 = xmm0

   ; 掩码寄存器：k0 ~ k7（64 位，用于条件化 SIMD 操作）
   ; k0 固定为全 0/全 1，k1-k7 可用作操作掩码

掩码操作
--------------

AVX-512 的特点是**嵌入掩码**——几乎所有指令都可以带掩码执行：

.. code-block:: none

   ; 语法：{k<掩码>}{z} 后缀控制合并（merge）或清零（zero）模式

   ; 带掩码的加载：只有掩码位为 1 时才加载该元素
   ; k1 = 0b0101 → 只加载元素 0 和 2
   vmovaps zmm0 {k1}, [rsi]

   ; 带掩码的加法：mask=0 的位置保留原值（merge）或归零（zero）
   vaddps  zmm1 {k1}, zmm0, [rdi]     ; merge 模式
   vaddps  zmm1 {k1}{z}, zmm0, [rdi]  ; zero 模式

   ; 比较指令直接产生掩码
   vcmpps  k1, zmm0, zmm1, 0          ; k1 = (zmm0 == zmm1) 的掩码
   ; 后续可以用 k1 控制其他操作

关键新特性
--------------

.. list-table::
   :header-rows: 1

   * - 特性
     - 指令示例
     - 说明
   * - 嵌入掩码
     - ``vaddps zmm {k1}, zmm, zmm``
     - 条件化执行，消除分支
   * - 广播（Broadcast）
     - ``vbroadcastss zmm, [scalar]``
     - 单值扩展到整个向量
   * - 压缩/扩展
     - ``vpcompressd`` / ``vpexpandd``
     - 按掩码压缩/扩展数据
   * - 冲突检测
     - ``vpconflictd``
     - 检测向量中的重复元素
   * - 置换（Permute）
     - ``vpermw`` / ``vpermd``
     - 交叉通道数据重排
   * - 三元逻辑
     - ``vpternlogd zmm, zmm, zmm, imm``
     - 任意三元布尔运算

.. code-block:: none

   ; 广播：从标量加载到所有元素
   vbroadcastss zmm0, [alpha]          ; zmm0 = [α, α, α, α, α, α, α, α,
                                       ;          α, α, α, α, α, α, α, α]

   ; 三元逻辑：一条指令完成任意 3 输入布尔运算
   ; vpternlogd dst, src1, src2, imm8
   ; imm8 是 256 种布尔函数对应的真值表
   vpternlogd zmm0, zmm1, zmm2, 0x80  ; zmm0 = zmm0 & zmm1 & zmm2
   vpternlogd zmm0, zmm1, zmm2, 0x96  ; zmm0 = zmm0 ^ zmm1 ^ zmm2

性能注意事项
--------------

.. warning::

   AVX-512 在高负载下可能导致 CPU :strong:`频率降频`\ （frequency throttling），
   因为 512 位操作功耗较高。具体降频幅度取决于 CPU 型号和工作负载。

   - 密集型 512 位 FMA 可能降低基础频率的 20-30%
   - 如果不需要 512 位的吞吐量，使用 AVX2（256 位）通常更省电
   - Intel Xeon Scalable（Skylake-SP 及之后）对 AVX-512 的降频控制较好

.. note::

   AVX-512 并非所有 x86_64 CPU 都支持。使用前需要通过 ``cpuid`` 指令检查：
   - AVX-512F（基础）：CPUID.(EAX=7, ECX=0):EBX bit 16
   - AVX-512DQ（双字/四字）：EBX bit 17
   - AVX-512BW（字节/字）：EBX bit 30

   在汇编代码中，如果目标平台不确定，最好提供 AVX2 回退路径。
