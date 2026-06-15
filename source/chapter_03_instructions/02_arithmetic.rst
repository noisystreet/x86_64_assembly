.. _chapter-03-arithmetic:

=============================
算术运算指令
=============================

x86_64 提供了丰富的算术运算指令，涵盖加减乘除、自增自减和取反等操作。

``add`` / ``sub`` 加减法
=============================

.. code-block:: none

   ; 加法
   add rax, rbx          ; rax = rax + rbx
   add rax, 1            ; rax = rax + 1
   add dword [var], 10   ; *var += 10

   ; 减法
   sub rbx, rcx          ; rbx = rbx - rcx
   sub rax, 42           ; rax = rax - 42
   sub qword [counter], 1 ; *counter -= 1

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作数
     - 效果
     - 影响的标志位
   * - ``add``
     - dst, src
     - dst += src
     - OF, SF, ZF, AF, CF, PF
   * - ``sub``
     - dst, src
     - dst -= src
     - OF, SF, ZF, AF, CF, PF

标志位受影响的含义：

- ``ZF``\ （零标志）：结果为 0 时置 1
- ``SF``\ （符号标志）：结果为负时置 1
- ``CF``\ （进位标志）：无符号溢出时置 1
- ``OF``\ （溢出标志）：有符号溢出时置 1

.. code-block:: none

   ; 检测溢出示例
   mov al, 0x80          ; al = -128（有符号）
   sub al, 1             ; al = 0x7F = 127, OF=1（有符号溢出）
                         ; CF=0（无符号未溢出：128-1=127 在 0-255 范围内）

``inc`` / ``dec`` 自增自减
===============================

.. code-block:: none

   inc rax               ; rax = rax + 1
   dec rcx               ; rcx = rcx - 1
   inc dword [counter]   ; *counter += 1

.. note::

   ``inc`` / ``dec`` 不会修改 ``CF`` 进位标志。如果需要同时影响 CF，应使用 ``add dst, 1`` 或 ``sub dst, 1``。

``neg`` 取负
================

.. code-block:: none

   mov rax, 42
   neg rax               ; rax = -42（等效于 sub rax, 0 再取反）

   mov rbx, -100
   neg rbx               ; rbx = 100

``mul`` / ``imul`` 乘法
===========================

x86_64 的乘法需要特别注意操作数的隐含位置：**被乘数隐含在 ``rax`` 中**，乘数作为显式操作数给出。

无符号乘法 ``mul``
---------------------

.. code-block:: none

   ; mul r/m64: rax = rax * r/m64（结果低 64 位存 rax，高 64 位存 rdx）
   mov rax, 1000
   mov rbx, 2000
   mul rbx               ; rax = 1000 * 2000 = 2,000,000

   ; 更宽的结果
   mov rax, 0x100000000  ; rax = 4,294,967,296
   mov rbx, 0x100000000
   mul rbx               ; rax = 0x0000000000000000（低 64 位）
                         ; rdx = 0x0000000000000001（高 64 位）
                         ; 结果：1 * 2^64 = 0x10000000000000000

   ; mul r/m32: edx:eax = eax * r/m32
   mov eax, 50000
   mov ecx, 60000
   mul ecx               ; eax = 低 32 位，edx = 高 32 位
                         ; 结果：3,000,000,000

有符号乘法 ``imul``
-----------------------

``imul`` 有三种形式：

.. code-block:: none

   ; 形式 1：单操作数（同 mul，但针对有符号）
   imul rbx              ; rax = rax * rbx，结果高位在 rdx

   ; 形式 2：双操作数（最常用）
   imul rax, rbx         ; rax = rax * rbx
   imul rax, 42          ; rax = rax * 42
   imul r8, r9, 100      ; r8 = r9 * 100

   ; 形式 3：三操作数（dst, src, imm）
   imul rcx, rdx, 5      ; rcx = rdx * 5
   imul r8, [var], 10    ; r8 = *var * 10

.. warning::

   双操作数和三操作数形式的 ``imul`` 仅保存乘积的 **低 64 位**，丢弃高位。
   它们不产生 ``rdx`` 作为额外输出。如果需要完整的 128 位结果，使用单操作数形式。

``div`` / ``idiv`` 除法
===========================

除法同样使用隐含寄存器：**被除数在 ``rdx:rax``（128 位）中**，除数为显式操作数。

无符号除法 ``div``
---------------------

.. code-block:: none

   ; div r/m64: rdx:rax / r/m64
   ;   商 → rax，余数 → rdx
   mov rax, 100           ; 被除数低 64 位
   xor rdx, rdx           ; 被除数高 64 位清零（rdx = 0）
   mov rbx, 7             ; 除数
   div rbx                ; rax = 100 / 7 = 14（商）
                          ; rdx = 100 % 7 = 2（余数）

   ; 32 位除法
   mov eax, 1000000
   xor edx, edx           ; 清零 edx
   mov ecx, 333
   div ecx                ; eax = 3003, edx = 1

有符号除法 ``idiv``
---------------------

.. code-block:: none

   ; idiv r/m64: rdx:rax / r/m64（有符号）
   ; 除法前需要对 rdx 进行符号扩展

   mov rax, -100          ; 被除数
   cqo                    ; 符号扩展 rax → rdx:rax
                          ; （cqo = Convert Quadword to Octaword）
   mov rbx, 7
   idiv rbx               ; rax = -14, rdx = -2

   ; 32 位有符号除法
   mov eax, -1000
   cdq                    ; 符号扩展 eax → edx:eax
   mov ecx, 7
   idiv ecx               ; eax = -142, edx = -6

符号扩展指令
================

.. list-table::
   :header-rows: 1

   * - 指令
     - 输入
     - 输出
     - 说明
   * - ``cbw``
     - al
     - ax
     - 1 字节 → 2 字节
   * - ``cwd``
     - ax
     - dx:ax
     - 2 字节 → 4 字节
   * - ``cdq``
     - eax
     - edx:eax
     - 4 字节 → 8 字节
   * - ``cqo``
     - rax
     - rdx:rax
     - 8 字节 → 16 字节

.. warning::

   ``div``/``idiv`` 会在 :strong:`除数为 0` 或 :strong:`商溢出`\ （结果放不进目标寄存器）时触发 ``#DE``\ （除法错误）异常，
   导致程序崩溃。始终确保除数不为 0，且被除数 / 除数的结果适合目标寄存器。

.. code-block:: none

   ; 典型的安全除法模式
   safe_div:
       test rbx, rbx            ; 检查除数是否为 0
       jz   .div_by_zero        ; 如果除数为 0，跳转到错误处理
       xor rdx, rdx             ; 清零高 64 位
       div rbx
       ret
   .div_by_zero:
       mov rax, -1              ; 返回 -1 表示错误
       ret
