`timescale 100 ps/10 ps

module nanci_tb ();
    reg clk;
    reg rst;

    PE #(.N(1),
         .SQRT_N(1),
         .I(0),
         .FILENAME("test/tb_data00.data"),
         .ADDR_WIDTH(3),
         .SORT_CYCLES(1),
         .FIRST_IN_ROW(0),
         .COMPUTE_CYCLES(1))
         PE_tb (.clk(clk),
          .rst(rst),
          .rst_memory(0),
          .i_PE_l(1),
          .i_PE_r(2),
          .i_PE_u(3),
          .i_PE_d(4),
          .o_PE());

    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
        #1000 $finish;
    end

    // GTKwave dumpfile setup
    initial
    begin
        $dumpfile("nanci.vcd");
        $dumpvars(0,nanci_tb);
    end
endmodule