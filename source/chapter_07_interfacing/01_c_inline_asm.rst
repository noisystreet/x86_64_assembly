.. _chapter-07-inline:

===============================
C 语言内联汇编
===============================

GCC 允许在 C 代码中直接嵌入汇编语句，称为内联汇编（Inline Assembly）。这在需要精确控制指令序列、访问特殊 CPU 功能，或优化关键代码段时非常有用。

**什么时候需要内联汇编？** 最常见的几个场景：

- **访问没有 C 库封装的 CPU 指令**：如 ``cpuid``（读取 CPU 信息）、``rdtsc``（高精度计时）、``bswap`` 等
- **微优化热点代码**：在已经用 ``perf`` 找到瓶颈后，用内联汇编替换掉编译器生成的不够理想的几行代码
- **实现原子操作**：在 C11 的 ``_Atomic`` 出现之前，内联汇编是实现锁和无锁数据结构的唯一方式

但也要注意：**内联汇编并不是"让代码变快"的魔法**。编译器在 ``-O3`` 下的优化常常超出你的直觉。
内联汇编会阻止编译器优化跨 asm 边界的代码，可能适得其反。核心原则是：**先用 C 写出正确代码，
profiling 证明是热点后，再考虑用内联汇编替换，且每次替换后都要重新 profiling 验证确实变快了**。

基本 asm
============

最基本的形式使用 ``asm`` 关键字，后跟括号内的汇编字符串：

.. code-block:: c

   asm("assembly_code");

.. code-block:: c

   // 最简单的内联汇编
   #include <stdio.h>

   int main(void) {
       asm("nop");              // 空操作指令
       asm("mov $42, %rax");    // 设置 rax = 42
       return 0;
   }

.. code-block:: bash

   gcc -O2 -S test.c -o test.s   # 查看生成的汇编

.. warning::

   基本 ``asm`` 中不能访问 C 变量。如果要读写 C 变量，必须使用扩展 asm。

扩展 asm
============

扩展 asm 的完整语法：

.. code-block:: none

   asm [volatile] (
       "汇编代码"
       : 输出操作数（可选）
       : 输入操作数（可选）
       : 破坏列表（可选）
   );

.. code-block:: c

   // 内联汇编计算 a + b
   #include <stdio.h>

   int main(void) {
       int a = 10, b = 20, result;

       asm (
           "addl %2, %1\n\t"      // %1 = %1 + %2
           "movl %1, %0"          // %0 = %1
           : "=r" (result)        // 输出：%0 = result（写后）
           : "r" (a), "r" (b)     // 输入：%1 = a, %2 = b
           : "cc"                 // 破坏：修改了条件码
       );

       printf("%d + %d = %d\n", a, b, result);
       return 0;
   }

操作数约束（Constraints）
============================

每个输入/输出操作数都有一个约束字符串，告诉 GCC 如何传递该值：

.. list-table::
   :header-rows: 1

   * - 约束
     - 含义
     - 示例
   * - ``r``
     - 通用寄存器
     - ``"r"(x)``
   * - ``m``
     - 内存地址
     - ``"m"(x)``
   * - ``i``
     - 立即数常量
     - ``"i"(42)``
   * - ``g``
     - 通用：寄存器、内存或立即数
     - ``"g"(x)``
   * - ``=``
     - 输出操作数（写）
     - ``"=r"(x)``
   * - ``+``
     - 输入+输出（读写）
     - ``"+r"(x)``
   * - ``&``
     - 早期破坏（不与输入共享寄存器）
     - ``"=&r"(x)``

.. code-block:: c

   // 使用 "r" 约束：通过寄存器传递
   int mul_by_two(int x) {
       int result;
       asm (
           "add %1, %1\n\t"
           "mov %1, %0"
           : "=r" (result)
           : "r" (x)
       );
       return result;
   }

   // 使用 "m" 约束：直接操作内存
   void atomic_inc(int *p) {
       asm volatile (
           "lock; incl %0"
           : "+m" (*p)           // "+" 表示读写
           :
           : "cc"
       );
   }

   // 使用 "i" 约束：立即数
   int shift_left(int x) {
       int result;
       asm (
           "shl %2, %1\n\t"
           "mov %1, %0"
           : "=r" (result)
           : "r" (x), "i" (3)    // 必须编译期常量
       );
       return result;
   }

