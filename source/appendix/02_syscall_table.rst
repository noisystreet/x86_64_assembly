.. _appendix-syscall:

=====================================
Linux x86_64 系统调用表
=====================================

以下列出了常见的 Linux x86_64 系统调用。系统调用号通过 ``rax`` 传递，参数依次通过 ``rdi``, ``rsi``, ``rdx``, ``r10``, ``r8``, ``r9`` 传递。

进程控制
============

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 56
     - ``sys_clone``
     - rdi=flags, rsi=stack, rdx=parent_tid, r10=child_tid, r8=tls
     - 创建子进程/线程
   * - 57
     - ``sys_fork``
     -
     - 创建子进程（通常用 clone 代替）
   * - 59
     - ``sys_execve``
     - rdi=path, rsi=argv, rdx=envp
     - 执行新程序
   * - 60
     - ``sys_exit``
     - rdi=error_code
     - 退出程序
   * - 61
     - ``sys_wait4``
     - rdi=pid, rsi=status, rdx=options, r10=rusage
     - 等待子进程
   * - 62
     - ``sys_kill``
     - rdi=pid, rsi=sig
     - 发送信号
   * - 39
     - ``sys_getpid``
     -
     - 获取进程 ID
   * - 186
     - ``sys_gettid``
     -
     - 获取线程 ID

文件操作
============

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 0
     - ``sys_read``
     - rdi=fd, rsi=buf, rdx=count
     - 从文件描述符读取
   * - 1
     - ``sys_write``
     - rdi=fd, rsi=buf, rdx=count
     - 写入文件描述符
   * - 2
     - ``sys_open``
     - rdi=path, rsi=flags, rdx=mode
     - 打开文件
   * - 3
     - ``sys_close``
     - rdi=fd
     - 关闭文件描述符
   * - 4
     - ``sys_stat``
     - rdi=path, rsi=statbuf
     - 获取文件状态
   * - 9
     - ``sys_mmap``
     - rdi=addr, rsi=len, rdx=prot, r10=flags, r8=fd, r9=offset
     - 内存映射
   * - 10
     - ``sys_mprotect``
     - rdi=addr, rsi=len, rdx=prot
     - 修改内存保护
   * - 11
     - ``sys_munmap``
     - rdi=addr, rsi=len
     - 解除内存映射
   * - 12
     - ``sys_brk``
     - rdi=addr
     - 修改堆数据段
   * - 13
     - ``sys_rt_sigaction``
     - rdi=sig, rsi=act, rdx=oldact
     - 设置信号处理函数
   * - 22
     - ``sys_pipe``
     - rdi=pipefd[2]
     - 创建管道
   * - 25
     - ``sys_mremap``
     - rdi=addr, rsi=old_len, rdx=new_len, r10=flags
     - 重新映射内存
   * - 32
     - ``sys_dup``
     - rdi=fd
     - 复制文件描述符
   * - 33
     - ``sys_dup2``
     - rdi=oldfd, rsi=newfd
     - 复制到指定描述符
   * - 41
     - ``sys_socket``
     - rdi=domain, rsi=type, rdx=protocol
     - 创建套接字
   * - 44
     - ``sys_sendto``
     - rdi=fd, rsi=buf, rdx=len, r10=flags, r8=addr, r9=addrlen
     - 发送数据报
   * - 45
     - ``sys_recvfrom``
     - rdi=fd, rsi=buf, rdx=len, r10=flags, r8=addr, r9=addrlen
     - 接收数据报

常见文件操作标志
====================

.. list-table::
   :header-rows: 1

   * - 宏
     - 值
     - 描述
   * - O_RDONLY
     - 0
     - 只读打开
   * - O_WRONLY
     - 1
     - 只写打开
   * - O_RDWR
     - 2
     - 读写打开
   * - O_CREAT
     - 64
     - 文件不存在则创建
   * - O_EXCL
     - 128
     - 与 O_CREAT 共用时，文件存在则失败
   * - O_TRUNC
     - 512
     - 打开时截断文件
   * - O_APPEND
     - 1024
     - 追加模式

开文件权限（mode）示例：

- ``0644``\ （rw-r--r--）：所有者可读写，其他人只读
- ``0755``\ （rwxr-xr-x）：所有者可读写执行，其他人只读执行

.. code-block:: none

   ; sys_open 完整示例
   ; 打开文件用于写入，不存在则创建
   mov rax, 2                 ; sys_open
   mov rdi, filename          ; 文件路径
   mov rsi, O_WRONLY | O_CREAT | O_TRUNC
   mov rdx, 0644              ; 权限
   syscall
   ; rax = 文件描述符（或负的 errno）

mmap 保护标志和映射标志
==============================

.. list-table::
   :header-rows: 1

   * - 宏
     - 值
     - 描述
   * - PROT_READ
     - 1
     - 可读
   * - PROT_WRITE
     - 2
     - 可写
   * - PROT_EXEC
     - 4
     - 可执行
   * - PROT_NONE
     - 0
     - 不可访问
   * - MAP_SHARED
     - 1
     - 共享映射（对文件修改可见）
   * - MAP_PRIVATE
     - 2
     - 私有映射（写时复制）
   * - MAP_ANONYMOUS
     - 32
     - 匿名映射（不映射文件）
   * - MAP_FIXED
     - 16
     - 使用指定地址

