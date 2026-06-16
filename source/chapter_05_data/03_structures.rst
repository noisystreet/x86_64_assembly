.. _chapter-05-structures:

===============================
结构体
===============================

结构体将多个不同类型的字段组合在一起，在汇编中以连续内存块的形式存在。访问结构体成员就是计算相对于结构体基址的偏移量。

**结构体就是带名字的偏移量。** 在高级语言中，C 编译器替你计算了 ``p->x`` 对应的地址偏移；在汇编中，你必须自己做这件事。好在计算非常简单：每个字段的偏移 = 之前所有字段大小之和 + 对齐填充。

新手最容易困惑的是：**为什么结构体的大小不等于各个字段大小的简单相加？** 因为 CPU 要求某些类型按特定边界对齐——访问一个 8 字节 ``double`` 时，如果它横跨两个 8 字节对齐的块，就需要两次内存访问。为了性能，编译器（和汇编程序员）会在字段之间插入填充（padding）字节，这就是对齐规则。

这也是为什么你会看到这样的现象：同样的三个字段，不同的排列顺序会导致结构体外尺寸不同。通常的优化技巧是：**把大的字段放在前面，小的放在后面**——这能最小化填充。

结构体布局
==============

.. code-block:: c
   :caption: 对应的 C 结构体

   struct Point {
       int x;       // 4 字节
       int y;       // 4 字节
       char label;  // 1 字节
       // 3 字节填充（padding）
   };
   // sizeof(struct Point) = 12

.. code-block:: none

   ; 在汇编中定义相同的结构体
   section .data
       ; 手动计算偏移量
       POINT_X     equ 0                  ; x 偏移 0，大小 4
       POINT_Y     equ 4                  ; y 偏移 4，大小 4
       POINT_LABEL equ 8                  ; label 偏移 8，大小 1
       POINT_SIZE  equ 12                 ; 结构体总大小（含填充）

       ; 声明并初始化结构体实例
       pt1:                               ; struct Point pt1
           dd  10                         ; x = 10     [偏移 0]
           dd  20                         ; y = 20     [偏移 4]
           db  'A'                        ; label = 'A' [偏移 8]
           times 3 db 0                   ; 填充         [偏移 9-11]

通过偏移量访问成员
====================

.. code-block:: none

   ; 通过基址+偏移访问结构体成员
   section .data
       pt1:                               ; struct Point pt1
           dd  10
           dd  20
           db  'A'
           times 3 db 0

   section .text
       lea  rbx, [pt1]                   ; rbx = &pt1

       ; 读取成员
       mov  eax, [rbx + POINT_X]         ; eax = pt1.x = 10
       mov  edx, [rbx + POINT_Y]         ; edx = pt1.y = 20
       mov  cl,  [rbx + POINT_LABEL]     ; cl  = pt1.label = 'A'

       ; 修改成员
       mov  dword [rbx + POINT_X], 99    ; pt1.x = 99
       mov  byte  [rbx + POINT_LABEL], 'B' ; pt1.label = 'B'

结构体数组
==============

.. code-block:: none

   ; 结构体数组：每个元素大小为 POINT_SIZE
   section .data
       points:                            ; struct Point points[3]
           ; points[0]
           dd  1, 2
           db  'A', 0, 0, 0
           ; points[1]
           dd  3, 4
           db  'B', 0, 0, 0
           ; points[2]
           dd  5, 6
           db  'C', 0, 0, 0
       POINTS_COUNT equ 3

   section .text
       ; 访问 points[i].y
       mov  rdi, 1                        ; 索引 i
       imul rdi, POINT_SIZE               ; 结构体数组偏移
       mov  eax, [points + rdi + POINT_Y] ; points[1].y = 4

       ; 遍历结构体数组
       xor  rcx, rcx                      ; i = 0
       lea  rsi, [points]                 ; 数组首地址
   .loop:
       mov  eax, [rsi + POINT_X]          ; points[i].x
       mov  edx, [rsi + POINT_Y]          ; points[i].y
       ; 处理当前结构体...
       add  rsi, POINT_SIZE               ; 指向下一个
       inc  rcx
       cmp  rcx, POINTS_COUNT
       jl   .loop

