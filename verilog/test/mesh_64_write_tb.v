`timescale 100 ps/10 ps

module mesh_64_write_tb ();
   reg clk;
   reg rst;

   parameter ADDR_WIDTH = 6;
   parameter DATA_WIDTH = 6;
   parameter WIDTH      = ADDR_WIDTH + DATA_WIDTH;
   parameter N          = 64;
   parameter SORT_CYCLES = 53;

   wire [DATA_WIDTH-1:0] mem   [N-1:0];
   wire [N-1:0] correct_output;
   
   genvar 	  k;

   mesh #(.N(N),
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
	  assign correct_output[k] = (mesh_tb.GEN[k].GENIF.PE.nanci_init.memory !== el[DATA_WIDTH-1:0]);
	  assign mem[k] = mesh_tb.GEN[k].GENIF.PE.nanci_init.memory;
       end
   endgenerate
   
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;

       #1000;
       if (correct_output !== {N{1'b0}}) begin
	  integer i;
	  $display("PE,out,corr");
	  for (i = 0; i < N; i=i+1) begin
	     $display("%d: %b %b", i, mem[i], N-1-i);
	  end
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
