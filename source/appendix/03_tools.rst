.. _appendix-tools:

=====================================
工具与调试
=====================================

.. 本篇内容

    - NASM 汇编器
    - GNU LD 链接器
    - GNU Debugger (GDB)
    - objdump / readelf
    - perf / valgrind

.. code-block:: bash

   ; 常用调试命令
   gdb ./program
   (gdb) break _start
   (gdb) run
   (gdb) info registers
   (gdb) stepi
   (gdb) x/10gx $rsp

TODO: 编写内容
