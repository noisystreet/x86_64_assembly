.. _chapter-05-strings:

===============================
字符串操作
===============================

在汇编层面，字符串就是连续存储的字节序列。x86_64 提供了一组专用的字符串指令，配合 ``rep`` 前缀可以高效处理字符串。

字符串的表示
================

Linux 中通常使用 **以 NUL（``0``）结尾** 的字符串（C 字符串风格）：

.. code-block:: none

   section .data
       ; NUL 结尾的字符串（C 风格）
       msg1  db  'Hello, World!', 0

       ; 带显式长度的字符串（Pascal 风格）
       msg2  db  'Hello', 0xA
       len   equ $ - msg2

       ; 转义序列
       newline db 0xA                     ; 换行
       tab     db 0x09                    ; 制表符
       null    db 0                       ; NUL 终止符

计算字符串长度
==================

.. code-block:: none

   ; strlen：返回 NUL 结尾字符串的长度（不包括 NUL）
   ; 参数：rdi = 字符串地址
   ; 返回：rax = 长度
   strlen:
       push rbp
       mov  rbp, rsp
       xor  rax, rax                      ; 长度 = 0
   .loop:
       cmp  byte [rdi + rax], 0           ; 检查当前字节
       je   .done
       inc  rax
       jmp  .loop
   .done:
       pop  rbp
       ret

使用 ``rep scasb`` 有更高效的实现：

.. code-block:: none

   ; 使用 scasb 的 strlen（更高效）
   strlen_fast:
       push rbp
       mov  rbp, rsp
       push rcx

       mov  rdi, [rbp + 16]              ; 字符串地址（或直接使用传入的 rdi）
       xor  rax, rax                      ; al = 0（搜索 NUL）
       mov  rcx, -1                       ; 最大搜索长度（-1 = 无限）
       cld                                 ; 方向标志清零（正向扫描）
       repne scasb                        ; 扫描直到找到 al
       not  rcx                            ; rcx = 找到的字节数
       dec  rcx                            ; 减去 NUL 本身
       mov  rax, rcx

       pop  rcx
       pop  rbp
       ret

字符串复制
==============

.. code-block:: none

   ; strcpy：复制字符串（包括 NUL）
   ; 参数：rdi = 目标地址，rsi = 源地址
   strcpy:
       push rbp
       mov  rbp, rsp
       push rcx
       push rdi                            ; 保存目标地址用于返回

       mov  rcx, -1                        ; 先找到源字符串长度
       xor  rax, rax
       cld
       repne scasb                         ; rcx = ~(strlen + 1)
       not  rcx                             ; rcx = strlen + 1（包括 NUL）

       mov  rsi, [rbp + 24]               ; 源地址（跳过 push 的 rdi, rcx, rbp）
       mov  rdi, [rbp + 16]               ; 目标地址
       cld
       rep movsb                           ; 逐字节复制

       pop  rax                            ; 返回目标地址
       pop  rcx
       pop  rbp
       ret

.. code-block:: none

   ; 更简洁的手工逐字节复制
   strcpy_simple:
       push rbp
       mov  rbp, rsp
   .loop:
       mov  al, [rsi]                      ; 读取源字节
       mov  [rdi], al                      ; 写入目标
       inc  rsi
       inc  rdi
       test al, al                         ; 检查是否为 NUL
       jnz  .loop                          ; 如果不是，继续
       pop  rbp
       ret

字符串比较
==============

.. code-block:: none

   ; strcmp：比较两个字符串
   ; 参数：rdi = 字符串 1，rsi = 字符串 2
   ; 返回：rax = 0（相等），<0（s1 < s2），>0（s1 > s2）
   strcmp:
       push rbp
       mov  rbp, rsp
   .loop:
       mov  al, [rdi]
       mov  bl, [rsi]
       cmp  al, bl
       jne  .done                          ; 遇到不同字符
       test al, al                         ; 检查是否到字符串末尾
       jz   .equal
       inc  rdi
       inc  rsi
       jmp  .loop
   .equal:
       xor  rax, rax                       ; 相等
       pop  rbp
       ret
   .done:
       movzx rax, al                       ; 零扩展到 64 位
       movzx rbx, bl
       sub   rax, rbx                      ; s1[i] - s2[i]
       pop  rbp
       ret

.. note::

   上述 ``strcmp`` 返回的差值符合 C 标准库 ``strcmp`` 的行为：返回值小于 0 表示 ``s1 < s2``，大于 0 表示 ``s1 > s2``。

字符串指令速查
==================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 方向
     - 配合 ``rep`` 前缀
   * - ``movsb``
     - 逐字节复制 ``[rsi] → [rdi]``
     - 自动更新 rsi, rdi
     - ``rep movsb``：复制 rcx 字节
   * - ``movsw``
     - 逐字复制
     - 自动更新 rsi, rdi
     - ``rep movsw``：复制 rcx 个字
   * - ``movsd`` / ``movsq``
     - 逐双字/四字复制
     - 自动更新 rsi, rdi
     - ``rep movsd`` / ``rep movsq``
   * - ``scasb``
     - 扫描 ``al`` 与 ``[rdi]`` 比较
     - 自动更新 rdi
     - ``repne scasb``：找到匹配或 rcx=0
   * - ``cmpsb``
     - 比较 ``[rsi]`` 与 ``[rdi]``
     - 自动更新 rsi, rdi
     - ``repe cmpsb``：相等时继续
   * - ``lodsb``
     - 加载 ``[rsi]`` 到 ``al``
     - 自动更新 rsi
     - ``rep lodsb``：很少用
   * - ``stosb``
     - 存储 ``al`` 到 ``[rdi]``
     - 自动更新 rdi
     - ``rep stosb``：填充 rcx 字节

``cld`` / ``std`` 方向标志
===============================

方向标志 ``DF`` 控制字符串指令自动更新地址的方向：

.. code-block:: none

   cld                                ; DF=0：正向（rsi/rdi 递增）
   std                                ; DF=1：反向（rsi/rdi 递减）

.. code-block:: none

   ; 反向复制字符串（从末尾开始）
   section .bss
       dst  resb 256

   section .text
       std                              ; 设为反向
       mov  rsi, src + 13              ; 指向源字符串末尾
       mov  rdi, dst + 13              ; 指向目标字符串末尾
       mov  rcx, 14                    ; 复制 14 个字节（包括 NUL）
       rep  movsb                      ; 从后往前复制
       cld                              ; 恢复为正向

.. warning::

   使用 ``std`` 后必须记得用 ``cld`` 恢复方向。忘记恢复会导致后续的字符串指令行为异常。在调用 C 标准库函数前，应确保 DF=0。

字符串填充
=============

.. code-block:: none

   ; memset 等效：用指定值填充缓冲区
   ; rdi = 缓冲区，al = 填充值，rcx = 填充字节数
   memset:
       push rbp
       mov  rbp, rsp
       cld
       rep  stosb                        ; 填充缓冲区
       pop  rbp
       ret
