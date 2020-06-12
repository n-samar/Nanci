flags = -Wall -Wextra -Wcast-align -Wcast-qual -Wctor-dtor-privacy -Wdisabled-optimization -Wformat=2 -Winit-self -Wlogical-op -Wmissing-include-dirs -Wnoexcept -Woverloaded-virtual -Wredundant-decls -Wshadow -Wsign-conversion -Wsign-promo -Wstrict-null-sentinel -Wstrict-overflow=5 -Wswitch-default -Wundef -Werror -Wno-unused

all:
	g++ $(flags) -O3 -std=c++11 sort.cpp -pthread -O3 -o sort

gdb:
	g++ $(flags) -g -std=c++11 sort.cpp -pthread -o sort_gdb 
profile:
	g++ $(flags) -pg -std=c++11 sort.cpp -pthread -o sort_pg
