%include "inc/famine.inc"

default rel

section .text
    global _start
    hello db         "Hello World",0
    dirs db         "/tmp/test",0,"/tmp/test2",0

    _start:

        .open_dirs:
            mov rax, SC_OPEN
            lea rdi, [dirs]
            mov rsi, O_RDONLY | O_DIRECTORY
            syscall
            test rax, rax
            jl .exit

            mov rax, 1
            mov rdi, 1
            mov rsi, hello
            mov rdx, 12
            syscall
            mov rax, 60
            mov rdi, 0
            syscall

        .exit:
            mov rax, SC_EXIT
            syscall
