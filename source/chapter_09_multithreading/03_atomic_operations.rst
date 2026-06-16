.. _chapter-09-atomic:

===============================
原子操作
===============================

原子操作是不可中断的操作——要么全部完成，要么完全不执行。它们是实现锁和无锁数据结构的基石。

.. admonition:: ABA 问题：无锁编程的头号敌人
   :class: funfact

   无锁数据结构有一个臭名昭著的陷阱叫 **ABA 问题**。以无锁栈为例：线程 A 读取栈顶为节点 X（值为 "A"），
   然后被调度器暂停。线程 B 将 X 出栈、释放内存、分配新节点 Y（巧合的是 Y 和 X 地址相同），再次入栈。
   线程 A 恢复后执行 ``cmpxchg``，发现栈顶地址和之前一样（都是地址 X），认为栈没变过——于是将 Y 当成
   旧的 X 处理，导致链表结构损坏。这个问题在现实中真实发生过：**Sun 的 Java JDK 1.4 的无锁 Stack
   实现就因 ABA 问题存在 bug**。常见解法是"标记指针"（tagged pointer）：将指针的低位用作版本号，
   每次操作递增版本号，这样就无法通过地址相等来欺骗比较。x86_64 中 48 位虚拟地址的高 16 位可以用作标记。

lock 前缀
=============

``lock`` 前缀将指令变为原子操作，确保在多核 CPU 上不会被其他核心中断：

.. code-block:: none

   ; 可以加 lock 前缀的指令：add, sub, inc, dec, and, or, xor, xchg, cmpxchg 等
   ; 目标操作数必须是内存地址

   lock inc  qword [counter]           ; 原子自增计数器
   lock add  qword [counter], 10       ; 原子加法
   lock dec  qword [counter]           ; 原子自减
   lock xchg rax, [lock_var]           ; xchg 自带 lock 语义（自动加 lock）
   lock cmpxchg [lock_var], rcx        ; 原子比较并交换

.. warning::

   ``lock`` 前缀只能用于**读取-修改-写入** （Read-Modify-Write）指令，
   且目标必须是内存地址。它对 ``mov [mem], reg`` 这样的简单存储无效。

原子交换（xchg）
===================

``xchg`` 指令**始终**是原子的，即使不加 ``lock`` 前缀：

.. code-block:: none

   ; xchg 自动带有 lock 语义（当操作数包含内存时）
   xchg rax, [lock_var]                ; 原子：rax ↔ *lock_var

   ; 利用 xchg 实现自旋锁
   spin_lock:
       mov rax, 1                      ; 期望锁住
   .retry:
       xchg rax, [rdi]                 ; 原子交换
       test rax, rax                   ; 检查原来状态
       jnz .retry                      ; 原来锁着就重试
       ret

比较并交换（cmpxchg）
========================

``cmpxchg`` 比较目标值是否等于 ``rax``，如果相等则写入新值，否则不写入：

.. code-block:: none

   ; cmpxchg dst, src
   ; 如果 [dst] == rax，则 [dst] = src，且 ZF=1
   ; 否则，rax = [dst]，且 ZF=0

   ; 原子的 "如果值为 0 就设为 1"
   mov rax, 0
   mov rcx, 1
   lock cmpxchg [lock_var], rcx        ; 如果 *lock_var == 0，则 *lock_var = 1
   jz  .locked                         ; 成功获取锁
   ; 锁已被占用，rax 中为锁的当前值

   ; 无锁递增
   ; 用 cmpxchg 安全递增计数器（等价于 lock inc，但更灵活）
   .retry:
       mov rax, [counter]              ; 读取当前值
       mov rcx, rax
       inc rcx                          ; 计算新值
       lock cmpxchg [counter], rcx      ; 如果没有被修改过，写入新值
       jnz .retry                       ; 被其他线程修改了，重试

== cmpxchg8b / cmpxchg16b ==

用于操作 8 字节和 16 字节的值：

.. code-block:: none

   ; cmpxchg8b: 比较交换 8 字节
   ; 比较 edx:eax 与 [dst]
   ; 如果相等，将 ecx:ebx 写入 [dst]
   ; 否则，将 [dst] 读入 edx:eax

   ; cmpxchg16b: 比较交换 16 字节（需要 CMPXCHG16B CPU 支持）
   ; 比较 rdx:rax 与 [dst]
   ; 如果相等，将 rcx:rbx 写入 [dst]
   ; 否则，将 [dst] 读入 rdx:rax

   section .data
       align 16
       counter_pair dq 0, 0             ; 16 字节的计数器对

   section .text
       ; 原子递增 16 字节计数器
       mov rax, [counter_pair]          ; 低 64 位
       mov rdx, [counter_pair + 8]      ; 高 64 位
   .retry:
       mov rbx, rax
       mov rcx, rdx
       add rbx, 1                       ; 低 64 位 +1
       adc rcx, 0                       ; 进位到高 64 位
       lock cmpxchg16b [counter_pair]
       jnz .retry                       ; 被其他线程修改，重试

