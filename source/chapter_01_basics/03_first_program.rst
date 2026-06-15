.. _chapter-01-first-program:

============================
第一个汇编程序
============================

.. 本篇内容

    - "Hello, World!" 完整示例
    - 汇编、链接、运行三步曲
    - 逐行解读代码
    - 使用 GCC 编译（GAS 语法）

Hello, World!
================

.. code-block:: none
   :caption: examples/hello.asm

   section .data
       msg db 'Hello, World!', 0xA
       len equ $ - msg

   section .text
       global _start

   _start:
       ; write(1, msg, len)
       mov rax, 1
       mov rdi, 1
       mov rsi, msg
       mov rdx, len
       syscall

       ; exit(0)
       mov rax, 60
       xor rdi, rdi
       syscall

汇编、链接、运行三步曲
========================

.. code-block:: bash

   ; 第 1 步：汇编（.asm → .o）
   nasm -f elf64 hello.asm -o hello.o

   ; 第 2 步：链接（.o → 可执行文件）
   ld hello.o -o hello

   ; 第 3 步：运行
   ./hello

逐行解读
============

.. list-table::
   :header-rows: 1

   * - 代码
     - 说明
   * - ``section .data``
     - 数据段开始，存放已初始化的全局数据
   * - ``msg db 'Hello, World!', 0xA``
     - 定义字节序列：字符串 + 换行符（0xA）
   * - ``len equ $ - msg``
     - equ 常量：当前地址减去 msg 地址 = 字符串长度
   * - ``section .text``
     - 代码段开始，存放可执行指令
   * - ``global _start``
     - 将 ``_start`` 标号导出，让链接器知道入口点
   * - ``_start:``
     - 程序入口标号
   * - ``mov rax, 1``
     - 系统调用号：``sys_write`` 为 1
   * - ``mov rdi, 1``
     - 第 1 个参数：文件描述符 stdout
   * - ``mov rsi, msg``
     - 第 2 个参数：缓冲区地址
   * - ``mov rdx, len``
     - 第 3 个参数：写入字节数
   * - ``syscall``
     - 触发系统调用
   * - ``mov rax, 60``
     - 系统调用号：``sys_exit`` 为 60
   * - ``xor rdi, rdi``
     - 退出码 0
   * - ``syscall``
     - 触发系统调用，退出程序

使用 GCC 编译（GAS 语法）
============================

如果不使用 NASM，也可以用 GCC 直接编译汇编代码。GCC 默认使用 GAS（GNU Assembler），
接 AT&T 语法。上面的 Hello World 用 GAS（AT&T）语法写出来是这样的：

.. code-block:: none
   :caption: hello_gas.S（GAS AT&T 语法）

   .data
   msg:    .ascii "Hello, World!\n"
   len = . - msg

   .text
   .globl _start

   _start:
       mov $1, %rax        # sys_write
       mov $1, %rdi        # stdout
       lea msg(%rip), %rsi # 使用 RIP 相对寻址
       mov $len, %rdx      # 长度
       syscall

       mov $60, %rax       # sys_exit
       xor %rdi, %rdi      # exit code 0
       syscall

.. code-block:: bash

   # 用 GCC 编译 GAS 汇编
   gcc -nostdlib -static hello_gas.S -o hello_gas
   ./hello_gas

.. note::

   注意 AT&T 语法与 NASM 的几个关键区别：
   1. 操作数顺序相反：``mov src, dst``（AT&T）vs ``mov dst, src``（NASM）
   2. 寄存器加 ``%`` 前缀
   3. 立即数加 ``$`` 前缀

   本书后续示例均使用 NASM 语法。如果你更熟悉 GAS，可参考 1.4 节的对照表进行转换。
