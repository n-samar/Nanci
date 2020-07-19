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
	    parameter I = 0,
	    parameter DATA_WIDTH = 32,
	    parameter SORT_CYCLES = 222)
   (input clk,
    input 		   rst,
    input [DATA_WIDTH-1:0] rst_memory,
    input [WIDTH:0] 	   i_PE_l,
    input [WIDTH:0] 	   i_PE_r,
    input [WIDTH:0] 	   i_PE_u,
    input [WIDTH:0] 	   i_PE_d,
    output [WIDTH:0] 	   o_PE);

   parameter ADDR_WIDTH = (N == 1024) ? 10 :
			  (N == 256)  ? 8  :
			  (N == 64)   ? 6  :
			  (N == 16)   ? 4  :
			  (N == 4)    ? 2  : 2;
   
   parameter SQRT_N = (N == 1024) ? 32 :
		      (N == 256)  ? 16 :
		      (N == 64)   ? 8  :
		      (N == 16)   ? 4  :
		      (N == 4)    ? 2  :
		      (N == 1)    ? 1  : 0;
   
   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   parameter FIRST_IN_ROW = I - I%SQRT_N;
			    
   wire [WIDTH:0] 		       app_request;   
   wire [WIDTH:0] 		       nanci_result;
   wire [14-1:0] 		       compute_cycles;
   
   
   application #(.N(N),
		 .I(I),
		 .DATA_WIDTH(DATA_WIDTH)) 
   app_init (.clk(clk),
	     .rst(rst),
	     .runnable(runnable),
	     .nanci_result(nanci_result),
	     .app_request(app_request),
	     .compute_cycles(compute_cycles));
   
   nanci #(.N(N),
	   .I(I),
	   .DATA_WIDTH(DATA_WIDTH),
	   .SORT_CYCLES(SORT_CYCLES)) 
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
	       .o_PE(o_PE));
endmodule

