.. _chapter-01-gcc-gas:

===============================
使用 GCC 与 GAS 汇编
===============================

.. 本篇内容

    - 用 ``gcc -S`` 观察编译器输出
    - GAS（GNU Assembler）语法详解
    - NASM 与 GAS 双向转换
    - 在项目中选择哪种汇编器

前面几节用 NASM + Intel 语法完成了所有示例。但你迟早会遇到需要看或写 GAS 语法的情况——

- :strong:`用 ``gcc -S`` 观察编译器输出`：当你想知道 C 代码被编译成了什么汇编，或者怀疑编译器没做好优化时
- :strong:`阅读 Linux 内核代码` ：内核中大量使用 GAS AT&T 语法（尤其是在启动代码和架构相关部分）
- :strong:`与 GCC 工具链集成` ：涉及 ``.cfi`` 指令（调试信息）、``.size`` / ``.type`` （符号类型）等 GCC 特有的伪指令时

好消息是，现代 GAS 支持 ``.intel_syntax noprefix`` 切换到 Intel 语法风格，所以两种语法的迁移成本比你想象的低得多。

通过 ``gcc -S`` 观察汇编输出
================================

编写汇编语言的一个常见场景是：**用 C 写逻辑，用 ``gcc -S`` 看编译器生成的汇编代码**。
这是学习汇编和理解编译器优化的强大手段。

.. code-block:: c
   :caption: test.c

   int add(int a, int b) {
       return a + b;
   }

   int main(void) {
       return add(1, 2);
   }

.. code-block:: bash

   # 生成 AT&T 语法的汇编
   gcc -O2 -S test.c -o test.s

   # 生成 Intel 语法的汇编（GAS Intel 模式）
   gcc -O2 -S -masm=intel test.c -o test.s

生成的 ``test.s`` 文件内容（Intel 语法）：

.. code-block:: none
   :caption: test.s（GAS Intel 语法，简化后）

   .file   "test.c"
   .intel_syntax noprefix
   .text
   .p2align 4

   add:
       mov     eax, edi       # edi 是第 1 个参数（int a）
       add     eax, esi       # esi 是第 2 个参数（int b）
       ret

   main:
       mov     edi, 1
       mov     esi, 2
       call    add
       ret

GAS 语法模式
================

GAS 支持两种语法模式：

AT&T 模式（默认）
-------------------

.. code-block:: none

   mov $1, %rax        # mov src, dst
   mov %rax, %rbx
   mov (%rax), %rcx    # 内存解引用用 ()
   lea (%rdi,%rsi,4), %rax

Intel 模式
--------------

在文件开头添加 ``.intel_syntax noprefix`` 即可切换：

.. code-block:: none

   .intel_syntax noprefix
   mov rax, 1          # mov dst, src
   mov rbx, rax
   mov rcx, [rax]      # 内存解引用用 []
   lea rax, [rdi+rsi*4]

NASM 与 GAS 转换示例
=======================

.. list-table::
   :header-rows: 1

   * - 功能
     - NASM
     - GAS (AT&T)
     - GAS (Intel)
   * - 定义数据段
     - ``section .data``
     - ``.data``
     - ``.data``
   * - 定义代码段
     - ``section .text``
     - ``.text``
     - ``.text``
   * - 导出符号
     - ``global _start``
     - ``.globl _start``
     - ``.globl _start``
   * - 定义字节
     - ``db 0x41``
     - ``.byte 0x41``
     - ``.byte 0x41``
   * - 定义四字
     - ``dq 42``
     - ``.quad 42``
     - ``.quad 42``
   * - 预留空间
     - ``resb 64``
     - ``.space 64``
     - ``.space 64``
   * - 常量定义
     - ``len equ 100``
     - ``len = 100``
     - ``len = 100``
   * - 注释
     - ``;``
     - ``#``
     - ``#``

.. note::

   如果你希望 GCC 生成 NASM 兼容的输出，可以使用 ``gcc -S -masm=intel``
   生成 Intel 语法，然后手动调整差异。不过更常见的做法是：
   直接用 GAS Intel 模式，或仅将 GAS 输出作为参考来手写 NASM。

在项目中选择汇编器
====================

.. list-table::
   :header-rows: 1

   * - 场景
     - 推荐
     - 理由
   * - 学习汇编
     - NASM
     - 语法简洁，无干扰性前缀
   * - 独立汇编项目
     - NASM
     - 跨平台、可读性好
   * - 嵌入到 gcc 编译流程
     - GAS
     - 与工具链无缝集成
   * - 分析编译器输出
     - GAS (Intel)
     - ``gcc -S -masm=intel`` 直接生成
   * - Linux 内核开发
     - GAS (AT&T)
     - 内核代码风格规范

本书使用 NASM 作为教学工具，在第 7 章涉及与 GCC 交互时也会展示 GAS 语法。
