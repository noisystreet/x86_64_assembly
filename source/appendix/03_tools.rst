.. _appendix-tools:

=====================================
工具与调试
=====================================

本节总结 x86_64 汇编开发的常用工具链和 GDB 调试技巧。

NASM 汇编器
===============

.. code-block:: bash

   # 基本用法
   nasm -f elf64 input.asm -o output.o      # 汇编为 64 位 ELF 对象文件
   nasm -f elf64 -l listing.lst input.asm    # 生成列表文件（含偏移量和机器码）
   nasm -f bin input.asm -o output.bin       # 生成纯二进制文件（引导扇区等）

   # 常见选项
   nasm -f elf64 -g -F dwarf input.asm -o output.o  # 带 DWARF 调试信息
   nasm -E input.asm                          # 仅执行预处理（宏展开）

GNU LD 链接器
=================

.. code-block:: bash

   # 基本链接
   ld hello.o -o hello                        # 默认入口 _start
   ld -e main hello.o -o hello                # 指定入口函数

   # 链接标准库和动态链接
   gcc -nostdlib -static hello.o -o hello     # 静态链接（无标准库）
   gcc hello.o -o hello                       # 动态链接（含标准库）

   # 查看链接细节
   ld --verbose                               # 显示默认链接脚本

GNU Debugger (GDB)
=====================

GDB 是调试汇编程序的核心工具。以下是常用调试命令：

.. list-table::
   :header-rows: 1

   * - 命令
     - 简写
     - 说明
   * - ``break _start``
     - ``b _start``
     - 在入口处设断点
   * - ``run``
     - ``r``
     - 启动程序
   * - ``stepi``
     - ``si``
     - 单步执行一条指令
   * - ``nexti``
     - ``ni``
     - 单步执行，跳过函数调用
   * - ``continue``
     - ``c``
     - 继续执行
   * - ``info registers``
     - ``i r``
     - 查看所有寄存器
   * - ``info registers rax rbx``
     - ``i r rax rbx``
     - 查看指定寄存器
   * - ``x/10gx $rsp``
     -
     - 检查内存（以 8 字节为单位显示 10 个元素）
   * - ``x/20xb $rsp``
     -
     - 检查内存（以 1 字节为单位显示 20 个元素）
   * - ``print $rax``
     - ``p $rax``
     - 打印 rax 的值
   * - ``display/8gx $rsp``
     -
     - 每次暂停时自动显示内存
   * - ``layout asm``
     -
     - 切换到汇编界面（TUI 模式）
   * - ``layout reg``
     -
     - 同时显示寄存器和汇编

.. code-block:: bash

   # 调试汇编程序的典型流程
   nasm -f elf64 -g -F dwarf program.asm -o program.o
   ld program.o -o program
   gdb ./program

   # GDB 调试会话示例
   (gdb) break _start              # 在入口断点
   (gdb) run                       # 运行
   (gdb) si                        # 单步执行
   (gdb) info registers            # 查看寄存器状态
   (gdb) x/10gx $rsp               # 查看栈顶 10 个 8 字节值
   (gdb) display/4gx $rsp          # 自动显示栈顶
   (gdb) layout reg                # TUI 模式：同时查看寄存器和代码

objdump 反汇编
==================

.. code-block:: bash

   objdump -d program.o               # 反汇编对象文件
   objdump -d program                 # 反汇编可执行文件
   objdump -S -d program              # 混合源码 + 汇编（需 -g 编译）
   objdump -d -M intel program        # Intel 语法（而非默认的 AT&T）
   objdump -t program                 # 查看符号表
   objdump -x program                 # 查看所有头信息

   # 查看特定函数的汇编
   objdump -d program | grep -A 50 '<my_func>:'

readelf 读取 ELF 信息
========================

.. code-block:: bash

   readelf -h program                # ELF 文件头
   readelf -S program                # 节（Section）信息
   readelf -s program                # 符号表
   readelf -r program                # 重定位信息
   readelf -l program                # 程序头（段）

perf 性能分析
=================

.. code-block:: bash

   # 安装
   sudo apt install linux-tools-common linux-tools-$(uname -r)

   # 基本性能统计
   perf stat ./program

   # 采样分析热点
   perf record ./program
   perf report

   # 指令级热点标注
   perf annotate hot_function

   # 缓存和分支分析
   perf stat -e cache-misses,branch-misses,instructions,cycles ./program

Valgrind 内存检测
=====================

.. code-block:: bash

   # 检查内存泄漏和错误
   valgrind --leak-check=full ./program

   # 汇编代码编译为带符号信息后再检查
   nasm -f elf64 -g -F dwarf program.asm -o program.o
   gcc -no-pie -g program.o -o program
   valgrind ./program

实用技巧
============

.. code-block:: bash

   # 使用 strace 跟踪系统调用
   strace ./program

   # 使用 ltrace 跟踪库调用
   ltrace ./program

   # 查看程序的入口地址
   readelf -h program | grep Entry

   # 查看程序的段布局
   readelf -l program

   # 快速编译和运行 NASM 程序
   nasm -f elf64 program.asm -o program.o && ld program.o -o program && ./program ; echo $?

调试注意事项
================

1. **优化级别**：调试时不要使用优化（GCC 的 ``-O2`` 会使源码与汇编对应关系复杂），汇编代码本身无需考虑优化问题
2. **断点设置**：在标号（label）处设置断点，不要直接在地址上设置
3. **查看内存**：使用 ``x`` 命令时注意格式：``x/gx`` 显示 8 字节十六进制，``x/wx`` 显示 4 字节，``x/s`` 显示字符串，``x/i`` 显示指令
4. **查看标志位**：``info registers eflags`` 查看所有标志位
5. **追踪系统调用**：在汇编程序中先 ``break syscall`` 即可在每次系统调用时中断
