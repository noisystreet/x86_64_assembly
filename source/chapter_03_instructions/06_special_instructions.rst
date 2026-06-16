.. _chapter-03-special:

===============================
实用特殊指令
===============================

x86_64 在基础指令集之上不断添加了各种扩展指令，覆盖加密、随机数、位操作、SIMD 查表等场景。
这些指令虽然不像 ``mov``/``add`` 那样常用，但在各自领域内无可替代。了解它们的存在，
等于在你的工具箱里多了一批"特种工具"——在需要的时候，你会知道去哪里找。

``cpuid`` — 读取 CPU 信息
================================

``cpuid`` 是了解 CPU 身份的入口指令，它返回处理器型号、特性支持（如 AVX-512 是否可用）、缓存大小等信息。

.. code-block:: none

   ; cpuid(eax=0) → 返回 CPU 厂商 ID
       mov rax, 0
       cpuid
       ; ebx:edx:ecx = "GenuineIntel" 或 "AuthenticAMD"

   ; cpuid(eax=1) → 返回特性位
       mov rax, 1
       cpuid
       ; 检查第 28 位（rdx bit 28）：是否支持 AVX
       test rdx, 1 << 28
       jnz  .has_avx

.. admonition:: 为什么叫 cpuid？
   :class: story

   ``cpuid`` 在 486 时代并不存在。Intel 推出 Pentium 后，程序员需要区分 386/486/Pentium，
   但因为各代 CPU 的指令行为和标志位设置不一致，靠软件识别 CPU 型号变得越来越不可靠。
   Intel 在 1993 年引入 ``cpuid`` 作为标准方案。有趣的是，**AMD 在 486 兼容 CPU 上提前实现了
   类似的识别机制**，但 Intel 的标准最终成为 x86 的统一接口。今天 ``cpuid`` 的 EAX 输入参数已
   从 0 扩展到 0x1F（第 31 级叶子），涵盖缓存拓扑、TSC 特性、SGX 等数百个特性位。

``rdrand`` / ``rdseed`` — 硬件随机数
=========================================

传统上，程序获取随机数需要向内核请求（``/dev/urandom``），涉及系统调用。``rdrand`` 直接从 CPU
内部的数字随机数发生器（DRNG）取数，一条指令即可完成：

.. code-block:: none

   ; rdrand: 读取硬件生成的随机数
   rdrand rax          ; rax = 64 位随机数
   jnc  .retry         ; CF=0 表示随机数不可用，重试
   ; 成功，rax 中是随机数

   ; rdseed: 更高质量的种子（用于播种 PRNG）
   rdseed rax          ; 从更原始的熵源读取
   jnc  .retry

   ; 填充缓冲区
       lea rdi, [buffer]
       mov rcx, 4       ; 生成 4 个 64 位随机数
   .loop:
       rdrand rax
       jnc  .loop       ; 重试直到成功
       mov [rdi], rax
       add rdi, 8
       dec rcx
       jnz .loop

.. admonition:: Snowden、NSA 与 rdrand 的信任争议
   :class: story

   2013 年 Edward Snowden 披露 NSA 可能对硬件 RNG 植入后门后，Linux 内核社区爆发了激烈争论。
   核心问题：**可以信任 CPU 厂商的硬件随机数发生器吗？** 如果 NSA 要求 Intel 在 ``rdrand``
   的输出中植入可预测模式，那么依赖 ``rdrand`` 的加密系统就是有后门的。Linus Torvalds 最终
   裁定：内核不应信任硬件 RNG 作为**唯一**熵源。今天 Linux 的 ``/dev/random`` 从 ``rdrand``
   取熵后与内核自身的熵池（来自中断时序、设备噪声）混杂，即使硬件被植入后门也无妨。
   这个"不相信任何人"的设计哲学体现了操作系统安全的核心原则。

``crc32`` — 硬件 CRC-32 校验
================================

CRC-32 是网络和存储中最常用的校验和算法（如以太网帧的 FCS、gzip 文件的校验）。
硬件 ``crc32`` 指令一次处理 8 字节，吞吐量是软件查表循环的 **10-20 倍**。

.. code-block:: none

   ; crc32 的两种操作数大小
   crc32 eax, byte [rsi]   ; 处理 1 字节，部分结果在 eax
   crc32 eax, qword [rsi]  ; 处理 8 字节

   ; 计算缓冲区 CRC-32
   ; rsi = 数据指针，rcx = 长度，返回 eax = CRC 值
   crc32_buffer:
       xor eax, eax        ; CRC 初始值 = 0
       cld
   .loop:
       crc32 eax, qword [rsi]
       add rsi, 8
       sub rcx, 8
       jg  .loop
       ; 处理剩余字节...
       ret

.. admonition:: 网络协议的底层引擎
   :class: application

   你可能每天都在使用 ``crc32`` 而不知道它。以太网帧尾部 4 字节的 FCS（Frame Check Sequence）
   就是用 CRC-32 计算出来的。当你的网卡接收到一个报文时，硬件自动校验 CRC——如果发现错误，
   直接丢弃，连内核都不会通知。iSCSI 协议也将 CRC-32C（Castagnoli 多项式）作为数据完整性
   校验的标准。如果没有 ``crc32`` 指令，每次网络传输的数据校验都需要几十条查表指令。

``movbe`` — 大小端交换加载/存储
=====================================

``movbe`` 一条指令完成"从内存加载 + 字节交换"或"字节交换 + 写入内存"。
对网络编程极为实用——网络字节序是大端，x86 是小端：

.. code-block:: none

   ; 从网络包中读取大端 uint32_t，转成小端
   movbe eax, [rsi]       ; eax = bswap(*(uint32_t*)rsi)

   ; 将小端整数转为大端写入网络包
   movbe [rdi], eax       ; *(uint32_t*)rdi = bswap(eax)

   ; 等效的传统写法（需要两条指令）
   mov eax, [rsi]
   bswap eax              ; 手动大端 → 小端

.. tip::

   ``movbe`` 在 Atom（2011）中首次引入，后续主流 CPU 都已支持。如果你在写网络协议栈的
   汇编代码（如 IP/TCP 头部解析），``movbe`` 可以省去处理器密集的 ``bswap`` 指令和额外的
   寄存器压力。

``aesenc`` / ``aesdec`` / ``pclmulqdq`` — 硬件密码学
=========================================================

AES-NI（AES New Instructions）是 Intel 在 Westmere（2010）引入的一组指令，直接用硬件电路
实现 AES 加密算法的核心轮函数——不仅比软件快 **10-30 倍**，而且**抵抗时序侧信道攻击**
（纯软件 AES 因查表操作导致缓存时序泄漏，已被证明可以远程攻击）。

.. code-block:: none

   ; AES 单轮加密
       movdqa xmm0, [plaintext]  ; 128 位明文
       movdqa xmm1, [key]        ; 128 位密钥
       aesenc xmm0, xmm1         ; 一轮加密
       aesenclast xmm0, xmm1     ; 最后一轮（省略 MixColumns）

   ; pclmulqdq: 无进位乘法（GF(2^128) 多项式乘法）
       movdqa xmm0, [a]
       movdqa xmm1, [b]
       pclmulqdq xmm0, xmm1, 0x00  ; xmm0 = a * b in GF(2^128)

.. admonition:: 全栈硬件加速：Intel 的云时代布局
   :class: story

   Westmere（2010）同时引入了 ``aesenc``、``pclmulqdq``、``rdrand``，这不是巧合。
   Intel 的战略目标是让 x86 成为第一个能做**全栈 TLS 硬件加速**的平台：**AES-NI** 负责
   对称加密、**CLMUL** 负责认证（AES-GCM 模式）、**rdrand** 提供会话密钥。这套组合拳在
   云计算时代大获成功——当你使用 HTTPS 访问网站时，底层每秒钟有数百万次 AES 加密。
   如果没有硬件加速，全球互联网的能耗将高出几个数量级。

``pshufb`` — SSSE3 并行查表
================================

``pshufb`` （Packed Shuffle Bytes）是 SSSE3 中最灵活的指令之一。它对 XMM 寄存器中的
16 个字节执行:strong:`并行查表`：每个目标字节的索引来自第二个操作数，取出的值来自第一个
操作数的对应位置。

.. code-block:: none

   ; pshufb 基础：按索引重排字节
       movdqa xmm0, [table]     ; xmm0 = ['a','b','c','d',...]
       movdqa xmm1, [indices]   ; xmm1 = [0, 1, 2, 3, ...]
       pshufb xmm0, xmm1        ; xmm0 = 按 xmm1 索引重排

   ; 大小写转换：只需一条 pshufb
   ; (利用 0x20 位控制大小写偏移)
   section .data
       toupper_mask db 0x20, 0x20, 0x20, ...  ; 16 字节掩码
   section .text
       movdqa xmm0, [input]     ; 加载 16 字节
       movdqa xmm1, [toupper_mask]
       psubusb xmm0, xmm1       ; 每个字节减去 0x20（小写→大写等效）

