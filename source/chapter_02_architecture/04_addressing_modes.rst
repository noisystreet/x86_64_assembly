.. _chapter-02-addressing-modes:

===============================
寻址方式
===============================

寻址方式决定了指令如何指定操作数的位置。x86_64 提供了多种寻址方式，灵活组合寄存器和内存引用。

.. code-block:: none

   ; 通用格式：mov 目标, 源
   ; 汇编器会解析操作数中的各种寻址模式

立即数寻址
==============

操作数直接编码在指令中，以常量形式给出：

.. code-block:: none

   mov rax, 42          ; rax = 42
   mov rbx, 0x1000     ; rbx = 4096
   mov rcx, 'A'        ; rcx = 65（ASCII 'A'）
   add rax, 1          ; rax = rax + 1

寄存器寻址
==============

操作数位于寄存器中，指令直接操作寄存器：

.. code-block:: none

   mov rax, rbx        ; rax = rbx
   add rcx, rdx        ; rcx = rcx + rdx
   xor rax, rax        ; rax = 0（常见清零惯用法）
   inc r8              ; r8 = r8 + 1

直接内存寻址
================

操作数位于内存中，地址通过符号标号指定：

.. code-block:: none

   section .data
       var dq 42

   section .text
       mov rax, [var]      ; rax = 内存中 var 处的值
       mov [var], rbx      ; 将 rbx 写入 var
       add rax, [var]      ; rax += *var

寄存器间接寻址
===================

地址存放在寄存器中（类似指针解引用）：

.. code-block:: none

   mov rax, [rbx]       ; rax = 内存中 rbx 指向的值
   mov [rsi], rax       ; 将 rax 写入 rsi 指向的地址
   add rcx, [rdx]      ; rcx += *rdx

基址+变址寻址
=================

地址由 ``[基址 + 变址 * 比例 + 偏移]`` 计算，常用于遍历数组或结构体：

.. code-block:: none

   ; 格式： [base + index * scale + displacement]
   ; 其中 scale 只能是 1, 2, 4, 8

   ; 数组遍历
   mov rax, [rbx + rcx*8]       ; rax = arr[rcx]（64 位数组）
   mov eax, [rbx + rcx*4]       ; eax = arr[rcx]（32 位数组）
   mov ax,  [rbx + rcx*2]       ; ax  = arr[rcx]（16 位数组）

   ; 结构体成员访问
   mov rax, [rbx + rcx*8 + 16]  ; rax = arr[rcx].field_at_offset_16

   ; 多个变体
   mov rax, [rbx + 8]           ; 基址 + 偏移
   mov rax, [rbx + rcx]         ; 基址 + 变址
   mov rax, [rbx + rcx*4 + 32]  ; 基址 + 变址*比例 + 偏移

RIP 相对寻址
=================

x86_64 特有的寻址方式，地址相对于当前指令指针（rip）计算。这是 64 位模式下访问全局数据最常用的方式：

.. code-block:: none

   ; 汇编器通常自动使用 RIP 相对寻址
   section .data
       msg db 'Hello', 0

   section .text
       mov rax, [msg]       ; 汇编器自动转为 [rip + msg]
       lea rsi, [rip + msg] ; 获取 msg 的地址（RIP 相对）

   ; 手动使用 RIP 相对
       lea rsi, [rip + msg]

.. note::

   在 x86_64 中，64 位立即数地址无法直接编码到指令中。RIP 相对寻址通过 32 位偏移量就能访问整个地址空间中的任何符号，
   使指令编码更紧凑，同时也支持位置无关代码（PIC，Position-Independent Code）。

各种寻址方式对比
====================

.. list-table::
   :header-rows: 1

   * - 类型
     - 格式
     - 示例
     - 说明
   * - 立即数
     - ``imm``
     - ``mov rax, 42``
     - 常量操作数
   * - 寄存器
     - ``reg``
     - ``mov rax, rbx``
     - 寄存器操作数
   * - 直接内存
     - ``[addr]``
     - ``mov rax, [var]``
     - 静态地址
   * - 寄存器间接
     - ``[reg]``
     - ``mov rax, [rbx]``
     - 指针解引用
   * - 基址+偏移
     - ``[reg + disp]``
     - ``mov rax, [rbx+8]``
     - 结构体字段
   * - 基址+变址
     - ``[reg + reg]``
     - ``mov rax, [rbx+rcx]``
     - 数组/指针
   * - 比例变址
     - ``[reg + reg*scale]``
     - ``mov rax, [rbx+rcx*8]``
     - 数组元素
   * - 比例变址+偏移
     - ``[reg + reg*scale + disp]``
     - ``mov rax, [rbx+rcx*8+4]``
     - 一般情况
   * - RIP 相对
     - ``[rip + disp]``
     - ``mov rax, [rip + msg]``
     - PIC 代码（默认）

.. warning::

   在 x86_64 中，:strong:`不能` 直接将两个内存操作数用于一条指令。例如：

   .. code-block:: none

      mov [dst], [src]   ; ❌ 非法——不能 mem→mem
      mov rax, [src]     ; ✅ 先加载到寄存器
      mov [dst], rax     ; ✅ 再写回内存
