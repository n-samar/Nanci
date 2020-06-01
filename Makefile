all:
	g++ -std=c++11 sort.cpp -O3 -o sort

gdb:
	g++ -g -std=c++11 sort.cpp -o sort_gdb
