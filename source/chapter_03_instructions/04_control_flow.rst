.. _chapter-03-control-flow:

===============================
控制流指令
===============================

控制流指令改变程序的执行顺序，包括无条件跳转、条件跳转和子程序调用。

程序不是一条直线。实际代码中到处都是分支（if/else、switch）、循环（for/while/do-while）
和函数调用——这些在底层都是由控制流指令实现的。

一个关键直觉：**RIP（指令指针寄存器）指向下一条指令的地址**。控制流指令的本质就是
修改 RIP 的值：跳转到函数入口、跳过 else 分支、回到循环起点。区别在于：
``jmp`` 直接覆盖 RIP，``call`` 先压入返回地址再覆盖 RIP，``ret`` 从栈弹出地址写回 RIP。

条件跳转依赖 RFLAGS：在执行 ``cmp``、``test``、``add`` 等指令之后，CPU 在 RFLAGS 中留下了
比较/运算的结果，条件跳转指令读取这些标志位来决定是否跳转。所以汇编中的 if/else 总是
成对出现：**先修改标志位，再条件跳转**。

.. code-block:: none

   ; 高级语言：if (a > b) { ... }
   ; 底层等价：
       cmp rax, rbx        ; 计算 rax - rbx，设置标志位
       jle .else_branch    ; 如果 rax <= rbx（否定条件），跳过 if 体
       ; if 体代码...
   .else_branch:
       ; else 或后续代码

``jmp`` 无条件跳转
=======================

.. admonition:: 分支预测：从 Pentium 到 Spectre
   :class: story

   CPU 的分支预测经历了惊人的演变。8086 没有分支预测——每次跳转都冲刷流水线。
   Pentium（1993）首次引入了**动态分支预测**，用一个 256 条目的 BTB（Branch Target Buffer）
   来预测跳转方向，预测准确率达到 ~80%。现代 CPU 的预测器（如 TAGE 预测器）采用多级历史表，
   准确率超过 99%。然而 2018 年曝光的 **Spectre** 漏洞揭示了分支预测的黑暗面——
   预测器会执行推测路径上的指令，即使这些指令最终不会被提交，但它们在缓存中留下的痕迹
   可以被攻击者侧信道窃取。这深刻地改变了现代系统安全的设计思路：处理器厂商不得不添加序列化指令
   （如 ``lfence``）来抑制推测执行。

``jmp`` 直接将指令指针 ``rip`` 设置为目标地址，接下来的指令从目标地址开始执行。

.. code-block:: none

   section .text
       ; 直接跳转（到标号）
       jmp .label

       ; 以下代码被跳过
       mov rax, 42

   .label:
       mov rax, 100      ; 从这里继续执行

       ; 寄存器间接跳转
       lea rbx, [.target]
       jmp rbx           ; 跳转到 rbx 中保存的地址

   .target:
       xor rax, rax

``cmp`` 比较与标志位
========================

``cmp`` 执行 ``dst - src`` 的减法运算，但**不保存结果**，只设置标志位。后续条件跳转根据标志位决定是否跳转。

.. code-block:: none

   cmp rax, rbx          ; 计算 rax - rbx，设置标志位
   ; 之后根据标志位判断：
   ;   ZF=1 → rax == rbx
   ;   ZF=0 → rax != rbx
   ;   SF=OF → rax >= rbx（有符号）
   ;   CF=1 → rax < rbx（无符号）

.. list-table:: ``cmp`` 后的标志位含义
   :header-rows: 1

   * - 关系
     - 有符号标志
     - 无符号标志
   * - dst == src
     - ZF=1
     - ZF=1
   * - dst != src
     - ZF=0
     - ZF=0
   * - dst > src
     - SF=OF 且 ZF=0
     - CF=0 且 ZF=0
   * - dst >= src
     - SF=OF
     - CF=0
   * - dst < src
     - SF≠OF
     - CF=1
   * - dst <= src
     - SF≠OF 或 ZF=1
     - CF=1 或 ZF=1

条件跳转指令
================