同步与时间
==============

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 35
     - ``sys_nanosleep``
     - rdi=req, rsi=rem
     - 休眠指定纳秒
   * - 96
     - ``sys_gettimeofday``
     - rdi=tv, rsi=tz
     - 获取时间
   * - 201
     - ``sys_getcpu``
     - rdi=cpu, rsi=node, rdx=tcache
     - 获取当前 CPU 和 NUMA 节点
   * - 202
     - ``sys_futex``
     - rdi=uaddr, rsi=op, rdx=val, r10=timeout, r8=uaddr2, r9=val3
     - 快速用户态互斥（线程同步核心）

网络通信
============

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 41
     - ``sys_socket``
     - rdi=domain, rsi=type, rdx=protocol
     - 创建套接字
   * - 42
     - ``sys_connect``
     - rdi=fd, rsi=addr, rdx=addrlen
     - 连接远程地址
   * - 49
     - ``sys_bind``
     - rdi=fd, rsi=addr, rdx=addrlen
     - 绑定地址到套接字
   * - 50
     - ``sys_listen``
     - rdi=fd, rsi=backlog
     - 监听连接
   * - 43
     - ``sys_accept``
     - rdi=fd, rsi=addr, rdx=addrlen
     - 接受连接
   * - 44
     - ``sys_sendto``
     - rdi=fd, rsi=buf, rdx=len, r10=flags, r8=addr, r9=addrlen
     - 发送数据报
   * - 45
     - ``sys_recvfrom``
     - rdi=fd, rsi=buf, rdx=len, r10=flags, r8=addr, r9=addrlen
     - 接收数据报
   * - 54
     - ``sys_setsockopt``
     - rdi=fd, rsi=level, rdx=optname, r10=optval, r8=optlen
     - 设置套接字选项
   * - 55
     - ``sys_getsockopt``
     - rdi=fd, rsi=level, rdx=optname, r10=optval, r8=optlen
     - 获取套接字选项

高级 I/O 与事件
===================

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 19
     - ``sys_readv``
     - rdi=fd, rsi=iov, rdx=iovcnt
     - 分散读取（scatter-gather）
   * - 20
     - ``sys_writev``
     - rdi=fd, rsi=iov, rdx=iovcnt
     - 集中写入（scatter-gather）
   * - 17
     - ``sys_pread64``
     - rdi=fd, rsi=buf, rdx=count, r10=pos
     - 指定位置读取（不改变文件偏移）
   * - 18
     - ``sys_pwrite64``
     - rdi=fd, rsi=buf, rdx=count, r10=pos
     - 指定位置写入
   * - 8
     - ``sys_lseek``
     - rdi=fd, rsi=offset, rdx=whence
     - 重定位文件偏移
   * - 40
     - ``sys_sendfile``
     - rdi=out_fd, rsi=in_fd, rdx=offset, r10=count
     - 高效文件到文件描述符传输
   * - 213
     - ``sys_eventfd2``
     - rdi=initval, rsi=flags
     - 创建事件通知文件描述符
   * - 232
     - ``sys_epoll_create1``
     - rdi=flags
     - 创建 epoll 实例
   * - 233
     - ``sys_epoll_ctl``
     - rdi=epfd, rsi=op, rdx=fd, r10=event
     - 控制 epoll 事件
   * - 234
     - ``sys_epoll_wait``
     - rdi=epfd, rsi=events, rdx=evcnt, r10=timeout
     - 等待 epoll 事件

安全与随机数
================

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 317
     - ``sys_seccomp``
     - rdi=op, rsi=flags, rdx=prog
     - 设置安全计算模式（sandbox）
   * - 318
     - ``sys_getrandom``
     - rdi=buf, rsi=buflen, rdx=flags
     - 获取 cryptographically secure 随机数

时间与定时器
================

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 228
     - ``sys_clock_gettime``
     - rdi=clk_id, rsi=tp
     - 获取指定时钟时间（高精度）
   * - 230
     - ``sys_clock_nanosleep``
     - rdi=clk_id, rsi=flags, rdx=req, r10=rem
     - 高精度休眠（指定时钟）
   * - 283
     - ``sys_timerfd_create``
     - rdi=clk_id, rsi=flags
     - 创建定时器文件描述符
   * - 286
     - ``sys_timerfd_settime``
     - rdi=fd, rsi=flags, rdx=new, r10=old
     - 设置定时器参数

更多进程控制
================

.. list-table::
   :header-rows: 1

   * - 编号
     - 名称
     - 参数
     - 描述
   * - 110
     - ``sys_getppid``
     -
     - 获取父进程 ID
   * - 112
     - ``sys_setsid``
     -
     - 创建新会话
   * - 119
     - ``sys_getpgid``
     - rdi=pid
     - 获取进程组 ID
   * - 157
     - ``sys_prctl``
     - rdi=op, rsi=arg2, rdx=arg3, r10=arg4, r8=arg5
     - 进程控制（设置名称、seccomp 等）
   * - 158
     - ``sys_arch_prctl``
     - rdi=code, rsi=addr
     - 架构特定控制（设置 fs.base 等）

.. note::

   上述系统调用号基于 Linux x86_64。不同架构（ARM、RISC-V 等）的系统调用号完全不同。
   可通过 ``/usr/include/asm/unistd_64.h`` 查看完整列表。
