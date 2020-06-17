`timescale 100 ps/10 ps

module mesh_64_tb ();
   reg clk;
   reg rst;

   parameter ADDR_WIDTH = 6;
   parameter DATA_WIDTH = 6;
   parameter WIDTH      = ADDR_WIDTH + DATA_WIDTH;
   parameter N          = 64;
   parameter SQRT_N     = 8;
   parameter SORT_CYCLES = 53;
  
    wire [WIDTH:0] nanci_result [N-1:0];   
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

   integer i, j;   
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
       #2000;
       for (i = 0; i < N; i=i+1) begin
	  j = N-1-i;
	  
          if (nanci_result[i] !== {1'b0, i[ADDR_WIDTH-1:0], j[ADDR_WIDTH-1:0]}) begin
	     $write("%c[1;31m",27);	   
             $display("[ERROR: %m] bad output for PE[%d]: %b !== %b", i, nanci_result[i], {i[ADDR_WIDTH-1:0], j[ADDR_WIDTH-1:0]});
	     $write("%c[0m",27);	   	   
	  end else begin
	     $write("%c[1;34m",27);	   	   	   
	     $display("[OK: %m]");
	     $write("%c[0m",27);	   
	  end
       end // for (i = 0; i < N; i=i+1)
       $finish;              
    end

    // GTKwave dumpfile setup
   initial
    begin
        $dumpfile("mesh.vcd");
        $dumpvars(0,mesh_64_tb);
    end
endmodule
