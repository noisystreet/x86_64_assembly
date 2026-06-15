.. _chapter-01-setup:

===========================
开发环境搭建
===========================

在开始编写汇编代码之前，需要安装必要的工具链。本节将指导你完成环境配置。

所需工具
============

.. list-table::
   :header-rows: 1

   * - 工具
     - 用途
     - 是否必装
   * - NASM
     - 汇编器：将 .asm 编译为 .o
     - ✅ 必需
   * - GNU ld
     - 链接器：将 .o 链接为可执行文件
     - ✅ 必需（gcc 自带）
   * - GCC
     - C 编译器：用于第 7 章的交互示例
     - ⚠ 可选（建议安装）
   * - GDB
     - 调试器：单步执行、查看寄存器/内存
     - ⚠ 可选（强烈建议）
   * - GNU Make
     - 构建工具：简化编译流程
     - ⚠ 可选（建议安装）

安装命令
==========

.. code-block:: bash

   # Ubuntu/Debian
   sudo apt install nasm gdb build-essential

   # Arch Linux
   sudo pacman -S nasm gdb base-devel

   # macOS (Homebrew)
   brew install nasm gdb gcc

   # Fedora/RHEL
   sudo dnf install nasm gdb gcc make

验证安装
============

安装完成后，运行以下命令确认工具可用：

.. code-block:: bash

   nasm -v          # 应显示 NASM 版本号
   gcc --version    # 应显示 GCC 版本号
   ld --version     # 应显示 GNU ld 版本号
   gdb --version    # 应显示 GDB 版本号

.. code-block:: text
   :caption: 预期输出示例

   NASM version 2.16.01
   gcc (Ubuntu 14.2.0) 14.2.0
   GNU ld (GNU Binutils) 2.43
   GNU gdb (Ubuntu 16.2.0) 16.2.0

本书使用 :strong:`GCC`\ （而非 g++）作为参考编译器，因为 C 的 ABI 更简单直接，最适合学习汇编交互。关于 C++ 的注意事项会在第 7 章说明。

本书涉及的编译器交互使用 :strong:`GCC`\ （GNU C Compiler），它包含在系统的构建工具包中。

.. code-block:: bash

   # Ubuntu/Debian
   sudo apt install nasm gdb build-essential

   # Arch Linux
   sudo pacman -S nasm gdb base-devel

   # macOS (Homebrew)
   brew install nasm gdb gcc
