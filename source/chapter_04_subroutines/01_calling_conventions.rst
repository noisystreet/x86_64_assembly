.. _chapter-04-calling-conventions:

===============================
System V AMD64 调用约定
===============================

调用约定（Calling Convention）定义了函数如何传递参数和返回值、哪些寄存器由调用者/被调用者保存等规则。
在 Linux x86_64 上，标准的调用约定是 **System V AMD64 ABI**。

寄存器使用规则
==================

.. admonition:: 为什么 Linux 选择了 System V ABI？
   :class: story

   System V ABI 的起源可以追溯到 20 世纪 80 年代的 **AT&T Unix** 系统。当时 Unix 厂商（Sun、IBM、HP）各自有
   不同的 ABI，带来了严重的互操作性问题。System V Release 4（SVR4）首次统一了 Unix 平台的 ABI 规范。
   当 AMD 设计 x86_64 时，Linux 社区和 AMD 共同选择了 System V ABI 作为标准（而非 Intel 建议的 Itanium ABI），
   因为它寄存器使用效率更高：6 个参数寄存器（而非 Windows x64 的 4 个）减少了栈参数传递。
   这也解释了为什么 **Linux 和 macOS 都使用 System V ABI，而 Windows 使用不同的 x64 calling convention**——
   纯粹是历史分叉的结果。

.. list-table::
   :header-rows: 1

   * - 寄存器
     - 用途
     - 谁负责保存
   * - ``rdi``
     - 第 1 个参数
     - 调用者
   * - ``rsi``
     - 第 2 个参数
     - 调用者
   * - ``rdx``
     - 第 3 个参数
     - 调用者
   * - ``rcx``
     - 第 4 个参数
     - 调用者
   * - ``r8``
     - 第 5 个参数
     - 调用者
   * - ``r9``
     - 第 6 个参数
     - 调用者
   * - ``rax``
     - 返回值
     - 调用者
   * - ``rbx``
     - 通用
     - :strong:`被调用者`\ （需保存并恢复）
   * - ``rbp``
     - 栈帧基址
     - **被调用者**
   * - ``rsp``
     - 栈指针
     - :strong:`被调用者`\ （函数返回时恢复）
   * - ``r12`` - ``r15``
     - 通用
     - **被调用者**

.. note::

   - **调用者保存** 的寄存器：调用者（caller）在调用前若需保留这些寄存器的值，应自行保存。被调用者可随意修改。
   - **被调用者保存** 的寄存器：被调用者（callee）如果修改了这些寄存器，必须在返回前恢复原值。

整数参数传递
================

前 6 个整数参数依次通过 ``rdi`` → ``rsi`` → ``rdx`` → ``rcx`` → ``r8`` → ``r9`` 传递。
超过 6 个的参数通过栈传递（从右到左压栈）。

.. code-block:: none

   ; 调用 func(a, b, c, d, e, f, g)
   ; 参数 a-f 通过寄存器传递，g 通过栈传递
   mov rdi, 10       ; 第 1 个参数 a
   mov rsi, 20       ; 第 2 个参数 b
   mov rdx, 30       ; 第 3 个参数 c
   mov rcx, 40       ; 第 4 个参数 d
   mov r8,  50       ; 第 5 个参数 e
   mov r9,  60       ; 第 6 个参数 f
   push 70           ; 第 7 个参数 g（通过栈传递）
   sub rsp, 8        ; 栈对齐调整
   call func
   add rsp, 16       ; 清理栈上的参数 + 对齐调整

返回值
==========

.. list-table::
   :header-rows: 1

   * - 类型
     - 寄存器
   * - 整数 / 指针（≤64 位）
     - ``rax``
   * - 128 位整数
     - ``rdx:rax``\ （高 64 位在 rdx，低 64 位在 rax）
   * - 浮点数
     - ``xmm0``

.. code-block:: none

   ; 整数返回值
   ; int add(int a, int b) => return a + b
   add_func:
       mov rax, rdi
       add rax, rsi
       ret
   ; 调用后 rax = a + b

   ; 128 位返回值（rdx:rax）
   ; __int128 mul128(__int128 a, __int128 b)
   ; 实际上：rdx:rax 作为返回值，低位在 rax

栈对齐规则
==============

System V ABI 要求 ``rsp`` 在 ``call`` 指令执行前必须是 **16 字节对齐** 的。
由于 ``call`` 会压入 8 字节的返回地址，因此进入函数时 ``rsp`` 实际上是 :strong:`8 字节对齐`\ （比 16 的倍数多 8）。

.. code-block:: none

   ; 函数入口时 rsp 的状态
   ; call func     → push 返回地址（8 字节），rsp -= 8
   ; 进入 func 时：rsp ≡ 8 (mod 16) ← 非对齐状态！
   func:
       push rbp       ; push 又减 8，现在 rsp ≡ 0 (mod 16) ← 对齐
       mov rbp, rsp
       ; ... 函数体 ...
       pop rbp
       ret            ; ret 弹出 8 字节，恢复到 rsp ≡ 8 (mod 16)

   ; 注意：如果函数体内部没有额外的 push，栈在函数体运行时是 16 字节对齐的
   ; 但如果函数需要调用其他函数，需确保调用前 rsp 又恢复为 16 字节对齐

.. code-block:: none

   ; 不对齐可能导致的问题
   func_caller:
       push rbp
       mov rbp, rsp

       ; 此时 rsp 已 16 字节对齐
       mov rdi, 42
       call other_func   ; ✅ rsp 在 call 前是 16 的倍数

       sub rsp, 8        ; 分配了 8 字节局部变量
       mov rdi, 99
       call other_func   ; ❌ rsp 现在是 8 的倍数而非 16 的倍数！
                         ; 如果 other_func 使用了 movaps 等对齐要求的 SIMD 指令，会崩溃

       ; 正确做法：sub rsp, 16（分配 16 的倍数）
       ; 或分配后再次对齐
       mov rsp, rbp
       pop rbp
       ret

被调用者保存寄存器的使用
============================

如果函数需要使用被调用者保存的寄存器（``rbx``, ``rbp``, ``r12``-``r15``），必须保存原始值并在返回前恢复。

.. code-block:: none

   func_uses_rbx:
       push rbx           ; 保存 rbx
       mov rbx, rdi       ; 使用 rbx 存储参数
       ; ... 函数体 ...
       pop rbx            ; 恢复 rbx
       ret

   ; 多个被调用者寄存器
   func_uses_multi:
       push rbx
       push r12
       push r13

       ; 使用 rbx, r12, r13

       pop r13
       pop r12
       pop rbx
       ret

与 C 代码对应
=================

.. code-block:: c
   :caption: C 语言中的同一函数

   long example(long a, long b, long c,
                 long d, long e, long f,
                 long g) {
       return a + b + c + d + e + f + g;
   }

对应的汇编实现：

.. code-block:: none
   :caption: 汇编实现

   ; System V ABI 说明
   ; rdi=a, rsi=b, rdx=c, rcx=d, r8=e, r9=f
   ; [rsp+0]=g（返回地址已在栈顶，g 在其上）
   example:
       push rbp
       mov  rbp, rsp

       ; 计算前 6 个参数的和
       mov  rax, rdi
       add  rax, rsi
       add  rax, rdx
       add  rax, rcx
       add  rax, r8
       add  rax, r9

       ; 加上栈上的第 7 个参数
       add  rax, [rbp+16]   ; 跳过返回地址（8 字节）

       pop  rbp
       ret
