.. _chapter-07-calling-c:

===============================
从汇编调用 C 函数
===============================

汇编程序可以调用 C 函数，只需遵循 System V AMD64 调用约定传递参数即可。这使得汇编代码可以复用 C 标准库和已有的 C 代码。

为什么要在汇编中调 C？因为 **纯汇编虽然性能极致，但开发效率低**。大部分程序适合"90% C + 10% 汇编"的混合模式：用 C 处理 I/O、内存管理、字符串处理等"脏活"，用汇编处理性能热点（算数密集循环、SIMD 向量化、系统调用包装）。

你可能会想：**从汇编调 C 函数，有什么需要注意的？** 核心就三条：

1. **按照 ABI 传参数**：第 1-6 个参数放在 ``rdi, rsi, rdx, rcx, r8, r9`` 中，多余的走栈
2. **栈必须 16 字节对齐**：调用 ``call`` 前，``rsp`` 必须是 16 的倍数。因为 ``call`` 会压入 8 字节的返回地址，所以刚进入被调用函数时栈是 8 字节对齐的——被调用者通过 ``push rbp`` 恢复 16 字节对齐
3. :strong:`调用者保存的寄存器` ：如果你在调用前占用了 ``rax``、``rcx``、``rdx``、``rsi``、``rdi``、``r8``-``r11`` 等调用者保存寄存器，记得先 ``push`` 保存

不理解这些规则的话，最常见的后果就是：printf 打印出随机数（因为参数传错了寄存器或栈没对齐导致 SIMD 指令崩溃）。

.. admonition:: 一个真实的血泪史
   :class: story

   Stack Overflow 上有一个经典问题：用户在汇编中写 ``call printf``，结果程序偶尔崩溃。
   排查了三天发现原因是 **栈没对齐**。因为 System V ABI 要求 ``call`` 前 rsp 是 16 字节对齐，
   但 ``printf`` 内部使用 ``movaps`` 指令（要求 16 字节对齐的 SIMD 加载），当 rsp 不对齐时，
   ``movaps`` 触发 ``#GP`` 异常（通用保护错误），程序直接 SIGSEGV。修复方式很简单：在 call 前
   确保 rsp ≡ 0 (mod 16)。这也是为什么许多汇编函数的序言包含 ``push rbp; mov rbp, rsp``——
   这恰好将 rsp 调整为 16 字节对齐，而不仅仅是方便访问栈帧。

声明外部符号
================

在汇编中使用 ``extern`` 关键字声明要调用的 C 函数：

.. code-block:: none

   ; 声明 C 标准库函数
   extern printf
   extern exit
   extern malloc, free

   ; 声明自定义 C 函数
   extern my_c_function

调用 printf
===============

.. code-block:: none

   ; 从汇编调用 C 的 printf
   section .data
       fmt db "The answer is: %d", 0xA, 0
       val dq 42

   section .text
       extern printf

       push rbp
       mov  rbp, rsp

       ; printf("The answer is: %d\n", 42)
       mov rdi, fmt        ; 第 1 个参数：格式字符串
       mov rsi, [val]      ; 第 2 个参数：整数值
       xor rax, rax         ; 无浮点参数（rax=0）
       call printf

       pop rbp
       ret

.. note::

   调用可变参数函数（如 ``printf``）时，必须在 ``al`` 中设置传递给函数的浮点参数的个数。
   如果没有浮点参数，设置 ``al = 0``。

调用多个参数的 C 函数
=========================

.. code-block:: c

   // C 函数定义
   long calc_sum(long a, long b, long c,
                 long d, long e, long f,
                 long g, long h) {
       return a + b + c + d + e + f + g + h;
   }

对应的汇编调用：

.. code-block:: none

       ; 按 System V ABI 传递 8 个参数
       mov rdi, 1          ; 第 1 个参数
       mov rsi, 2          ; 第 2 个参数
       mov rdx, 3          ; 第 3 个参数
       mov rcx, 4          ; 第 4 个参数
       mov r8,  5          ; 第 5 个参数
       mov r9,  6          ; 第 6 个参数
       push 8              ; 第 8 个参数（先压最后一个）
       push 7              ; 第 7 个参数
       sub rsp, 8          ; 保持 RSP 16 字节对齐（第 7 个参后多了 16 字节）
       call calc_sum       ; rax = 1+2+...+8 = 36
       add rsp, 16+8       ; 清理栈上参数 + 对齐调整

分配和释放堆内存
====================

