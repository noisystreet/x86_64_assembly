.. _chapter-08-profiling:

===============================
性能分析
===============================

编写汇编代码时，"优化前先测量"是铁律。本节介绍如何使用 Linux 性能分析工具找到代码热点。

.. admonition:: RDTSC：从可靠计时器到不可靠的"受害者"
   :class: story

   ``rdtsc``（Read Time-Stamp Counter）指令在 Pentium 时代被引入，用于读取 CPU 内部递增的周期计数器。
   当时 CPU 频率固定，TSC 就是可靠的纳秒级计时器。但到了 **Pentium 4 (NetBurst)** 时代，Intel 引入了
   动态频率缩放（SpeedStep），TSC 不再与真实时间线性相关。现代 x86_64 CPU 努力维持一个"恒定速率 TSC"
   （invariant TSC），但**在多核系统上不同核心的 TSC 值可能不同步**（差异可达几十微秒）。此外，
   推测执行和乱序执行意味着 ``rdtsc`` 附近的指令可能在其之前或之后执行，导致测量结果偏大或偏小。
   ``lfence; rdtsc`` 序列可以缓解，但无法完全消除。Linux 内核推荐的替代方案是 ``clock_gettime``
   系统调用——虽然开销比 ``rdtsc`` 大，但结果更可靠。

perf 工具使用
=================

``perf`` 是 Linux 内置的性能分析工具，基于硬件性能计数器工作。

.. code-block:: bash

   # 安装 perf
   sudo apt install linux-tools-common linux-tools-$(uname -r)

.. code-block:: bash

   # 基本用法：统计程序运行的性能计数器
   perf stat ./my_program

   # 示例输出
   #  Performance counter stats for './my_program':
   #
   #       1325.67 msec task-clock                #    0.999 CPUs utilized
   #              3      context-switches          #    2.263 /sec
   #              0      cpu-migrations            #    0.000 /sec
   #            310      page-faults               #  233.848 /sec
   #    4,200,541,231      cycles                    #    3.168 GHz
   #    3,100,234,567      instructions              #    0.74  insn per cycle
   #      800,123,456      branches                  #  603.654 M/sec
   #       10,234,567      branch-misses             #    1.28% of all branches

性能计数器
==============

``perf stat`` 可以统计数十种硬件事件：

.. code-block:: bash

   # 列出可用事件
   perf list

   # 统计指定事件
   perf stat -e cycles,instructions,cache-misses,cache-references ./program

   # 统计缓存相关
   perf stat -e L1-dcache-load-misses,L1-dcache-loads ./program

   # 统计分支预测
   perf stat -e branch-misses,branch-instructions ./program

.. list-table::
   :header-rows: 1

   * - 计数器
     - 含义
     - 分析目标
   * - ``cycles``
     - CPU 周期数
     - 程序总运行时间
   * - ``instructions``
     - 执行的指令数
     - 代码量评估
   * - ``instructions per cycle (IPC)``
     - 每周期指令数
     - 但周期数 IPC 越高越好（上限 ~4）
   * - ``cache-misses``
     - 缓存未命中次数
     - 内存访问模式优化
   * - ``branch-misses``
     - 分支预测失败次数
     - 控制流优化

采样分析（Sampling）
=======================

``perf record`` 以固定频率采样程序执行位置，找出热点：

.. code-block:: bash

   # 采样（默认 CPU 周期）
   perf record ./my_program

   # 指定采样频率
   perf record -F 1000 ./my_program    # 每秒 1000 次采样

   # 生成报告
   perf report

.. code-block:: text

   # perf report 输出示例
   #
   # Overhead  Command   Shared Object    Symbol
   # ........  .......  ...............  ...................
   #
       45.2%  my_prog   my_prog          [.] my_hot_loop
       12.3%  my_prog   my_prog          [.] strlen
        8.1%  my_prog   libc.so.6        [.] __memcpy_avx_unaligned
        5.4%  my_prog   my_prog          [.] less_hot_func

微基准测试
==============

为特定代码片段编写微基准测试：

.. code-block:: none

   ; microbench.asm——简单的微基准测试框架

   section .data
       iterations equ 100000000           ; 迭代次数
       msg        db "Completed %d iterations", 0xA, 0

   section .text
       extern printf
       global _start

   _start:
       ; 记录开始时间
       rdtsc                              ; 读取时间戳计数器
       mov r12d, eax                      ; 保存低 32 位
       mov r13d, edx                      ; 保存高 32 位（已弃用）

       ; 基准测试循环
       mov rcx, iterations
   .loop:
       ; === 被测代码开始 ===
       imul rax, rcx, 7                    ; 测试的乘法运算
       add  rax, rcx
       ; === 被测代码结束 ===
       dec rcx
       jnz .loop

       ; 记录结束时间
       rdtsc
       shl rdx, 32
       or  rax, rdx                        ; rax = 结束时间 (TSC)
       shl r13, 32
       or  r12, r13                        ; r12 = 开始时间
       sub rax, r12                        ; rax = 消耗的周期数

       ; 计算每迭代平均周期
       xor rdx, rdx
       mov rcx, iterations
       div rcx                             ; rax = 周期/迭代

       ; 打印结果
       mov rsi, rax
       lea rdi, [msg]
       xor rax, rax
       call printf

       mov rax, 60
       xor rdi, rdi
       syscall

.. code-block:: bash

   nasm -f elf64 microbench.asm -o microbench.o
   gcc -no-pie microbench.o -o microbench
   taskset -c 0 ./microbench         # 固定在一个核心上避免调度干扰

.. warning::

   微基准测试容易产生误导性结果。常见陷阱包括：
   1. **预热效应**：CPU 频率在开始时较低（省电模式），运行几秒后才升到最高
   2. **指令重排**：CPU 可能乱序执行，影响测量结果
   3. **缓存预热**：第一次运行缓存未命中，后续命中，应丢弃前几次结果
   4. **RDTSC 不够精确**：在多核系统上不同核心的 TSC 值可能不同步，使用 ``taskset -c 0`` 固定核心

使用 objdump 分析编译输出
============================

.. code-block:: bash

   # 反汇编查看编译器输出
   objdump -d my_program | less

   # 查看混合源码+汇编（需要 -g 编译）
   objdump -S -d my_program | less

   # 查看特定函数的汇编
   objdump -d my_program | grep -A 50 '<my_func>:'

.. code-block:: bash

   # 生成带注释的反汇编
   gcc -O2 -g -c test.c -o test.o
   objdump -d test.o

   # 输出会显示每条指令的字节数、地址和性能评论（如果是 perf annotate）

使用 perf annotate 查看热点指令
===================================

.. code-block:: bash

   # 采样并标注
   perf record ./my_program
   perf annotate my_hot_loop

   # 输出示例
   #       │  my_hot_loop():
   #       │  push %rbp
   #       │  mov  %rsp,%rbp
   #  0.01 │  mov  $0x0,%eax
   # 65.23 │  imul %rdi,%rax          ← 这里是热点！
   #  2.15 │  add  %rsi,%rax
   # 30.10 │  cmp  %rdi,%rsi
   #  2.51 │  jl   my_hot_loop

通过 ``perf annotate`` 可以精确定位到哪条指令消耗了最多 CPU 时间，然后针对性地优化该指令。
