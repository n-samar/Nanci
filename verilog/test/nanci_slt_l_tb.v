`timescale 100 ps/10 ps

// Test `s left'
module nanci_tb ();
    reg clk;
    reg rst;
   wire [5:0] o_PE;
   reg  [5:0] i_PE_l;
   reg [5:0] i_PE_r;
   reg [5:0] i_PE_u;
   reg [5:0] i_PE_d;
   
    PE #(.N(1),
         .SQRT_N(0),
         .I(0),
         .FILENAME("test/testdata/tb_data_slt_l.data"),
         .ADDR_WIDTH(3),
         .DATA_WIDTH(3),
         .SORT_CYCLES(1),
         .FIRST_IN_ROW(0))
         PE_tb (.clk(clk),
          .rst(rst),
          .rst_memory(3'b000),
          .i_PE_l(i_PE_l),
          .i_PE_r(i_PE_r),
          .i_PE_u(i_PE_u),
          .i_PE_d(i_PE_d),
          .o_PE(o_PE));

    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        i_PE_l = 6'b001000;
        i_PE_r = 6'b010000;
        i_PE_u = 6'b011000;
        i_PE_d = 6'b100000;
        #20 rst = 1'b0;
        #45;
        if (o_PE != 6'b001000) begin	   	   
	   $write("%c[1;31m",27);	   
           $display("[ERROR: nanci_slt_l_tb.v] bad output: %b != 001000", o_PE);
	   $write("%c[0m",27);	   
        end else begin
	   $write("%c[1;34m",27);
	   $display("[OK: nanci_slt_l_tb.v]");
	   $write("%c[0m",27);
	end
       $finish();
    end

    // GTKwave dumpfile setup

    /*initial
    begin
        $dumpfile("nanci.vcd");
        $dumpvars(0,nanci_tb);
    end */
endmodule
