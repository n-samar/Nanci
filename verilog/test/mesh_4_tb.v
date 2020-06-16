`timescale 100 ps/10 ps

module nanci_tb ();
    reg clk;
    reg rst;

   mesh mesh_tb (.clk(clk),
		 .rst(rst));

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
        $dumpfile("mesh.vcd");
        $dumpvars(0,mesh_tb);
    end
endmodule
