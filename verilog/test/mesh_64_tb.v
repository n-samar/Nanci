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

   integer i, j;
   genvar  k;
   
   wire [N-1:0] correct_output;   
   wire [WIDTH:0] nanci_result [N-1:0];   
   mesh #(.N(N),
	     .SQRT_N(SQRT_N),
	     .ADDR_WIDTH(ADDR_WIDTH),
	     .DATA_WIDTH(DATA_WIDTH),
	     .SORT_CYCLES(SORT_CYCLES))
   mesh_tb (.clk(clk),
	    .rst(rst));

    always begin
        #5 clk = ~clk;
    end

   generate
       for (k = 0; k < N; k=k+1) begin
	  localparam el = N-1-k;
	  assign correct_output[k] = (mesh_tb.GEN[k].GENIF.PE.app_init.nanci_result !== {1'b0, k[ADDR_WIDTH-1:0], el[ADDR_WIDTH-1:0]}) ? 1'b1 : 1'b0;
       end
   endgenerate
   
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
       #2000;
       if (correct_output !== {N{1'b0}}) begin
	  $write("%c[1;31m",27);	   
          $display("[ERROR: %m] bad output: %b", correct_output);
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
