.. _chapter-09-memory-ordering:

===============================
内存序与内存模型
===============================

上一节介绍了 ``mfence`` / ``lfence`` / ``sfence`` 三条屏障指令，但「为什么需要屏障」这个问题值得深入。本节从 CPU 的内存模型出发，讲清楚乱序执行、内存序（memory ordering）以及屏障的真正作用。

为什么会有内存序问题
======================

现代 CPU 为了性能，会做两件「看起来违反直觉」的事：

1. **乱序执行**：CPU 可能不按程序顺序执行指令，只要结果「看起来」一样。
2. **写缓冲（Store Buffer）**：CPU 把写操作先放进缓冲区，稍后再真正写入内存，让后续指令不必等待写完成。

在**单线程**里，CPU 保证这些优化对外不可见——你看到的执行结果和顺序执行一致。但在**多线程**里，不同核心各自乱序、各自缓冲，一个线程观察到的另一个线程的操作顺序就可能「错乱」。

.. admonition:: 一个经典的例子
   :class: story

   假设两个线程共享两个变量 ``x`` 和 ``y``，初始都为 0：

   - 线程 A：``x = 1; r1 = y;``
   - 线程 B：``y = 1; r2 = x;``

   直觉上，``r1`` 和 ``r2`` 不可能**同时**为 0——因为如果 A 先执行 ``x = 1``，B 读 ``x`` 时至少能看到 1。
   但在真实 CPU 上，由于写缓冲和乱序，``r1 = 0`` 且 ``r2 = 0`` 是**可能**发生的。
   这就是著名的「Store Buffer 重排」问题，也是内存屏障存在的根本原因。

x86_64 的内存模型：TSO
=========================

x86_64 采用 **TSO（Total Store Order，全存储序）** 模型，属于「强内存模型」。它的核心保证是：

- ``Load 不会重排到更早的 Load 之前`` （Load-Load 有序）
- ``Store 不会重排到更早的 Store 之前`` （Store-Store 有序）
- ``Load 不会重排到更早的 Store 之前`` （Store-Load 有序）

换句话说，x86_64 上唯一允许的重排是：``Store 之后的 Load 可能被提前执行`` （Store-Load 重排）。

.. list-table:: x86_64 允许/禁止的重排
   :header-rows: 1

   * - 重排类型
     - 是否允许
     - 说明
   * - Load-Load
     - 禁止
     - 读操作保持顺序
   * - Store-Store
     - 禁止
     - 写操作保持顺序
   * - Load-Store
     - 禁止
     - 读不会跑到后面的写之后
   * - Store-Load
     - **允许**
     - 写之后的读可能被提前（唯一需要屏障的地方）

.. note::

   相比之下，ARM 采用**弱内存模型**，几乎允许所有重排，需要更密集的屏障。
   这也是为什么「在 x86 上能跑对的代码，移植到 ARM 上可能出错」——x86 的强序掩盖了很多潜在的数据竞争。

Store-Load 重排与屏障
========================

Store-Load 重排是 x86_64 上唯一需要显式屏障的场景。典型例子是「发布-订阅」模式：

.. code-block:: none

   ; 生产者：写入数据，然后置 ready 标志
   section .data
       data  dq 0
       ready dq 0

   section .text
   producer:
       mov qword [data], 42          ; 写入数据
       mov qword [ready], 1          ; 置 ready 标志
       ret

   ; 消费者：轮询 ready，然后读 data
   consumer:
   .wait:
       mov rax, [ready]              ; 读 ready
       test rax, rax
       jz   .wait                    ; 还没准备好，继续等
       mov rax, [data]               ; 读 data
       ret

问题在于：在消费者看来，``ready`` 的读（Load）可能被重排到 ``data`` 的读之前——但更关键的是，**生产者**的 ``data`` 写（Store）和 ``ready`` 写（Store）之间，以及消费者侧的读之间，x86 都保证有序。真正需要屏障的是**生产者侧的 Store 与消费者侧的 Load 之间的跨线程可见性**。

正确的做法是加屏障：

.. code-block:: none

   producer:
       mov qword [data], 42
       sfence                        ; 确保 data 的写先于 ready 对其它核心可见
       mov qword [ready], 1
       ret

   consumer:
   .wait:
       mov rax, [ready]
       test rax, rax
       jz   .wait
       lfence                        ; 确保 ready 的读先于 data 的读
       mov rax, [data]
       ret

