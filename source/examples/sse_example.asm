; ============================================================
; sse_example.asm - SSE/SIMD 浮点运算演示
; 编译：nasm -f elf64 sse_example.asm -o sse_example.o
;       ld sse_example.o -o sse_example
; ============================================================

section .data
    ; 两个 4 元素 float 向量
    vec1 dd 1.0, 2.0, 3.0, 4.0
    vec2 dd 5.0, 6.0, 7.0, 8.0

section .bss
    result resd 4

section .text
    global _start

_start:
    ; 加载向量到 xmm 寄存器
    movaps xmm0, [vec1]   ; xmm0 = [1.0, 2.0, 3.0, 4.0]
    movaps xmm1, [vec2]   ; xmm1 = [5.0, 6.0, 7.0, 8.0]

    ; 向量加法
    addps  xmm0, xmm1     ; xmm0 = [6.0, 8.0, 10.0, 12.0]

    ; 存储结果
    movaps [result], xmm0

    ; 标量浮点运算示例
    movss  xmm2, [vec1]   ; xmm2 = [1.0]
    movss  xmm3, [vec2]   ; xmm3 = [5.0]
    mulss  xmm2, xmm3     ; xmm2 = [5.0]

    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall
