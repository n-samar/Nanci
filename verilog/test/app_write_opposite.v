// User application module
module application #(parameter N = 1024,
                     parameter I = 0,
                     parameter DATA_WIDTH = 10,
                     parameter ADDR_WIDTH = 10) 
   (input clk,
    input 				   rst,
    input 				   runnable,
    input [ADDR_WIDTH+DATA_WIDTH:0] 	   nanci_result,
    output reg [ADDR_WIDTH+DATA_WIDTH:0] app_request,
    output [14-1:0] 			   compute_cycles);

   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   assign compute_cycles = 5;
  
   always @(posedge clk) begin
      if (runnable) begin
	 app_request[WIDTH] <= 1'b1;                         // specify write
         app_request[WIDTH-1:DATA_WIDTH] <= N-1-I;
         app_request[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b1}};  // write all 1's to destination
      end
   end
endmodule
