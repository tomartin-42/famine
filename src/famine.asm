%include "inc/famine.inc"

default rel

section .text
    ; Trazas
    hello db            "[+] Hello",10,0  ;11
    folder db           "F",10,0 ;3

    global _start
    dirs db         "/tmp/test",0,"/tmp/test2",0,0

    _start:

    mov rbp, rsp
    sub rbp, famine_size            ;generate stack

    lea r14, [dirs]                 ;load dirs
    ;mov rsi, rdi
    
    .open_dir:
            TRACE_TEXT folder, 3
        cmp byte [r14], 0
        je .exit
        mov rax, SC_OPEN
        mov rsi, O_RDONLY | O_DIRECTORY
        syscall
        test rax, rax
        jl .next_dir
        mov VAR(famine.fd_dir), rax

        .dirent:
            mov rax, SC_GETDENTS
            mov rdi, VAR(famine.fd_dir)
            lea rsi, VAR(famine.dirent_struc)
            mov rdx, 1024
            syscall
            test rax, rax
            jle .close_dir
            xor r12, r12            

        .validate_files_types:
            lea rdi, VAR(famine.dirent_struc)
            add rdi, r12
            movzx edx, word [rdi + dirent.d_len]
            add r12, rdx
            cmp [rdi + rdx - 1], REGULAR_FILE
            jne .next_file
            call process

        .next_file:
            cmp r12, rax
            jne .validate_files_types
            
        .close_dir:
            mov rax, SC_CLOSE
            mov rdi, VAR(famine.fd_dir)
            syscall

        .next_dir:        ; fallo por rdi que cambia y no apunta a la string de directorios
            mov rsi, r14
        
        .find_null:
            lodsb               ; al = *rsi++
            test al, al
            jnz .find_null

            mov r14, rsi
            cmp byte [r14], 0   ; find double null
            jnz .open_dir

        .exit:
            mov rax, SC_EXIT
            syscall
    
    process:
        TRACE_TEXT hello, 11        
        ret
    
    