.. code-block:: none

   ; 调用 malloc 和 free
   section .data
       err_msg db "malloc failed!", 0xA, 0

   section .text
       extern malloc, free, printf, exit

       mov rdi, 1024       ; 分配 1024 字节
       call malloc
       test rax, rax        ; 检查是否分配成功
       jz   .error

       ; 使用分配的内存（rax 中是地址）
       mov qword [rax], 42 ; *ptr = 42
       ; ...

       ; 释放内存
       mov rdi, rax
       call free

       ret

   .error:
       mov rdi, err_msg
       xor rax, rax
       call printf
       mov rdi, 1
       call exit

调用 C 标准库数学函数
=========================

.. code-block:: none

   ; 调用 sqrt 计算平方根
   section .data
       val dq 16.0
       fmt db "sqrt(%.1f) = %.1f", 0xA, 0

   section .text
       extern sqrt, printf

       push rbp
       mov  rbp, rsp

       movsd xmm0, [val]  ; 第 1 个参数（浮点数在 xmm0 中）
       call sqrt           ; xmm0 中返回结果

       ; 打印结果
       lea  rdi, [fmt]
       movsd xmm1, [val]  ; 原始值
       ; 注意：xmm0 中已经是 sqrt 结果
       ; 这里 xmm1 是原始值，xmm0 是 sqrt 结果
       ; 实际上需要先 push 重建...
       mov rax, 2          ; 2 个浮点参数
       call printf

       pop rbp
       ret

调用 C 函数时的寄存器保存
============================

调用 C 函数前，必须保存可能被 C 函数修改的**被调用者保存寄存器**（如果没有其他用途则不必保存）：

.. code-block:: none

   section .text
       extern qsort

       ; qsort 的回调函数
       compare:
           mov rax, [rdi]        ; 比较两个 long
           sub rax, [rsi]
           ret

   my_func:
       push rbx               ; 保存被调用者保存寄存器
       push r12
       push r13

       ; 调用 qsort(arr, count, size, compare)
       mov rdi, arr
       mov rsi, count
       mov rdx, 8
       mov rcx, compare
       call qsort

       pop r13
       pop r12
       pop rbx
       ret

.. note::

   ``printf`` 等 C 标准库函数会破坏 ``rax`` 及所有调用者保存寄存器
   （``rcx``、``rdx``、``rsi``、``rdi``、``r8``-``r11``）。
   如果需要保留它们，在调用前入栈保存。

与 C 代码链接
=================

.. code-block:: none

   ; asm_main.asm
   section .data
       fmt db "Result: %d", 0xA, 0

   section .text
       global asm_main
       extern calc_sum

   asm_main:
       push rbp
       mov  rbp, rsp

       mov rdi, 10
       mov rsi, 20
       call calc_sum          ; 调用外部 C 函数

       mov rsi, rax           ; 打印结果
       mov rdi, fmt
       xor rax, rax
       call printf

       pop rbp
       ret

.. code-block:: c

   // calc_sum.c
   long calc_sum(long a, long b) {
       return a + b;
   }

   // main.c
   void asm_main(void);      // 声明汇编入口

   int main(void) {
       asm_main();
       return 0;
   }

.. code-block:: bash

   # 编译和链接
   nasm -f elf64 asm_main.asm -o asm_main.o
   gcc -c calc_sum.c -o calc_sum.o
   gcc -c main.c -o main.o
   gcc asm_main.o calc_sum.o main.o -o program
   ./program

g++ 与名称修饰（扩展话题）
=============================

如果使用 :strong:`g++`\ （C++ 编译器），函数名会被:strong:`名称修饰`\ （name mangling）：

.. code-block:: cpp

   // C++ 代码
   int add(int a, int b) { return a + b; }

   // 实际的符号名被修饰为：_Z3addii

要在汇编中调用 C++ 函数，可以通过 ``extern "C"`` 禁用名称修饰：

.. code-block:: cpp

   // C++ 代码
   extern "C" int add(int a, int b) {
       return a + b;
   }

这样汇编中就可以直接用 ``call add`` 调用。

.. code-block:: none

   ; 调用 extern "C" 函数
   extern add
   mov rdi, 10
   mov rsi, 20
   call add            ; rax = 30

.. tip::

   如果你的项目使用 g++，将所有汇编可调用的 C 函数放在 ``extern "C"`` 块中。
   这样既保留了 C++ 的特性，又不影响汇编端的调用。
