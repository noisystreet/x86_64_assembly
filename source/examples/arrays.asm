; ============================================================
; arrays.asm - 数组操作演示
; 编译：nasm -f elf64 arrays.asm -o arrays.o
;       ld arrays.o -o arrays
; ============================================================

section .data
    ; 数组定义
    arr  dq  5, 3, 8, 1, 9, 2, 7, 4, 6, 0
    arr_len equ ($ - arr) / 8

section .bss
    sorted_arr resq 10

section .text
    global _start

_start:
    ; 遍历数组，找到最大值
    mov rcx, arr_len
    mov rsi, arr
    mov rax, [rsi]       ; 初始化最大值为第一个元素
    xor rdi, rdi         ; 索引

.loop:
    cmp rdi, rcx
    jge .done
    mov rbx, [rsi + rdi*8]
    cmp rbx, rax
    cmovg rax, rbx       ; 条件移动：如果 rbx > rax，则 rax = rbx
    inc rdi
    jmp .loop

.done:
    ; rax 中为最大值（应为9）
    mov rax, 60
    xor rdi, rdi
    syscall
