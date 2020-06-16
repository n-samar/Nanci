flags = -Wall -Wextra -Wcast-align -Wcast-qual -Wctor-dtor-privacy -Wdisabled-optimization -Wformat=2 -Winit-self -Wlogical-op -Wmissing-include-dirs -Wnoexcept -Woverloaded-virtual -Wredundant-decls -Wshadow -Wsign-conversion -Wsign-promo -Wstrict-null-sentinel -Wstrict-overflow=5 -Wswitch-default -Wundef -Werror -Wno-unused

all:
	g++ $(flags) -O3 -std=c++14 sort.cpp -pthread -O3 -o sort
	g++ $(flags) -std=c++14 get_filename_string.cpp -o get_filename_string

gdb:
	g++ $(flags) -g -std=c++14 sort.cpp -pthread -o sort_gdb 
profile:
	g++ $(flags) -pg -std=c++14 sort.cpp -pthread -o sort_pg
clean: 
	rm -rf ../data \
	rm ../simulation/sort_* \
	rm ../verilog/nanci \
	rm ../verilog/*.vcd
data: all
	rm -rf ../data/* && \
	./sort -N 2 -d && \
	./sort -N 4 -d && \
	./sort -N 8 -d && \
	./sort -N 16 -d && \
	./sort -N 32 -d && \
	./sort -N 64 -d

test: all
	./sort -N 2 -a && \
	./sort -N 4 -a && \
	./sort -N 8 -a && \
	./sort -N 16 -a && \
	./sort -N 32 -a && \
	./sort -N 64 -a
