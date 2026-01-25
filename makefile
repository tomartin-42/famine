NAME = famine

SRC_DIR = src/
OBJ_DIR = obj/
COMP = nasm
ASMFLAGS = -f elf64 -F dwarf
LD = ld
CONTAINER_NAME = docker_famine

SRC_FILES = famine.asm
SRC = $(addprefix $(SRC_DIR), $(SRC_FILES))

OBJ_FILES = $(SRC_FILES:.asm=.o)
OBJ = $(addprefix $(OBJ_DIR), $(OBJ_FILES))

all: obj $(NAME)

obj:
	@mkdir -p $(OBJ_DIR)

$(OBJ_DIR)%.o: $(SRC_DIR)%.asm
	$(COMP) $(ASMFLAGS) -o $@ $< 

$(NAME): $(OBJ)
	$(LD) -o $(NAME) $(OBJ)

fclean: clean
	@rm -f $(NAME)
	@rm -Rf $(OBJ_DIR)

clean:
	@rm -Rf $(OBJ_DIR)

build: 
	@echo "Building image $(CONTAINER_NAME)"
	docker build -t $(CONTAINER_NAME) .

docker: 
	@echo "Run container $(CONTAINER_NAME)"
	docker run --rm -it --net=bridge \
  	--cap-add=NET_ADMIN \
  	-v $(CURDIR):/app \
  	$(CONTAINER_NAME)

re: fclean all
