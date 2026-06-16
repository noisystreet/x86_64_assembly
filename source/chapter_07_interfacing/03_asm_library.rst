.. _chapter-07-library:

===============================
编写汇编库
===============================

将汇编代码封装为可重用的库（静态库或共享库），是现代汇编工程实践的重要组成部分。

想一想你在 C 中怎么复用代码：把重复使用的函数放进 ``.c`` 文件，编译成 ``.o``，再打包成 ``.a`` 或 ``.so``。汇编也一样——**把通用的工具函数抽离出来，避免在每个程序里重复写同样的汇编代码**。

最常见的汇编库用法有两类：

- :strong:`数学运算库`：自定义的乘法/除法/浮点操作，编译器可能无法自动向量化或优化到满意的程度
- :strong:`系统调用包装`：把 ``sys_read``、``sys_write``、``sys_exit`` 等封装成便于调用的函数，省去每次写 ``mov rax, N`` 的重复劳动

有三种库形态：:strong:`静态库` （.a，链接时嵌入可执行文件）、:strong:`共享库` （.so，运行时动态加载）和:strong:`头文件宏库` （.inc，汇编时 ``%include`` 展开）。你可以根据使用场景选择：静态库部署简单，共享库节省磁盘/内存，宏库零开销但只适合小规模代码。

导出符号

使用 ``global`` 伪指令将汇编标号导出，使链接器和其他目标文件可以引用：

.. code-block:: none

   ; math_utils.asm——汇编数学库
   section .text

   ; 导出所有公共函数
   global add_i64
   global sub_i64
   global mul_i64
   global div_i64

   ; long add_i64(long a, long b)
   add_i64:
       mov rax, rdi
       add rax, rsi
       ret

   ; long sub_i64(long a, long b)
   sub_i64:
       mov rax, rdi
       sub rax, rsi
       ret

   ; long mul_i64(long a, long b)
   mul_i64:
       mov rax, rdi
       imul rax, rsi
       ret

   ; long div_i64(long a, long b)
   div_i64:
       test rsi, rsi            ; 除零检查
       jz   .error
       xor rdx, rdx
       mov rax, rdi
       idiv rsi
       ret
   .error:
       mov rax, -1
       ret

创建静态库（.a）
===================

.. code-block:: bash

   # 汇编为对象文件
   nasm -f elf64 math_utils.asm -o math_utils.o

   # 创建静态库
   ar rcs libmath.a math_utils.o

   # 查看库中的符号
   nm libmath.a

   # 使用静态库
   gcc main.c -L. -lmath -o program

创建共享库（.so）
===================

共享库需要位置无关代码（PIC, Position-Independent Code）：

.. code-block:: none

   ; string_utils.asm——位置无关的字符串库
   section .text
       global strlen_pic
       global strcpy_pic

   ; size_t strlen_pic(const char *s)
   strlen_pic:
       xor rax, rax
   .loop:
       cmp byte [rdi + rax], 0
       je .done
       inc rax
       jmp .loop
   .done:
       ret

   ; char *strcpy_pic(char *dst, const char *src)
   strcpy_pic:
       xor rax, rax
   .loop:
       mov cl, [rsi + rax]
       mov [rdi + rax], cl
       inc rax
       test cl, cl
       jnz .loop
       mov rax, rdi
       ret

.. code-block:: bash

   # 编译为位置无关的对象文件
   nasm -f elf64 string_utils.asm -o string_utils.o

   # 创建共享库
   gcc -shared string_utils.o -o libstring.so

   # 使用共享库
   gcc main.c -L. -lstring -o program

   # 确保运行时能找到库
   export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
   ./program

带有 C 头文件的汇编库
=========================

创建一个完整的汇编库，使 C 代码可以像调用普通 C 函数一样使用：

.. code-block:: c
   :caption: include/math_utils.h

   #ifndef MATH_UTILS_H
   #define MATH_UTILS_H

   long add_i64(long a, long b);
   long sub_i64(long a, long b);
   long mul_i64(long a, long b);
   long div_i64(long a, long b);

   #endif

.. code-block:: c
   :caption: main.c（使用汇编库）

   #include <stdio.h>
   #include "include/math_utils.h"

   int main(void) {
       long a = 100, b = 7;
       printf("%ld + %ld = %ld\n", a, b, add_i64(a, b));
       printf("%ld - %ld = %ld\n", a, b, sub_i64(a, b));
       printf("%ld * %ld = %ld\n", a, b, mul_i64(a, b));
       printf("%ld / %ld = %ld rem %ld\n",
              a, b, div_i64(a, b), a % b);
       return 0;
   }

.. code-block:: bash

   # 完整构建流程
   nasm -f elf64 math_utils.asm -o math_utils.o
   ar rcs libmath.a math_utils.o
   gcc main.c -L. -lmath -o program
   ./program

使用 NASM 宏组织代码
=========================

对于较大的库，使用宏可以提高可维护性：

.. code-block:: none

   ; 宏：定义导出函数
   %macro export_func 1
       global %1
       %1:
   %endmacro

   ; 宏：函数序言
   %macro func_prologue 0
       push rbp
       mov  rbp, rsp
   %endmacro

   ; 宏：函数尾声
   %macro func_epilogue 0
       pop  rbp
       ret
   %endmacro

   section .text
       export_func abs_i64       ; 展开为 global abs_i64 / abs_i64:
       func_prologue
       test rdi, rdi
       jns .done
       neg rdi
   .done:
       mov rax, rdi
       func_epilogue

C 与汇编混合工程结构建议
============================

.. code-block:: text

   project/
   ├── include/           # 头文件（声明汇编函数）
   │   ├── math_utils.h
   │   └── string_utils.h
   ├── src/               # C 源码
   │   └── main.c
   ├── asm/               # 汇编源码
   │   ├── math_utils.asm
   │   └── string_utils.asm
   ├── lib/               # 生成的库文件
   │   ├── libmath.a
   │   └── libstring.so
   ├── Makefile
   └── README.md

练习题
========

1. 创建 ``math_utils.asm`` 文件，导出 ``add_i64``、``sub_i64``、``mul_i64``、``div_i64``
   四个函数。编写 C 程序调用它们，编译并运行。

2. 将上述函数打包为静态库 ``libmath.a``，在编译 C 程序时通过 ``-lmath`` 链接。

3. 将其中一部分函数改为共享库 ``libmath.so``，运行时通过 ``LD_LIBRARY_PATH`` 加载。

4. 编写一个汇编函数 ``reverse_str``，接收 C 字符串指针，原地反转字符串。
   在 C 代码中声明并调用它。

5. 在 C 代码中使用 ``asm`` 关键字（内联汇编）实现一个简单的 ``cpuid`` 指令封装，
   读取 CPU 的 vendor ID 字符串。
