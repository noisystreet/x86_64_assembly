.. _chapter-09-threads:

===============================
线程基础
===============================

在 Linux 中，线程和进程都是通过 ``clone`` 系统调用创建的。线程本质上是共享地址空间的轻量级进程。

clone 系统调用
==================

``clone``（系统调用号 56）比 ``fork`` 更灵活，可以精确控制父子进程/线程共享哪些资源。

.. code-block:: none

   ; sys_clone(flags, stack, parent_tid, child_tid, tls)
   ; rdi = flags（共享资源标志）
   ; rsi = 子线程栈地址
   ; rdx = parent_tid（父线程 TID 地址）
   ; r10 = child_tid（子线程 TID 地址）
   ; r8  = tls（线程本地存储地址）

.. list-table:: clone flags（部分）
   :header-rows: 1

   * - 标志
     - 值
     - 含义
   * - CLONE_VM
     - 0x100
     - 共享地址空间（线程的核心特征）
   * - CLONE_FS
     - 0x200
     - 共享文件系统信息（umask, cwd）
   * - CLONE_FILES
     - 0x400
     - 共享文件描述符表
   * - CLONE_SIGHAND
     - 0x800
     - 共享信号处理函数
   * - CLONE_THREAD
     - 0x10000
     - 同一线程组（getpid 返回相同值）
   * - CLONE_SYSVSEM
     - 0x40000
     - 共享 System V 信号量
   * - CLONE_SETTLS
     - 0x80000
     - 设置线程本地存储
   * - CLONE_PARENT_SETTID
     - 0x1000000
     - 将子 TID 写入父线程
   * - CLONE_CHILD_SETTID
     - 0x2000000
     - 将子 TID 写入子线程

.. note::

   创建线程时，以上标志通常一起使用。一个经典的组合是：

   .. code-block:: none

      ; 线程标志组合
      THREAD_FLAGS equ \
          CLONE_VM       | \   ; 共享地址空间
          CLONE_FS       | \   ; 共享文件系统
          CLONE_FILES    | \   ; 共享文件描述符
          CLONE_SIGHAND  | \   ; 共享信号处理
          CLONE_THREAD           ; 同一线程组

   注意 ``CLONE_THREAD`` 的缺失后果：没有它，``clone`` 创建的是一个**进程**（子进程），
   而非线程（子进程拥有独立的 PID）。

   Linux 5.3 引入了更新、更灵活的 ``clone3`` 系统调用（RAX=435），
   通过结构体传递参数，避免了 ``clone`` 参数过多的可维护性问题。

线程创建示例
================

.. code-block:: none

   ; thread_create.asm——创建线程
   section .data
       ; 线程标志：共享地址空间、文件系统、文件描述符、信号处理
       CLONE_FLAGS equ 0x100 | 0x200 | 0x400 | 0x800 | 0x10000
       STACK_SIZE  equ 4096 * 4                    ; 16 KB 栈空间
       msg         db "Hello from thread!", 0xA, 0
       msg_len     equ $ - msg

   section .bss
       stack       resb STACK_SIZE                 ; 线程栈
       child_tid   resq 1                          ; 子线程 TID

   section .text
       extern printf
       global _start

   _start:
       ; 创建线程
       mov rdi, CLONE_FLAGS
       lea rsi, [stack + STACK_SIZE]               ; 栈从高地址向低增长
       mov rdx, 0                                   ; parent_tid = NULL
       mov r10, child_tid                          ; child_tid 地址
       mov r8, 0                                    ; tls = NULL
       mov rax, 56                                  ; sys_clone
       syscall

       test rax, rax
       jz   .child                                  ; rax=0 表示子线程
       jmp  .parent                                 ; rax>0 表示父进程（返回 TID）

   .child:
       ; 子线程代码
       mov rdi, msg
       xor rax, rax
       call printf

       ; 子线程退出
       mov rax, 60                                   ; sys_exit
       xor rdi, rdi
       syscall

   .parent:
       ; 父进程等待子线程
       ; 注意：简单示例中父进程直接退出
       ; 实际应用应该使用 futex 或 join 机制
       mov rax, 60
       xor rdi, rdi
       syscall

.. warning::

   上述示例使用 ``sys_exit`` 退出子线程是简化的做法。在生产代码中，
   应该使用 ``sys_exit``（线程退出）或 ``pthread_exit``。直接退出会导致整个进程退出。

线程本地存储（TLS）
=====================

线程本地存储（Thread-Local Storage, TLS）允许每个线程拥有自己的数据副本。
x86_64 通过 ``fs`` 段寄存器实现 TLS。

