.. _chapter-04-recursion:

===============================
递归
===============================

递归（Recursion）是指函数直接或间接调用自身。在汇编中实现递归需要理解栈帧的增长规律，
以及对被调用者保存寄存器的正确处理。

阶乘示例
============

.. code-block:: none

   ; factorial(n) = n * factorial(n-1), 其中 factorial(1) = 1
   ; 参数：rdi = n
   ; 返回：rax = n!
   factorial:
       push rbp
       mov  rbp, rsp

       cmp rdi, 1
       jle .base_case      ; n <= 1 时返回 1

       ; 递归情况：n * factorial(n-1)
       push rdi            ; 保存当前 n（被调用者保存）
       dec  rdi            ; n - 1
       call factorial      ; rax = factorial(n-1)
       pop  rdi            ; 恢复 n
       mul  rdi            ; rax = rax * n = factorial(n-1) * n
       jmp  .done

   .base_case:
       mov  rax, 1

   .done:
       pop  rbp
       ret

.. mermaid::

   flowchart TD
       F5[factorial 5 栈帧 n=5] --> F4[factorial 4 栈帧 n=4]
       F4 --> F3[factorial 3 栈帧 n=3]
       F3 --> F2[factorial 2 栈帧 n=2]
       F2 --> F1[factorial 1 栈帧 base case]

   ↑ 递归深度为 5，消耗约 5 × 32 = 160 字节栈空间

斐波那契数列
================

.. code-block:: none

   ; fib(n) = fib(n-1) + fib(n-2), 其中 fib(0)=0, fib(1)=1
   ; 参数：rdi = n
   ; 返回：rax = fib(n)
   fib:
       push rbp
       mov  rbp, rsp
       push rbx            ; 保存 rbx（被调用者保存）

       cmp rdi, 1
       jle .base_case      ; n <= 1 时返回 n

       ; 递归 fib(n-1)
       mov rbx, rdi        ; 保存 n
       dec rdi             ; n - 1
       call fib            ; rax = fib(n-1)

       ; 递归 fib(n-2)
       mov rdi, rbx
       sub rdi, 2          ; n - 2
       push rax            ; 保存 fib(n-1) 结果
       call fib            ; rax = fib(n-2)
       pop rdx             ; rdx = fib(n-1)

       add rax, rdx        ; rax = fib(n-1) + fib(n-2)
       jmp .done

   .base_case:
       mov rax, rdi        ; n <= 1 时 fib(n) = n

   .done:
       pop rbx
       pop rbp
       ret

.. warning::

   上述朴素递归实现的斐波那契效率极低（指数级时间复杂度，存在大量重复计算）。
   计算 ``fib(40)`` 可能需要数十亿次递归调用，会很快耗尽栈空间。

尾递归优化
==============

尾递归（Tail Recursion）是指递归调用是函数的最后一条指令。如果递归调用后直接返回结果（不再有额外操作），
编译器或汇编程序员可以将其优化为循环，避免栈帧增长。

.. code-block:: none

   ; 阶乘的尾递归版本（使用累加器）
   ; factorial_tail(n, acc) = factorial_tail(n-1, n*acc)
   ;                      factorial_tail(1, acc) = acc
   ; 参数：rdi = n, rsi = acc
   ; 返回：rax = n!
   factorial_tail:
       cmp rdi, 1
       jle .base_case

       ; 更新参数并跳回（无需 call，避免压栈）
       mul  rsi, rdi       ; acc = acc * n
       dec  rdi            ; n = n - 1
       jmp  factorial_tail ; 尾递归 → 等效于循环

   .base_case:
       mov  rax, rsi       ; 返回 acc
       ret

   ; 调用入口
   factorial:
       push rbp
       mov  rbp, rsp
       mov  rsi, 1         ; acc = 1
       call factorial_tail
       pop rbp
       ret

.. note::

   尾递归优化把递归变成了循环，**不消耗额外栈空间**。GCC 在 ``-O2`` 以上优化级别会自动将尾递归转换为循环。
   在编写汇编时，如果函数的最后一步是 ``call`` 后立即 ``ret``，可以改为 ``jmp`` 来手动实现这个优化。

递归 vs 迭代对比
====================

.. list-table::
   :header-rows: 1

   * - 维度
     - 递归
     - 迭代（循环）
   * - 栈空间
     - O(n)，深度限制
     - O(1)
   * - 代码简洁性
     - 表达自然，逻辑清晰
     - 需手动维护状态
   * - 性能
     - 函数调用有额外开销
     - 无调用开销
   * - 适用场景
     - 树、图遍历，分治算法
     - 线性重复操作

.. code-block:: none

   ; 阶乘的迭代版本（等效循环）
   factorial_iter:
       mov  rax, 1         ; result = 1
   .loop:
       cmp  rdi, 1
       jle  .done
       mul  rdi            ; result *= n
       dec  rdi            ; n--
       jmp  .loop
   .done:
       ret

   递归深度限制
   ================

   Linux 默认栈大小为 8 MB。每条递归调用消耗约 32\~64 字节栈空间。
   因此直接递归深度通常限制在约 **10 万到 20 万层**。
   实际编程中，深度超过几千层的递归都应考虑改用迭代或尾递归。

   .. code-block:: bash

      # 查看当前栈大小限制
      ulimit -s

      # 临时增大限制（单位 KB）
      ulimit -s 65536   # 64 MB

练习题
========

1. 实现汇编版阶乘 ``factorial(n)``，在 ``main`` 中调用并输出结果。
   验证 ``factorial(5) = 120``，``factorial(10) = 3628800``。

2. 将阶乘改写为尾递归版本，比较两种版本的汇编代码长度和执行效率。

3. 实现斐波那契数列的迭代版本，与文中朴素递归版本对比性能差异。
   尝试计算 ``fib(40)``，记录两种方式的耗时。

4. 编写一个递归的二分查找函数，参数为有序数组地址、左右索引和目标值，
   返回匹配位置的索引或 -1。

5. 用 System V 调用约定编写函数 ``gcd`` （最大公约数，欧几里得算法），
   分别用递归和迭代两种方式实现。
