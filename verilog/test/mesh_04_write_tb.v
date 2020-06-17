`timescale 100 ps/10 ps

module mesh_04_write_tb ();
   reg clk;
   reg rst;

   parameter ADDR_WIDTH = 2;
   parameter DATA_WIDTH = 2;
   parameter WIDTH      = ADDR_WIDTH + DATA_WIDTH;
   parameter N          = 4;
   parameter SQRT_N     = 2;
   parameter SORT_CYCLES = 4;

   wire [DATA_WIDTH-1:0] mem   [N-1:0];
   wire [WIDTH:0] nanci_result [N-1:0];      
   mesh_db #(.N(N),
	     .SQRT_N(SQRT_N),
	     .ADDR_WIDTH(ADDR_WIDTH),
	     .DATA_WIDTH(DATA_WIDTH),
	     .SORT_CYCLES(SORT_CYCLES))
   mesh_tb (.clk(clk),
	    .rst(rst),
	    .nanci_result(nanci_result),
	    .mem(mem));

    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20 rst = 1'b0;
       #1000;
        if (mem[0] !== 2'b11) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for mem[0]: %b !== 11", mem[0]);
	   $write("%c[0m",27);	   	   
        end else if (mem[1] !== 2'b11) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for mem[1]: %b !== 11", mem[1]);
	   $write("%c[0m",27);	   	   	   
	end else if (mem[2] !== 2'b11) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for mem[2]: %b !== 11", mem[2]);
	   $write("%c[0m",27);	   	   	   	   
	end else if (mem[3] !== 5'b11) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for mem[3]: %b !== 11", mem[3]);
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
        $dumpvars(0,mesh_04_write_tb);
    end
endmodule
