.. _chapter-02-addressing-modes:

===============================
寻址方式
===============================

.. 本篇内容

    - 立即数寻址
    - 寄存器寻址
    - 直接内存寻址
    - 寄存器间接寻址
    - 基址+变址寻址
    - RIP 相对寻址

.. code-block:: none

   ; 各种寻址方式示例
   mov rax, 42          ; 立即数寻址
   mov rax, rbx         ; 寄存器寻址
   mov rax, [var]       ; 直接内存寻址
   mov rax, [rbx]       ; 寄存器间接寻址
   mov rax, [rbx+rcx]   ; 基址+变址
   mov rax, [rbx+rcx*8] ; 带比例因子的变址

TODO: 编写内容
