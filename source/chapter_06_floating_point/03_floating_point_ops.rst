.. _chapter-06-fp-ops:

===============================
浮点运算高级主题
===============================

本节深入浮点运算的底层细节，包括 IEEE 754 标准、精度问题、舍入模式以及异常处理。

IEEE 754 标准
=================

x86_64 的浮点运算遵循 IEEE 754 标准。单精度（32 位）和双精度（64 位）的位布局如下：

.. code-block:: text

   ; 单精度 float（32 位）
   ; ┌──────┬──────────────────┬───────────────────────┐
   ; │ 1    │ 8                │ 23                    │
   ; │ 符号  │ 指数（偏移 127）  │ 尾数                  │
   ; └──────┴──────────────────┴───────────────────────┘
   ; 值 = (-1)^符号 × 2^(指数-127) × 1.尾数

   ; 双精度 double（64 位）
   ; ┌──────┬──────────────────┬───────────────────────┐
   ; │ 1    │ 11               │ 52                    │
   ; │ 符号  │ 指数（偏移 1023） │ 尾数                  │
   ; └──────┴──────────────────┴───────────────────────┘

.. code-block:: none

   ; 检查浮点数的位模式
   section .data
       fp1 dd 1.0                    ; 位模式：0x3F800000
       fp2 dd -2.5                   ; 位模式：0xC0200000
       nan dd 0x7FC00000             ; NaN（非数）
       inf dd 0x7F800000             ; +∞（正无穷）

汇编中的浮点常量
====================

.. code-block:: none

   section .data
       ; 浮点常量直接写（NASM 支持）
       f1 dd 3.14159                 ; 单精度
       f2 dq 2.718281828459045       ; 双精度
       f3 dd 1.0e-10                 ; 科学计数法

       ; 也可以使用十六进制直接指定位模式
       f4 dd 0x3F800000              ; 等同于 1.0
       f5 dq 0x400921FB54442D18      ; 等同于 π 的双精度近似

精度与舍入
==============

浮点运算不精确是常态，而非异常：

.. code-block:: none

   ; 精度损失示例
   section .data
       a dd 0.1
       b dd 0.2
       c dd 0.3

   section .text
       movss xmm0, [a]               ; xmm0 = 0.1
       addss xmm0, [b]               ; xmm0 = 0.1 + 0.2
       comiss xmm0, [c]              ; 比较
       jne .not_equal                ; 0.1 + 0.2 != 0.3！精度损失

       ; 正确比较方式：检查差的绝对值是否小于某个 epsilon
       movss xmm1, [c]
       subss xmm0, xmm1              ; 计算差值
       andps xmm0, [abs_mask]        ; 取绝对值（去除符号位）
       comiss xmm0, [epsilon]        ; 比较与 epsilon
       jb   .approx_equal

   section .data
       abs_mask dd 0x7FFFFFFF        ; 清除符号位
       epsilon  dd 1.0e-6            ; 比较阈值

控制舍入模式
================

SSE 控制寄存器 ``MXCSR`` 控制浮点运算的舍入模式：

.. code-block:: none

   ; MXCSR 寄存器中的舍入控制位（bits 13-14）
   ; 00 = 最近舍入（Round to Nearest，默认）
   ; 01 = 向下舍入（Round Down，向 -∞）
   ; 10 = 向上舍入（Round Up，向 +∞）
   ; 11 = 向零舍入（Round Toward Zero，截断）

   ; 设置舍入模式
   push rbp
   mov  rbp, rsp
   sub  rsp, 8

   stmxcsr [rsp-4]                   ; 保存当前控制字
   ldmxcsr [new_mode]               ; 设置新舍入模式

   ; 执行需要特殊舍入的计算
   ; ...

   ldmcsr [rsp-4]                    ; 恢复原舍入模式
   add  rsp, 8
   pop  rbp
   ret

section .data
    new_mode dd 0x00006000           ; 向下舍入（bits 13-14 = 01）

.. note::

   默认的最近舍入（Round to Nearest）在大多数场景下工作良好。改变舍入模式主要用于
   区间算术（interval arithmetic）和数值分析中的误差边界计算。

浮点异常
============

浮点运算可能触发以下异常：

.. list-table::
   :header-rows: 1

   * - 异常
     - MXCSR 位
     - 触发条件
   * - 精度（Inexact）
     - 12
     - 结果需要舍入（最常见）
   * - 下溢（Underflow）
     - 11
     - 结果太小，无法正常表示
   * - 上溢（Overflow）
     - 10
     - 结果太大，无法表示
   * - 除零（Divide-by-Zero）
     - 9
     - 除以 0
   * - 非规约数（Denormal）
     - 8
     - 操作数是非规约数
   * - 无效操作（Invalid）
     - 7
     - 0/0、∞-∞、sqrt(-1) 等

.. code-block:: none

   ; 检查浮点异常
   section .data
       mxcsr_val dd 0

   section .text
       stmxcsr [mxcsr_val]          ; 读取 MXCSR
       mov eax, [mxcsr_val]
       test eax, 0x0080             ; 检查无效操作位
       jnz .invalid_op
       test eax, 0x0200             ; 检查除零位
       jnz .div_by_zero

       ; 屏蔽/解除屏蔽异常
       ; MXCSR 低 6 位是异常屏蔽位（1 = 不触发异常，0 = 触发 SIGFPE）
       ; 默认所有异常都被屏蔽

特殊浮点值
==============

.. list-table::
   :header-rows: 1

   * - 值
     - 含义
     - 何时出现
   * - NaN
     - 非数（Not a Number）
     - 0/0, ∞-∞, sqrt(-1)
   * - +∞ / -∞
     - 正/负无穷
     - 除以 0，上溢
   * - ±0
     - 正/负零
     - 下溢到 0
   * - 非规约数
     - 最小精度以下的数
     - 接近零的值

.. code-block:: none

   ; 检测 NaN
   section .data
       nan_val dd 0x7FC00000

   section .text
       movss xmm0, [nan_val]
       ucomiss xmm0, xmm0            ; NaN 与自己比较不相等
       jp   .is_nan                   ; PF 置位表示无序（包括 NaN）

       ; 另一种方法：检查位模式
       movd eax, xmm0                 ; 将 float 位模式移到 eax
       and  eax, 0x7FFFFFFF          ; 清除符号位
       cmp  eax, 0x7F800000          ; 大于等于这个值就是 NaN 或 ∞
       jae  .is_nan_or_inf