.. note::

   在 x86_64 上，``sfence`` 保证「之前的 Store 先于之后的 Store 对其它核心可见」，
   ``lfence`` 保证「之后的 Load 不会在之前的 Load 之前执行」。
   而 ``mfence`` 是两者的全集（Store-Load 全屏障）。

``lock`` 前缀的屏障语义
=========================

带 ``lock`` 前缀的指令（如 ``lock add``、``lock cmpxchg``、``xchg``）**自动充当全屏障**，等价于 ``mfence``：

.. code-block:: none

   ; 用 lock 指令替代 mfence
   producer:
       mov qword [data], 42
       lock inc qword [counter]      ; 这条指令充当 mfence，确保 data 的写先可见
       mov qword [ready], 1
       ret

.. tip::

   在需要「写后读」屏障的场景，``lock`` 前缀指令往往比 ``mfence`` 更快，
   因为 ``mfence`` 在某些 CPU 上代价较高。这也是为什么无锁数据结构大量使用
   ``lock cmpxchg`` / ``xchg``——它们天然自带屏障语义。

``pause`` 指令
================

``pause`` 不是内存屏障，但它在自旋等待中与内存序密切相关：

.. code-block:: none

   spin_lock:
       mov rax, 1
   .retry:
       xchg rax, [rdi]              ; 原子交换

       test rax, rax                 ; 检查原来状态
       jnz  .retry                   ; 锁被占用，继续自旋
       ret

``pause`` 的作用是给 CPU 一个「提示」：当前处于自旋等待，可以降低功耗、避免内存序相关的性能问题：

.. code-block:: none

   spin_lock:
       mov rax, 1
   .retry:
       xchg rax, [rdi]              ; 原子交换
       test rax, rax
       jz   .locked                 ; 成功获取锁
       pause                         ; 自旋等待时降低功耗、减少总线争用
       jmp  .retry
   .locked:
       ret

.. note::

   ``pause`` 在超线程（Hyper-Threading）场景下尤其重要：它让出执行资源给同核心的另一个逻辑线程，
   避免自旋线程空转浪费整个核心。同时 ``pause`` 也提示 CPU 当前是「读-改-写」自旋，
   有助于减少内存序相关的流水线停顿。

内存序与 C/C++ 内存模型
=========================

汇编层面的内存序，对应到 C/C++ 就是 ``std::atomic`` 的内存序参数：

.. list-table:: 汇编屏障与 C++ 内存序的对应
   :header-rows: 1

   * - 汇编
     - C++ ``std::atomic``
     - 说明
   * - 无屏障（普通 load/store）
     - ``memory_order_relaxed``
     - 不保证任何顺序
   * - ``sfence`` / ``lfence``
     - ``memory_order_release`` / ``memory_order_acquire``
     - 发布/获取语义
   * - ``mfence`` / ``lock`` 前缀
     - ``memory_order_seq_cst``
     - 顺序一致性（最强）

.. tip::

   理解汇编层面的内存序，能帮你读懂 ``std::atomic`` 到底「编译成了什么」。
   例如 ``std::atomic<int>::store(..., memory_order_release)`` 在 x86_64 上通常
   只是一条普通的 ``mov``（因为 x86 的 Store-Store 天然有序），
   而 ``memory_order_seq_cst`` 的 store 才会生成 ``xchg`` 或 ``mfence``。

练习题
========

1. 解释为什么 x86_64 上「Store-Load 重排」是唯一需要屏障的场景，并举例说明。

2. 用 ``sfence`` / ``lfence`` 实现一个正确的生产者-消费者模型，验证消费者
   始终能看到生产者写入的最新数据。

3. 对比 ``mfence`` 与 ``lock`` 前缀指令在「写后读」屏障场景下的差异，
   说明为什么无锁数据结构更倾向使用 ``lock cmpxchg``。

4. 在自旋锁的 ``.retry`` 循环中加入 ``pause`` 指令，观察并说明它对
   超线程场景下性能的影响。

5. 将汇编层面的 ``sfence`` / ``lfence`` / ``mfence`` 与 C++ 的
   ``memory_order_release`` / ``acquire`` / ``seq_cst`` 对应起来，
   说明它们各自的语义。
