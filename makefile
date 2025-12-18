NAME := Famine

CFLAGS = -Wall -Wextra -Werror
#CFLAGS += -Wno-comment -Wno-unused-variable -Wno-unused-parameter
###CFLAGS += -fsanitize=address

CC := gcc

SRC_FILES := famine.c

SRC_DIR := src
SRC := $(addprefix $(SRC_DIR)/, $(SRC_FILES))

OBJ_DIR := obj
OBJ := $(addprefix $(OBJ_DIR)/, $(SRC_FILES:.c=.o))

INC_DIR := include
INC_FLAGS = -I $(INC_DIR) -I.

.PHONY: all

all: $(OBJ_DIR) $(NAME)

$(OBJ_DIR):
	@[ ! -d $@ ] && mkdir -p $@

debug: CFLAGS += -g3
debug: all

$(NAME): $(OBJ)
	$(CC) $(CFLAGS) $(INC_FLAGS) $^ -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INC_FLAGS) -c $? -o $@

.PHONY: clean fclean re

clena clnea claen clean:
	rm -rf $(OBJ_DIR)/*.o

fclena fclnea fclaen fclean: clean
	rm -f $(NAME)
	rm -rf $(OBJ_DIR)

re: fclean all
