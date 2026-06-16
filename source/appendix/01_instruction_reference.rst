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

SIMD 整数指令（SSE2）
=========================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 描述
   * - ``paddb`` / ``paddw`` / ``paddd`` / ``paddq``
     - xmm, xmm
     - 整数加法（字节/字/双字/四字）
   * - ``psubb`` / ``psubw`` / ``psubd`` / ``psubq``
     - xmm, xmm
     - 整数减法
   * - ``pmullw`` / ``pmuludq``
     - xmm, xmm
     - 整数乘法（低 16 位/无符号双字→四字）
   * - ``paddusb`` / ``paddusw``
     - xmm, xmm
     - 饱和无符号加法（自动钳位到 [0, 255]/[0, 65535]）
   * - ``psubusb`` / ``psubusw``
     - xmm, xmm
     - 饱和无符号减法
   * - ``pavgb`` / ``pavgw``
     - xmm, xmm
     - 平均值（四舍五入）
   * - ``pminub`` / ``pmaxub``
     - xmm, xmm
     - 字节最小/最大值
   * - ``pand`` / ``por`` / ``pxor``
     - xmm, xmm
     - 按位运算
   * - ``psllw`` / ``psrld`` / ``psrad``
     - xmm, imm
     - 移位（逻辑/算术）

位操作指令
=================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 描述
     - 设置标志位
   * - ``bsf``
     - dst, src
     - 位扫描正向（从 LSB 开始找第一个 1）
     - ZF
   * - ``bsr``
     - dst, src
     - 位扫描反向（从 MSB 开始找第一个 1）
     - ZF
   * - ``popcnt``
     - dst, src
     - 统计 1 的个数（需 POPCNT 支持）
     - ZF
   * - ``lzcnt``
     - dst, src
     - 前导零计数（需 LZCNT 支持）
     - ZF, CF
   * - ``tzcnt``
     - dst, src
     - 尾随零计数（需 BMI1 支持）
     - ZF, CF
   * - ``andn``
     - dst, src1, src2
     - 与非：dst = ~src1 & src2（BMI1）
     - 无
   * - ``bextr``
     - dst, src, control
     - 位域提取（BMI1）
     - ZF
   * - ``bzhi``
     - dst, src, index
     - 高位清零（BMI2）
     - 无
   * - ``mulx``
     - dst_hi, dst_lo, src
     - 无进位乘法（BMI2）
     - 无

原子操作指令
=================

.. list-table::
   :header-rows: 1

   * - 指令
     - 操作
     - 描述
   * - ``xadd``
     - dst, src
     - 交换并相加：dst += src, src = 原 dst 值
   * - ``cmpxchg``
     - dst, src
     - 比较并交换：若 [dst]==rax 则 [dst]=src，否则 rax=[dst]
   * - ``cmpxchg8b``
     - dst
     - 比较交换 8 字节：若 [dst]==edx:eax 则写入 ecx:ebx
   * - ``cmpxchg16b``
     - dst
     - 比较交换 16 字节（需 CMPXCHG16B 支持）
   * - ``xchg``
     - dst, src
     - 交换（遇内存时自动 lock）

以上指令可与 ``lock`` 前缀配合（除 ``xchg`` 本身已是原子操作）。

标志位操作指令
===================

.. list-table::
   :header-rows: 1

   * - 指令
     - 描述
     - 影响
   * - ``stc``
     - 置进位标志 (CF=1)
     - CF
   * - ``clc``
     - 清进位标志 (CF=0)
     - CF
   * - ``cld``
     - 清方向标志 (DF=0，字符串操作向上增长)
     - DF
   * - ``std``
     - 置方向标志 (DF=1，字符串操作向下递减)
     - DF
   * - ``lahf``
     - 加载标志到 AH（低 8 位 RFLAGS）
     - 无
   * - ``sahf``
     - 存储 AH 到标志寄存器
     - SF,ZF,AF,PF,CF
   * - ``pushfq``
     - 将 RFLAGS 压栈
     - 无
   * - ``popfq``
     - 从栈弹出 RFLAGS
     - 所有

系统指令
=============

.. list-table::
   :header-rows: 1

   * - 指令
     - 描述
     - 使用场景
   * - ``syscall``
     - 发起系统调用（64 位模式）
     - 用户态调用内核服务
   * - ``sysret``
     - 从系统调用返回
     - 内核返回用户态专用
   * - ``int 0x80``
     - 传统 32 位系统调用
     - x86_64 下不建议使用
   * - ``cpuid``
     - 读取 CPU 信息
     - 检测 CPU 特性（如 AVX-512 支持）
   * - ``rdtsc``
     - 读取时间戳计数器
     - 高精度计时（纳秒级）
   * - ``rdtscp``
     - 读取 TSC 和核心 ID
     - 更精确的线程级计时
   * - ``rdmsr``
     - 读 MSR（模式特定寄存器）
     - 内核/驱动调试
   * - ``wrmsr``
     - 写 MSR
     - 需要 ring 0 权限
   * - ``pause``
     - 暂停等待（提示 CPU 处于自旋锁循环）
     - 节省功耗，提高超线程效率
   * - ``nop``
     - 空操作（无操作）
     - 对齐、占位、时序调整
   * - ``xgetbv``
     - 读 XCR 寄存器（扩展控制）
     - 检测 XSAVE/AVX 状态