对齐与填充（Padding）
==========================

CPU 要求（或推荐）某些数据类型按特定地址对齐。编译器在结构体字段之间插入填充字节以满足对齐要求。

.. list-table::
   :header-rows: 1

   * - 字段类型
     - 大小
     - 对齐要求
   * - ``char``
     - 1
     - 1
   * - ``short``
     - 2
     - 2
   * - ``int`` / ``float``
     - 4
     - 4
   * - ``long`` / ``double`` / 指针
     - 8
     - 8
   * - ``long double`` / SIMD
     - 16
     - 16

.. code-block:: none

   ; 不同字段顺序导致结构体大小不同

   ; 结构体 A：紧凑排列 → 12 字节
   ; offset  size
   ; 0       4     int x
   ; 4       4     int y
   ; 8       1     char c
   ; 9       3     (填充)
   ; total = 12
   STRUCT_A_SIZE equ 12

   ; 结构体 B：交错排列 → 16 字节（更浪费）
   ; offset  size
   ; 0       1     char c
   ; 1       3     (填充)
   ; 4       4     int x
   ; 8       4     int y
   ; total = 12（实际上可能是 12）
   ; 但是如果后面还有 double：
   ; 0       1     char c
   ; 1       7     (填充)
   ; 8       8     double d
   ; 4       4     int x
   ; total = 24（最坏情况）

.. warning::

   为了提高缓存利用率，:strong:`按对齐要求从大到小排列结构体字段`\ （先放指针/浮点，再放 int，最后放 char）。
   这样可以最小化填充字节。编译器在 ``-O2`` 下会自动重排字段，但汇编中需要手动安排。

等价的 C 结构体（使用 ``align`` 伪指令）
============================================

.. code-block:: none

   ; 使用 align 伪指令确保字段对齐
   section .data
       align 8                            ; 确保 8 字节对齐
       my_struct:
           dq  0                          ; long value   [偏移 0]
           dd  0                          ; int count    [偏移 8]
           align 8                        ; 在 count 后填充到 8 字节边界
           dq  0                          ; long ptr     [偏移 16]
       MY_STRUCT_SIZE equ $ - my_struct

结构体作为函数参数
======================

根据 System V ABI，小结构体通过寄存器传递；较大的结构体通过指针传递。

.. code-block:: none

   ; 小结构体通过寄存器传递（每字段一个寄存器）
   ; 对应 C: long process_point(int x, int y)

   ; 结构体通过指针传递（推荐）
   ; 对应 C: void move_point(struct Point *p, int dx, int dy)
   ;
   ; 参数：rdi = 结构体指针，rsi = dx，rdx = dy
   move_point:
       push rbp
       mov  rbp, rsp

       mov  eax, [rdi + POINT_X]          ; p->x
       add  eax, esi                      ; p->x + dx
       mov  [rdi + POINT_X], eax          ; p->x = new_x

       mov  eax, [rdi + POINT_Y]          ; p->y
       add  eax, edx                      ; p->y + dy
       mov  [rdi + POINT_Y], eax          ; p->y = new_y

       pop  rbp
       ret

练习题
========

1. 定义一个 ``Student`` 结构体，包含 ``id`` （8 字节）、``score`` （4 字节）、
   ``grade`` （1 字节）三个字段。手动计算各字段偏移和总大小。

2. 声明并初始化一个 ``Student`` 数组（3 个元素），编写函数遍历数组并计算平均分。

3. 将结构体字段按不同顺序排列，观察总大小的变化。验证"从大到小排列字段可减少填充"
   的论断。

4. 编写 ``init_point`` 函数，通过指针初始化结构体的 x 和 y 字段。
   用 ``call`` 调用并验证结果。

5. 给定一个 ``int`` 数组和结构体数组，对比二者在内存中的布局差异，
   分别计算访问第 N 个元素所需的地址偏移。
