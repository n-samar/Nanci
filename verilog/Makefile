test: clean
	iverilog test/nanci_s_l_tb.v nanci.v -o objnanci_s_l && \
	iverilog test/nanci_s_r_tb.v nanci.v -o objnanci_s_r && \
	iverilog test/nanci_s_u_tb.v nanci.v -o objnanci_s_u && \
	iverilog test/nanci_s_d_tb.v nanci.v -o objnanci_s_d && \
	./objnanci_s_l && \
	./objnanci_s_r && \
	./objnanci_s_u && \
	./objnanci_s_d && \
	iverilog test/nanci_slt_l_tb.v nanci.v -o objnanci_slt_l && \
	iverilog test/nanci_slt_r_tb.v nanci.v -o objnanci_slt_r && \
	iverilog test/nanci_slt_u_tb.v nanci.v -o objnanci_slt_u && \
	iverilog test/nanci_slt_d_tb.v nanci.v -o objnanci_slt_d && \
	./objnanci_slt_l && \
	./objnanci_slt_r && \
	./objnanci_slt_u && \
	./objnanci_slt_d && \
	iverilog test/nanci_sgt_l_tb.v nanci.v -o objnanci_sgt_l && \
	iverilog test/nanci_sgt_r_tb.v nanci.v -o objnanci_sgt_r && \
	iverilog test/nanci_sgt_u_tb.v nanci.v -o objnanci_sgt_u && \
	iverilog test/nanci_sgt_d_tb.v nanci.v -o objnanci_sgt_d && \
	./objnanci_sgt_l && \
	./objnanci_sgt_r && \
	./objnanci_sgt_u && \
	./objnanci_sgt_d && \
	iverilog -g2005-sv test/mesh_04_tb.v nanci.v -o objnanci_mesh_4 && \
	./objnanci_mesh_4

run:
	iverilog -Wall test/nanci_s_l_tb.v nanci.v -o objnanci_s_l && \
	./nanci
clean:
	rm -rf test/objnanci* && \
	rm -rf ../verilog/nanci && \
	rm -rf ../verilog/*.vcd
