; ============================================================
; strings.asm - 字符串操作演示
; 编译：nasm -f elf64 strings.asm -o strings.o
;       ld strings.o -o strings
; ============================================================

section .data
    src  db 'Hello from x86_64!', 0
    src_len equ $ - src

section .bss
    dst  resb 64         ; 目标缓冲区

section .text
    global _start

; ============================================================
; strlen: 计算字符串长度
; 参数：rdi = 字符串地址
; 返回：rax = 长度
; ============================================================
strlen:
    push rbp
    mov rbp, rsp
    xor rax, rax

.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop

.done:
    pop rbp
    ret

; ============================================================
; strcpy: 复制字符串
; 参数：rdi = 目标, rsi = 源
; ============================================================
strcpy:
    push rbp
    mov rbp, rsp
    xor rcx, rcx

.loop:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    cmp al, 0
    je .done
    inc rcx
    jmp .loop

.done:
    pop rbp
    ret

_start:
    ; 计算 src 字符串长度
    mov rdi, src
    call strlen          ; rax = 19

    ; 复制字符串
    mov rdi, dst
    mov rsi, src
    call strcpy

    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall
