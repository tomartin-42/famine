#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>
#include <signal.h>

int main() {
    const size_t X = 4096;          // tamaño inicial del fichero
    const size_t EXTRA = 10000;
    const char *filename = "testfile.bin";

    int fd = open(filename, O_RDWR | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) {
        perror("open");
        exit(1);
    }

    // Fichero inicialmente de tamaño X
    if (ftruncate(fd, X) < 0) {
        perror("ftruncate inicial");
        exit(1);
    }

	for (int i = 0; i < X; i++) {
		write(fd, &(char[]){'A'}, 1);
	}

    // mmap MÁS GRANDE que el fichero
    char *map = mmap(NULL, X + EXTRA,
                     PROT_READ | PROT_WRITE,
                     MAP_SHARED,
                     fd, 0);

    if (map == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }

    printf("mmap ok (tamaño %zu)\n", X + EXTRA);

    // Ahora agrandamos el fichero DESPUÉS del mmap
    if (ftruncate(fd, X + EXTRA) < 0) {
        perror("ftruncate posterior");
        exit(1);
    }

    printf("ftruncate posterior ok (nuevo tamaño %zu)\n", X + EXTRA);

    // Escritura dentro del tamaño original
    strcpy(map, "Hola dentro del tamaño original");
    printf("Escritura dentro de X OK\n");

    // Escritura más allá del tamaño original
    printf("Intentando escribir más allá de X...\n");
    map[X + 500] = 'A';
    map[X + EXTRA - 1] = 'Z';

    printf("Escritura más allá de X OK\n");

    munmap(map, X + EXTRA);
    close(fd);
    return 0;
}