条件跳转检查标志位的状态，满足条件时跳转到目标地址。

有符号比较跳转
-----------------

.. code-block:: none

   cmp rax, rbx

   je  .equal            ; 跳转 if rax == rbx (ZF=1)
   jne .not_equal        ; 跳转 if rax != rbx (ZF=0)
   jg  .greater          ; 跳转 if rax >  rbx (SF=OF && ZF=0)
   jge .ge               ; 跳转 if rax >= rbx (SF=OF)
   jl  .less             ; 跳转 if rax <  rbx (SF≠OF)
   jle .le               ; 跳转 if rax <= rbx (SF≠OF || ZF=1)

无符号比较跳转
-----------------

.. code-block:: none

   cmp rax, rbx

   ja  .above            ; 跳转 if rax >  rbx (CF=0 && ZF=0)
   jae .above_equal      ; 跳转 if rax >= rbx (CF=0)
   jb  .below            ; 跳转 if rax <  rbx (CF=1)
   jbe .below_equal      ; 跳转 if rax <= rbx (CF=1 || ZF=1)

简单标志跳转
----------------

.. code-block:: none

   ; 不需要先执行 cmp
   jz  .zero             ; 跳转 if ZF=1
   jnz .non_zero         ; 跳转 if ZF=0
   js  .negative         ; 跳转 if SF=1
   jns .positive         ; 跳转 if SF=0
   jo  .overflow         ; 跳转 if OF=1
   jno .no_overflow      ; 跳转 if OF=0

.. code-block:: none

   ; 完整示例：计算两个数的最大值
   section .text
       mov rax, 50
       mov rbx, 100

       cmp rax, rbx
       jge  .max_is_rax   ; 如果 rax >= rbx，跳转
       mov rax, rbx        ; 否则 rax = rbx

   .max_is_rax:
       ; rax 中为最大值
       mov rax, 60
       xor rdi, rdi
       syscall

``test`` 与条件跳转组合
=============================

``test`` 执行按位 ``and`` 但不写回结果，只设置标志位，常与条件跳转配合。

.. code-block:: none

   test rax, rax          ; 检查 rax 是否为 0
   jz   .zero             ; rax == 0 时跳转

   test rax, 1            ; 检查最低位
   jnz  .odd              ; 最低位为 1 → 奇数

   ; 检查是否设置了多个标志位中的某一个
   test rcx, 0x1100       ; 检查第 8 位或第 12 位
   jnz  .flag_set         ; 任一位置 1 即跳转

``cmov`` 条件传送
====================

条件传送指令根据标志位决定是否执行数据传送，避免分支预测失败，常用于无分支编程。

.. code-block:: none

   ; 格式：cmovcc dst, src
   ; 条件是 `cc` 满足时执行 mov

   mov rax, 50
   mov rbx, 100
   cmp rax, rbx

   cmovg rax, rbx        ; 如果 rax > rbx，则 rax = rbx（否则不动）
   ; 相当于 rax = max(rax, rbx)

.. list-table::
   :header-rows: 1

   * - 条件码后缀
     - 含义
     - 标志位条件
   * - ``e`` / ``z``
     - 相等 / 零
     - ZF=1
   * - ``ne`` / ``nz``
     - 不相等 / 非零
     - ZF=0
   * - ``g``
     - 大于（有符号）
     - SF=OF 且 ZF=0
   * - ``ge``
     - 大于等于（有符号）
     - SF=OF
   * - ``l``
     - 小于（有符号）
     - SF≠OF
   * - ``le``
     - 小于等于（有符号）
     - SF≠OF 或 ZF=1
   * - ``a``
     - 大于（无符号）
     - CF=0 且 ZF=0
   * - ``ae``
     - 大于等于（无符号）
     - CF=0
   * - ``b``
     - 小于（无符号）
     - CF=1
   * - ``be``
     - 小于等于（无符号）
     - CF=1 或 ZF=1

``call`` / ``ret`` 子程序调用与返回
=========================================

