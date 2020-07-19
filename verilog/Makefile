test: clean
	iverilog -g2005-sv test/nanci_s_l_tb.v test/app_read_opposite.v nanci.v -o objnanci_s_l && \
	iverilog -g2005-sv test/nanci_s_r_tb.v test/app_read_opposite.v nanci.v -o objnanci_s_r && \
	iverilog -g2005-sv test/nanci_s_u_tb.v test/app_read_opposite.v nanci.v -o objnanci_s_u && \
	iverilog -g2005-sv test/nanci_s_d_tb.v test/app_read_opposite.v nanci.v -o objnanci_s_d && \
	./objnanci_s_l && \
	./objnanci_s_r && \
	./objnanci_s_u && \
	./objnanci_s_d && \
	iverilog -g2005-sv test/nanci_slt_l_tb.v test/app_read_opposite.v nanci.v -o objnanci_slt_l && \
	iverilog -g2005-sv test/nanci_slt_r_tb.v test/app_read_opposite.v nanci.v -o objnanci_slt_r && \
	iverilog -g2005-sv test/nanci_slt_u_tb.v test/app_read_opposite.v nanci.v -o objnanci_slt_u && \
	iverilog -g2005-sv test/nanci_slt_d_tb.v test/app_read_opposite.v nanci.v -o objnanci_slt_d && \
	./objnanci_slt_l && \
	./objnanci_slt_r && \
	./objnanci_slt_u && \
	./objnanci_slt_d && \
	iverilog -g2005-sv test/nanci_sgt_l_tb.v test/app_read_opposite.v nanci.v -o objnanci_sgt_l && \
	iverilog -g2005-sv test/nanci_sgt_r_tb.v test/app_read_opposite.v nanci.v -o objnanci_sgt_r && \
	iverilog -g2005-sv test/nanci_sgt_u_tb.v test/app_read_opposite.v nanci.v -o objnanci_sgt_u && \
	iverilog -g2005-sv test/nanci_sgt_d_tb.v test/app_read_opposite.v nanci.v -o objnanci_sgt_d && \
	./objnanci_sgt_l && \
	./objnanci_sgt_r && \
	./objnanci_sgt_u && \
	./objnanci_sgt_d && \
	iverilog -g2005-sv test/mesh_04_tb.v test/app_read_opposite.v nanci.v -o objnanci_mesh_04 && \
	./objnanci_mesh_04 && \
	iverilog -g2005-sv test/mesh_16_tb.v test/app_read_opposite.v nanci.v -o objnanci_mesh_16 && \
	./objnanci_mesh_16 && \
	iverilog -g2005-sv test/mesh_64_tb.v test/app_read_opposite.v nanci.v -o objnanci_mesh_64 && \
	./objnanci_mesh_64 && \
	iverilog -g2005-sv test/mesh_256_tb.v test/app_read_opposite.v nanci.v -o objnanci_mesh_256 && \
	./objnanci_mesh_256 && \
	iverilog -g2005-sv test/mesh_04_write_tb.v test/app_write_opposite.v nanci.v -o objnanci_mesh_write_04 && \
	./objnanci_mesh_write_04 && \
	iverilog -g2005-sv test/mesh_16_write_tb.v test/app_write_opposite.v nanci.v -o objnanci_mesh_write_16 && \
	./objnanci_mesh_write_16 && \
	iverilog -g2005-sv test/mesh_64_write_tb.v test/app_write_opposite.v nanci.v -o objnanci_mesh_write_64 && \
	./objnanci_mesh_write_64 && \
	iverilog -g2005-sv test/mesh_256_write_tb.v test/app_write_opposite.v nanci.v -o objnanci_mesh_write_256 && \
	./objnanci_mesh_write_256

sheartest: clean
	iverilog -g2005-sv test/mesh_16_shear_tb.v test/app_read_opposite.v nanci_shearsort.v -o objnanci_mesh_16 && \
	./objnanci_mesh_16

run:
	iverilog -Wall test/nanci_s_l_tb.v nanci.v -o objnanci_s_l && \
	./nanci
clean:
	rm -rf test/objnanci* && \
	rm -rf ../verilog/nanci && \
	rm -rf ../verilog/*.vcd
