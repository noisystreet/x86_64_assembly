.. _chapter-04-stack-frames:

===============================
栈帧
===============================

栈帧（Stack Frame）是函数在栈上分配的一块内存区域，用于存储局部变量、保存的寄存器和函数参数。
栈帧通常由 ``rbp``\ （基址指针）和 ``rsp``\ （栈指针）共同界定。

为什么需要栈帧？**因为我们写的函数不是孤立运行的。** 函数 A 调用函数 B，B 调用 C……每个函数都有自己的局部变量，都需要工作空间。如果 A 和 B 都使用同一个栈空间来存局部变量，就会互相覆盖。栈帧的作用就是 **给每个函数划分一个独立的"工作区"**，互不干扰。

更具体地说，栈帧解决了三个问题：

1. **局部变量的存储**：函数的局部变量放在栈帧中，退出函数时自动释放（无需像堆内存那样手动 ``free``）
2. **保存调用者的现场**：被调用者保存的寄存器（``rbx``、``rbp``、``r12``-``r15``）在修改前被 ``push`` 到栈帧，返回前 ``pop`` 恢复
3. **栈回溯（Stack Unwinding）**：通过栈帧链（``rbp`` 链），调试器和异常处理机制可以回溯调用栈——这就是 ``gdb`` 中 ``backtrace`` 命令的工作原理

函数序言与尾声
==================

每个函数通常以序言（Prologue）开始、以尾声（Epilogue）结束。

.. code-block:: none

   ; 标准函数序言
   my_function:
       push rbp           ; 保存调用者的 rbp
       mov  rbp, rsp      ; 设置当前函数的基址
       sub  rsp, N        ; 分配 N 字节局部变量空间
       ; ...
       ; 函数体
       ; ...
       mov  rsp, rbp      ; 撤销局部变量空间（函数尾声开始）
       pop  rbp           ; 恢复调用者的 rbp
       ret                ; 返回

.. mermaid::

   flowchart TD
       subgraph Frame[栈帧布局 从高地址到低地址]
           Arg[调用者参数] --> Ret[返回地址]
           Ret --> SavedRBP[保存的 rbp]
           SavedRBP --> Local1[局部变量 1]
           Local1 --> Local2[局部变量 ...]
           Local2 --> LocalN[局部变量 N]
       end

局部变量的访问
==================

局部变量通过 ``rbp`` 加上负偏移量访问：

.. code-block:: none

   ; 在栈上分配 3 个局部变量
   my_func:
       push rbp
       mov  rbp, rsp
       sub  rsp, 32           ; 分配 32 字节

       ; int a = 10;
       mov dword [rbp-4], 10

       ; int b = 20;
       mov dword [rbp-8], 20

       ; long c = 100;
       mov qword [rbp-16], 100

       ; 使用局部变量
       mov eax, [rbp-4]
       add eax, [rbp-8]
       ; eax = a + b

       ; 函数尾声...
       mov rsp, rbp
       pop rbp
       ret

省略帧指针优化
==================

现代编译器常用 ``-fomit-frame-pointer`` 优化，省略 ``rbp`` 的使用，仅用 ``rsp`` 访问局部变量。

.. code-block:: none

   ; 有帧指针（常规）
   func:
       push rbp
       mov  rbp, rsp
       sub  rsp, 16
       mov  dword [rbp-4], 42
       mov  rsp, rbp
       pop  rbp
       ret

   ; 无帧指针（优化后）
   func_opt:
       sub  rsp, 16
       mov  dword [rsp+12], 42    ; 直接用 rsp+偏移访问
       add  rsp, 16
       ret                         ; 少了两条指令（push/pop rbp）

.. warning::

   省略帧指针会使调试变得更困难（因为通过帧指针回溯调用栈被破坏），但能节省寄存器（``rbp`` 可作通用寄存器使用）并减少指令数。在 GDB 中，``-fomit-frame-pointer`` 会让 ``backtrace`` 命令在某些情况下不准确。

嵌套函数调用中的栈帧
=======================

当一个函数调用另一个函数时，栈帧会逐层叠加：

.. code-block:: none

   f1:
       push rbp
       mov  rbp, rsp
       ; ... f1 代码 ...
       mov  rdi, 100
       call f2            ; 调用 f2 时，栈帧嵌套
       ; ... f1 继续 ...
       pop rbp
       ret

   f2:
       push rbp
       mov  rbp, rsp
       ; ... f2 代码 ...
       pop rbp
       ret

.. code-block:: text

   栈帧嵌套示意图（调用 f1 → f2）：
   ┌────────────────────────────┐
   │     f1 的调用者栈帧          │
   ├────────────────────────────┤
   │     f1 的返回地址           │
   ├────────────────────────────┤  ← f1 的 rbp
   │     f1 保存的 rbp           │
   ├────────────────────────────┤
   │     f1 的局部变量            │
   ├────────────────────────────┤  ← f1 的 rsp（调用 f2 时）
   │     f2 的返回地址            │
   ├────────────────────────────┤  ← f2 的 rbp
   │     f2 保存的 rbp           │
   ├────────────────────────────┤
   │     f2 的局部变量            │
   └────────────────────────────┘  ← f2 的 rsp

栈帧与 ``alloca``
====================

``alloca``（或手动修改 ``rsp``）可以在运行时动态分配栈空间：

.. code-block:: none

   ; 动态分配 n 字节的栈空间
   func_dynamic:
       push rbp
       mov  rbp, rsp

       ; rdi 中为需要分配的大小
       sub  rsp, rdi       ; 动态分配
       and  rsp, -16       ; 16 字节对齐

       ; 使用 [rsp], [rsp+8] 等访问分配到的空间

       mov  rsp, rbp       ; 一次性撤销所有分配
       pop  rbp
       ret

.. caution::

   手工调整 ``rsp`` 时需要格外小心。任何时候 ``call`` 指令执行前，``rsp`` 必须 16 字节对齐。此外，动态分配较大的栈空间可能导致栈溢出。
