; ============================================================
; mmap_example.asm - 内存映射 (mmap) 演示
; 编译：nasm -f elf64 mmap_example.asm -o mmap_example.o
;       ld mmap_example.o -o mmap_example
; ============================================================

; 系统调用号
%define SYS_MMAP  9
%define SYS_EXIT  60
%define SYS_WRITE 1

; mmap 参数标志
%define PROT_READ   0x1
%define PROT_WRITE  0x2
%define MAP_PRIVATE 0x02
%define MAP_ANONYMOUS 0x20

section .data
    msg db 'mmap succeeded!', 0xA
    msg_len equ $ - msg

section .bss
    ; 将用 mmap 分配的内存地址

section .text
    global _start

_start:
    ; mmap(addr=0, len=4096, prot=PROT_READ|PROT_WRITE,
    ;      flags=MAP_PRIVATE|MAP_ANONYMOUS, fd=-1, offset=0)
    mov rax, SYS_MMAP
    xor rdi, rdi          ; addr = NULL
    mov rsi, 4096         ; length = 1 page
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1            ; fd = -1 (无文件)
    xor r9, r9            ; offset = 0
    syscall

    ; rax 中为分配到的内存地址
    ; 在分配的内存中写入数据
    mov dword [rax], 0xDEADBEEF

    ; 正常退出
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
