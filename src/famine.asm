%include "inc/famine.inc"

default rel

section .text
    ; Trazas
    hello db         "[+] Hello",10,0  ;11

    global _start
    dirs db         "/tmp/test",0,"/tmp/test2",0,0

    _start:

    mov rbp, rsp
    sub rbp, famine_size            ;generate stack

    lea rdi, [dirs]                 ;load dirs
    mov rsi, rdi
    
    .open_dir:
        cmp byte [rdi], 0
        je .exit
        mov rax, SC_OPEN
        mov rsi, O_RDONLY | O_DIRECTORY
        syscall
        test rax, rax
        jl .next_dir
        mov VAR(famine.fd_dir), rax
        TRACE_TEXT hello, 11        
        
    .next_dir:               
        mov rcx, -1
        xor al, al
        repne scasb                 ;busca /0
        cmp byte [rdi], 0
        jnz .open_dir
    
    .exit:
        mov rax, SC_EXIT
        syscall
    