.. _chapter-06-avx:

===============================
AVX 指令集
===============================

AVX（Advanced Vector Extensions）是 SSE 的继任者，将 SIMD 寄存器从 128 位扩展到 256 位（YMM 寄存器），
并引入了三操作数指令编码（VEX 前缀），减少了对寄存器的破坏。

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
