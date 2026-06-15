.. _chapter-06-floating-point:

===============================
SSE/SSE2 浮点运算
===============================

SSE（Streaming SIMD Extensions）和 SSE2 是 x86_64 上处理浮点运算的基础指令集。SSE 提供单精度（32 位）浮点支持，SSE2 扩展了双精度（64 位）浮点支持。

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
