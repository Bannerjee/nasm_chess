
nasmWin  = nasm -fwin64 -o src/window.obj src/window.asm 
nasmGame = nasm -fwin64 -o src/game.obj src/game.asm 

compileResource = windres src/resource.rc src/resource.o
CXXFLAGS =  -lgdi32 -lglu32 -lopengl32 -Wall -pedantic -lgdiplus -lShlwapi
SOURCES = src/main.c 
OBJECTS = src/game.obj src/window.obj src/resource.o

compileGcc = g++ $(SOURCES) $(OBJECTS) -o demo $(CXXFLAGS)
debug:
	$(nasmWin)
	$(nasmGame)
	$(compileResource)
	$(compileGcc) -O0 -fno-inline -g
release:
	$(nasmWin)
	$(nasmGame)
	$(compileResource)
	$(compileGcc) -Oz -ffunction-sections -Wl,--gc-sections