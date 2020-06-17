module assert_always (input clk,
                      input test);
   always @(posedge clk) begin
      if (test !== 1) begin
	 $write("%c[1;31m",27);	   
         $display("[ASSERTION FAILED: %m]");
	 $write("%c[0m",27);
         $finish();
      end
   end
endmodule

module counter #(parameter ADDR_WIDTH = 16)
   (input                       clk,
    input 			rst,
    output reg [14-1:0] counter);
   always @(posedge clk) begin
      if (rst) begin
         counter <= 0; 
      end else begin
         counter <= counter+1;
      end
   end
endmodule


module PE #(parameter N = 1024,
	    parameter SQRT_N = 32,
	    parameter I = 0,
	    parameter FILENAME = "../data/0004/0000.data",
	    parameter ADDR_WIDTH = 10,
	    parameter DATA_WIDTH = 10,
	    parameter SORT_CYCLES = 222,
	    parameter FIRST_IN_ROW = 0)
   (input clk,
    input 		   rst,
    input [DATA_WIDTH-1:0] rst_memory,
    input [WIDTH:0] 	   i_PE_l,
    input [WIDTH:0] 	   i_PE_r,
    input [WIDTH:0] 	   i_PE_u,
    input [WIDTH:0] 	   i_PE_d,
    output [WIDTH:0] 	   o_PE,
    output [DATA_WIDTH-1:0] mem,            // Included as output only for debugging,
    output [WIDTH:0] 	   nanci_result);   // Included as output only for debugging,

   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   
   wire [WIDTH:0]    nanci_result;
   wire [WIDTH:0]    app_request;   
   wire [14-1:0]     compute_cycles;
     
   application #(.N(N),
		 .I(I),
		 .DATA_WIDTH(DATA_WIDTH),
		 .ADDR_WIDTH(ADDR_WIDTH)) 
   app_init (.clk(clk),
	     .rst(rst),
	     .runnable(runnable),
	     .nanci_result(nanci_result),
	     .app_request(app_request),
	     .compute_cycles(compute_cycles));
   
   nanci #(.N(N),
	   .SQRT_N(SQRT_N),
	   .I(I),
	   .FILENAME(FILENAME),
	   .ADDR_WIDTH(ADDR_WIDTH),
	   .DATA_WIDTH(DATA_WIDTH),
	   .SORT_CYCLES(SORT_CYCLES),
	   .FIRST_IN_ROW(FIRST_IN_ROW)) 
   nanci_init (.clk(clk),
	       .rst(rst),
	       .rst_memory(rst_memory),
	       .i_PE_l(i_PE_l),
	       .i_PE_r(i_PE_r),
	       .i_PE_u(i_PE_u),
	       .i_PE_d(i_PE_d),
	       .compute_cycles(compute_cycles),
	       .nanci_result(nanci_result),
	       .app_request(app_request),
	       .runnable(runnable),
	       .o_PE(o_PE),
	       .mem(mem));
endmodule

