%define SC_OPEN        2
%define SC_EXIT        60

%define	O_RDONLY       0x00000000
%define O_DIRECTORY    0x00010000


struc famine
    .fd_dir_1 resq     1
    .fd_dir_2 resq     1
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
