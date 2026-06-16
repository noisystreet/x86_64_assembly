.. _chapter-01-macros:

===============================
NASM 宏与预处理
===============================

NASM 提供了强大的宏和预处理功能，可以在汇编时生成重复代码、定义常量和条件编译。

单行宏（``%define``）
=========================

``%define`` 类似 C 的 ``#define``，定义一个文本替换：

.. code-block:: none

   ; 常量定义
   %define SYS_EXIT  60
   %define SYS_WRITE 1
   %define STDIN     0
   %define STDOUT    1

   section .text
       mov rax, SYS_EXIT      ; 展开为 mov rax, 60
       xor rdi, rdi
       syscall

   ; 带参数的单行宏
   %define PRINT(reg) mov rdi, reg ; call printf

   ; 条件宏
   %define IS_ZERO(val) val == 0

   ; 取消定义
   %undef SYS_EXIT

``%assign`` 与 ``%defstr``
==============================

``%assign`` 定义数值常量（支持表达式求值），``%defstr`` 将值转换为字符串：

.. code-block:: none

   %assign VERSION 1
   %assign VERSION VERSION + 1        ; 可以重新赋值

   %defstr VERSION_STR VERSION        ; "2"

多行宏（``%macro`` / ``%endmacro``）
=======================================

.. code-block:: none

   ; 定义无参数宏
   %macro prologue 0
       push rbp
       mov  rbp, rsp
   %endmacro

   ; 定义带参数的宏
   %macro func_prologue 1
       push rbp
       mov  rbp, rsp
       sub  rsp, %1                   ; %1 = 局部变量空间大小
   %endmacro

   ; 使用宏
   my_func:
       func_prologue 32               ; 展开为 push rbp / mov rbp, rsp / sub rsp, 32
       ; ...
       mov rsp, rbp
       pop rbp
       ret

.. code-block:: none

   ; 多个参数的宏
   %macro swap 2
       push %1
       push %2
       pop  %1
       pop  %2
   %endmacro

   swap rax, rbx                      ; 交换 rax 和 rbx

   ; 可变参数宏（%{1} 到 %{n}，$$ 表示参数个数）
   %macro muls 1-*
       %rep %0
           imul %1, %2
           %rotate 1                  ; 旋转参数列表
       %endrep
   %endmacro

.. list-table::
   :header-rows: 1

   * - 宏参数
     - 含义
   * - ``%1``, ``%2``, ...
     - 第 1, 2, ... 个参数
   * - ``%0``
     - 参数个数
   * - ``%{-1}``
     - 最后一个参数
   * - ``%rotate N``
     - 循环旋转参数列表

条件汇编
============

.. code-block:: none

   ; %if / %elif / %else / %endif
   %define DEBUG 1

   %ifdef DEBUG
       %define LOG(msg) mov rdi, msg ; call printf
   %else
       %define LOG(msg)              ; 空定义
   %endif

   ; %ifidni 不区分大小写的字符串比较
   %ifidni ARCH, x86_64
       %define BITS 64
   %elifidni ARCH, i386
       %define BITS 32
   %else
       %error "Unsupported architecture"
   %endif

.. list-table::
   :header-rows: 1

   * - 条件指令
     - 说明
   * - ``%ifdef`` / ``%ifndef``
     - 检查宏是否定义
   * - ``%ifidni`` / ``%ifnidni``
     - 不区分大小写字符串比较
   * - ``%ifidn`` / ``%ifnidn``
     - 区分大小写字符串比较
   * - ``%ifctx`` / ``%ifnctx``
     - 检查是否在某个上下文（上下文栈）
   * - ``%error`` / ``%warning``
     - 在汇编时输出错误/警告

重复块
==========

.. code-block:: none

   ; %rep / %endrep——重复代码块
   %rep 5
       inc rax
   %endrep
   ; 展开为 5 次 inc rax

   ; 带计数器的重复
   %assign i 0
   %rep 10
       dq i * 2
       %assign i i + 1
   %endrep
   ; 生成 0, 2, 4, ..., 18

   ; %exitrep——提前退出
   %rep 100
       %if i >= 10
           %exitrep
       %endif
       db i
       %assign i i + 1
   %endrep

文件包含
============

.. code-block:: none

   ; %include——包含其他文件
   %include "macros.inc"              ; 包含宏定义文件
   %include "syscalls.inc"            ; 包含系统调用号常量

   ; 被包含的文件：syscalls.inc
   ; %define SYS_READ  0
   ; %define SYS_WRITE 1
   ; ...

   ; %pathsearch——搜索包含路径
   %pathsearch COMMON_MACROS "common/macros.inc"
   %include COMMON_MACROS

.. code-block:: bash

   # 指定包含搜索路径
   nasm -f elf64 -I include/ -I /usr/share/nasm/ program.asm -o program.o

上下文栈
============

上下文栈（Context Stack）用于实现更复杂的宏状态管理：

.. code-block:: none

   ; 上下文栈的推入/弹出
   %push myctx                    ; 推入名为 myctx 的上下文
       %define LOCAL_VAR 42
       ; ... 在此上下文中工作 ...
   %pop                            ; 弹出上下文，LOCAL_VAR 失效

   ; 检查是否在特定上下文中
   %ifctx myctx
       ; 在 myctx 上下文中
   %else
       ; 不在 myctx 上下文中
   %endif

   ; 嵌套上下文
   %push outer
       %define X 1
       %push inner
           ; 可以访问 outer 和 inner 中的定义
       %pop     ; 弹出 inner
       ; X 1 仍然有效
   %pop        ; 弹出 outer

宏使用建议
==============

.. list-table::
   :header-rows: 1

   * - 场景
     - 推荐
     - 说明
   * - 常量定义
     - ``%define`` / ``equ``
     - 数值常量用 ``equ``，带参数的文本替换用 ``%define``
   * - 可重用代码段
     - ``%macro`` / ``%endmacro``
     - 函数序言/尾声、系统调用包装
   * - 条件编译
     - ``%ifdef`` / ``%if``
     - 调试模式、平台适配
   * - 数据表格生成
     - ``%rep`` / ``%endrep``
     - 查找表、初始化数组
   * - 项目组织
     - ``%include``
     - 将常量、宏定义分离到独立文件