.. code-block:: none

   ; 设置 TLS（在 clone 时使用 CLONE_SETTLS 标志）
   section .data
       tls_area:
           dq 0                    ; 线程本地变量 1
           dq 0                    ; 线程本地变量 2

   section .text
       ; 创建线程时设置 TLS
       mov rdi, CLONE_FLAGS | 0x80000        ; 添加 CLONE_SETTLS
       lea rsi, [stack + STACK_SIZE]
       mov r10, child_tid
       mov r8, tls_area                      ; r8 = TLS 区域地址
       mov rax, 56
       syscall

       ; 在线程中访问 TLS
       mov rax, [fs:0]                       ; 访问 TLS 变量 1
       mov qword [fs:8], 42                  ; 设置 TLS 变量 2

.. note::

   TLS 的底层机制是 ``fs`` 段寄存器的基地址（Base Address）。x86_64 提供了
   ``arch_prctl`` 系统调用（RAX=158）来读写 ``fs`` 基地址：

   .. code-block:: none

      ; 使用 arch_prctl 设置 fs.base
      ; 参数：rdi = 操作码，rsi = 地址
      ; ARCH_SET_FS = 0x1002（设置 fs.base）
      ; ARCH_GET_FS = 0x1003（读取 fs.base）

      mov  rdi, 0x1002          ; ARCH_SET_FS
      mov  rsi, tls_area        ; 设置 fs.base = tls_area
      mov  rax, 158             ; sys_arch_prctl
      syscall

   C 运行时（glibc）的 ``pthread_create`` 会为每个线程分配 TLS 区域，
   并通过 ``arch_prctl`` 设置 ``fs.base``。因此汇编中直接调用 ``pthread``
   接口时，无需手动处理 TLS 设置。

线程生命周期
================

一个线程从创建到结束经历以下状态：

.. list-table::
   :header-rows: 1

   * - 阶段
     - 说明
     - 关键操作
   * - 创建
     - ``clone`` 系统调用返回新的 TID
     - 分配栈空间，设置 TLS
   * - 运行
     - 线程函数执行
     - 使用共享内存/锁/信号量
   * - 等待
     - 线程主动调用 ``futex(FUTEX_WAIT)`` 或等待锁
     - 进入阻塞状态，不消耗 CPU
   * - 终止
     - 线程函数 ``ret`` 或调用 ``sys_exit``
     - 释放栈空间，通知其他线程

``pthread_join`` 对应等待阶段：调用线程阻塞直到目标线程终止，
   并回收其退出状态。如果线程已经终止，``pthread_join`` 立即返回。

.. code-block:: none

   ; 线程生命周期示意图
   ;
   ;   主线程                          子线程
   ;     │                               │
   ;     ├── pthread_create() ──────────► │
   ;     │                               │
   ;     │ (继续执行)                    ├── 执行线程函数
   ;     │                               │ ...
   ;     │                               │
   ;     ├── pthread_join() ──────────────┤ 线程退出
   ;     │ (等待子线程结束)               │
   ;     │      │                         │
   ;     │ ◄───结束───────────────────────┘
   ;     │                               │

使用 futex 等待线程结束
============================

futex（Fast Userspace Mutex）是 Linux 线程同步的核心机制：

.. code-block:: none

   ; futex 系统调用（系统调用号 202）
   ; sys_futex(uaddr, op, val, timeout, uaddr2, val3)
   ; rdi = futex 地址
   ; rsi = 操作（FUTEX_WAIT=0, FUTEX_WAKE=1）
   ; rdx = 期望值 / 唤醒数量

   section .data
       futex_val dq 0               ; futex 状态值

   section .text
       ; 等待 futex 值变为 1
       mov rdi, futex_val
       mov rsi, 0                    ; FUTEX_WAIT
       mov rdx, 0                    ; 期望当前值为 0
       mov r10, 0                    ; timeout = NULL
       mov rax, 202
       syscall

       ; 唤醒等待者
       mov rdi, futex_val
       mov rax, 1                    ; FUTEX_WAKE
       mov rdx, 1                    ; 唤醒 1 个线程
       mov rax, 202
       syscall

使用 pthread 库（C 语言包装）
================================

在汇编中直接使用 ``clone`` 很繁琐。更实用的方式是通过 C 的 ``pthread`` 库：

.. code-block:: none

   ; 调用 pthread_create 和 pthread_join
   section .data
       msg      db "Thread running!", 0xA, 0
       thread_id dq 0

   section .text
       extern pthread_create, pthread_join, printf

       ; pthread_create(&thread, NULL, thread_func, arg)
       mov rdi, thread_id               ; 输出线程 ID
       xor rsi, rsi                      ; 默认属性
       mov rdx, thread_func             ; 线程函数
       xor rcx, rcx                      ; 无参数
       call pthread_create

       ; pthread_join(thread, NULL)
       mov rdi, [thread_id]
       xor rsi, rsi
       call pthread_join

       ; ... 主线程继续 ...

   thread_func:
       push rbp
       mov  rbp, rsp
       mov  rdi, msg
       xor  rax, rax
       call printf
       pop  rbp
       ret

.. code-block:: bash

   # 编译链接线程程序
   nasm -f elf64 thread_demo.asm -o thread_demo.o
   gcc thread_demo.o -lpthread -o thread_demo
   ./thread_demo