module nanci #(parameter N = 1024,                            // Total number of PEs
	       parameter I = 0,                               // Index of this PE
	       parameter DATA_WIDTH = 32,                     // Width of memory register in each PE
	       parameter SORT_CYCLES = 222)                   // Number of cycles to run sort
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
    output [WIDTH:0] 	   o_PE);

   parameter ADDR_WIDTH = (N == 1024) ? 10 :
			  (N == 256)  ? 8  :
			  (N == 64)   ? 6  :
			  (N == 16)   ? 4  :
			  (N == 4)    ? 2  : 2;
   parameter WIDTH  = ADDR_WIDTH + DATA_WIDTH;   
   parameter SQRT_N = (N == 1024) ? 32 :
		      (N == 256)  ? 16 :
		      (N == 64)   ? 8  :
		      (N == 16)   ? 4  :
		      (N == 4)    ? 2  :
		      (N == 1)    ? 1  : 0;
   parameter SHEARSORT_ROUNDS_TOTAL = (N == 1024) ? 11 :
				      (N == 256)  ? 9  :
				      (N == 64)   ? 7  :
				      (N == 16)   ? 5  :
				      (N == 4)    ? 3  :
				      (N == 1)    ? 1  : 0;    // Should be exactly roof(log_2 N) + 1
   parameter FIRST_IN_ROW = I - I%SQRT_N;
   parameter MAX_INT = {(WIDTH+1){1'b1}};
   parameter IS_FIRST_IN_ROW = (FIRST_IN_ROW == I);
   parameter IS_LAST_IN_ROW = (FIRST_IN_ROW + SQRT_N - 1 == I);
   parameter IS_FIRST_IN_COL = (I < SQRT_N);
   parameter IS_LAST_IN_COL = (I >= N - SQRT_N);
   parameter IS_EVEN_ROW = ((I/SQRT_N)%2 == 0);
   parameter IS_EVEN_COL = ((I-FIRST_IN_ROW)%2 == 0);   
   parameter SHEARSORT_ROWS = 1'b0;
   parameter SHEARSORT_COLS = 1'b1;
   
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

   reg [3:0] 			       state;
   reg [3:0] 			       next_state = 4'b0000;
   reg [3:0] 			       inst_ROM [SORT_CYCLES-1:0];
   reg 				       shearsort_state;
   reg 				       next_shearsort_state;   
   reg [10:0] 			       shearsort_rounds;
   reg [10:0] 			       next_shearsort_rounds;   
   
   assign runnable = (state == COMPUTE);
   wire 			       rst_counter = (state != next_state) | (shearsort_state != next_shearsort_state) | rst;
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
           if (clk_counter == SQRT_N) begin
	      if (shearsort_rounds == SHEARSORT_ROUNDS_TOTAL && shearsort_state == 1'b1) begin
		 next_state = PUSH_ADDR_TO_ROW_MAJOR;
		 next_shearsort_state = 1'b0;
		 next_shearsort_rounds = 0;
	      end else if (shearsort_state == 1'b1) begin
		 next_shearsort_rounds <= shearsort_rounds + 1'b1;
		 next_state = PUSH_ADDR_SORT;
		 next_shearsort_state = ~shearsort_state;		 
	      end else begin
		 next_shearsort_state = ~shearsort_state;
		 next_state = PUSH_ADDR_SORT;
	      end
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
           if (clk_counter == SQRT_N) begin
	      if (shearsort_rounds == SHEARSORT_ROUNDS_TOTAL && shearsort_state == 1'b1) begin
		 next_state = GET_DATA_TO_ROW_MAJOR;
		 next_shearsort_state = 1'b0;
		 next_shearsort_rounds = 0;
	      end else if (shearsort_state == 1'b1) begin
		 next_shearsort_rounds <= shearsort_rounds + 1'b1;
		 next_state = GET_DATA_SORT;
		 next_shearsort_state = ~shearsort_state;		 		 
	      end else begin
		 next_state = GET_DATA_SORT;		 
		 next_shearsort_state = ~shearsort_state;		 
	      end
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
	 shearsort_state <= 1'b0;
	 shearsort_rounds <= 0;
	 next_shearsort_rounds <= 0;
	 next_shearsort_state <= 0;
      end else begin
         state <= next_state;
	 shearsort_state <= next_shearsort_state;
	 shearsort_rounds <= next_shearsort_rounds;
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
      end else if (state == PUSH_ADDR_SORT || state == GET_DATA_SORT) begin // if (state == LOAD_DATA)
	 if (shearsort_state == SHEARSORT_ROWS) begin
	    if (IS_EVEN_ROW) begin
	       if (IS_EVEN_COL) begin
		  if (clk_counter) begin
		     if (!IS_FIRST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
				    : comm_reg;
		     end
		  end else begin
		     if (!IS_LAST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
				    : comm_reg;
		     end			   
		  end
	       end else begin // if (IS_EVEN_COL)
		  if (clk_counter) begin			
		     if (!IS_LAST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
				    : comm_reg;
		     end
		  end else begin
		     if (!IS_FIRST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
				    : comm_reg;
		     end			   
		  end
	       end
	    end // if (IS_EVEN_ROW)
	    
	    else begin
	       if (IS_EVEN_COL) begin
		  if (clk_counter) begin
		     if (!IS_FIRST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
				    : comm_reg;
		     end
		  end else begin
		     if (!IS_LAST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
				    : comm_reg;
		     end			   
		  end
	       end else begin // if (IS_EVEN_COL)
		  if (clk_counter) begin			
		     if (!IS_LAST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
				    : comm_reg;
		     end
		  end else begin
		     if (!IS_FIRST_IN_ROW) begin			
			comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
				    : comm_reg;
		     end			   
		  end
	       end
	    end // else: !if(IS_EVEN_ROW)
	 end // if (shearsort_state == SHEARSORT_ROWS)

	 else begin
	    if (IS_EVEN_ROW) begin
	       if (clk_counter) begin
		  if (!IS_FIRST_IN_COL) begin			
		     comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
				 : comm_reg;
		  end
	       end else begin
		  if (!IS_LAST_IN_COL) begin			
		     comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
				 : comm_reg;
		  end			   
	       end
	    end else begin // if (IS_EVEN_ROW)
	       if (clk_counter) begin			
		  if (!IS_LAST_IN_COL) begin			
		     comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] > i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
				 : comm_reg;
		  end
	       end else begin
		  if (!IS_FIRST_IN_COL) begin			
		     comm_reg <= (comm_reg[WIDTH-1:DATA_WIDTH] < i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
				 : comm_reg;
		  end			   
	       end
	    end // else: !if(IS_EVEN_ROW)
	 end // else: !if(shearsort_state == SHEARSORT_ROWS)
	 
      // NEW STATE
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
module mesh #(parameter N = 4,                            // Total number of PEs
		 parameter DATA_WIDTH = 32,                     // Width of memory register in each PE
		 parameter SORT_CYCLES = 4)                    // Number of cycles to run sort
   (input clk,
    input rst);

   parameter SQRT_N = (N == 1024) ? 32 :
		      (N == 256)  ? 16 :
		      (N == 64)   ? 8  :
		      (N == 16)   ? 4  :
		      (N == 4)    ? 2  :
		      (N == 1)    ? 1  : 0;
   parameter ADDR_WIDTH = (N == 1024) ? 10 :
			  (N == 256)  ? 8  :
			  (N == 64)   ? 6  :
			  (N == 16)   ? 4  :
			  (N == 4)    ? 2  : 2;   
   parameter WIDTH = ADDR_WIDTH + DATA_WIDTH;
   parameter MAX_INT = {(WIDTH+1){1'b1}};
   
   wire [WIDTH:0] PE [N-1:0];
   
   genvar 	    i;
   generate
      for (i = 0; i < N; i=i+1) begin : GEN
         if (i == 0) begin : GENIF
            // top-left PE
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end else if (i == N-1) begin : GENIF
            // bottom-right PE
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]));
         end else if (i == N-SQRT_N) begin : GENIF
            // bottom-left PE
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]));
         end else if (i == SQRT_N-1) begin : GENIF
            // top-right PE
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end else if (i < SQRT_N) begin : GENIF
            // top row
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(MAX_INT),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end else if (i >= N-SQRT_N) begin : GENIF
            // bottom row
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(MAX_INT),
                .o_PE(PE[i]));
         end else if (i%SQRT_N == 0) begin : GENIF
            // left column
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(MAX_INT),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end else if (i%SQRT_N == SQRT_N-1) begin : GENIF
            // right column
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(MAX_INT),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end else begin : GENIF
            // in middle of mesh
            PE #(.N(N),
                 .I(i),
                 .DATA_WIDTH(DATA_WIDTH),
                 .SORT_CYCLES(SORT_CYCLES))
            PE (.clk(clk),
                .rst(rst),
                .rst_memory(i[DATA_WIDTH-1:0]),
                .i_PE_l(PE[i-1]),
                .i_PE_r(PE[i+1]),
                .i_PE_u(PE[i-SQRT_N]),
                .i_PE_d(PE[i+SQRT_N]),
                .o_PE(PE[i]));
         end
      end
   endgenerate
endmodule