.. caution::

   ``cmpxchg16b`` 需要 CPU 支持（大多数 x86_64 CPU 都支持）。可以用 ``cpuid`` 指令检查。
   不支持时只能使用锁或 ``lock cmpxchg8b``。

原子算术操作
===============

.. code-block:: none

   ; 原子加法
   lock add qword [counter], 1

   ; 原子的获取并自增（Fetch-And-Add）
   ; lock xadd dst, src: 将 src 加到 [dst]，原值保存到 src
   mov rax, 1                           ; 要增加的值
   lock xadd [counter], rax             ; rax = 原值，counter += 1
   ; 现在 rax 中保存的是增加前的计数值

   ; 使用 xadd 实现无锁计数器
   ; 分配唯一序列号（线程安全）
   section .data
       sequence dq 0

   section .text
       mov rax, 1
       lock xadd [sequence], rax        ; 原子获取下一个序列号
       ; rax = 分配到的序号（递增前的值）

内存序与屏障
================

现代 CPU 可能乱序执行指令，导致一个线程看到的操作顺序与另一个线程不同。
内存屏障指令用于保证顺序一致性。

.. list-table::
   :header-rows: 1

   * - 指令
     - 作用
     - 场景
   * - ``mfence``
     - 全屏障（Load+Store）
     - 序列化所有内存操作
   * - ``lfence``
     - 加载屏障（Load）
     - 序列化读取
   * - ``sfence``
     - 存储屏障（Store）
     - 序列化写入

.. code-block:: none

   ; 使用 StoreLoad 屏障（mfence）保证写入对所有线程可见
   section .data
       ready dq 0
       data  dq 0

   section .text
       ; 线程 A：生产数据
       mov qword [data], 42              ; 写入数据
       sfence                            ; 确保 data 写入先于 ready 对其它线程可见
       mov qword [ready], 1              ; 标记准备好

       ; 线程 B：消费数据
   .wait:
       pause
       cmp qword [ready], 0
       je  .wait
       lfence                            ; 确保读取 ready 后读取 data
       mov rax, [data]                   ; 应该看到 data = 42

.. note::

   x86_64 架构的内存模型是**强序**的（Total Store Order, TSO）。
   大多数普通 load/store 不会重排，但写入后读取（StoreLoad）需要 ``mfence`` 或 ``lock`` 指令来保证顺序。
   在 x86_64 上，``lfence`` 主要用于序列化指令流，而非内存顺序（除非配合特定场景）。

带 lock 前缀的指令自动充当内存屏障：

.. code-block:: none

   ; lock 前缀指令自带完整的 barrier 语义
   mov qword [data], 42
   lock inc qword [counter]              ; 充当 mfence：确保之前的写入对其它线程可见

无锁编程示例：无锁栈
=======================

.. code-block:: none

   ; 无锁栈（Treiber Stack）
   ; 基于 cmpxchg 的链表头插入
   section .data
       stack_head dq 0                   ; 栈顶指针

   section .bss
       ; 节点结构（在实际代码中应使用 malloc 分配）
       ; node = [next_ptr (8 bytes)] [value (8 bytes)]

   ; 入栈（push）
   ; rdi = 新节点地址
   lockfree_push:
   .retry:
       mov rax, [stack_head]             ; 读取当前栈顶
       mov [rdi], rax                    ; 新节点.next = 当前栈顶
       lock cmpxchg [stack_head], rdi    ; 尝试原子替换栈顶
       jnz .retry                         ; 被其他线程修改了，重试
       ret

   ; 出栈（pop）
   ; 返回 rax = 节点地址，0 表示空栈
   lockfree_pop:
   .retry:
       mov rax, [stack_head]             ; 读取当前栈顶
       test rax, rax
       jz   .empty                       ; 空栈
       mov rcx, [rax]                    ; 读取栈顶节点的 next 指针
       lock cmpxchg [stack_head], rcx    ; 尝试原子替换栈顶为 next
       jnz .retry                         ; 被修改了，重试
       ret
   .empty:
       xor rax, rax
       ret

.. warning::

   无锁编程**极其复杂**。上述示例未处理 ABA 问题（ABA problem，即节点被回收后又重新分配）。
   生产环境中的无锁数据结构还需要考虑内存回收（RCU 或 hazard pointers）等问题。
   除非绝对必需，建议使用锁保护数据结构。

练习题
========

1. 用 ``lock inc`` 实现一个多线程安全的计数器，创建两个线程各递增 100 万次，
   验证最终结果是否为 200 万。

2. 使用 ``xchg`` 指令实现自旋锁，保护一个临界区（如共享变量的递增）。

3. 用 ``lock cmpxchg`` 实现无锁计数器，对比与 ``lock xadd`` 版本的代码差异。

4. 分析文中无锁栈的 ABA 问题：在什么场景下会发生？如何用标记指针
   （tagged pointer）解决？

5. 使用 ``mfence`` / ``lfence`` / ``sfence`` 实现一个生产者-消费者模型，
   保证消费者始终看到生产者写入的最新数据。
