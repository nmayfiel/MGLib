# MiniGraphics Library
# Nick Mayfield (@PSDRNDM)

NOM		= libmg.a
FNS		= macos/mg.m macos/MacosPlatformInterface.m macos/MacosDebug.c \
		  opengl/default_shaders.c

OBJX		= $(FNS:.c=.o)
OBJ		= $(OBJX:.m=.o)
CFLAGS		+= -O2 -I./ -Iopengl/

# Comment line below to enable assertions and debug printing
CFLAGS		+= -DNDEBUG

all: $(NOM)

$(NOM): $(OBJ)
	ar -r $(NOM) $(OBJ)
	ranlib $(NOM)

clean:
	/bin/rm -f $(OBJ) *~

fclean: clean
	/bin/rm -f $(NOM) *~

re: fclean all

.PHONY: all clean fclean re
