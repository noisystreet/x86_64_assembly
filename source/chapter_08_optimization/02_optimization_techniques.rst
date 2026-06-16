.. _chapter-08-optimization:

===============================
优化技术
===============================

在正确分析出热点之后，可以应用各种优化技术来提升性能。本节覆盖指令选择、循环优化、分支预测和内存访问等方面。

指令选择优化
================

选择更高效的指令或指令序列：

.. code-block:: none

   ; 常见优化替换模式

   ; 1. 清零寄存器：xor 比 mov 好
   mov rax, 0              ; ❌ 7 字节
   xor rax, rax            ; ✅ 3 字节，且 CPU 会识别为零消除模式

   ; 2. 移动寄存器：使用 32 位清零高 32 位的特性
   mov rax, rbx            ; 3 字节
   mov eax, ebx            ; ✅ 2 字节（如果只需要低 32 位）

   ; 3. 乘以常数：用 lea 或移位代替 imul
   imul rax, 5             ; ❌ imul 有 ~3 周期延迟
   lea rax, [rax + rax*4]  ; ✅ lea 只有 1 周期延迟

   ; 4. 比较后条件传送代替分支
   cmp rax, rbx
   jg  .greater            ; ❌ 分支可能预测失败
   cmovg rax, rbx          ; ✅ 无分支，消除预测失败惩罚

   5. 重复内存复制：使用 rep movsb 或 SSE

   ; ❌ 逐字节循环复制
   .loop:
       mov al, [rsi]
       mov [rdi], al
       inc rsi
       inc rdi
       dec rcx
       jnz .loop

   ; ✅ 使用 rep movsb（微码优化，效率更高）
   cld
   rep movsb               ; 硬件加速的内存复制

.. note::

   GCC 和 Clang 在 ``-O2`` / ``-O3`` 下会自动应用大部分上述优化。
   手写汇编的优势在于编译器**无法做**的优化——与算法或领域知识相关的优化，
   而不是做这些简单优化。

循环优化
============

循环是优化收益最大的地方：

.. code-block:: none

   ; 1. 循环展开——减少循环开销
   ; 原始循环（100 次迭代）
   xor rax, rax
   mov rcx, 100
   .loop:
       add rax, [rsi + rcx*8 - 8]
       dec rcx
       jnz .loop

   ; 展开为 4 倍（25 次迭代，每次处理 4 个元素）
   xor rax, rax
   mov rcx, 25
   .loop:
       add rax, [rsi + rcx*8 - 8]
       add rax, [rsi + rcx*8 - 16]
       add rax, [rsi + rcx*8 - 24]
       add rax, [rsi + rcx*8 - 32]
       dec rcx
       jnz .loop

   ; 2. 循环不变代码外提
   ; ❌ 每次迭代都计算相同的地址
   .loop:
       mov rbx, [rsi + rdi*8 + 16]    ; rsi, rdi, 16 是循环不变的
       ...

   ; ✅ 提前计算，移到循环外
   lea rbx, [rsi + rdi*8 + 16]
   .loop:
       mov rax, [rbx]                  ; 直接用寄存器访问
       ...

.. code-block:: none

   ; 3. 强度削弱——将乘法替换为加法
   ; ❌ 每次迭代计算索引 * 8
   .loop:
       mov rax, [arr + rcx*8]
       dec rcx
       jnz .loop

   ; ✅ 使用指针递增，将乘法转为加法
   mov rsi, arr + (N-1)*8             ; 指向最后一个元素
   mov rcx, N
   .loop:
       mov rax, [rsi]
       sub rsi, 8                      ; 指针递减（减法比乘法快得多）
       dec rcx
       jnz .loop

分支预测优化
================

分支预测失败代价高达 10-20 周期。以下技巧可以减少分支预测失败：

.. code-block:: none

   ; 1. 条件传送替代分支
   ; ❌ 分支版本（可能预测失败）
       cmp rax, rbx
       jl  .use_rbx
       mov rdx, rax
       jmp .done
   .use_rbx:
       mov rdx, rbx
   .done:

   ; ✅ 无分支版本（cmov 无预测惩罚）
       cmp rax, rbx
       cmovl rdx, rbx      ; 如果 rax < rbx，rdx = rbx
       cmovge rdx, rax     ; 如果 rax >= rbx，rdx = rax

   ; 2. 将可预测的分支提前
   ; 常见情况放在前面
       test rax, rax
       jz   .common_case    ; 通常 rax 为 0，跳转有 90% 概率被预测为"跳"
       ; ... 罕见情况 ...

   ; 3. 使用位运算消除分支
   ; branchless abs()
   mov rax, rdi
   sar rax, 63             ; rax = 符号位（全 1 或全 0）
   xor rdi, rax
   sub rdi, rax            ; rdi = abs(rdi)
   ; 完全无分支！

.. note::

   条件传送（``cmov``）并不总是比分支快。如果分支**预测准确率极高** （如 99%），
   分支版本反而更快。``cmov`` 的代价是它**总是**执行两条路径中的指令，
   如果计算复杂度高（如 ``cmovg rax, [rbx+rcx*8+mem_func()]`` 涉及内存访问），
   反而更慢。

