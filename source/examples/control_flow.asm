; ============================================================
; control_flow.asm - 控制流演示
; 编译：nasm -f elf64 control_flow.asm -o control_flow.o
;       ld control_flow.o -o control_flow
; ============================================================

section .data
    greater_msg db 'rax > rbx', 0xA
    greater_len equ $ - greater_msg
    less_msg    db 'rax <= rbx', 0xA
    less_len    equ $ - less_msg

section .text
    global _start

_start:
    mov rax, 50
    mov rbx, 30

    ; 比较 rax 和 rbx
    cmp rax, rbx
    jg  .greater         ; 如果 rax > rbx，跳转

    ; rax <= rbx 的情况
    mov rax, 1
    mov rdi, 1
    mov rsi, less_msg
    mov rdx, less_len
    syscall
    jmp .exit

.greater:
    mov rax, 1
    mov rdi, 1
    mov rsi, greater_msg
    mov rdx, greater_len
    syscall

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall
