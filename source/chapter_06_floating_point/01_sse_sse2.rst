.. _chapter-06-sse:

===============================
SSE/SSE2 浮点运算
===============================

SSE（Streaming SIMD Extensions）和 SSE2 是 x86_64 上处理浮点运算的基础指令集。SSE 提供单精度（32 位）浮点支持，SSE2 扩展了双精度（64 位）浮点支持。

.. admonition:: 从 MMX 到 AVX-512：3D 游戏驱动的 SIMD 革命
   :class: story

   SIMD 在 x86 上的发展史就是 3D 图形需求的映射史。1997 年 Intel 推出的 **MMX** 是第一个 SIMD 扩展
   （64 位，整数运算），但实际是借用 FPU 寄存器，导致不能同时使用浮点和 SIMD。1999 年 **SSE** 引入了
   专用 128 位 XMM 寄存器，支持单精度浮点——恰好赶上 3D 游戏爆发期，Quake III 等游戏大量使用 SSE
   进行顶点变换和矩阵运算。2000 年 **SSE2** 加入双精度支持，使科学计算受益。2011 年 **AVX** 将寄存器
   翻倍到 256 位，2017 年 **AVX-512** 再翻倍到 512 位。有趣的是，**Intel 曾在 Pentium 4 时代力推
   软件 SIMD 优化，结果发现许多程序员用 SIMD 写出的代码比手动优化的标量代码还慢**——
   这加速了"让编译器自动向量化"的工具链改进。

SSE 寄存器：XMM0-XMM15
============================

x86_64 提供了 16 个 128 位的 XMM 寄存器（``xmm0`` ~ ``xmm15``）。

.. code-block:: text

   ; XMM 寄存器布局（128 位）
   ; ┌──────┬──────┬──────┬──────┐
   ; │ 32   │ 32   │ 32   │ 32   │  ← 4 个单精度 float
   ; └──────┴──────┴──────┴──────┘
   ; ┌─────────┬─────────┐
   ; │ 64      │ 64      │  ← 2 个双精度 double
   ; └─────────┴─────────┘
   ; ┌─────────────────────────┐
   ; │ 128                     │  ← 1 个 128 位整数
   ; └─────────────────────────┘

.. warning::

   写入 XMM 寄存器的低 64 位**不会**像通用寄存器（``eax``）那样清零高 64 位。
   始终使用 ``xorpd xmm0, xmm0`` 等方式初始化整个寄存器。

数据传送指令
================

.. code-block:: none

   section .data
       s1 dd 1.0, 2.0, 3.0, 4.0       ; 4 个单精度
       d1 dq 1.0, 2.0                  ; 2 个双精度
       scalar dd 3.14

   section .text
       ; 加载/存储对齐的 packed 数据（要求 16 字节对齐）
       movaps xmm0, [s1]               ; xmm0 = [1.0, 2.0, 3.0, 4.0]
       movaps [rsp], xmm1              ; 存储

       ; 加载/存储未对齐的 packed 数据（不要求对齐）
       movups xmm0, [rsi]              ; xmm0 = [a, b, c, d]

       ; 加载/存储标量
       movss  xmm0, [scalar]           ; xmm0[0] = 3.14，其余位不变
       movsd  xmm1, [d1]              ; xmm1[0] = 1.0（双精度）

       ; 广播标量到所有元素
       shufps xmm0, xmm0, 0            ; xmm0 = [3.14, 3.14, 3.14, 3.14]

标量浮点运算
================

.. code-block:: none

   section .data
       a dd 3.14
       b dd 2.71

   section .text
       movss  xmm0, [a]                ; xmm0 = 3.14
       movss  xmm1, [b]                ; xmm1 = 2.71

       ; 标量运算
       addss  xmm0, xmm1               ; xmm0 = 3.14 + 2.71 = 5.85
       subss  xmm0, xmm1               ; xmm0 = 5.85 - 2.71 = 3.14
       mulss  xmm0, xmm1               ; xmm0 = 3.14 * 2.71
       divss  xmm0, xmm1               ; xmm0 = 3.14 / 2.71
       sqrtss xmm0, xmm1               ; xmm0 = sqrt(2.71)

       ; 双精度标量
       movsd  xmm2, [d_a]
       movsd  xmm3, [d_b]
       addsd  xmm2, xmm3               ; 双精度加法

Packed（向量）运算
=====================

Packed 指令同时对寄存器的所有元素执行相同操作：

.. code-block:: none

   section .data
       vec1 dd 1.0, 2.0, 3.0, 4.0
       vec2 dd 5.0, 6.0, 7.0, 8.0

   section .text
       movaps xmm0, [vec1]             ; xmm0 = [1.0, 2.0, 3.0, 4.0]
       movaps xmm1, [vec2]             ; xmm1 = [5.0, 6.0, 7.0, 8.0]

       ; 向量运算
       addps  xmm0, xmm1               ; xmm0 = [6.0, 8.0, 10.0, 12.0]
       subps  xmm0, xmm1               ; 减法
       mulps  xmm0, xmm1               ; 点乘
       divps  xmm0, xmm1               ; 除法
       sqrtps xmm0, xmm1               ; 逐元素求平方根

       ; 双精度 packed
       movapd xmm2, [d_vec1]
       movapd xmm3, [d_vec2]
       addpd  xmm2, xmm3               ; 双精度向量加法

类型转换
============

.. code-block:: none

   section .data
       int_val dd 42
       fp_val  dd 3.14

   section .text
       ; 整数 → 浮点
       cvtsi2ss xmm0, dword [int_val]  ; xmm0 = 42.0（单精度）
       cvtsi2sd xmm1, qword [rbx]      ; 双精度

       ; 浮点 → 整数（截断）
       cvtss2si eax, xmm0              ; eax = (int)42.0
       cvttss2si eax, xmm0             ; 截断取整（向零）

       ; 单精度 ↔ 双精度
       cvtss2sd xmm0, xmm1             ; 单精度 → 双精度
       cvtsd2ss xmm0, xmm1             ; 双精度 → 单精度

比较指令
============

SSE 比较指令设置目标寄存器的掩码（全 1 为真，全 0 为假）：

.. code-block:: none

       movaps xmm0, [vec1]
       movaps xmm1, [vec2]

       ; 比较（第三个操作数是条件码）
       cmpps  xmm0, xmm1, 0            ; 等于（EQ）
       cmpps  xmm0, xmm1, 1            ; 小于（LT）
       cmpps  xmm0, xmm1, 2            ; 小于等于（LE）
       cmpps  xmm0, xmm1, 3            ; 不等于（NEQ）

       ; 标量比较
       comiss xmm0, xmm1               ; 比较并设置 EFLAGS
       ja     .greater
       jb     .less
       je     .equal

.. list-table:: ``comiss``/``comisd`` 后的标志位
   :header-rows: 1

   * - 关系
     - ZF
     - PF
     - CF
   * - a > b
     - 0
     - 0
     - 0
   * - a < b
     - 0
     - 0
     - 1
   * - a == b
     - 1
     - 0
     - 0
   * - 无序（NaN）
     - 1
     - 1
     - 1

点积示例
============

.. code-block:: none

   ; 计算两个 4 元素向量的点积：sum(a[i] * b[i])
   section .data
       a dd 1.0, 2.0, 3.0, 4.0
       b dd 5.0, 6.0, 7.0, 8.0

   section .text
   dot_product:
       movaps xmm0, [a]                ; xmm0 = [1.0, 2.0, 3.0, 4.0]
       movaps xmm1, [b]                ; xmm1 = [5.0, 6.0, 7.0, 8.0]
       mulps  xmm0, xmm1               ; xmm0 = [5.0, 12.0, 21.0, 32.0]
       haddps xmm0, xmm0               ; 水平加法
       haddps xmm0, xmm0               ; [5+12+21+32, ...]
       ; xmm0[0] = 70.0
       ret

.. note::

   ``haddps``（水平加法）是 SSE3 引入的指令。它将同一寄存器中的相邻元素相加：
   ``xmm0 = [a, b, c, d]`` → ``haddps xmm0, xmm0`` → ``[a+b, c+d, a+b, c+d]``
   第二次 ``haddps`` → ``[a+b+c+d, ...]``

对齐要求
============

.. list-table::
   :header-rows: 1

   * - 指令
     - 对齐要求
     - 未对齐时的行为
   * - ``movaps`` / ``movapd``
     - 16 字节
     - 触发 ``#GP`` 异常（崩溃）
   * - ``movups`` / ``movupd``
     - 无要求
     - 正常工作（可能稍慢）
   * - ``movss`` / ``movsd``
     - 无要求
     - 正常工作

.. warning::

   使用 ``movaps`` 前务必确保地址 16 字节对齐。如果地址来自 ``malloc``（通常只对齐到 8 或 16 字节），
   使用 ``memalign``、``aligned_alloc`` 或 ``posix_memalign`` 获取对齐内存。

向量规约（Reduction）
=========================

规约操作将向量中的所有元素合并为一个标量值。常见的规约有求和、求最大值、求最小值：

.. code-block:: none

   ; 计算 4 个 float 的和（水平求和）
   ; 输入: xmm0 = [a, b, c, d]
   ; 输出: eax = a + b + c + d
   horizontal_sum_f32:
       haddps xmm0, xmm0          ; [a+b, c+d, a+b, c+d]
       haddps xmm0, xmm0          ; [a+b+c+d, ...]
       ; 结果在 xmm0[0]

   ; 计算最大值
   max_reduce_f32:
       movaps xmm1, xmm0
       shufps xmm1, xmm1, 0x4E    ; [c, d, a, b] 交换高低 64 位
       maxps  xmm0, xmm1          ; [max(a,c), max(b,d), ...]
       shufps xmm1, xmm0, 0xB1    ; [b, a, d, c] 交换相邻
       maxps  xmm0, xmm1          ; [max(...), ...]
       ; 结果在 xmm0[0]

