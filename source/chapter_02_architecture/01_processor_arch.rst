.. _chapter-02-proc-arch:

===============================
现代 x86_64 处理器架构概述
===============================

在深入寄存器、指令集之前，先花一页篇幅了解现代 x86_64 CPU 的内部结构。
这有助于理解为什么某些代码跑得快、某些代码跑得慢——这些"为什么"将是后续章节反复出现的主题。

指令流水线
==============

现代 x86_64 CPU 将指令执行分为多个阶段（流水线），每个阶段由专门的硬件单元处理：

.. mermaid::

   flowchart LR
       A[取指 Fetch] --> B[译码 Decode]
       B --> C[重命名/分发 Rename]
       C --> D[执行 Execute]
       D --> E[访存 Memory]
       E --> F[提交 Writeback]

.. list-table::
   :header-rows: 1

   * - 阶段
     - 说明
     - 相关的代码优化
   * - 取指（Fetch）
     - 从 L1 I-cache 读取指令字节
     - 紧凑的指令编码、对齐
   * - 译码（Decode）
     - 将指令翻译为微操作（µop）
     - 使用简单指令（单个 µop）避免复杂指令
   * - 重命名（Rename）
     - 消除寄存器假依赖
     - 使用足够的寄存器避免停顿
   * - 执行（Execute）
     - 在 ALU/FPU/Load-Store 单元执行
     - 指令级并行（ILP）、多累加器
   * - 访存（Memory）
     - 访问 L1/L2/L3 缓存或内存
     - 缓存友好访问模式、对齐
   * - 提交（Writeback）
     - 确认结果写入寄存器
     - 分支预测正确/失败的确认

超标量与乱序执行
====================

现代 x86_64 CPU 每个周期可以发射 4-6 条指令到不同执行单元：

.. code-block:: text

   每个核心的执行单元（以 Intel Skylake 为例）：
   ┌──────────────────────────────────────┐
   │  Port 0: ALU + Vector FMA           │
   │  Port 1: ALU + Vector FMA + Branch  │
   │  Port 2: Load + Store Address       │
   │  Port 3: Load + Store Address       │
   │  Port 4: Store Data                 │
   │  Port 5: ALU + Vector Shuffle       │
   │  Port 6: ALU + Branch               │
   └──────────────────────────────────────┘

.. code-block:: none

   ; 乱序执行的影响——指令顺序不一定等于执行顺序
       mov rax, [rsi]       ; 加载数据（可能需要等待内存）
       add rax, rbx         ; 等待上一条完成
       mov rcx, [rdi]       ; 独立于 rax 的指令可乱序执行
       add rcx, rdx         ; 通常与上一条并行执行

.. note::

   乱序执行意味着第 8 章讨论的**指令级并行（ILP）**优化有效——
   消除数据依赖可以让多条指令同时在不同执行单元上运行。

分支预测
============

CPU 使用分支预测器猜测条件跳转的方向。预测正确时流水线保持满状态；
预测失败时，已进入流水线的指令必须被冲刷，损失 **10-20 个周期**。

.. mermaid::

   flowchart TD
       A[取指] --> B[译码]
       B --> C[执行]
       C --> D{发现预测错误！}
       D -->|是| E[冲刷流水线]
       E --> F[从正确地址重新取指]
       F --> G[浪费 10-20 周期]
       D -->|否| H[继续执行]

.. code-block:: none

   ; 高度可预测的分支（几乎总是跳转）：
       test rax, rax
       jz   .common_case       ; 预测器能学会这个模式

   ; 难以预测的分支（随机模式）：
       cmp rbx, rdx
       jg  .random_pattern     ; 预测器难以学习 → 使用 cmov 替代

   影响分支预测的几个优化手段详见第 8.2 节。

缓存层次结构
================

内存访问速度比 CPU 慢两个数量级。缓存用于弥合这一差距：

