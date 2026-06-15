.. _chapter-03-syscalls:

=============================
系统调用
=============================

系统调用（System Call）是用户态程序请求内核服务的唯一途径。编写汇编程序时，最常见的两个系统调用是 ``write``\ （输出）和 ``exit``\ （退出）。

Linux x86_64 系统调用机制
=============================

在 x86_64 Linux 中，系统调用通过 ``syscall`` 指令完成。参数和调用号的传递规则如下：

.. list-table::
   :header-rows: 1

   * - 寄存器
     - 用途
   * - ``rax``
     - 系统调用号
   * - ``rdi``
     - 第 1 个参数
   * - ``rsi``
     - 第 2 个参数
   * - ``rdx``
     - 第 3 个参数
   * - ``r10``
     - 第 4 个参数（注意：不是 ``rcx``）
   * - ``r8``
     - 第 5 个参数
   * - ``r9``
     - 第 6 个参数

.. note::

   为什么第 4 个参数用 ``r10`` 而不是 ``rcx``？因为 ``syscall`` 指令内部会使用 ``rcx`` 来保存返回地址（``rcx = rip``），所以 ``rcx`` 被覆盖，无法作为参数传递寄存器。

   系统调用的返回值放在 ``rax`` 中。如果返回值为负值，表示发生了错误（错误码的相反数）。

常见系统调用
================

退出程序（sys_exit）
-----------------------

.. code-block:: none

   ; sys_exit(exit_code)
   mov rax, 60           ; 系统调用号：sys_exit
   mov rdi, 0            ; 退出码：0 表示成功
   syscall

   ; 带错误码退出
   mov rax, 60
   mov rdi, 1            ; 退出码 1（通常表示错误）
   syscall

写入标准输出（sys_write）
---------------------------

.. code-block:: none

   ; sys_write(fd, buf, count)
   ; rdi = 文件描述符（1 = stdout）
   ; rsi = 缓冲区地址
   ; rdx = 写入字节数

   section .data
       msg db 'Hello, World!', 0xA
       len equ $ - msg

   section .text
       mov rax, 1         ; sys_write
       mov rdi, 1         ; stdout
       mov rsi, msg       ; 缓冲区
       mov rdx, len       ; 长度
       syscall

从标准输入读取（sys_read）
-----------------------------

.. code-block:: none

   ; sys_read(fd, buf, count)
   ; rdi = 文件描述符（0 = stdin）
   ; rsi = 缓冲区地址
   ; rdx = 最大读取字节数

   section .bss
       input_buf resb 64

   section .text
       mov rax, 0         ; sys_read
       mov rdi, 0         ; stdin
       mov rsi, input_buf ; 缓冲区
       mov rdx, 64        ; 最大读取 64 字节
       syscall
       ; rax = 实际读取的字节数（0 表示 EOF）

打开文件（sys_open）
-----------------------

.. code-block:: none

   ; sys_open(pathname, flags, mode)
   ; rdi = 文件路径
   ; rsi = 标志（O_RDONLY=0, O_WRONLY=1, O_RDWR=2, O_CREAT=64）
   ; rdx = 权限（创建时需要）

   %define O_RDONLY   0
   %define O_WRONLY   1
   %define O_RDWR     2
   %define O_CREAT    64

   ; 打开已有文件进行读取
   mov rax, 2            ; sys_open
   mov rdi, filename     ; 文件路径
   mov rsi, O_RDONLY     ; 只读
   xor rdx, rdx          ; 不创建文件
   syscall
   ; rax = 文件描述符（或负的错误码）

内存映射（sys_mmap）
-----------------------

.. code-block:: none

   ; sys_mmap(addr, length, prot, flags, fd, offset)
   ; rdi = 建议地址（0 表示让内核选择）
   ; rsi = 长度
   ; rdx = 保护标志
   ; r10 = 映射标志
   ; r8  = 文件描述符（-1 表示匿名映射）
   ; r9  = 偏移量

   %define PROT_READ    1
   %define PROT_WRITE   2
   %define MAP_PRIVATE  2
   %define MAP_ANONYMOUS 0x20

   mov rax, 9            ; sys_mmap
   xor rdi, rdi          ; addr = NULL（内核选择）
   mov rsi, 4096         ; length = 1 页
   mov rdx, PROT_READ | PROT_WRITE
   mov r10, MAP_PRIVATE | MAP_ANONYMOUS
   mov r8, -1            ; fd = -1（无文件）
   xor r9, r9            ; offset = 0
   syscall
   ; rax = 映射的内存地址

系统调用号速查
==================

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 功能
     - 参数
   * - 0
     - ``sys_read``
     - 从文件描述符读取
     - rdi=fd, rsi=buf, rdx=count
   * - 1
     - ``sys_write``
     - 写入文件描述符
     - rdi=fd, rsi=buf, rdx=count
   * - 2
     - ``sys_open``
     - 打开文件
     - rdi=path, rsi=flags, rdx=mode
   * - 3
     - ``sys_close``
     - 关闭文件描述符
     - rdi=fd
   * - 9
     - ``sys_mmap``
     - 内存映射
     - rdi=addr, rsi=len, rdx=prot, r10=flags, r8=fd, r9=offset
   * - 10
     - ``sys_mprotect``
     - 修改内存保护
     - rdi=addr, rsi=len, rdx=prot
   * - 11
     - ``sys_munmap``
     - 解除内存映射
     - rdi=addr, rsi=len
   * - 12
     - ``sys_brk``
     - 修改堆数据段
     - rdi=addr
   * - 56
     - ``sys_clone``
     - 创建子进程/线程
     - rdi=flags, rsi=stack
   * - 60
     - ``sys_exit``
     - 退出程序
     - rdi=error_code
   * - 61
     - ``sys_wait4``
     - 等待子进程
     - rdi=pid, rsi=status, rdx=options
   * - 62
     - ``sys_kill``
     - 发送信号
     - rdi=pid, rsi=sig

错误处理
============

系统调用返回负值时表示出错，该值的绝对值即为 ``errno`` 错误码。

.. code-block:: none

   ; 带错误处理的系统调用
   section .data
       err_msg db 'Error occurred!', 0xA
       err_len equ $ - err_msg

   section .text
       ; 尝试打开文件
       mov rax, 2           ; sys_open
       mov rdi, filename
       mov rsi, 0           ; O_RDONLY
       xor rdx, rdx
       syscall

       test rax, rax         ; 检查返回值
       js   .error           ; 负数表示错误

       ; 正常处理，rax 为文件描述符
       ; ...

   .error:
       ; rax 中的负数是 -errno
       neg rax               ; rax = errno 值
       ; 打印错误消息
       mov rax, 1            ; sys_write
       mov rdi, 1
       mov rsi, err_msg
       mov rdx, err_len
       syscall
       mov rax, 60
       mov rdi, 1
       syscall
