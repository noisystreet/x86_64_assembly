.. _chapter-01-syntax:

===============================
NASM 语法基础
===============================

本节介绍 NASM 汇编语言的基本语法要素。你将学习如何编写注释、定义标号、使用伪指令、组织段等基础知识。

汇编语言的语法和高级语言有很大不同。想象你在写 Python 或 C 时，编译器替你管理变量名、类型和函数签名。而在汇编中，**你直接面对的是内存、寄存器和字面量**——没有编译器帮你做语义分析，所有细节都要自己掌控。

NASM 的语法被设计得尽量简洁（相比 AT&T 语法少了 ``%`` 和 ``$`` 前缀），这也是本书选择 NASM 的原因。在本节中你会看到它的三个核心设计理念：

- **操作数顺序是 "目标, 源"**：``mov rax, 42`` 表示把 42 复制到 rax，和 C 的赋值一致
- **内存引用用 ``[]``**：``[var]`` 表示"地址 var 处的值"，``[rbx+rcx*8]`` 表示指针解引用
- **标号就是地址**：``my_func:`` 不仅仅是代码标记，它在汇编时会被解析为一个内存地址

注释
=======

NASM 使用 ``;`` （分号）表示单行注释：

.. code-block:: none

   ; 这是注释
   mov rax, 1  ; 指令后的注释

标号（Labels）
================

标号用于标记代码或数据的位置，是跳转和引用地址的锚点：

.. code-block:: none

   global _start       ; 导出标号（对链接器可见）

   _start:             ; 代码标号
       mov rax, 60

   .local_label:       ; 局部标号（以 . 开头，作用域限定在前一个非局部标号内）
       xor rdi, rdi

   data_segment:
   .value: dq 42       ; 数据标号

伪指令（Directives）
======================

伪指令不是 CPU 指令，而是告诉汇编器如何处理代码和数据：

.. list-table::
   :header-rows: 1

   * - 伪指令
     - 说明
     - 示例
   * - ``db``, ``dw``, ``dd``, ``dq``
     - 定义字节/字/双字/四字数据
     - ``msg db 'Hello', 0``
   * - ``resb``, ``resw``, ``resd``, ``resq``
     - 预留未初始化空间
     - ``buf resb 64``
   * - ``equ``
     - 定义常量（编译期求值）
     - ``len equ 100``
   * - ``%define``
     - 宏定义（类似 C 的 ``#define``）
     - ``%define SYS_EXIT 60``
   * - ``global``
     - 导出符号（对链接器可见）
     - ``global _start``
   * - ``extern``
     - 引用外部符号
     - ``extern printf``
   * - ``section`` / ``segment``
     - 切换段
     - ``section .data``

数据定义
============

.. code-block:: none

   ; 初始化数据（section .data）
   byte_val   db  0x41          ; 1 字节
   word_val   dw  0x1234        ; 2 字节
   dword_val  dd  0x12345678    ; 4 字节
   qword_val  dq  0x1234567890ABCDEF  ; 8 字节
   string     db  'Hello', 0    ; 字符串
   array      dd  1, 2, 3, 4    ; 数组
   times 10 db 0xFF             ; 重复 10 次

   ; 未初始化数据（section .bss）
   buffer     resb  1024        ; 预留 1024 字节
   ptr_list   resq  100         ; 预留 100 个四字

段（Sections）
================

NASM 中主要的数据段和代码段：

.. list-table::
   :header-rows: 1

   * - 段
     - 用途
     - 内容
   * - ``section .data``
     - 已初始化数据
     - 全局变量、字符串常量
   * - ``section .bss``
     - 未初始化数据
     - 缓冲区和零初始化的变量
   * - ``section .text``
     - 代码段
     - 可执行指令

操作数表示
=============

.. code-block:: none

   ; 立即数
   mov rax, 42          ; 十进制
   mov rax, 0x2A        ; 十六进制
   mov rax, 0b101010    ; 二进制
   mov rax, 'A'         ; ASCII 字符常量

   ; 寄存器
   mov rax, rbx         ; 寄存器间传送

   ; 内存引用（方括号表示解引用）
   mov rax, [var]       ; 读取 var 的值
   mov [var], rax       ; 写入 var
   mov rax, [rbx]       ; 读取 rbx 指向的值
   mov rax, [rbx+rcx*8] ; 基址+变址*比例

常量与表达式
===============

.. code-block:: none

   ; equ 常量
   BUF_SIZE equ 1024

   ; 编译期表达式
   msg db 'Hello, World!'
   msg_len equ $ - msg    ; $ 表示当前位置

   ; 算术表达式
   SEGMENT_SIZE equ 16 * 1024

GAS（GNU Assembler）语法对照
================================

NASM 并非唯一的汇编器选择。大多数 Linux 系统预装的是 :strong:`GAS` （GNU Assembler，命令 ``as``），
它是 GCC 工具链的一部分。GAS 默认使用 AT&T 语法，也可以通过 ``.intel_syntax noprefix`` 伪指令切换为 Intel 语法。

.. list-table:: GAS 语法模式对比
   :header-rows: 1

   * - 特性
     - NASM
     - GAS (AT&T)
     - GAS (Intel)
   * - 操作数顺序
     - ``mov dst, src``
     - ``mov src, dst``
     - ``mov dst, src``
   * - 寄存器前缀
     - ``rax``
     - ``%rax``
     - ``rax``
   * - 立即数前缀
     - ``42``
     - ``$42``
     - ``42``
   * - 内存引用
     - ``[rax]``
     - ``(%rax)``
     - ``[rax]``
   * - 注释
     - ``;``
     - ``#`` 或 ``/* */``
     - ``#`` 或 ``/* */``
   * - 段定义
     - ``section .data``
     - ``.data``
     - ``.data``
   * - 全局标号
     - ``global _start``
     - ``.globl _start``
     - ``.globl _start``
   * - 伪指令前缀
     - ``db``, ``dw``
     - ``.byte``, ``.word``
     - ``.byte``, ``.word``

.. note::

   本书主线使用 **NASM** 语法，因为它更简洁清晰，适合学习。GAS（AT&T 语法）的使用者可以参考本节对照表理解示例代码。
   第 1.5 节会进一步介绍使用 ``gcc -S`` 观察编译器生成的汇编代码，以及 GAS 的更多细节。
