.. _chapter-03-data-movement:

=============================
数据传送指令
=============================

数据传送指令是汇编程序中最常用的一类指令，负责在寄存器、内存和立即数之间搬运数据。

``mov`` 基本数据传送
========================

``mov`` 将源操作数的值复制到目标操作数。源操作数不变。

.. code-block:: none

   ; 寄存器 ← 立即数
   mov rax, 42            ; rax = 42
   mov byte [rbx], 0x41   ; *rbx = 0x41

   ; 寄存器 ← 寄存器
   mov rbx, rax           ; rbx = rax
   mov r8, r9             ; r8 = r9（新增的 64 位寄存器）

   ; 寄存器 ← 内存
   mov rax, [var]         ; rax = *var
   mov ecx, [rsi]         ; ecx = *rsi

   ; 内存 ← 寄存器
   mov [var], rax         ; *var = rax
   mov [rdi], ebx         ; *rdi = ebx

.. warning::

   x86_64 **不允许** ``内存 → 内存`` 的直接传送。以下代码非法：

   .. code-block:: none

      mov [dst], [src]    ; ❌ 需要拆分为 reg ← mem, mem ← reg
      mov rax, [src]
      mov [dst], rax

``mov`` 的操作数大小
=======================

.. code-block:: none

   mov rax, 0x12345678         ; 64 位传送
   mov eax, 0x12345678         ; 32 位传送（隐式清零高 32 位）
   mov ax,  0x1234             ; 16 位传送
   mov al,  0x12               ;  8 位传送

   ; 操作数大小必须匹配，不能混用
   mov rax, [var64]            ; 读取 8 字节
   mov eax, [var32]            ; 读取 4 字节
   mov ax,  [var16]            ; 读取 2 字节
   mov al,  [var8]             ; 读取 1 字节

   ; 内存操作数可以用 size 修饰符明确指定
   mov dword [rbx], 42         ; 写入 4 字节
   mov qword [rbx], 42         ; 写入 8 字节
   mov word  [rbx], 42         ; 写入 2 字节

``movzx`` / ``movsx`` 带扩展的传送
======================================

将较小的源操作数传送到较大的目标，同时进行零扩展（``movzx``）或符号扩展（``movsx``）。

.. code-block:: none

   ; movzx: 零扩展（高位补 0）
   movzx rax, byte [rbx]      ; 读取 1 字节，零扩展到 64 位
   movzx eax, word [rsi]      ; 读取 2 字节，零扩展到 32 位
   movzx r8d, al              ; al → r8d，高位补 0

   ; movsx: 符号扩展（高位按符号位填充）
   movsx rax, byte [rbx]      ; 读取 1 字节，符号扩展到 64 位
   movsx eax, word [rsi]      ; 读取 2 字节，符号扩展到 32 位
   movsx rcx, al              ; al → rcx，符号扩展

   ; 不同效果对比
   mov al, 0x80                ; al = -128（有符号）
   movzx rax, al               ; rax = 0x0000000000000080（128）
   movsx rax, al               ; rax = 0xFFFFFFFFFFFFFF80（-128）

``xchg`` 交换
=================

``xchg`` 交换两个操作数的值。这是一个 :strong:`原子操作`\ （当操作数包含内存时），常用于锁的实现。

.. code-block:: none

   xchg rax, rbx        ; rax ↔ rbx
   xchg eax, ecx        ; eax ↔ ecx
   xchg [lock_var], rax ; 原子交换寄存器与内存（lock 前缀自动添加）

``lea`` 加载有效地址
=======================

``lea``\ （Load Effective Address）计算源操作数的:strong:`地址`\ （而非值）并存入目标寄存器。
它不访问内存，而是在 CPU 内部执行地址计算。

.. code-block:: none

   ; lea 与 mov 的区别
   mov rax, [rbx+rcx*8]       ; rax = *(rbx + rcx*8)——读取内存值
   lea rax, [rbx+rcx*8]       ; rax = rbx + rcx*8——计算地址

   ; lea 用于算术运算（无需额外指令）
   lea rax, [rdx + rsi]       ; rax = rdx + rsi（等同于 add）
   lea rax, [rcx + rcx*4]     ; rax = rcx * 5
   lea rax, [rbx + rcx*8]     ; rax = rbx + rcx*8

   ; lea 用于取变量地址
   lea rdi, [msg]             ; rdi = &msg

.. note::

   ``lea`` 是一个异常灵活的指令，编译器也经常用它来实现算术优化。例如 ``lea rax, [rcx + rcx*4]``
   可以在一条指令中完成 ``rax = rcx * 5`` 的乘法，比使用 ``imul`` 更快。

``push`` / ``pop`` 栈操作
===============================

详见 :ref:`chapter-02-stack` 的详细讨论，这里列出用法总结：

.. code-block:: none

   push rax              ; rsp -= 8; [rsp] = rax
   push qword [var]      ; 压入内存值
   push 42               ; 压入立即数

   pop rbx               ; rbx = [rsp]; rsp += 8
   pop dword [var]       ; 弹出到内存

数据传送指令总结
====================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 典型场景
   * - ``mov``
     - 数据复制
     - 通用数据搬运
   * - ``xchg``
     - 交换
     - 原子交换/锁
   * - ``movzx``
     - 零扩展传送
     - 无符号类型提升
   * - ``movsx``
     - 符号扩展传送
     - 有符号类型提升
   * - ``lea``
     - 加载有效地址
     - 地址计算/算术优化
   * - ``push``
     - 入栈
     - 保存寄存器/参数传递
   * - ``pop``
     - 出栈
     - 恢复寄存器
