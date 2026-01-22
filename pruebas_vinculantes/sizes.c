#include <stdio.h>
#include <elf.h>

int main(void) {
    printf("=== Elf64_Ehdr ===\n");
    printf("Tamaño total de Elf64_Ehdr: %zu bytes\n\n", sizeof(Elf64_Ehdr));

    printf("e_ident      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_ident));
    printf("e_type       : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_type));
    printf("e_machine    : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_machine));
    printf("e_version    : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_version));
    printf("e_entry      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_entry));
    printf("e_phoff      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_phoff));
    printf("e_shoff      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_shoff));
    printf("e_flags      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_flags));
    printf("e_ehsize     : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_ehsize));
    printf("e_phentsize  : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_phentsize));
    printf("e_phnum      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_phnum));
    printf("e_shentsize  : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_shentsize));
    printf("e_shnum      : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_shnum));
    printf("e_shstrndx   : %zu bytes\n", sizeof(((Elf64_Ehdr *)0)->e_shstrndx));

    printf("\n=== Elf64_Phdr ===\n");
    printf("Tamaño total de Elf64_Phdr: %zu bytes\n\n", sizeof(Elf64_Phdr));

    printf("p_type   : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_type));
    printf("p_flags  : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_flags));
    printf("p_offset : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_offset));
    printf("p_vaddr  : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_vaddr));
    printf("p_paddr  : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_paddr));
    printf("p_filesz : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_filesz));
    printf("p_memsz  : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_memsz));
    printf("p_align  : %zu bytes\n", sizeof(((Elf64_Phdr *)0)->p_align));

    return 0;
}