.. list-table::
   :header-rows: 1

   * - 缓存层级
     - 典型大小
     - 延迟
     - 说明
   * - L1 (指令/数据)
     - 32 KB + 32 KB
     - ~4 周期
     - 每核心私有，最快
   * - L2
     - 256 KB - 1 MB
     - ~12 周期
     - 每核心私有
   * - L3
     - 8 MB - 32 MB
     - ~40 周期
     - 所有核心共享
   * - 主内存
     - 8 GB+
     - ~200+ 周期
     - 最慢，通过内存控制器

.. mermaid::

   flowchart TD
       subgraph Core0[Core 0]
           L1i0[L1i] --- L1d0[L1d]
           L1d0 --- L20[L2]
       end
       subgraph Core1[Core 1]
           L1i1[L1i] --- L1d1[L1d]
           L1d1 --- L21[L2]
       end
       L20 --- L3[L3 Cache 共享]
       L21 --- L3
       L3 --- MEM[主内存]

.. code-block:: none

   ; 缓存友好的顺序访问（利用空间局部性）
       mov rax, [arr + rcx*8]    ; 访问 arr[0] 时，arr[0..7] 都进入缓存

   ; 缓存不友好的随机访问（每次访问不同缓存行、甚至不同页）
       mov rax, [matrix + rcx*1024]  ; 每 1024 字节访问一次——每次都在不同缓存行

.. caution::

   第 8 章详细讨论缓存优化技术。一条核心原则：:strong:`顺序访问比跳跃访问快几十倍`\ 。

TLB（转译后备缓冲区）
=========================

x86_64 使用 4 级页表将虚拟地址转换为物理地址。每次地址转换可能需要 4 次内存访问。
TLB 缓存最近使用的地址转换结果，:strong:`TLB 未命中的代价极高`\ （数百周期）。

.. list-table::
   :header-rows: 1

   * - 级别
     - 缓存内容
     - 大小
     - 未命中代价
   * - L1 TLB
     - 4 KB 页表项
     - 64-128 项
     - ~7 周期后查 L2 TLB
   * - L2 TLB
     - 4 KB / 2 MB 页表项
     - 512-2048 项
     - 数十到数百周期（页表遍历）

.. tip::

   使用 **大页（Huge Pages, 2 MB / 1 GB）** 可以减少 TLB 压力。
   对于大数据集应用，启用透明大页（Transparent Huge Pages）可显著提升性能。

指令集扩展演进
==================

现代 x86_64 CPU 在基础指令集之上不断添加扩展：

.. list-table::
   :header-rows: 1

   * - 扩展
     - 引入时间
     - 关键特性
   * - MMX
     - 1997
     - 64 位 SIMD（已过时）
   * - SSE / SSE2
     - 1999 / 2001
     - 128 位浮点/整数 SIMD — **基本要求**
   * - SSE3 / SSSE3
     - 2004 / 2006
     - 水平加法、整数计算增强
   * - SSE4.1 / SSE4.2
     - 2008
     - popcnt、字符串处理、打包比较
   * - AVX / AVX2
     - 2011 / 2013
     - 256 位 SIMD、VEX 编码、Gather
   * - AVX-512
     - 2017
     - 512 位 SIMD（仅 Xeon / Ice Lake+）
   * - FMA
     - 2013
     - 融合乘加（Fused Multiply-Add）
   * - AES-NI
     - 2010
     - AES 加密加速
   * - SHA-NI
     - 2013
     - SHA-1/SHA-256 加速

本章后续内容
================

理解上述微架构概念后，接下来的小节将深入：

- :ref:`chapter-02-registers` — x86_64 的 16 个通用寄存器和专用寄存器
- :ref:`chapter-02-memory-model` — 虚拟地址空间、段、字节序、对齐
- :ref:`chapter-02-addressing-modes` — 九种寻址方式详解
- :ref:`chapter-02-stack` — 栈的原理与栈帧管理

.. note::

   本章提供的是简化的概览。不同厂商（Intel / AMD）以及不同代际的 CPU 在具体实现上有差异。
   如果需要精确的微架构数据，请查阅对应 CPU 的优化手册。

   - Intel: `Intel® 64 and IA-32 Architectures Optimization Reference Manual <https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>`__
   - AMD: `AMD64 Architecture Programmer's Manual <https://www.amd.com/en/developer/open-source/amd64.html>`__