.. note::

   ``+`` 约束表示操作数同时是输入和输出，这样就不需要单独写输入和输出各一次。
   但 ``+`` 不能用于分离的输入/输出操作数，若输入和输出是不同 C 变量，应分别写。

volatile 关键字
==================

``volatile`` 告诉编译器不要优化掉内联汇编（即使其输出看起来未被使用）：

.. code-block:: c

   // 没有 volatile——编译器可能删除这个 asm
   asm("nop");

   // 有 volatile——强制保留
   asm volatile("nop");

   // 有副作用的操作必须加 volatile
   asm volatile("lock; xchg %0, %1"
                : "+r" (val), "+m" (*lock));

GAS 语法在内联汇编中的使用
=============================

GCC 的内联汇编使用 **GAS（AT&T）语法**，而非 NASM 语法。本书前几章使用 NASM 讲解，但在 C 内联汇编中，必须使用 AT&T 语法。

.. list-table:: NASM vs AT&T 在内联汇编中的关键区别
   :header-rows: 1

   * - 特性
     - NASM
     - AT&T（内联汇编）
   * - 操作数顺序
     - ``mov dst, src``
     - ``mov %src, %dst``
   * - 寄存器前缀
     - ``rax``
     - ``%%rax``
   * - 立即数前缀
     - ``42``
     - ``$42``
   * - 内存引用
     - ``[rax]``
     - ``(%rax)``
   * - 操作数引用
     - ``%0``, ``%1``
     - ``%0``, ``%1``

.. code-block:: c

   // 在内联汇编中引用操作数
   int x = 10, y;
   asm ("movl %1, %0\n\t"
        "addl $1, %0"
        : "=r" (y)
        : "r" (x));
   // y = x + 1

.. note::

   在内联汇编字符串中，寄存器需要写为 ``%%rax``（双百分号），因为单个 ``%`` 被用作操作数占位符（``%0``、``%1`` 等）。在宏中使用时也需要转义。

破坏列表（Clobbers）
=======================

破坏列表告诉 GCC 内联汇编会破坏哪些寄存器，让 GCC 在必要的时候保存和恢复它们。

.. code-block:: c

   // 通知 GCC 我们修改了 rax, rcx, rdx 和内存
   asm volatile (
       "mov $1, %%rax\n\t"
       "mov $2, %%rcx\n\t"
       "mov $3, %%rdx\n\t"
       :
       :
       : "rax", "rcx", "rdx", "memory"
   );

常见破坏列表：

.. list-table::
   :header-rows: 1

   * - 约束
     - 含义
   * - ``"rax"``
     - 破坏了寄存器
   * - ``"memory"``
     - 修改了内存（阻止 GCC 缓存内存值）
   * - ``"cc"``
     - 修改了条件码寄存器标志位

寄存器变量
==============

GCC 允许将局部变量绑定到指定寄存器：

.. code-block:: c

   register int counter asm("r12") = 0;  // counter 固定在 r12

   // 在内联汇编中使用
   asm volatile ("addl $1, %0" : "+r" (counter));

.. warning::

   寄存器变量只是向 GCC 发出**建议**，不保证一定会被分配到指定寄存器。
   只有在 ``-O2`` 以上优化级别或使用 ``__attribute__((used))`` 时更可靠。

通过内联汇编调用 Linux 系统调用
==================================

.. code-block:: c

   // 使用内联汇编实现 sys_exit
   static inline void sys_exit(int code) {
       asm volatile (
           "mov %0, %%rdi\n\t"
           "mov $60, %%rax\n\t"
           "syscall"
           :
           : "r" (code)
           : "rax", "rdi", "rcx", "r11"
       );
   }

   // 使用内联汇编实现 sys_write
   static inline long sys_write(int fd, const void *buf, size_t count) {
       long ret;
       asm volatile (
           "mov %1, %%rdi\n\t"
           "mov %2, %%rsi\n\t"
           "mov %3, %%rdx\n\t"
           "mov $1, %%rax\n\t"
           "syscall\n\t"
           "mov %%rax, %0"
           : "=r" (ret)
           : "r" (fd), "r" (buf), "r" (count)
           : "rax", "rdi", "rsi", "rdx", "rcx", "r11"
       );
       return ret;
   }
