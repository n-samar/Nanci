`timescale 100 ps/10 ps

// Test `s left'
module nanci_tb ();
    reg clk;
    reg rst;
   wire [5:0] o_PE;
   
    PE #(.N(1),
         .SQRT_N(0),
         .I(0),
         .FILENAME("test/testdata/tb_data_s_l.data"),
         .ADDR_WIDTH(3),
         .DATA_WIDTH(3),
         .SORT_CYCLES(1),
         .FIRST_IN_ROW(0),
         .COMPUTE_CYCLES(1))
         PE_tb (.clk(clk),
          .rst(rst),
          .rst_memory(3'b000),
          .i_PE_l(6'b000_001),
          .i_PE_r(6'b000_010),
          .i_PE_u(6'b000_011),
          .i_PE_d(6'b000_100),
          .o_PE(o_PE));

    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
        #100;
        if (o_PE != 1) begin	   	   
	   $write("%c[1;31m",27);	   
           $display("[ERROR: nanci_s_l_tb.v] bad output: %b != 1", o_PE);
	   $write("%c[0m",27);	   
        end else begin
	   $write("%c[1;34m",27);
	   $display("[OK: nanci_s_l_tb.v]");
	   $write("%c[0m",27);
	end
       $finish();
    end

    // GTKwave dumpfile setup
   /*
    initial
    begin
        $dumpfile("nanci.vcd");
        $dumpvars(0,nanci_tb);
    end */
endmodule
