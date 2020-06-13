`timescale 100 ps/10 ps

module nanci_tb ();
    reg clk;
    reg rst;

    PE #(.N(4),
         .SQRT_N(2),
         .I(0),
         .ADDR_WIDTH(3),
         .SORT_CYCLES(4),
         .COMPUTE_CYCLES(7))
         PE_tb (.clk(clk),
          .rst(rst),
          .i_PE_l(),
          .i_PE_r(),
          .i_PE_u(),
          .i_PE_d(),
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