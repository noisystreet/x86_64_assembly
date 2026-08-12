.. _chapter-06-fma:

===============================
FMA：乘加融合指令
===============================

FMA（Fused Multiply-Add，乘加融合）是 AVX2 之后引入的一类指令，它把「乘法 + 加法」合并成**一条指令**完成：

.. code-block:: none

   ; 传统做法：两条指令，两次舍入
   vmulps ymm0, ymm1, ymm2      ; ymm0 = ymm1 * ymm2（第一次舍入）
   vaddps ymm0, ymm0, ymm3      ; ymm0 = ymm0 + ymm3（第二次舍入）

   ; FMA 做法：一条指令，一次舍入
   vfmadd231ps ymm0, ymm1, ymm2 ; ymm0 = ymm1 * ymm2 + ymm0

FMA 的核心价值不在「少一条指令」，而在**只做一次舍入** 。传统做法里，乘法结果先被舍入到 32/64 位，再参与加法；FMA 则保留乘法的**无限精度中间结果** ，只在最后加完才舍入一次。这对数值精度和性能都有意义。

为什么需要 FMA
=================

两个实际收益：

- **精度更高**：少一次舍入意味着更小的累积误差。在矩阵乘法、多项式求值、点积等「乘完就加」的场景里，FMA 能显著降低舍入误差。
- **吞吐更高**：一条指令完成两件事，减少了指令数和寄存器压力，也减少了依赖链长度。

.. admonition:: 一个直观的例子
   :class: funfact

   计算 ``a * b + c`` 时，传统做法是 ``mul`` 后 ``add``，中间结果 ``a * b`` 会被舍入一次。
   如果 ``a * b`` 恰好落在两个可表示浮点数之间，这次舍入就引入了误差，随后 ``+ c`` 又舍入一次。
   FMA 把 ``a * b`` 的精确值（无限精度）直接与 ``c`` 相加，只舍入一次，结果更接近真实值。

FMA 指令族
=============

FMA 指令的命名规则是 ``vfmadd/sub/nmadd/nmsub + 132/213/231 + ps/pd/ss/sd``：

- ``前缀``：``fmadd`` （乘加）、``fmsub`` （乘减）、``fnmadd`` （负乘加）、``fnmsub`` （负乘减）
- ``数字``：表示三个操作数中哪个是「累加目标」，例如 ``231`` 表示 ``dst = src2 * src3 + src1``
- ``后缀``：``ps`` （packed 单精度）、``pd`` （packed 双精度）、``ss`` （标量单精度）、``sd`` （标量双精度）

.. list-table::
   :header-rows: 1

   * - 指令
     - 语义
     - 说明
   * - ``vfmadd231ps``
     - ``dst = src2 * src3 + dst``
     - 最常用：累加到目标寄存器
   * - ``vfmadd213ps``
     - ``dst = dst * src2 + src3``
     - 目标同时是乘数
   * - ``vfmadd132ps``
     - ``dst = dst * src3 + src2``
     - 目标同时是乘数（顺序不同）
   * - ``vfmsub231ps``
     - ``dst = src2 * src3 - dst``
     - 乘减
   * - ``vfnmadd231ps``
     - ``dst = -(src2 * src3) + dst``
     - 负乘加

.. note::

   三个数字 ``132`` / ``213`` / ``231`` 描述的是「目标寄存器在三个操作数中的位置」。
   以 ``vfmadd231ps dst, src2, src3`` 为例：``dst`` 是第 1 个操作数（累加目标），
   ``src2`` 是第 2 个，``src3`` 是第 3 个，所以是 ``231``。

基本用法
==========

.. code-block:: none

   section .data
       align 32
       a  dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
       b  dd 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0
       c  dd 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5

   section .text
       vmovaps ymm0, [c]           ; ymm0 = c（累加目标）
       vmovaps ymm1, [a]           ; ymm1 = a
       vmovaps ymm2, [b]           ; ymm2 = b
       vfmadd231ps ymm0, ymm1, ymm2 ; ymm0 = a * b + c

标量 FMA
==========

标量版本 ``ss`` / ``sd`` 只处理最低位的一个元素，适合单个浮点数的乘加：

