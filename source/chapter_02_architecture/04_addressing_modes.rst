.. _chapter-02-addressing-modes:

===============================
寻址方式
===============================

寻址方式决定了指令如何指定操作数的位置。x86_64 提供了多种寻址方式，灵活组合寄存器和内存引用。

如果说寄存器是 CPU 的"随身工具盒"，内存就是"大仓库"。不同的寻址方式好比不同的取货方式：有时直接把工具拿在手里（寄存器寻址），有时要去仓库的固定位置拿（直接内存寻址），有时得先查一个地址再去拿（寄存器间接寻址），还有时要根据索引计算位置再去拿（基址+变址寻址）。

面对这么多种寻址方式，新手最常问的问题是：**我该用哪一种？** 答案是：取决于你的数据在哪里、访问模式是什么。以下逐一讲解每种方式，并在末尾给出场景选择指南。

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

寻址方式选择指南
====================

选择合适的寻址方式可以让代码更简洁、更高效：

.. list-table::
   :header-rows: 1

   * - 场景
     - 推荐寻址方式
     - 示例
     - 理由
   * - 访问全局变量
     - RIP 相对
     - ``mov rax, [global_var]``
     - 自动生成 PIC 代码，编码紧凑
   * - 指针解引用
     - 寄存器间接
     - ``mov rax, [rbx]``
     - 直接通过指针访问
   * - 遍历数组
     - 基址+变址*比例
     - ``mov rax, [arr + rcx*8]``
     - 不修改基址指针，仅变索引
   * - 访问结构体字段
     - 基址+偏移
     - ``mov eax, [rdi + 8]``
     - 结构体指针+字段偏移
   * - 遍历结构体数组
     - 基址+变址*比例+偏移
     - ``mov rax, [rbx + rcx*32 + 8]``
     - 同时处理索引和字段偏移
   * - 大量常数操作
     - 立即数
     - ``mov rax, 100``
     - 不在内存/寄存器中占用空间
   * - 指针递增遍历
     - 寄存器间接（自增）
     - ``add rsi, 8; mov rax, [rsi]``
     - 计算地址的代价分摊到每次迭代
   * - 查表（switch/case）
     - 基址+变址*比例
     - ``jmp [.jumptable + rax*8]``
     - 一次计算即可跳转到目标

LEA（加载有效地址）的特殊用途
=================================

``lea``（Load Effective Address）计算内存操作数的地址并将结果存入寄存器。
虽然名字叫"加载地址"，但 ``lea`` 并不访问内存——它只做**地址计算**：

.. code-block:: none

   ; lea 的常见用途

   ; 1. 代替 add/mul 做算术（比 imul 更快）
   lea rax, [rbx + rcx]     ; rax = rbx + rcx（2 周期延迟）
   ; vs:  mov rax, rbx; add rax, rcx（需 2 条指令）

   lea rax, [rbx + rbx*4]   ; rax = rbx * 5（1 周期延迟）
   ; vs:  imul rax, rbx, 5（3 周期延迟）

   lea rax, [rbx + rcx*8]   ; rax = rbx + rcx*8

   ; 2. 获取标号地址（RIP 相对）
   lea rsi, [rip + msg]     ; rsi = msg 的地址（位置无关）

   ; 3. 双指针算术
   lea rax, [rsi + rdi]     ; rax = rsi + rdi（同时使用两个基址寄存器）

   ; 4. 计算数组元素的地址
   lea rsi, [arr + rcx*4]   ; rsi = &arr[rcx]（32 位元素数组）
   mov eax, [rsi]            ; 读取元素

.. note::

   ``lea`` 不设置任何标志位（不像 ``add`` 会影响 ZF/SF/CF/OF）。
   它也不访问内存——尽管使用内存操作数语法。这是 ``lea`` 独特的"零副作用"算术能力：
   可以在不干扰标志位的情况下做加法/乘法，这在需要同时维护循环计数和累加结果时非常有用。