.. note::

   ``pshufb`` 是 SSSE3 指令（2006 年 Core 2 引入），灵感来自 IBM PowerPC 的 AltiVec
   ``vperm`` 指令。一条 ``pshufb`` 等效于 16 次并行查表，常用于 Base64 编码/解码、
   UTF-8 验证、字符替换等需要大规模字符映射的场景。在实现 ``strlen`` 的自定义版本时，
   ``pshufb`` 配合 ``pcmpistri`` 可以做到每 16 字节仅需几条指令。

``blsr`` / ``blsi`` / ``andn`` — BMI 位操作扩展
====================================================

BMI（Bit Manipulation Instructions）是 Intel Haswell（2013）引入的位操作扩展。
它将常见的 3-4 条指令的位操作序列压缩为一条：

.. code-block:: none

   ; blsr: 清除最低置 1 位 (= rax & (rax - 1))
   blsr rax, rbx       ; rax = rbx & (rbx - 1)

   ; blsi: 提取最低置 1 位 (= rax & (-rax))
   blsi rcx, rdx       ; rcx = rdx & (-rdx)

   ; bzhi: 将高位清零
   bzhi rax, rbx, 8    ; rax = rbx & 0xFF（只保留低 8 位）

   ; andn: 与非（= ~src1 & src2）
   andn rax, rbx, rcx  ; rax = ~rbx & rcx

.. code-block:: none

   ; 遍历位图中所有置 1 的位（用 blsr 循环）
       xor rcx, rcx            ; 位计数
   .loop:
       mov rax, bitmap
       blsr rax, rax           ; 清除最低置 1 位，原值在标志位
       inc rcx                 ; 计数 +1
       jnz .loop               ; rax ≠ 0 继续

.. admonition:: 硬件化的"编译器惯用法"
   :class: story

   BMI 指令的设计思路和 RISC 类似：**观察编译器生成的常见代码模式，然后硬件化**。
   以 ``blsr`` 为例，C 代码 ``x & (x - 1)`` 被广泛应用于位图遍历和 2 的幂次判断，
   GCC 对这段代码有专门的识别优化——但无论怎么优化，都需要至少一条 ``sub``、一条 ``and``。
   Intel 的解决方案是：把这 2 条指令的序列固化到硬件里，变成一条指令。
   ``blsi`` 和 ``bzhi`` 也是同理。这套策略让 BMI 在编译器生成的代码中自动生效，
   开发者甚至不需要修改源码。

``adox`` / ``adcx`` — 多精度加法链（ADX 扩展）
====================================================

大整数算术（RSA、ECC 等公钥加密）的核心操作是 **64x64→128 位乘法后累加**。
传统做法是：乘 → 加 → 带进位加，形成一条累加链。ADX 扩展让你**同时维护两条独立的进位链**：

.. code-block:: none

   ; adcx: 使用 CF 标志的带进位加法
   adcx rax, rbx       ; rax += rbx + CF（进位在 CF）

   ; adox: 使用 OF 标志的带进位加法
   adox rax, rbx       ; rax += rbx + OF（进位在 OF）

   ; 两条加法链并行执行：
       mulx rcx, rbx, [rsi]    ; 无进位乘法（BMI2）
       adcx rax, rbx           ; 加法链 1（用 CF）
       adox rdx, r8            ; 加法链 2（用 OF）
       ; 两条加法互不干扰，CPU 可以并行调度

.. admonition:: RSA 性能翻倍的秘密
   :class: story

   在 Broadwell（2015）之前，RSA 2048 位解密的主要瓶颈是乘法器。
   Haswell 引入了 ``mulx``（无进位乘法，BMI2 扩展），将大整数乘法的吞吐量翻倍。
   但现在**加法链成了新瓶颈**——每次乘法后的累加必须串行等待上一轮进位。
   Intel 的解决方案是 ``adox``/``adcx``：提供两套独立的进位链，让乘法和两条加法链
   并行工作。结果：**RSA 2048 位解密的吞吐量再次翻倍**。
   这也是为什么现代 ``openssl speed rsa2048`` 在 Haswell 之后的 CPU 上表现持续提升。

``vfmadd`` — 融合乘加（FMA）
==================================

FMA（Fused Multiply-Add）将 ``a * b + c`` 压缩为一条指令，且**只舍入一次**。

.. code-block:: none

   ; FMA 三操作数形式（132 = a * c + b）
   vfmadd132ps ymm0, ymm1, ymm2   ; ymm0 = ymm0 * ymm2 + ymm1
   vfmadd231pd ymm0, ymm1, ymm2   ; ymm0 = ymm1 * ymm2 + ymm0

   ; 对比：传统写法需要两条指令 + 中间舍入
   mulps  ymm0, ymm2               ; ymm0 = ymm0 * ymm2
   addps  ymm0, ymm1                ; ymm0 = ... + ymm1（精度损失）

.. tip::

   融合乘加只执行一次舍入（而不是乘法和加法各一次），所以结果更精确。
   在科学计算（矩阵乘法、多项式求值）中，FMA 可以显著提高精度并减少一半指令数。
   Intel Haswell（2013）引入 FMA3，AMD Bulldozer（2011）更早引入 FMA4。
   两家在 FMA 格式上有过一次经典的 **ABI 战争**——最终市场统一到 Intel 的 FMA3。

``umonitor`` / ``umwait`` — 用户态等待
=============================================

传统上，自旋锁在线程等待时反复检查内存值，浪费 CPU 周期和功耗。
``umonitor``/``umwait`` 允许用户态程序在**不陷入内核**的情况下等待内存写入：

.. code-block:: none

   ; 监控内存地址 rdi 的写入
   umonitor rdi

   ; 等待最多 100 微秒（或该地址被写入）
   mov ecx, 100          ; 上限时间（自动转换到 TSC）
   xor edx, edx
   umwait rcx, rdx       ; 暂停等待，线程不消耗执行资源

   ; 检查是否超时
   jc  .timed_out        ; CF=1 表示超时

.. note::

   ``umonitor``/``umwait`` 是 Intel ADX 扩展的一部分（Broadwell，2015）。
   它们解决的问题是：自旋锁在低竞争场景下响应快但浪费功耗，而 ``futex`` 省功耗但需要
   系统调用（上下文切换代价大）。用户态等待提供了中间态：**等待时降低功耗但不切换到内核**。
   不过，AMD 未实现这些指令，所以在跨平台代码中普及率不高。

``vzeroupper`` — 清除 YMM 高 128 位
========================================

当混用 AVX（256 位 YMM）和 SSE（128 位 XMM）指令时，必须在每次 SSE 操作前
清除 YMM 的高 128 位，否则 CPU 进入"保存状态"模式，``movaps`` 等 SSE 指令
会有几十周期的性能惩罚。

.. code-block:: none

   ; 在 SSE 代码前执行 vzeroupper
   vzeroupper              ; 清零所有 YMM 高 128 位
   movaps xmm0, [data]     ; SSE 指令，不再有性能惩罚

   ; 在函数返回前也应执行
   my_avx_func:
       ; ... 使用 ymm 寄存器 ...
       vzeroupper
       ret                  ; 调用者可以安全使用 SSE

.. warning::

   忘记 ``vzeroupper`` 的场景很隐蔽：你写了一个 AVX 函数，然后在某个 C 文件中调用了它。
   调用者接着调用 ``printf``：printf 内部使用 SSE ``movaps`` 操作栈 ——
   由于你的 AVX 函数没有 ``vzeroupper``，printf 的 ``movaps`` 触发状态切换惩罚，
   printf 变慢 2-3 倍，但代码完全"正常"。这种性能 bug 极难通过 profiling 定位。

``prefetch`` — 缓存预取
===============================

``prefetch`` 指令告诉 CPU"我马上就要这个地址的数据"，让 CPU 提前将数据加载到
缓存中，减少缓存未命中的等待：

.. code-block:: none

   ; 预取级别
   prefetcht0 [rax]       ; 预取到所有缓存级（L1+L2+L3）
   prefetcht1 [rax]       ; 预取到 L2+L3
   prefetcht2 [rax]       ; 预取到 L3
   prefetchnta [rax]      ; 非临时预取（数据只用一次，不进 L2/L3，避免污染）

   ; 在循环中预取
       mov rcx, 1024
       xor rsi, rsi
   .loop:
       prefetchnta [big_array + rsi + 64]  ; 提前加载下一个缓存行
       mov rax, [big_array + rsi]
       ; ... 处理 ...
       add rsi, 8
       dec rcx
       jnz .loop

.. caution::

   预取不是魔法。过度预取会**浪费内存带宽**：CPU 预取的数据如果没被使用，仍然是
   一次完整的内存访问。经验法则是每次预取 1-2 个缓存行（64-128 字节）就足够。
   在顺序访问的大数组上，**CPU 的硬件预取器早已能自动识别模式**，手动预取往往是
   多余的。真正有用的是非顺序访问场景（如树的遍历、链表处理）。
