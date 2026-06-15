; ============================================================
; hello.asm - Hello World 程序
; 演示：系统调用 write 和 exit
; 编译：nasm -f elf64 hello.asm -o hello.o && ld hello.o -o hello
; ============================================================

section .data
    msg  db 'Hello, World!', 0xA    ; 字符串 + 换行符
    len  equ $ - msg                 ; 字符串长度

section .text
    global _start

_start:
    ; sys_write(1, msg, len)
    mov rax, 1      ; 系统调用号：sys_write
    mov rdi, 1      ; 文件描述符：stdout
    mov rsi, msg    ; 缓冲区地址
    mov rdx, len    ; 写入长度
    syscall

    ; sys_exit(0)
    mov rax, 60     ; 系统调用号：sys_exit
    xor rdi, rdi    ; 退出码：0
    syscall