module nanci #(parameter N = 1024,                            // Total number of PEs
	       parameter SQRT_N = 32,                         // Side-length of mesh (= sqrt(N))
	       parameter I = 0,                               // Index of this PE
	       parameter FILENAME = "../data/0004/0000.data", // Filename for instructions
	       parameter ADDR_WIDTH = 10,                     // Width required to store index into PEs
	       parameter DATA_WIDTH = 10,                     // Width of memory register in each PE
	       parameter SORT_CYCLES = 222,                   // Number of cycles to run sort
	       parameter FIRST_IN_ROW = 0)                    // Index of first PE in this PE's 
   (input                   clk,
    input 		   rst,
    input [DATA_WIDTH-1:0] rst_memory, // Value of memory register after reset
    input [WIDTH:0] 	   i_PE_l,
    input [WIDTH:0] 	   i_PE_r,
    input [WIDTH:0] 	   i_PE_u,
    input [WIDTH:0] 	   i_PE_d, 
    input [14-1:0] 	   compute_cycles,
    input [WIDTH:0] 	   app_request,
    output reg [WIDTH:0]   nanci_result,
    output 		   runnable,
    output [WIDTH:0] 	   o_PE,
    output [DATA_WIDTH-1:0] mem);     // Included as output only for debugging

   assign mem = memory;

   parameter WIDTH  = ADDR_WIDTH + DATA_WIDTH;
   parameter MAX_INT = {(WIDTH+1){1'b1}};
   
   // States
   parameter COMPUTE                = 4'b0000;
   parameter PUT_ADDR               = 4'b0001;
   parameter PUSH_ADDR_SORT         = 4'b0010;
   parameter PUSH_ADDR_TO_ROW_MAJOR = 4'b0011;   
   parameter PUSH_ADDR_ROW_ALIGN    = 4'b0100;
   parameter PUSH_ADDR_COL_ALIGN    = 4'b0101;
   parameter LOAD_DATA              = 4'b0110;
   parameter GET_DATA_SORT          = 4'b0111;
   parameter GET_DATA_TO_ROW_MAJOR  = 4'b1000;   
   parameter GET_DATA_ROW_ALIGN     = 4'b1001;     
   parameter GET_DATA_COL_ALIGN     = 4'b1010;


   // Instructions
   parameter s_l  = 4'b11_00;
   parameter s_r  = 4'b11_01;
   parameter s_u  = 4'b11_10;
   parameter s_d  = 4'b11_11;

   parameter slt_l = 4'b01_00;
   parameter slt_r = 4'b01_01;
   parameter slt_u = 4'b01_10;
   parameter slt_d = 4'b01_11;

   parameter sgt_l = 4'b10_00;
   parameter sgt_r = 4'b10_01;
   parameter sgt_u = 4'b10_10;   
   parameter sgt_d = 4'b10_11;
   
   parameter nop   = 4'b00_00;

   reg [3:0] 			       state;
   reg [3:0] 			       next_state = 4'b0000;
   reg [3:0] 			       inst_ROM [SORT_CYCLES-1:0];

   assign runnable = (state == COMPUTE);
   wire 			       rst_counter = (state != next_state) | rst;
   wire [14-1:0] 		       clk_counter;
   counter #(ADDR_WIDTH) counter_init (.clk(clk),
                                       .rst(rst_counter),
                                       .counter(clk_counter));


   assert_always assert_data_width_geq_addr_width (clk, (DATA_WIDTH >= ADDR_WIDTH));

   // Used for debugging
   wire 			       s_01_COMPUTE = (state == COMPUTE);
   wire 			       s_02_PUT_ADDR = (state == PUT_ADDR);
   wire 			       s_03_PUSH_ADDR_SORT = (state == PUSH_ADDR_SORT);
   wire 			       s_04_PUSH_ADDR_TO_ROW_MAJOR = (state == PUSH_ADDR_TO_ROW_MAJOR);
   wire 			       s_05_PUSH_ADDR_ROW_ALIGN = (state == PUSH_ADDR_ROW_ALIGN);
   wire 			       s_06_PUSH_ADDR_COL_ALIGN = (state == PUSH_ADDR_COL_ALIGN);   
   wire 			       s_07_LOAD_DATA = (state == LOAD_DATA);
   wire 			       s_08_GET_DATA_SORT = (state == GET_DATA_SORT);
   wire 			       s_09_GET_DATA_TO_ROW_MAJOR = (state == GET_DATA_TO_ROW_MAJOR);
   wire 			       s_10_GET_DATA_ROW_ALIGN = (state == GET_DATA_ROW_ALIGN);
   wire 			       s_11_GET_DATA_COL_ALIGN = (state == GET_DATA_COL_ALIGN);
   wire [3:0] 			       s_12_INSTRUCTION = inst_ROM[clk_counter] & {14{(s_03_PUSH_ADDR_SORT | s_08_GET_DATA_SORT)}};


   reg [WIDTH:0] 		       comm_reg;    // Extra register needed for COL_ALIGN
   reg [DATA_WIDTH-1:0] 	       memory;      // Data held by processor I
   assign o_PE = comm_reg;
   
   // Initialize instruction ROM
   initial begin
      $display("%s\n", FILENAME);
      $readmemb(FILENAME, inst_ROM);
   end

   // Next-state logic
   always @(*) begin
      case (state)
        COMPUTE: begin
           if (clk_counter == compute_cycles-1) begin
              next_state = PUT_ADDR;
           end
        end
        PUT_ADDR: begin
           next_state = PUSH_ADDR_SORT;
        end
        PUSH_ADDR_SORT: begin
           if (clk_counter == SORT_CYCLES-1) begin
              next_state = PUSH_ADDR_TO_ROW_MAJOR;
           end
        end
	PUSH_ADDR_TO_ROW_MAJOR: begin
           if (clk_counter == SQRT_N) begin
              next_state = PUSH_ADDR_ROW_ALIGN;
           end	   
	end
        PUSH_ADDR_ROW_ALIGN: begin
           if (clk_counter == SQRT_N) begin
              next_state = PUSH_ADDR_COL_ALIGN;
           end
        end
        PUSH_ADDR_COL_ALIGN: begin
           if (clk_counter == SQRT_N) begin
              next_state = LOAD_DATA;
           end
        end
        LOAD_DATA: begin
           next_state = GET_DATA_SORT;
        end
        GET_DATA_SORT: begin
           if (clk_counter == SORT_CYCLES-1) begin
              next_state = GET_DATA_TO_ROW_MAJOR;
           end
        end
	GET_DATA_TO_ROW_MAJOR: begin
	   if (clk_counter == SQRT_N) begin
	      next_state = GET_DATA_ROW_ALIGN;
	   end
	end
        GET_DATA_ROW_ALIGN: begin
           if (clk_counter == SQRT_N) begin
              next_state = GET_DATA_COL_ALIGN;
           end
        end
        GET_DATA_COL_ALIGN: begin
           if (clk_counter == SQRT_N) begin
              next_state = COMPUTE;
           end
        end
      endcase 
   end

   always @(posedge clk) begin
      if (rst) begin
         state <= COMPUTE;
         memory <= rst_memory;
      end else begin
         state <= next_state;
      end
   end

   // Addressing logic
   always @(posedge clk) begin
      if (state == PUT_ADDR) begin
	 if (app_request[WIDTH] == 1'b0) begin
            // If read, load destination and source addresses
            comm_reg[WIDTH:DATA_WIDTH] <= app_request[WIDTH:DATA_WIDTH];
            comm_reg[DATA_WIDTH-1:DATA_WIDTH-ADDR_WIDTH] <= I[ADDR_WIDTH-1:0];
	 end else begin
	    // If write, just read app_request; it should already have the data in it
	    comm_reg <= app_request;
	 end
      end else if (state == LOAD_DATA) begin
	 if (nanci_result[WIDTH-1 -: ADDR_WIDTH] == I) begin
	    if (nanci_result[WIDTH] == 1'b0) begin
	       // Somebody requested a read from our memory
               comm_reg <= {1'b0, nanci_result[DATA_WIDTH-1:DATA_WIDTH-ADDR_WIDTH], memory};
	    end else begin
	       // Somebody wants to write to our memory
	       memory <= nanci_result[DATA_WIDTH-1:0];
	       comm_reg <= MAX_INT;
	    end
	 end else begin
	    // Nobody requested a read from our memory
	    comm_reg <= MAX_INT;
	 end
      end else if (state == PUSH_ADDR_SORT || state == GET_DATA_SORT) begin
         case(inst_ROM[clk_counter]) 
           s_l: begin
              comm_reg <= i_PE_l;
           end
           s_r: begin
              comm_reg <= i_PE_r;
           end
           s_u: begin
              comm_reg <= i_PE_u;
           end
           s_d: begin
              comm_reg <= i_PE_d;
           end
           slt_l: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
                          : comm_reg;
           end
           slt_r: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
                          : comm_reg;                
           end
           slt_u: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
                          : comm_reg;                
           end
           slt_d: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
                          : comm_reg;                
           end
           sgt_l: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
                          : comm_reg;
           end
           sgt_r: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
                          : comm_reg;                 
           end
           sgt_u: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
                          : comm_reg; 
           end
           sgt_d: begin
              comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
                          : comm_reg; 
           end
           nop: begin
              comm_reg <= comm_reg;
           end
         endcase
      end else if (state == PUSH_ADDR_TO_ROW_MAJOR || state == GET_DATA_TO_ROW_MAJOR) begin
	 if (clk_counter[0] == I[0]) begin
	    // swap right
	    if (I != FIRST_IN_ROW + SQRT_N - 1) begin
	       if (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_r[WIDTH-1:DATA_WIDTH]) begin
		  comm_reg <= i_PE_r;
	       end else begin
		  comm_reg <= comm_reg;
	       end
	    end
	 end else begin
	    // swap left
	    if (I != FIRST_IN_ROW) begin
	       if (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]) begin
		  comm_reg <= i_PE_l;
	       end else begin
		  comm_reg <= comm_reg;
	       end
	    end
	 end
      end else if (state == PUSH_ADDR_ROW_ALIGN || state == GET_DATA_ROW_ALIGN) begin
         if (comm_reg[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
            // comm_reg holds no value, should look to see if PE_u has something for it
            if (i_PE_u[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW) begin
               comm_reg <= i_PE_u;
            end else begin
               comm_reg[WIDTH-1:DATA_WIDTH] <= MAX_INT;
            end
         end else if (comm_reg[WIDTH-1:DATA_WIDTH] < FIRST_IN_ROW + SQRT_N && comm_reg[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW) begin
            // comm_reg's key-value pair is in proper position, do nothing
            comm_reg <= comm_reg;
         end else if (comm_reg[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW + SQRT_N) begin
            // comm_reg's key-value pair is too high up, move it down if possible
            if (i_PE_d[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
               comm_reg <= i_PE_d;
            end else begin
               comm_reg <= comm_reg;
            end
         end else begin
            // Shouldn't get here ever
            comm_reg <= comm_reg;
         end
      end else if (state == PUSH_ADDR_COL_ALIGN || state == GET_DATA_COL_ALIGN) begin
         if (comm_reg[WIDTH-1:DATA_WIDTH] == I) begin
            // comm_reg holds the right value, copy into nanci_result
            nanci_result <= comm_reg;
            // Discard comm_reg's address pins
            comm_reg[WIDTH-1:DATA_WIDTH] <= MAX_INT;
         end else if (comm_reg[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
            // comm_reg holds no value
            // should look to see if PE_l or PE_r has something for it
            if (i_PE_l[WIDTH-1:DATA_WIDTH] >= I) begin
               comm_reg <= i_PE_l;
            end else if (i_PE_r[WIDTH-1:DATA_WIDTH] <= I) begin
               comm_reg <= i_PE_r;
            end
         end else begin
            // comm_reg holds some value that is not MAX_INT and is not I
            // try to exchange with neighbors if possible
            if (comm_reg[WIDTH-1:DATA_WIDTH] > I) begin
               // should move right
               if (i_PE_r[WIDTH-1:DATA_WIDTH] == MAX_INT || i_PE_r[WIDTH-1:DATA_WIDTH] <= I) begin
                  comm_reg <= i_PE_r;
               end else begin
                  // no space in right neighbor, can't move
                  comm_reg <= comm_reg;
               end
            end else begin
               // should move left
               if (i_PE_l[WIDTH-1:DATA_WIDTH] == MAX_INT || i_PE_l[WIDTH-1:DATA_WIDTH] >= I) begin
                  comm_reg <= i_PE_l;
               end else begin
                  // no space in left neighbor, can't move
                  comm_reg <= comm_reg;
               end
            end
         end
      end
   end
endmodule

// Debug version of mesh module
// No need for wire PE[] to be exposed as output (expect for debugging)
// Should only load/read data from one side of the square generated by the mesh
module mesh_db #(parameter N = 4,                            // Total number of PEs
		 parameter SQRT_N = 2,                         // Side-length of mesh (= sqrt(N))
		 parameter ADDR_WIDTH = 4,                     // Width required to store index into PEs
		 parameter DATA_WIDTH = 4,                     // Width of memory register in each PE
		 parameter SORT_CYCLES = 4)                    // Number of cycles to run sort
   (input clk,
    input 		    rst,
    output [WIDTH:0] 	    PE [N-1:0],              // Included in output only for debugging
    output [DATA_WIDTH-1:0] mem [N-1:0],             // Included in output only for debugging
    output [WIDTH:0] 	    nanci_result [N-1:0]);   // Included in output only for debugging
   
   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   parameter MAX_INT = {(WIDTH+1){1'b1}};
   parameter FILENAME_OFFSET = 2*(N/2-2)/3*22*8;
   
   // TODO: Generalize X to work with any N
   parameter  X = "../data/0256/0255.data../data/0256/0254.data../data/0256/0253.data../data/0256/0252.data../data/0256/0251.data../data/0256/0250.data../data/0256/0249.data../data/0256/0248.data../data/0256/0247.data../data/0256/0246.data../data/0256/0245.data../data/0256/0244.data../data/0256/0243.data../data/0256/0242.data../data/0256/0241.data../data/0256/0240.data../data/0256/0239.data../data/0256/0238.data../data/0256/0237.data../data/0256/0236.data../data/0256/0235.data../data/0256/0234.data../data/0256/0233.data../data/0256/0232.data../data/0256/0231.data../data/0256/0230.data../data/0256/0229.data../data/0256/0228.data../data/0256/0227.data../data/0256/0226.data../data/0256/0225.data../data/0256/0224.data../data/0256/0223.data../data/0256/0222.data../data/0256/0221.data../data/0256/0220.data../data/0256/0219.data../data/0256/0218.data../data/0256/0217.data../data/0256/0216.data../data/0256/0215.data../data/0256/0214.data../data/0256/0213.data../data/0256/0212.data../data/0256/0211.data../data/0256/0210.data../data/0256/0209.data../data/0256/0208.data../data/0256/0207.data../data/0256/0206.data../data/0256/0205.data../data/0256/0204.data../data/0256/0203.data../data/0256/0202.data../data/0256/0201.data../data/0256/0200.data../data/0256/0199.data../data/0256/0198.data../data/0256/0197.data../data/0256/0196.data../data/0256/0195.data../data/0256/0194.data../data/0256/0193.data../data/0256/0192.data../data/0256/0191.data../data/0256/0190.data../data/0256/0189.data../data/0256/0188.data../data/0256/0187.data../data/0256/0186.data../data/0256/0185.data../data/0256/0184.data../data/0256/0183.data../data/0256/0182.data../data/0256/0181.data../data/0256/0180.data../data/0256/0179.data../data/0256/0178.data../data/0256/0177.data../data/0256/0176.data../data/0256/0175.data../data/0256/0174.data../data/0256/0173.data../data/0256/0172.data../data/0256/0171.data../data/0256/0170.data../data/0256/0169.data../data/0256/0168.data../data/0256/0167.data../data/0256/0166.data../data/0256/0165.data../data/0256/0164.data../data/0256/0163.data../data/0256/0162.data../data/0256/0161.data../data/0256/0160.data../data/0256/0159.data../data/0256/0158.data../data/0256/0157.data../data/0256/0156.data../data/0256/0155.data../data/0256/0154.data../data/0256/0153.data../data/0256/0152.data../data/0256/0151.data../data/0256/0150.data../data/0256/0149.data../data/0256/0148.data../data/0256/0147.data../data/0256/0146.data../data/0256/0145.data../data/0256/0144.data../data/0256/0143.data../data/0256/0142.data../data/0256/0141.data../data/0256/0140.data../data/0256/0139.data../data/0256/0138.data../data/0256/0137.data../data/0256/0136.data../data/0256/0135.data../data/0256/0134.data../data/0256/0133.data../data/0256/0132.data../data/0256/0131.data../data/0256/0130.data../data/0256/0129.data../data/0256/0128.data../data/0256/0127.data../data/0256/0126.data../data/0256/0125.data../data/0256/0124.data../data/0256/0123.data../data/0256/0122.data../data/0256/0121.data../data/0256/0120.data../data/0256/0119.data../data/0256/0118.data../data/0256/0117.data../data/0256/0116.data../data/0256/0115.data../data/0256/0114.data../data/0256/0113.data../data/0256/0112.data../data/0256/0111.data../data/0256/0110.data../data/0256/0109.data../data/0256/0108.data../data/0256/0107.data../data/0256/0106.data../data/0256/0105.data../data/0256/0104.data../data/0256/0103.data../data/0256/0102.data../data/0256/0101.data../data/0256/0100.data../data/0256/0099.data../data/0256/0098.data../data/0256/0097.data../data/0256/0096.data../data/0256/0095.data../data/0256/0094.data../data/0256/0093.data../data/0256/0092.data../data/0256/0091.data../data/0256/0090.data../data/0256/0089.data../data/0256/0088.data../data/0256/0087.data../data/0256/0086.data../data/0256/0085.data../data/0256/0084.data../data/0256/0083.data../data/0256/0082.data../data/0256/0081.data../data/0256/0080.data../data/0256/0079.data../data/0256/0078.data../data/0256/0077.data../data/0256/0076.data../data/0256/0075.data../data/0256/0074.data../data/0256/0073.data../data/0256/0072.data../data/0256/0071.data../data/0256/0070.data../data/0256/0069.data../data/0256/0068.data../data/0256/0067.data../data/0256/0066.data../data/0256/0065.data../data/0256/0064.data../data/0256/0063.data../data/0256/0062.data../data/0256/0061.data../data/0256/0060.data../data/0256/0059.data../data/0256/0058.data../data/0256/0057.data../data/0256/0056.data../data/0256/0055.data../data/0256/0054.data../data/0256/0053.data../data/0256/0052.data../data/0256/0051.data../data/0256/0050.data../data/0256/0049.data../data/0256/0048.data../data/0256/0047.data../data/0256/0046.data../data/0256/0045.data../data/0256/0044.data../data/0256/0043.data../data/0256/0042.data../data/0256/0041.data../data/0256/0040.data../data/0256/0039.data../data/0256/0038.data../data/0256/0037.data../data/0256/0036.data../data/0256/0035.data../data/0256/0034.data../data/0256/0033.data../data/0256/0032.data../data/0256/0031.data../data/0256/0030.data../data/0256/0029.data../data/0256/0028.data../data/0256/0027.data../data/0256/0026.data../data/0256/0025.data../data/0256/0024.data../data/0256/0023.data../data/0256/0022.data../data/0256/0021.data../data/0256/0020.data../data/0256/0019.data../data/0256/0018.data../data/0256/0017.data../data/0256/0016.data../data/0256/0015.data../data/0256/0014.data../data/0256/0013.data../data/0256/0012.data../data/0256/0011.data../data/0256/0010.data../data/0256/0009.data../data/0256/0008.data../data/0256/0007.data../data/0256/0006.data../data/0256/0005.data../data/0256/0004.data../data/0256/0003.data../data/0256/0002.data../data/0256/0001.data../data/0256/0000.data../data/0064/0063.data../data/0064/0062.data../data/0064/0061.data../data/0064/0060.data../data/0064/0059.data../data/0064/0058.data../data/0064/0057.data../data/0064/0056.data../data/0064/0055.data../data/0064/0054.data../data/0064/0053.data../data/0064/0052.data../data/0064/0051.data../data/0064/0050.data../data/0064/0049.data../data/0064/0048.data../data/0064/0047.data../data/0064/0046.data../data/0064/0045.data../data/0064/0044.data../data/0064/0043.data../data/0064/0042.data../data/0064/0041.data../data/0064/0040.data../data/0064/0039.data../data/0064/0038.data../data/0064/0037.data../data/0064/0036.data../data/0064/0035.data../data/0064/0034.data../data/0064/0033.data../data/0064/0032.data../data/0064/0031.data../data/0064/0030.data../data/0064/0029.data../data/0064/0028.data../data/0064/0027.data../data/0064/0026.data../data/0064/0025.data../data/0064/0024.data../data/0064/0023.data../data/0064/0022.data../data/0064/0021.data../data/0064/0020.data../data/0064/0019.data../data/0064/0018.data../data/0064/0017.data../data/0064/0016.data../data/0064/0015.data../data/0064/0014.data../data/0064/0013.data../data/0064/0012.data../data/0064/0011.data../data/0064/0010.data../data/0064/0009.data../data/0064/0008.data../data/0064/0007.data../data/0064/0006.data../data/0064/0005.data../data/0064/0004.data../data/0064/0003.data../data/0064/0002.data../data/0064/0001.data../data/0064/0000.data../data/0016/0015.data../data/0016/0014.data../data/0016/0013.data../data/0016/0012.data../data/0016/0011.data../data/0016/0010.data../data/0016/0009.data../data/0016/0008.data../data/0016/0007.data../data/0016/0006.data../data/0016/0005.data../data/0016/0004.data../data/0016/0003.data../data/0016/0002.data../data/0016/0001.data../data/0016/0000.data../data/0004/0003.data../data/0004/0002.data../data/0004/0001.data../data/0004/0000.data";
   

   genvar 	    i;
   generate
      for (i = 0; i < N; i=i+1) begin : GEN
         if (i == 0) begin
            // top-left PE
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i == N-1) begin
            // bottom-right PE
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i == N-SQRT_N) begin 
            // bottom-left PE
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i == SQRT_N-1) begin
            // top-right PE
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i < SQRT_N) begin
            // top row
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i >= N-SQRT_N) begin
            // bottom row
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i%SQRT_N == 0) begin
            // left column
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else if (i%SQRT_N == SQRT_N-1) begin
            // right column
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end else begin
            // in middle of mesh
            PE #(.N(N),
                 .SQRT_N(SQRT_N),
                 .I(i),
                 .FILENAME(X[(i+1)*22*8+FILENAME_OFFSET-1 -: 22*8]),
                 .ADDR_WIDTH(ADDR_WIDTH),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES),
                 .FIRST_IN_ROW(i-i%SQRT_N))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[ADDR_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]),
		.nanci_result(nanci_result[i]),
		.mem(mem[i]));
         end
      end
   endgenerate
endmodule
