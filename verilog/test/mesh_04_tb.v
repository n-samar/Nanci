`timescale 100 ps/10 ps

module mesh_04_tb ();
   reg clk;
   reg rst;

   wire [2+2-1:0] nanci_result [4-1:0];   
   mesh_db mesh_tb (.clk(clk),
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
        end else if (nanci_result[1] !== 4'b0110) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[1]: %b !== 4'b0110", nanci_result[1]);
	   $write("%c[0m",27);	   	   	   
	end else if (nanci_result[2] !== 4'b1001) begin
	   $write("%c[1;31m",27);	   
           $display("[ERROR: %m] bad output for PE[2]: %b !== 4'b1001", nanci_result[2]);
	   $write("%c[0m",27);	   	   	   	   
	end else if (nanci_result[3] !== 4'b1100) begin
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
