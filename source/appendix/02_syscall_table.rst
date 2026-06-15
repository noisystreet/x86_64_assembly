.. _appendix-syscall:

=====================================
Linux x86_64 系统调用表
=====================================

.. list-table::
   :header-rows: 1

   * - 系统调用号
     - 名称
     - 参数
     - 描述
   * - 0
     - sys_read
     - rdi=fd, rsi=buf, rdx=count
     - 从文件描述符读取
   * - 1
     - sys_write
     - rdi=fd, rsi=buf, rdx=count
     - 写入文件描述符
   * - 2
     - sys_open
     - rdi=path, rsi=flags, rdx=mode
     - 打开文件
   * - 3
     - sys_close
     - rdi=fd
     - 关闭文件描述符
   * - 9
     - sys_mmap
     - rdi=addr, rsi=len, rdx=prot, r10=flags, r8=fd, r9=offset
     - 内存映射
   * - 60
     - sys_exit
     - rdi=error_code
     - 退出程序

TODO: 扩展为完整系统调用表
