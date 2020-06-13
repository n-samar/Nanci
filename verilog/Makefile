all:
	iverilog -Wall nanci_tb.v nanci.v -o nanci
gtk: all
	./nanci; gtkwave nanci.vcd
run: all
	./nanci