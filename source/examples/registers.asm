; ============================================================
; registers.asm - 寄存器操作演示
; 编译：nasm -f elf64 registers.asm -o registers.o
;       ld registers.o -o registers
; ============================================================

section .data
    newline db 0xA

section .text
    global _start

_start:
    ; 通用寄存器基本操作
    mov rax, 0x1234567890ABCDEF
    mov rbx, rax        ; rbx = rax
    mov rcx, 42         ; rcx = 42

    ; 子寄存器访问
    mov eax, 0xFFFFFFFF ; 写入 eax 会清零 rax 高32位
    mov ax,  0x1234     ; 写入 ax 不影响高48位
    mov al,  0x56       ; 写入 al 不影响高56位

    ; xchg 交换
    mov rax, 100
    mov rbx, 200
    xchg rax, rbx       ; 交换后：rax=200, rbx=100

    ; lea 示例
    lea rdi, [newline]  ; rdi = newline 的地址

    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall
