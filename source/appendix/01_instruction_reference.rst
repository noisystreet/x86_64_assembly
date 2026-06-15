.. _appendix-instruction-ref:

=====================================
常用指令快速参考
=====================================

数据传送指令
================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作数
     - 描述
     - 示例
   * - ``mov``
     - dst, src
     - 数据传送
     - ``mov rax, 42``
   * - ``movzx``
     - dst, src
     - 零扩展传送
     - ``movzx rax, al``
   * - ``movsx``
     - dst, src
     - 符号扩展传送
     - ``movsx rax, al``
   * - ``xchg``
     - dst, src
     - 交换（自动原子）
     - ``xchg rax, rbx``
   * - ``lea``
     - dst, src
     - 加载有效地址
     - ``lea rax, [rbx+rcx]``
   * - ``push``
     - src
     - 入栈
     - ``push rax``
   * - ``pop``
     - dst
     - 出栈
     - ``pop rax``
   * - ``cmovcc``
     - dst, src
     - 条件传送
     - ``cmovg rax, rbx``

算术运算指令
================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作数
     - 描述
     - 示例
   * - ``add``
     - dst, src
     - 加法
     - ``add rax, rbx``
   * - ``sub``
     - dst, src
     - 减法
     - ``sub rax, 1``
   * - ``inc``
     - dst
     - 自增 1
     - ``inc rax``
   * - ``dec``
     - dst
     - 自减 1
     - ``dec rcx``
   * - ``mul``
     - src
     - 无符号乘法（rax*src）
     - ``mul rbx``
   * - ``imul``
     - dst, src
     - 有符号乘法
     - ``imul rax, rbx``
   * - ``div``
     - src
     - 无符号除法（rdx:rax/src）
     - ``div rbx``
   * - ``idiv``
     - src
     - 有符号除法
     - ``idiv rbx``
   * - ``neg``
     - dst
     - 取负
     - ``neg rax``

逻辑运算与移位指令
======================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作数
     - 描述
     - 示例
   * - ``and``
     - dst, src
     - 按位与
     - ``and rax, 0xFF``
   * - ``or``
     - dst, src
     - 按位或
     - ``or rax, 0x100``
   * - ``xor``
     - dst, src
     - 按位异或
     - ``xor rax, rax``
   * - ``not``
     - dst
     - 按位取反
     - ``not rax``
   * - ``shl``
     - dst, count
     - 逻辑左移
     - ``shl rax, 3``
   * - ``shr``
     - dst, count
     - 逻辑右移
     - ``shr rax, 1``
   * - ``sar``
     - dst, count
     - 算术右移
     - ``sar rax, 2``
   * - ``rol``
     - dst, count
     - 循环左移
     - ``rol rax, 4``
   * - ``ror``
     - dst, count
     - 循环右移
     - ``ror rax, 4``

控制流指令
==============

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作数
     - 描述
   * - ``jmp``
     - target
     - 无条件跳转
   * - ``je`` / ``jz``
     - target
     - 相等/为零时跳转
   * - ``jne`` / ``jnz``
     - target
     - 不等/非零时跳转
   * - ``jg`` / ``jge``
     - target
     - 大于/大于等于（有符号）
   * - ``jl`` / ``jle``
     - target
     - 小于/小于等于（有符号）
   * - ``ja`` / ``jae``
     - target
     - 高于/高于等于（无符号）
   * - ``jb`` / ``jbe``
     - target
     - 低于/低于等于（无符号）
   * - ``cmp``
     - op1, op2
     - 比较并置标志位
   * - ``test``
     - op1, op2
     - 按位与并置标志位
   * - ``call``
     - target
     - 子程序调用
   * - ``ret``
     -
     - 子程序返回
   * - ``loop``
     - target
     - rcx--; 非零则跳转

系统调用指令
===============

.. list-table::
   :header-rows: 1

   * - 指令
     - 描述
     - 注意事项
   * - ``syscall``
     - 发起系统调用
     - 破坏 rcx 和 r11（分别保存 rip 和 rflags）
   * - ``int 0x80``
     - 传统系统调用（32 位）
     - x86_64 下不建议使用

字符串操作指令
=================

.. list-table::
   :header-rows: 1

   * - 指令
     - 描述
     - 配合 rep 前缀
   * - ``movsb``
     - 复制字节 [rsi]→[rdi]
     - ``rep movsb``
   * - ``movsq``
     - 复制四字 [rsi]→[rdi]
     - ``rep movsq``
   * - ``scasb``
     - 扫描 al 与 [rdi] 比较
     - ``repne scasb``
   * - ``cmpsb``
     - 比较 [rsi] 与 [rdi]
     - ``repe cmpsb``
   * - ``lodsb``
     - 加载 [rsi] 到 al
     - ``rep lodsb``
   * - ``stosb``
     - 存储 al 到 [rdi]
     - ``rep stosb``

SSE/AVX 指令
===============

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 描述
   * - ``movaps`` / ``movapd``
     - [mem] ↔ xmm
     - 对齐的 packed 加载/存储（16 字节）
   * - ``movups`` / ``movupd``
     - [mem] ↔ xmm
     - 未对齐 packed 加载/存储
   * - ``movss`` / ``movsd``
     - [mem] ↔ xmm
     - 标量加载/存储
   * - ``addps`` / ``addpd``
     - xmm, xmm
     - packed 浮点加法
   * - ``mulps`` / ``mulpd``
     - xmm, xmm
     - packed 浮点乘法
   * - ``haddps`` / ``haddpd``
     - xmm, xmm
     - 水平加法
   * - ``sqrtss`` / ``sqrtps``
     - xmm, xmm
     - 平方根
   * - ``cvtsi2ss`` / ``cvtsi2sd``
     - xmm, reg/mem
     - 整数转浮点
   * - ``cvtss2si`` / ``cvtsd2si``
     - reg, xmm
     - 浮点转整数
   * - ``comiss`` / ``comisd``
     - xmm, xmm
     - 比较并置 EFLAGS
   * - ``vmovaps`` / ``vmulps``\ （AVX）
     - ymm, ymm, ymm
     - AVX 三操作数版本
   * - ``vzeroupper``
     -
     - 清除 YMM 高 128 位