.. code-block:: none

   ; 计算 d = a * b + c（标量双精度）
   section .data
       a dq 3.0
       b dq 4.0
       c dq 5.0

   section .text
       vmovsd xmm0, [c]            ; xmm0 = c
       vmovsd xmm1, [a]            ; xmm1 = a
       vmovsd xmm2, [b]            ; xmm2 = b
       vfmadd231sd xmm0, xmm1, xmm2 ; xmm0 = a * b + c = 17.0

实际应用：点积
================

点积（dot product）是 FMA 最典型的应用场景——「乘完就累加」：

.. code-block:: none

   ; 计算两个长度为 8 的 float 数组的点积
   ; rdi = 数组 a，rsi = 数组 b，返回 xmm0 = 点积结果
   dot_product:
       vxorps ymm0, ymm0, ymm0     ; 累加器清零
       vmovups ymm1, [rdi]         ; 加载 a[0..7]
       vmovups ymm2, [rsi]         ; 加载 b[0..7]
       vfmadd231ps ymm0, ymm1, ymm2 ; ymm0 += a[i] * b[i]（8 个元素一次）

       ; 水平求和：把 ymm0 的 8 个 float 加起来
       ; （简化起见，这里省略了完整的水平归约，实际需要 vextractf128 + vhaddps 等）

       ret

.. note::

   点积的完整实现还需要「水平归约」（把向量里的 8 个元素加成一个标量）。
   这通常用 ``vextractf128`` 把高 128 位移到低 128 位，再用 ``vaddps`` / ``vhaddps`` 逐步归约。
   但核心的「乘加」部分，FMA 一条指令就完成了。

FMA 与精度
============

FMA 的「一次舍入」特性在数值计算中意义重大。以多项式求值（Horner 法）为例：

.. code-block:: none

   ; 用 Horner 法计算多项式 p(x) = a3*x^3 + a2*x^2 + a1*x + a0
   ; 等价于 p(x) = ((a3*x + a2)*x + a1)*x + a0
   ; 每一步都是「乘加」，天然适合 FMA

   ; 传统做法（每步两次舍入）
   ;   t = a3 * x      （舍入 1）
   ;   t = t + a2      （舍入 2）
   ;   t = t * x       （舍入 3）
   ;   ...

   ; FMA 做法（每步一次舍入）
   ;   t = fma(a3, x, a2)   （一次舍入）
   ;   t = fma(t,  x, a1)   （一次舍入）
   ;   t = fma(t,  x, a0)   （一次舍入）

.. warning::

   FMA 虽然精度更高，但**不要假设它和「先乘后加」结果完全一致**。
   如果你的代码依赖某种特定的舍入行为（例如与某个参考实现逐位对齐），
   引入 FMA 可能改变结果。编译器在 ``-mfma`` 或 ``-march=native`` 下会自动把
   ``a * b + c`` 融合成 FMA，这可能导致「同一份代码在不同机器上结果不同」。

CPU 支持检测
==============

FMA 并非所有 CPU 都支持，使用前需通过 ``cpuid`` 检查：

.. code-block:: none

   ; 检测 FMA 支持
   ; CPUID.(EAX=1):ECX bit 12 = FMA
   mov eax, 1
   cpuid
   test ecx, (1 << 12)             ; 检查 FMA 位
   jz  .no_fma                     ; 不支持则走回退路径

.. note::

   - FMA3（三操作数 FMA）：CPUID.(EAX=1):ECX bit 12，Intel Haswell 及以后、AMD Piledriver 及以后支持
   - FMA4（四操作数 FMA）：仅 AMD 部分 CPU 支持，现已基本废弃
   - 编译器 ``-mfma`` 生成的是 FMA3 指令

   如果目标平台不确定，应提供「先乘后加」的回退路径。

练习题
========

1. 用 ``vfmadd231ps`` 实现两个长度为 8 的 ``float`` 数组的点积，并与
   「``vmulps`` + ``vaddps``」的传统实现对比结果精度。

2. 用标量 FMA（``vfmadd231sd``）实现 Horner 法多项式求值，计算
   ``p(x) = 3x^3 + 2x^2 + x + 5`` 在 ``x = 2.0`` 处的值。

3. 编写 ``cpuid`` 检测代码，判断当前 CPU 是否支持 FMA，不支持时打印提示。

4. 对比 FMA 与传统「先乘后加」在 ``0.1 * 0.2 + 0.3`` 上的结果差异，
   解释为什么两者可能不同。
