; ============================================================
; avx_example.asm - AVX/AVX2 SIMD 运算演示
; 编译：nasm -f elf64 avx_example.asm -o avx_example.o
;       ld avx_example.o -o avx_example
; 运行：./avx_example
; 注意：需要支持 AVX/AVX2 的 CPU（2013 年后的主流 x86_64）
; ============================================================

section .data
    ; 两个 8 元素 float 向量（256 位）
    align 32                    ; AVX 的 256 位数据建议 32 字节对齐
    vec1 dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
    vec2 dd 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0

    ; 两个 4 元素 double 向量（256 位）
    align 32
    dvec1 dq 1.0, 2.0, 3.0, 4.0
    dvec2 dq 0.5, 0.5, 0.5, 0.5

    ; 两个 8 元素 int 向量（AVX2 整数运算）
    align 32
    ivec1 dd 1, 2, 3, 4, 5, 6, 7, 8
    ivec2 dd 10, 20, 30, 40, 50, 60, 70, 80

    ; 广播用的标量
    scalar dd 2.0

section .bss
    align 32
    fresult resd 8              ; float 结果
    dresult resq 4              ; double 结果
    iresult resd 8              ; int 结果

section .text
    global _start

_start:
    ; ============================================================
    ; 1. AVX 三操作数浮点运算（非破坏性）
    ;    vaddps ymm0, ymm1, ymm2  →  ymm0 = ymm1 + ymm2
    ;    ymm1 和 ymm2 保持不变
    ; ============================================================
    vmovaps ymm0, [vec1]        ; ymm0 = [1.0 ... 8.0]
    vmovaps ymm1, [vec2]        ; ymm1 = [8.0 ... 1.0]

    vaddps  ymm2, ymm0, ymm1    ; ymm2 = ymm0 + ymm1（三操作数，ymm0/ymm1 不变）
    vmovaps [fresult], ymm2     ; fresult = [9.0, 9.0, ..., 9.0]

    ; 三操作数编码的优势：源寄存器不被破坏，无需额外 movaps 保存副本
    vmulps  ymm3, ymm0, ymm1    ; ymm3 = ymm0 * ymm1，ymm0 仍可用
    vmovaps [fresult], ymm3     ; fresult = [8.0, 14.0, 18.0, 20.0, 20.0, 18.0, 14.0, 8.0]

    ; ============================================================
    ; 2. 双精度向量运算（一次处理 4 个 double）
    ; ============================================================
    vmovapd ymm4, [dvec1]       ; ymm4 = [1.0, 2.0, 3.0, 4.0]
    vmovapd ymm5, [dvec2]       ; ymm5 = [0.5, 0.5, 0.5, 0.5]

    vmulpd  ymm6, ymm4, ymm5    ; ymm6 = ymm4 * ymm5
    vmovapd [dresult], ymm6     ; dresult = [0.5, 1.0, 1.5, 2.0]

    ; ============================================================
    ; 3. AVX2 整数向量运算
    ; ============================================================
    vmovdqu ymm7, [ivec1]       ; ymm7 = [1 ... 8]
    vmovdqu ymm8, [ivec2]       ; ymm8 = [10 ... 80]

    vpaddd  ymm9, ymm7, ymm8    ; ymm9 = ymm7 + ymm8（整数加法）
    vmovdqu [iresult], ymm9     ; iresult = [11, 22, 33, 44, 55, 66, 77, 88]

    ; ============================================================
    ; 4. 广播（broadcast）：将标量扩展到整个向量
    ; ============================================================
    vbroadcastss ymm10, [scalar] ; ymm10 = [2.0, 2.0, ..., 2.0]（8 个 2.0）

    ; ============================================================
    ; 5. 退出前执行 vzeroupper
    ;    清除 YMM 寄存器的高 128 位，避免后续 SSE 代码的性能惩罚
    ; ============================================================
    vzeroupper

    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall
