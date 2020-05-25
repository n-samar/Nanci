all:
	g++ -std=c++11 sort.cpp -O3 -o sort

debug:
	g++ -g -std=c++11 sort.cpp -o dbg_sort
