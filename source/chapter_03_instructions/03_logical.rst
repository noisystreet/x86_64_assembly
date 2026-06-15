.. _chapter-03-logical:

=============================
逻辑运算与移位指令
=============================

逻辑运算指令对操作数进行按位操作，移位指令则对操作数的位进行左移或右移。

按位逻辑运算
================

.. code-block:: none

   ; and: 按位与
   and rax, rbx          ; rax = rax & rbx
   and rax, 0xFF         ; rax = rax & 0xFF（只保留低 8 位）
   and byte [status], 0x7F ; 清零最高位

   ; or: 按位或
   or rax, rbx           ; rax = rax | rbx
   or rcx, 0x1000        ; 设置第 12 位
   or dword [flags], 1   ; 设置最低位

   ; xor: 按位异或
   xor rax, rbx          ; rax = rax ^ rbx
   xor rax, rax          ; rax = 0（最常见的清零惯用法）
   xor byte [val], 0xFF  ; 取反所有位

   ; not: 按位取反
   not rax               ; rax = ~rax

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 影响的标志位
   * - ``and``
     - ``dst &= src``
     - OF=0, CF=0, SF, ZF, PF
   * - ``or``
     - ``dst |= src``
     - OF=0, CF=0, SF, ZF, PF
   * - ``xor``
     - ``dst ^= src``
     - OF=0, CF=0, SF, ZF, PF
   * - ``not``
     - dst = ~dst
     - 不影响标志位

.. code-block:: none

   ; 常见位操作惯用法
   ; 清零寄存器（比 mov reg, 0 更高效，编码也更短）
   xor rax, rax          ; rax = 0

   ; 检查某一位是否为 0
   test rax, 0x100       ; 检查第 8 位（相当于 and，但不写回结果）
   jz   .bit_not_set     ; 如果该位为 0 则跳转

   ; 设置某一位
   or   rax, 0x100       ; 设第 8 位为 1

   ; 清除某一位
   and  rax, ~0x100      ; 设第 8 位为 0

   ; 翻转某一位
   xor  rax, 0x100       ; 第 8 位取反

``test`` 指令
=================

``test`` 执行按位 ``and``，但 **不写回结果**，只设置标志位。常用于检查寄存器的值。

.. code-block:: none

   test rax, rax         ; 检查 rax 是否为 0
   jz   .zero            ; ZF=1 → rax == 0

   test rbx, 1           ; 检查最低位是否为 1（奇偶判断）
   jnz  .odd             ; 最低位为 1 → 奇数

   test al, al           ; 检查 al 是否为 0（常用于字符串处理）
   jz   .end_of_string

移位指令
=============

逻辑移位（shl / shr）
------------------------

.. code-block:: none

   ; shl: 逻辑左移（高位丢弃，低位补 0）
   ; 左移 1 位相当于乘以 2
   mov rax, 5
   shl rax, 1            ; rax = 10（5 * 2）
   shl rax, 3            ; rax = 40（10 * 8 = 5 * 16）

   ; shr: 逻辑右移（低位丢弃，高位补 0）
   ; 右移 1 位相当于无符号除以 2
   mov rax, 100
   shr rax, 1            ; rax = 50（无符号：100 / 2）
   shr rax, 2            ; rax = 12（50 / 4 = 100 / 8）

.. code-block:: none

   ; 移位计数可以是立即数或 cl 寄存器
   shl rax, 8            ; 左移 8 位（立即数）
   mov cl, 4
   shl rax, cl           ; 左移 cl 位（使用寄存器）

算术移位（sal / sar）
-------------------------

.. code-block:: none

   ; sal: 算术左移（与 shl 效果相同）
   sal rax, 1            ; = shl rax, 1

   ; sar: 算术右移（高位按符号位填充，保持有符号数的正负）
   mov rax, -100
   sar rax, 1            ; rax = -50（有符号：-100 / 2）

   ; shr 与 sar 的区别（对有符号负数）
   mov rax, -8           ; rax = 0xFFFFFFFFFFFFFFF8
   shr rax, 1            ; rax = 0x7FFFFFFFFFFFFFFC（= 很大的正数）
   mov rax, -8
   sar rax, 1            ; rax = 0xFFFFFFFFFFFFFFFC（= -4）

.. note::

   算术右移（``sar``）和逻辑右移（``shr``）对有符号负数的结果**完全不同**。
   ``sar`` 保持符号位不变，相当于有符号除以 2（向下取整）；``shr`` 在高位补 0，相当于无符号除以 2。

循环移位（rol / ror）
------------------------

循环移位将被移出的位填补到另一端的空位中，不会丢失信息：

.. code-block:: none

   ; rol: 循环左移
   mov rax, 0x8000000000000000
   rol rax, 1            ; rax = 0x0000000000000001（最高位移到最低位）

   ; ror: 循环右移
   mov rax, 0x0000000000000001
   ror rax, 1            ; rax = 0x8000000000000000（最低位移到最高位）

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 用途
   * - ``shl`` / ``sal``
     - 左移（低位补 0）
     - 乘以 2^n
   * - ``shr``
     - 逻辑右移（高位补 0）
     - 无符号除以 2^n
   * - ``sar``
     - 算术右移（高位复制符号位）
     - 有符号除以 2^n
   * - ``rol``
     - 循环左移
     - 位旋转、密码学
   * - ``ror``
     - 循环右移
     - 位旋转、密码学
