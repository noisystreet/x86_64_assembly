.. _chapter-03-data-movement:

=============================
数据传送指令
=============================

数据传送指令是汇编程序中最常用的一类指令，负责在寄存器、内存和立即数之间搬运数据。如果把 CPU 比作一个工厂，数据传送指令就是"传送带"——把原材料（数据）送到加工工位（ALU、FPU 等）并运走成品。

三个最重要的直觉
====================

学习数据传送时，建立以下直觉对后续编程极有帮助：

1. **寄存器是 CPU 内部最快的存储**，但数量极其有限（16 个通用寄存器 + 16 个 XMM 寄存器）。
   绝大多数指令的操作数必须是寄存器或立即数——不能直接从内存到内存。

2. **x86_64 是 load-store 混合架构**：它既允许 `[mem]` 作为算术指令的操作数（不像 RISC 那样严格区分
   load/store），但 ``mov [dst], [src]`` 这种 mem→mem 直接传送是不允许的。

3. **32 位寄存器操作隐式清零高 32 位**：这是 x86_64 的一个重要细节——向 ``eax`` 写入会自动将
   ``rax`` 的高 32 位置零。这意味着 ``mov eax, 1`` 不仅设置低 32 位为 1，还把高 32 位清零了。
   而 8/16 位写入（如 ``mov al, 1``）**不会**清零高 56 位。这个不对称行为是许多隐蔽 bug 的来源。

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

.. admonition:: 为什么 x86 不允许 mem→mem？
   :class: story

   这其实是 x86 从 CISC 向 RISC 理念靠拢的一个体现。早期 x86（8086）允许很多内存操作数组合，
   但现代 CPU 内部已经变成了"类 RISC"设计：指令先被译码成 µop，再发送到执行单元。
   允许 ``mov [dst], [src]`` 意味着译码器需要为一条汇编指令生成两条 µop（一条 load、一条 store），
   增加了复杂度。更关键的是，**寄存器是 CPU 内部最快的存储**，强制先加载到寄存器再写回，
   保持了设计的一致性。其他架构如 ARM 和 RISC-V 也采用了相同的设计哲学。

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

常见用法模式
================

.. code-block:: none

   ; 模式 1：复制内存块（用 rep movsb）
   ; 对应 C: memcpy(dst, src, n)
       cld                    ; 确保方向标志为 0（地址递增）
       mov rdi, dst
       mov rsi, src
       mov rcx, n
       rep movsb              ; 硬件加速的块复制

   ; 模式 2：寄存器清零
       xor rax, rax           ; ✅ 推荐（3 字节，CPU 零消除优化）
       mov rax, 0             ; ❌ 不推荐（7 字节，无优化）

   ; 模式 3：32 位清零高 32 位
       mov eax, ebx           ; 清零 rax 高 32 位 + 复制
       ; 等效于：mov rax, rbx（但编码更短）

   ; 模式 4：指针解引用 + 偏移
       mov eax, [rdi + 16]    ; 读取结构体第 3 个 int 字段

   ; 模式 5：符号扩展后运算
       movsx rax, word [rsi]  ; 将 16 位有符号整数扩展到 64 位
       add rax, rdx

   ; 模式 6：栈上临时变量
       sub rsp, 16            ; 分配 16 字节栈空间
       mov [rsp], rax         ; 保存临时值
       mov [rsp + 8], rbx
       ; ... 使用临时值 ...
       add rsp, 16            ; 释放

.. caution::

   一个新手常见错误是混淆了 ``mov rax, [var]`` 和 ``mov rax, var``。
   前者加载 :strong:`地址 var 处的值`，后者加载 :strong:`var 的地址本身` （相当于 ``lea rax, [var]``）。
   在高版本 NASM 中，``mov rax, var`` 会被解释为立即数加载，行为可能出乎预期。

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
