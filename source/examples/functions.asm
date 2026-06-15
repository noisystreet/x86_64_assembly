; ============================================================
; functions.asm - 子程序与栈帧演示
; 编译：nasm -f elf64 functions.asm -o functions.o
;       ld functions.o -o functions
; ============================================================

section .data
    result_msg db 'Result: ', 0xA
    result_len equ $ - result_msg

section .text
    global _start

; ============================================================
; sum 函数：计算三个数的和
; 参数：rdi, rsi, rdx
; 返回：rax
; ============================================================
sum:
    push rbp
    mov rbp, rsp

    mov rax, rdi
    add rax, rsi
    add rax, rdx

    pop rbp
    ret

; ============================================================
; factorial 函数：递归计算阶乘
; 参数：rdi = n
; 返回：rax = n!
; ============================================================
factorial:
    push rbp
    mov rbp, rsp

    cmp rdi, 1
    jle .base_case

    ; n * factorial(n-1)
    push rdi
    dec rdi
    call factorial
    pop rdi
    mul rdi            ; rax = rax * rdi
    jmp .done

.base_case:
    mov rax, 1

.done:
    pop rbp
    ret

_start:
    ; 测试 sum 函数
    mov rdi, 10
    mov rsi, 20
    mov rdx, 30
    call sum
    ; rax 中应为 60

    ; 测试 factorial 函数
    mov rdi, 5
    call factorial
    ; rax 中应为 120

    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall
