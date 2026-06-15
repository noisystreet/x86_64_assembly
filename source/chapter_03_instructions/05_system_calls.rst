.. _chapter-03-syscalls:

=============================
系统调用
=============================

.. 本篇内容

    - Linux 系统调用机制
    - syscall 指令
    - 参数传递规则（rdi, rsi, rdx, r10, r8, r9）
    - 常见系统调用（read, write, exit, mmap, brk）
    - 错误处理

.. code-block:: none
   :caption: 常用系统调用号（x86_64）

   sys_read  = 0
   sys_write = 1
   sys_open  = 2
   sys_close = 3
   sys_mmap  = 9
   sys_exit  = 60

TODO: 编写内容