矩阵乘法（4x4）
====================

4x4 矩阵乘法是 3D 图形中最核心的运算之一。SSE 可以大幅加速：

.. code-block:: none

   ; 4x4 矩阵乘法 C = A * B
   ; 矩阵列优先存储（column-major），每个列向量在一个 XMM 寄存器中
   ; A 的 4 列: xmm0, xmm1, xmm2, xmm3
   ; B 的 4 列: xmm4, xmm5, xmm6, xmm7
   ; 输出 C 的 4 列: xmm8, xmm9, xmm10, xmm11

   mat4_mul:
       ; C 的第 0 列 = B[0][0]*A[0] + B[1][0]*A[1] + B[2][0]*A[2] + B[3][0]*A[3]
       movaps xmm8,  xmm4
       shufps xmm8,  xmm8, 0x00    ; 广播 B[0][0]
       mulps  xmm8,  xmm0          ; *= A 的第 0 列

       movaps xmm9,  xmm4
       shufps xmm9,  xmm9, 0x55    ; 广播 B[1][0]
       mulps  xmm9,  xmm1
       addps  xmm8,  xmm9

       movaps xmm9,  xmm4
       shufps xmm9,  xmm9, 0xAA    ; 广播 B[2][0]
       mulps  xmm9,  xmm2
       addps  xmm8,  xmm9

       movaps xmm9,  xmm4
       shufps xmm9,  xmm9, 0xFF    ; 广播 B[3][0]
       mulps  xmm9,  xmm3
       addps  xmm8,  xmm9
       ; xmm8 = C 的第 0 列
       ; ... 同理计算第 1-3 列 ...
       ret

.. note::

   在实际的 3D 引擎中，4x4 矩阵乘法一般由 GPU 完成。这里的示例展示了 SSE 如何通过
   **向量化广播 + 乘加** 模式大幅减少指令数：每次广播处理一个元素的一次乘加，
   4 条指令即可完成一列的计算。

图像像素处理
================

SSE 在处理逐像素操作时也非常高效，例如亮度调整（对每个像素 RGB 分量加一个常数）：

.. code-block:: none

   ; 对 4 个像素的 RGB 通道分别加一个亮度偏移
   ; xmm0 = [R1,G1,B1,A1, R2,G2,B2,A2, ...]（BGRA 格式）
   ; xmm1 = [brightness, 0, 0, 0]（广播到各通道）
   section .data
       align 16
       brightness db 32, 32, 32, 32  ; 亮度偏移（RGBA 各 +32）
           times 12 db 0             ; 填充到 16 字节
       pixel_mask db 0xFF, 0xFF, 0xFF, 0x00  ; 只修改 RGB，不修改 Alpha
           times 12 db 0             ; 填充

   section .text
       movdqu xmm0, [pixel_batch]    ; 加载 4 个像素（未对齐）
       movdqa xmm1, [brightness]     ; 加载亮度偏移
       paddusb xmm0, xmm1            ; 饱和加法（不溢出，自动截断到 255）
       ; 结果保存在 xmm0

       ; 对大量像素批量处理
       mov rcx, 1024                 ; 像素数量
       lea rsi, [image_data]         ; 图像数据指针
   .pixel_loop:
       movdqu xmm0, [rsi]           ; 加载 4 个像素
       paddusb xmm0, xmm1           ; 亮度调整
       movdqu [rsi], xmm0           ; 写回
       add rsi, 16                  ; 前进 4 个像素
       sub rcx, 4
       jnz .pixel_loop

.. tip::

   ``paddusb``（饱和无符号字节加法）非常适合图像处理：结果自动钳位到 [0, 255]，
   无需手动检查溢出。类似的 ``psubusb`` 用于减法（变暗）。SSE2 还提供了
   ``paddsw``/``psubsw`` 等有符号饱和版本。

向量化 vs 标量性能对比
============================

.. list-table::
   :header-rows: 1

   * - 操作
     - 标量（SSE 标量）
     - 向量化（Packed）
     - 加速比
   * - 4 个 float 相加
     - 4 条 ``addss``
     - 1 条 ``addps``
     - 4x
   * - 4x4 矩阵乘法
     - 64 条 ``mulss`` + 48 条 ``addss``
     - 16 条 ``mulps`` + 12 条 ``addps``
     - ~4x
   * - 16 个像素亮度调整
     - 16 次加载 + 16 次运算
     - 4 次加载 + 4 次 ``paddusb``
     - ~4x
   * - 点积 (4 元素)
     - 4 条 ``mulss`` + 3 条 ``addss``
     - 1 条 ``mulps`` + 2 条 ``haddps``
     - ~3x
