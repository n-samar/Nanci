// User application module
module application #(parameter N = 1024,
                     parameter I = 0,
                     parameter DATA_WIDTH = 32) 
   (input clk,
    input 		 rst,
    input 		 runnable,
    input [WIDTH:0] 	 nanci_result,
    output reg [WIDTH:0] app_request,
    output [14-1:0] 	 compute_cycles);

   parameter ADDR_WIDTH = (N == 1024) ? 10 :
			  (N == 256)  ? 8  :
			  (N == 64)   ? 6  :
			  (N == 16)   ? 4  :
			  (N == 4)    ? 2  : 2;
   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   assign compute_cycles = 5;
  
   always @(posedge clk) begin
      if (runnable) begin
	 app_request[WIDTH] <= 1'b1;                         // specify write
         app_request[WIDTH-1:DATA_WIDTH] <= N-1-I;
         app_request[DATA_WIDTH-1:0] <= I;                   // write itself
      end
   end
endmodule
