%define SC_OPEN         2
%define SC_CLOSE        3
%define SC_FSTAT        5
%define SC_EXIT         60
%define SC_GETDENTS     78
%define SC_OPENAT       257      

%define	O_RDONLY        0x00000000
%define O_DIRECTORY     0x00010000

; Para dirent
%define REGULAR_FILE        0x08 

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

struc	dirent
    .d_inode	resq    1	; inode number
    .d_offset	resq	1	; offset to next structure
    .d_len  	resw	1	; Size of this dirent
    .d_name		resb	1	; Filename
endstruc ; OJO el typo de fichero está al final, en el último byte del registro. 8 para ficheros regulares


struc famine
    .fd_dir             resq    1
    .fd_file            resq    1
    .dirent_struc       resb    1024
    .dir_name_pointer   resq    1
    .file_permissions   resd    1
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

%define VAR(n) [(rbp - famine_size) + n]
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
; | .fd_dir     | <--- VAR(Data) ej: mov rax, VAR(famine.fd_dir)
; |             |
; |             |
; |             |
; |             |
; --------------- <- ebp
