.. _chapter-01-setup:

===========================
开发环境搭建
===========================

.. 本篇内容

    - 安装 NASM
    - 安装 GNU Debugger (GDB)
    - 安装构建工具 (GCC, GNU Make, ld)
    - 验证安装

本书使用 :strong:`GCC`\ （而非 g++）作为参考编译器，因为 C 的 ABI 更简单直接，最适合学习汇编交互。关于 C++ 的注意事项会在第 7 章说明。

本书涉及的编译器交互使用 :strong:`GCC`\ （GNU C Compiler），它包含在系统的构建工具包中。

.. code-block:: bash

   # Ubuntu/Debian
   sudo apt install nasm gdb build-essential

   # Arch Linux
   sudo pacman -S nasm gdb base-devel

   # macOS (Homebrew)
   brew install nasm gdb gcc

TODO: 编写内容