内存访问优化（缓存友好）
============================

内存访问速度比 CPU 慢两个数量级，优化内存访问模式至关重要：

.. code-block:: none

   ; 1. 顺序访问 vs 随机访问
   ; ✅ 顺序访问（缓存友好）
   .loop:
       add rax, [arr + rcx*8]
       dec rcx
       jnz .loop

   ; ❌ 跨步访问（缓存不友好，每次访问不同缓存行）
   .loop:
       add rax, [matrix + rcx*64]    ; 每 64 字节访问一次
       dec rcx
       jnz .loop

   ; 2. 数据对齐
   section .data
       align 64                       ; 缓存行对齐（64 字节）
       hot_data dq 0

   ; 3. 将热点数据集中存放
   section .data
       ; 热量数据放在一起，提高缓存局部性
       hot_var1 dq 0
       hot_var2 dq 0
       hot_var3 dq 0
       align 64
       ; 冷数据放在后面
       cold_var1 dq 0

.. code-block:: none

   ; 4. 预取（Prefetch）帮助 CPU 提前加载数据
   section .data
       big_array times 1024 dq 0

   section .text
       ; 在循环中手动预取
       mov rcx, 1024/8
       xor rsi, rsi
   .loop:
       prefetchnta [big_array + rsi + 64]   ; 提前加载下一个缓存行
       mov rax, [big_array + rsi]
       ; ... 处理数据 ...
       add rsi, 8
       dec rcx
       jnz .loop

.. caution::

   过度预取会浪费内存带宽，适度预取才有益。通常预取 1-2 个缓存行（64-128 字节）就足够了。

指令级并行（ILP）
====================

现代 CPU 可以在每个周期执行多条指令（superscalar 架构）。
利用指令级并行的关键是**打破指令间的数据依赖**：

.. code-block:: none

   ; 串行计算（数据依赖链长，ILP 利用率低）
       mov rax, [a]
       add rax, [b]        ; 等待 rax
       add rax, [c]        ; 等待 rax
       add rax, [d]        ; 等待 rax
       mov [sum], rax

   ; 并行计算（打破依赖链，ILP 利用率高）
       mov rax, [a]        ; 独立计算 a+b
       add rax, [b]
       mov rbx, [c]        ; 独立计算 c+d
       add rbx, [d]
       add rax, rbx         ; 最后合并
       mov [sum], rax

.. code-block:: none

   ; 累加器的 ILP 优化
   ; ❌ 单一累加器带来了依赖链
   .loop:
       add rax, [rsi]       ; 🌩 rax 依赖前一次迭代的 rax
       add rsi, 8
       dec rcx
       jnz .loop

   ; ✅ 多个累加器消除依赖
       xor rax, rax
       xor rbx, rbx
       xor rdx, rdx
       xor r8, r8
       shr rcx, 2            ; 每次处理 4 个元素
   .loop:
       add rax, [rsi]        ; 4 条独立指令
       add rbx, [rsi+8]
       add rdx, [rsi+16]
       add r8,  [rsi+24]
       add rsi, 32
       dec rcx
       jnz .loop
       add rax, rbx          ; 合并
       add rax, rdx
       add rax, r8
       ; total in rax

优化策略总结
================

.. list-table::
   :header-rows: 1

   * - 策略
     - 收益
     - 复杂度
     - 适用场景
   * - 指令选择
     - 中
     - 低
     - 通用，广泛适用
   * - 循环展开
     - 中-高
     - 中
     - 小循环体，高迭代次数
   * - 条件传送
     - 中
     - 低
     - 难以预测的分支
   * - 缓存优化
     - 高
     - 中-高
     - 大数据集，内存密集
   * - 指令级并行
     - 中-高
     - 中
     - 长依赖链，浮点计算
   * - SIMD 向量化
     - 高
     - 高
     - 数据并行操作
   * - 算法优化
     - 最高
     - 高
     - 始终优先考虑

.. warning::

   优化的一条基本原则：**不要过早优化**。始终先编写清晰的代码，用 ``perf`` 找到真正的热点，
   然后只优化热点。超过 90% 的优化收益来自不到 10% 的代码。

练习题
========

1. 用 ``perf stat ./program`` 测量一个简单循环程序的 CPI 和 IPC，分析瓶颈。

2. 将一个累加循环展开为 4 路，比较展开前后的运行时间和指令数。

3. 实现数组元素求和的两种版本：单累加器 vs 4 累加器，用 ``perf`` 对比 IPC 差异。

4. 用 ``objdump -d`` 反汇编编译器生成的代码（如 ``gcc -O2 -S``），
   找出至少 3 个编译器自动应用的优化模式。

5. 编写一个分支密集的程序（如二分查找），然后改用 ``cmov`` 消除分支。
   对比两种版本的 ``perf stat`` 输出中的 branch-misses 指标。
