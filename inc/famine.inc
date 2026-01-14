%define SC_OPEN        2
%define SC_CLOSE       3
%define SC_EXIT        60
%define SC_GETDENTS    78

%define	O_RDONLY       0x00000000
%define O_DIRECTORY    0x00010000


struc	dirent
    .d_inode	resq    1	; inode number
    .d_offset	resq	1	; offset to next structure
    .d_len  	resw	1	; Size of this dirent
    .d_name		resb	1	; Filename
endstruc


struc famine
    .fd_dir         resq    1
    .dirent_struc   resb    1024    
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