``call`` 指令：1）将返回地址（即 ``call`` 的下一条指令地址）压栈；2）跳转到目标地址。

``ret`` 指令：从栈顶弹出返回地址，跳转回去。

.. code-block:: none

   section .text
       call my_func      ; 1. 压入返回地址 2. 跳转到 my_func
       mov rax, 60       ; 调用返回后从这里继续

   my_func:
       ; 函数体
       ret               ; 弹出返回地址，跳回 call 的下一条指令

关于栈帧和参数传递的更多细节，参见 :ref:`chapter-04`。

循环结构
============

使用条件跳转可以实现循环：

.. code-block:: none

   ; 计算 1+2+...+10 的和
       mov rcx, 10        ; 循环计数器
       xor rax, rax       ; sum = 0

   .loop:
       add rax, rcx       ; sum += counter
       dec rcx            ; counter--
       jnz .loop          ; 如果 counter != 0 继续循环

       ; 此时 rax = 55（1+2+...+10）

``loop`` / ``loope`` / ``loopne`` 循环指令
===============================================

x86_64 提供了专用的循环指令，它们隐式使用 ``rcx`` 作为计数器：

.. code-block:: none

   ; loop target: rcx--; 如果 rcx != 0，跳转
       mov rcx, 10
   .loop:
       ; ... 循环体 ...
       loop .loop                 ; rcx--; if (rcx) goto .loop

   ; loope (loopz): rcx--; 如果 rcx != 0 且 ZF=1，跳转
   ; loopne (loopnz): rcx--; 如果 rcx != 0 且 ZF=0，跳转
       mov rcx, 100
       xor rax, rax
   .scan:
       cmp byte [rdi + rax], 0
       loopne .scan               ; 直到找到 NUL 或遍历完

   ; jecxz / jrcxz: 如果 ecx/rcx == 0，跳转
       jrcxz .skip                ; 如果 rcx == 0，跳过处理
       ; ... 需要 rcx>0 的代码 ...
   .skip:

.. warning::

   ``loop`` 指令在现代 CPU 上性能较低（吞吐量不如 ``dec rcx; jnz``），
   因为其隐式标志位修改破坏了流水线。在高性能代码中，优先使用 ``dec rcx; jnz``。

常见控制流模式
====================

.. code-block:: none

   ; 模式 1：if-else（比较→否定条件跳转）
   ; C: if (a > 0) { positive } else { non_positive }
       cmp rax, 0
       jle .else
       ; ... positive 代码 ...
       jmp .end_if
   .else:
       ; ... non_positive 代码 ...
   .end_if:

   ; 模式 2：switch/case（跳转表）
   ; 适合连续的范围（如 0-9），用跳转表 O(1)
       cmp rax, 9
       ja  .default
       jmp [.jumptable + rax*8]
   .jumptable:
       dq .case0, .case1, .case2, .case3, .case4
       dq .case5, .case6, .case7, .case8, .case9

   ; 模式 3：do-while（入口在循环体内）
   ; 至少执行一次循环体
   .do:
       ; ... 循环体 ...
       test rax, rax
       jnz .do

   ; 模式 4：无穷循环（等待中断/事件）
       jmp .infinite_loop          ; 等效于 for(;;)

   ; 模式 5：提前退出循环
   ; 在循环体中间使用条件跳转跳出
       mov rcx, 100
   .loop:
       ; ... 循环体 ...
       cmp rax, 0
       je  .loop_exit              ; 提前退出
       dec rcx
       jnz .loop
   .loop_exit:

.. tip::

   **分支预测友好** 模式：CPU 的前瞻执行依赖于分支预测器。对于高度可预测的分支
   （如循环末尾的 ``dec rcx; jnz .loop`` ，大多数时候是"跳"），预测成功率可达 99% 以上。
   而对于数据驱动的分支（如二分查找中 ``cmp rax, [mid]`` 的结果几乎随机），预测失败率很高，
   此时应考虑改用 ``cmov`` （条件传送）消除分支。详见第 8 章优化技术的讨论。
