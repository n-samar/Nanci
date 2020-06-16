`timescale 100 ps/10 ps

module mesh_04_tb ();
   reg clk;
   reg rst;

   parameter ADDR_WIDTH = 6;
   parameter DATA_WIDTH = 6;
   parameter WIDTH      = ADDR_WIDTH + DATA_WIDTH;
   parameter N          = 16;
   parameter SQRT_N     = 4;
   parameter SORT_CYCLES = 21;
  
    wire [WIDTH-1:0] nanci_result [N-1:0];   
   mesh_db #(.N(N),
	     .SQRT_N(SQRT_N),
	     .ADDR_WIDTH(ADDR_WIDTH),
	     .DATA_WIDTH(DATA_WIDTH),
	     .SORT_CYCLES(SORT_CYCLES))
   mesh_tb (.clk(clk),
	    .rst(rst),
	    .nanci_result(nanci_result));

    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
       #1000;
        if (nanci_result[0] !== 4'b0011) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[0]: %b !== 4'b0011", nanci_result[0]);
	   $write("%c[0m",27);	   	   
        end else if (nanci_result[SQRT_N-1] !== 4'b0110) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[1]: %b !== 4'b0110", nanci_result[1]);
	   $write("%c[0m",27);	   	   	   
	end else if (nanci_result[N-SQRT_N] !== 4'b1001) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[2]: %b !== 4'b1001", nanci_result[2]);
	   $write("%c[0m",27);	   	   	   	   
	end else if (nanci_result[N-1] !== 4'b1100) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[3]: %b !== 4'b1100", nanci_result[3]);
	   $write("%c[0m",27);	   	   	   	   
	end else begin
	   $write("%c[1;34m",27);	   	   	   
	   $display("[OK: %m]");
	   $write("%c[0m",27);	   
	end
       $finish;       
    end

    // GTKwave dumpfile setup
   initial
    begin
        $dumpfile("mesh.vcd");
        $dumpvars(0,mesh_tb);
    end
endmodule
