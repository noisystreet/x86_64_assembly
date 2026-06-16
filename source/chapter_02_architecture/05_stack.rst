.. _chapter-02-stack:

===============================
栈
===============================

栈（Stack）是一种 "后进先出"（LIFO, Last-In-First-Out）的数据结构，在程序运行中扮演着核心角色：
保存局部变量、传递函数参数、管理函数调用和返回。

栈的工作原理
================

栈在内存中从高地址向低地址增长（向下增长）。``rsp`` 寄存器始终指向栈顶（当前栈的最低地址）。

.. mermaid::

   flowchart TD
       subgraph Stack[栈内存]
           Top[← rsp 栈顶 低地址] --> Used[已占用的栈空间]
           Used --> Recent[最新 push 的数据]
           Recent --> Older[次新数据]
           Older --> More[...]
           More --> Bottom[← rbp 栈底 高地址]
       end

push / pop 指令
===================

``push`` 入栈
------------------

1. ``rsp`` 减去操作数的大小（64 位模式下减 8）
2. 将操作数写入新的 ``rsp`` 位置

``pop`` 出栈
-----------------

1. 从 ``rsp`` 指向的位置读取数据到目标寄存器
2. ``rsp`` 加上操作数的大小（64 位模式下加 8）

.. code-block:: none

   ; 基本入栈出栈
   section .text
       mov rax, 42
       push rax           ; rsp -= 8; [rsp] = 42
       mov rax, 100
       pop  rbx           ; rbx = [rsp]; rsp += 8
       ; 最终: rax=100, rbx=42, 栈恢复原状

   ; 保存和恢复寄存器
   push rax               ; 保存 rax
   push rcx               ; 保存 rcx
   ; ... 中间代码可以自由使用 rax 和 rcx ...
   pop rcx                ; 恢复 rcx
   pop rax                ; 恢复 rax（注意出栈顺序与入栈相反！）

.. code-block:: none

   ; push/pop 的其他操作数大小
   push rax               ; 64 位（rsp -= 8）
   push eax               ; 64 位（x86_64 下 push imm32 实际是 64 位）
   push word 0x1234       ; 16 位（rsp -= 2，不常见）

   pop  rbx               ; 64 位
   pop  bx                ; 16 位
   pop  r8                ; 64 位

rsp 寄存器
==============

``rsp`` 是 **栈指针寄存器**，必须始终保持有效。错误修改 ``rsp`` 会导致程序崩溃。

.. code-block:: none

   ; 直接修改 rsp 来分配栈空间
   sub rsp, 32            ; 在栈上分配 32 字节
   ; ... 使用 [rsp]、[rsp+8] 等访问 ...
   add rsp, 32            ; 恢复栈

   ; 使用 lea 管理栈帧
   push rbp
   mov rbp, rsp           ; rbp 指向旧的栈顶
   sub rsp, 64            ; 分配 64 字节局部空间

.. warning::

   ``rsp`` 必须始终保持 :strong:`16 字节对齐`\ （即 ``rsp`` 应能被 16 整除），这是 System V AMD64 ABI 的要求。
   在调用 ``call`` 指令时，CPU 会自动压入 8 字节的返回地址，因此进入被调用函数时，``rsp`` 会变成 8 的倍数而非 16 的倍数——这正是为什么通常需要 ``push rbp``\ （再压 8 字节）来恢复对齐。

栈帧
========

栈帧是函数在栈上分配的一块区域，用于存储局部变量、保存的寄存器和函数参数：

.. code-block:: none

   ; 典型栈帧布局
   ; ┌──────────────────────┐
   ; │     参数 N           │  ← rbp + 16 + N*8
   ; │     ...              │
   ; │     参数 1           │  ← rbp + 16
   ; │     返回地址          │  ← rbp + 8
   ; ├──────────────────────┤
   ; │     保存的 rbp        │  ← rbp (基址指针)
   ; ├──────────────────────┤
   ; │     局部变量 1        │  ← rbp - 8
   ; │     局部变量 2        │  ← rbp - 16
   ; │     ...              │
   ; │     局部变量 N        │  ← rsp
   ; └──────────────────────┘

.. code-block:: none

   ; 完整栈帧示例
   my_function:
       push rbp            ; 保存调用者的 rbp
       mov  rbp, rsp       ; 设置当前栈帧基址
       sub  rsp, 32        ; 分配 32 字节局部变量空间

       ; 使用局部变量
       mov  dword [rbp-4], 10      ; int local1 = 10
       mov  dword [rbp-8], 20      ; int local2 = 20

       ; 函数体...

       mov  rsp, rbp       ; 撤销局部变量空间
       pop  rbp            ; 恢复调用者的 rbp
       ret                 ; 返回

栈溢出（Stack Overflow）
==========================

栈的大小是有限的（通常为 8 MB，可通过 ``ulimit -s`` 查看）。如果递归过深或分配过大的局部变量，
会导致栈溢出，程序崩溃：

.. code-block:: none

   ; 有问题的递归——没有终止条件的 factorial
   factorial:
       push rbp
       mov  rbp, rsp
       sub  rsp, 16

       ; ... 递归体 ...

       ; 没有 base case 或递归太深
       call factorial       ; 每调用一次消耗 ~32 字节栈空间
                            ; 最终耗尽栈空间

   ; 避免栈溢出的常见方法：
   ; 1. 确保递归有终止条件
   ; 2. 用迭代替代深度递归
   ; 3. 增大栈空间（ulimit -s 或链接器选项）
   ; 4. 使用堆分配（mmap）替代过大的局部数组

.. note::

   Linux 使用 "guard page" 机制检测栈溢出。当程序触及 guard page 时会触发 ``SIGSEGV`` 信号，
   操作系统会尝试自动扩展栈空间。如果已到上限，程序就会崩溃。

   ``ulimit -s`` 可以查看和修改栈大小限制（单位 KB）：
   
   .. code-block:: bash
   
      ulimit -s          # 查看当前栈大小限制（默认 8192 KB）
      ulimit -s 16384    # 增大到 16 MB（需要 root 权限或 soft 设置）
