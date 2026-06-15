.. _chapter-05-arrays:

===============================
数组
===============================

数组是连续存储在内存中的相同类型元素的集合。在汇编中，数组本质上是一块连续的内存区域，通过偏移量访问各个元素。

一维数组的声明与访问
========================

.. code-block:: none

   section .data
       ; 声明并初始化数组
       arr32  dd  10, 20, 30, 40, 50   ; 32 位整数数组（5 个元素）
       arr64  dq  100, 200, 300         ; 64 位整数数组（3 个元素）
       arr8   db  1, 2, 3, 4, 5         ; 8 位整数数组（5 个元素）

   section .bss
       buffer resd 256                   ; 256 个 32 位整数的未初始化数组
       buf64  resq 128                   ; 128 个 64 位整数的未初始化数组

.. code-block:: none

   ; 通过偏移量访问数组元素
   section .data
       arr  dd  10, 20, 30, 40, 50
       len  equ ($ - arr) / 4            ; 数组长度 = 总字节数 / 元素大小

   section .text
       ; 读取第 3 个元素（索引 2）
       mov eax, [arr + 2*4]              ; eax = 30（偏移 = 索引 × 元素大小）

       ; 修改第 1 个元素
       mov dword [arr], 99               ; arr[0] = 99

       ; 读取第 5 个元素（索引 4）
       mov eax, [arr + 4*4]              ; eax = 50

使用寄存器间接访问数组
========================

实际编程中，数组索引通常存放在寄存器中：

.. code-block:: none

   ; 使用变址寄存器访问数组
   section .data
       arr  dq  10, 20, 30, 40, 50

   section .text
       mov rcx, 2                         ; 索引
       mov rax, [arr + rcx*8]             ; rax = arr[2] = 30

       ; 遍历数组求和
       xor rax, rax                       ; sum = 0
       xor rcx, rcx                       ; i = 0
   .loop:
       add rax, [arr + rcx*8]             ; sum += arr[i]
       inc rcx
       cmp rcx, 5
       jl  .loop
       ; rax = 10 + 20 + 30 + 40 + 50 = 150

.. code-block:: none

   ; 通过指针遍历数组（使用寄存器递增）
   section .data
       arr  dq  10, 20, 30, 40, 50
       len  equ 5

   section .text
       mov rsi, arr                       ; rsi = 数组首地址
       mov rcx, len                       ; 循环计数
       xor rax, rax                       ; sum = 0
   .loop:
       add rax, [rsi]                     ; sum += *rsi
       add rsi, 8                         ; 指向下一个 64 位元素
       dec rcx
       jnz .loop

多维数组
============

多维数组在内存中以**行优先**（row-major）方式存储。

.. code-block:: none

   ; 3×4 的二维数组（3 行，每行 4 列）
   ; 地址计算：matrix[row][col] = base + (row * 列数 + col) * 元素大小
   section .data
       matrix dd  1,  2,  3,  4           ; 第 0 行
              dd  5,  6,  7,  8           ; 第 1 行
              dd  9, 10, 11, 12           ; 第 2 行
       ROWS equ 3
       COLS equ 4

   section .text
       ; 访问 matrix[1][2]（第 1 行第 2 列）
       mov rax, 1                          ; row
       mov rbx, 2                          ; col
       imul rax, COLS                      ; row * COLS
       add rax, rbx                        ; + col
       mov edx, [matrix + rax*4]           ; = matrix[1][2] = 7

       ; 遍历所有元素（行优先）
       xor rdi, rdi                        ; row = 0
   .row_loop:
       xor rsi, rsi                        ; col = 0
   .col_loop:
       mov rax, rdi
       imul rax, COLS
       add rax, rsi
       mov ecx, [matrix + rax*4]           ; matrix[row][col]
       ; 处理 element...
       inc rsi
       cmp rsi, COLS
       jl  .col_loop
       inc rdi
       cmp rdi, ROWS
       jl  .row_loop

冒泡排序示例
================

.. code-block:: none

   ; 对数组进行冒泡排序
   section .data
       arr  dd  5, 3, 8, 1, 9, 2, 7, 4, 6, 0
       len  equ ($ - arr) / 4

   section .text
   bubble_sort:
       mov rcx, len                        ; 外层循环计数器
       dec rcx                             ; 只需要 n-1 轮
   .outer:
       xor rdx, rdx                        ; 交换标志：0 = 未交换
       mov rdi, 0                           ; 内层循环索引
   .inner:
       mov eax, [arr + rdi*4]              ; arr[i]
       mov ebx, [arr + rdi*4 + 4]          ; arr[i+1]
       cmp eax, ebx
       jle .no_swap
       mov [arr + rdi*4], ebx              ; 交换
       mov [arr + rdi*4 + 4], eax
       mov rdx, 1                           ; 标记已交换
   .no_swap:
       inc rdi
       cmp rdi, rcx
       jl  .inner
       dec rcx
       jnz .outer
       ret

.. note::

   数组操作中常见的性能注意事项：

   1. **缓存友好**：按顺序访问元素（如上面的行优先遍历）比随机跳跃访问快得多，因为 CPU 会预取连续内存
   2. **边界检查**：汇编不会检查数组越界。访问 ``arr[len]`` 会静默读取相邻内存——可能导致数据损坏或崩溃
   3. **元素大小**：始终使用正确的元素大小计算偏移。32 位数组用 ``index*4``，64 位用 ``index*8``
   4. ``lea`` 优化：``lea rax, [rbx + rcx*8]`` 可以在一条指令中完成地址计算，常用于数组元素定位
