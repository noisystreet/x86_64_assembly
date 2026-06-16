.. _chapter-03-logical:

=============================
逻辑运算与移位指令
=============================

逻辑运算指令对操作数进行按位操作，移位指令则对操作数的位进行左移或右移。

位运算是底层编程的"瑞士军刀"——单个指令就可以完成高级语言中数行代码才能做到的事情。
例如，用一条 ``and`` 就可以掩码提取一个字节的某几位，用 ``xor rax, rax`` 清零寄存器
（比 ``mov rax, 0`` 更快、编码更短）。理解位运算不仅对汇编编程重要，在 C 的系统编程、网络协议解析、
图形学、密码学中也无处不在。

``xor`` 清零为什么比 ``mov`` 好？
------------------------------------

- ``xor rax, rax`` 编码 3 字节，``mov rax, 0`` 编码 7 字节
- 现代 CPU 会对 ``xor`` 做**寄存器重命名** （register renaming），不依赖之前的 rax 值，
  所以不需要等待前面指令写完 rax 就能开始执行——这消除了数据依赖
- 因此 ``xor rax, rax`` 不仅是字节短，在 CPU 内部执行路径也更短

.. admonition:: ``xor rax, rax``：从惯用法到零周期指令
   :class: story

   这个 "xor 清零" 的惯用法最早出现在 8086 时代，当时它比 ``mov ax, 0`` 短 2 字节（2 字节 vs 4 字节），
   对 ROM 和 RAM 都极其有限的市场意义重大。到了 Pentium Pro 时代，Intel 的工程师注意到
   几乎所有的代码都使用 ``xor`` 而非 ``mov`` 清零，于是在硬件层面做了特殊优化：
   CPU 的寄存器重命名模块**识别出这种模式后，直接为 rax 分配一个零值专用物理寄存器** ，
   不消耗任何执行单元。这就是所谓的"零周期清零"（zero-idiom）——``xor rax, rax`` 
   在现代 CPU 上执行时间为 0 个周期，因为它根本不进入执行流水线。

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

   ; 检查多个标志位
   test al, 0b00000111   ; 检查低 3 位是否有任意 1
   jnz  .any_set

.. note::

   ``test`` 和 ``cmp`` 的区别：``test a, b`` 执行 ``a & b`` 并设置 ZF/SF（相当于 ``and`` 但不写回结果），
   而 ``cmp a, b`` 执行 ``a - b`` 并设置 ZF/SF/CF/OF。``test`` 用于检查位模式，``cmp`` 用于数值比较。

位运算常见模式
=================

.. code-block:: none

   ; 模式 1：掩码提取（提取低 4 位）
   and rax, 0x0F          ; 只保留低 4 位，其余清零

   ; 模式 2：设置某位（置 1）
   or rax, 0x08           ; 设置第 3 位（不改变其他位）

   ; 模式 3：清除某位（置 0）
   and rax, ~0x08         ; 清除第 3 位（NASM 支持编译期 ~ 运算符）

   ; 模式 4：翻转某位
   xor rax, 0x08          ; 第 3 位取反（0→1, 1→0）

   ; 模式 5：检查寄存器是否为零（影响 ZF）
   test rax, rax
   jz   .zero             ; 等价于 cmp rax, 0

   ; 模式 6：对齐到 16 字节
   add rax, 15
   and rax, ~15           ; 向下对齐到 16 的倍数

   ; 模式 7：2 的幂次判断
   test rax, rax
   jz   .not_power_of_two ; 0 不是 2 的幂
   mov rbx, rax
   sub rbx, 1
   test rax, rbx
   jz   .is_power_of_two  ; (n & (n-1)) == 0 → n 是 2 的幂

.. caution::

   位运算是汇编程序员最强大的工具之一，但也最容易引入隐蔽 bug。常见陷阱包括：

   - **运算符优先级混淆**：比如想检查第 3 位，写 ``test rax, 0x08`` 是对的，
     但写 ``and rax, 0x08`` 会 **改变 rax 的值**。用 ``test`` 只检查不修改。
   - **符号位处理**：右移负数时，逻辑右移 (``shr``) 和算术右移 (``sar``) 结果不同。
   - **位宽不匹配**：``and eax, 0xFFFF`` 清零高 16 位（且因 32 位操作自动清零高 32 位），
     ``and rax, 0xFFFF`` 则保留高 48 位。两种写法行为完全不同。

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

位扫描指令（BSF / BSR / POPCNT）
=====================================

位扫描指令用于查找位位置和统计位数：

.. code-block:: none

   ; bsf: 向前扫描（从低位到高位），找到第一个 1 的位置
   mov rax, 0x1000               ; rax = 0000 0000 0000 1000 0000...
   bsf rbx, rax                  ; rbx = 12（第 12 位是第一个 1）
   jz  .zero                     ; 如果没有 1（ZF=1），跳转

   ; bsr: 向后扫描（从高位到低位），找到最后一个 1 的位置
   mov rax, 0x1010               ; 二进制：...0001 0000 0001 0000
   bsr rcx, rax                  ; rcx = 12（两个 1 中最高位的位置）

   ; popcnt: 统计 1 的个数（需要 SSE4.2 支持）
   mov rax, 0xFF                 ; 8 个 1
   popcnt rbx, rax               ; rbx = 8
   popcnt rcx, qword [mask]      ; 统计内存中的 1 位数

   ; tzcnt: 尾随零计数（Haswell+，与 BSF 不同之处在于对 0 的处理）
   mov rax, 0x1000
   tzcnt rbx, rax                ; rbx = 12（与 BSF 相同）
   ; tzcnt 对 0 输入返回操作数大小，而 BSF 设置 ZF=1 且结果未定义

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 性能
     - 需要
   * - ``bsf``
     - 向前扫描第一个 1
     - 1-3 周期
     - 所有 x86_64
   * - ``bsr``
     - 向后扫描最后一个 1
     - 1-3 周期
     - 所有 x86_64
   * - ``popcnt``
     - 统计 1 的个数
     - 1 周期
     - SSE4.2（Nehalem+）
   * - ``tzcnt``
     - 尾随零计数
     - 1 周期
     - Haswell+
   * - ``lzcnt``
     - 前导零计数
     - 1 周期
     - Haswell+
