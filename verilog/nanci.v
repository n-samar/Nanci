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
                 input                       rst,
                 output reg [ADDR_WIDTH-1:0] counter);
    always @(posedge clk) begin
        if (rst) begin
           counter <= 0; 
        end else begin
            counter <= counter+1;
        end
    end
endmodule

module PE #(parameter N = 1024,                            // Total number of PEs
            parameter SQRT_N = 32,                         // Side-length of mesh (= sqrt(N))
            parameter I = 0,                               // Index of this PE
            parameter FILENAME = "../data/0004/0000.data", // Filename for instructions
            parameter ADDR_WIDTH = 10,                     // Width required to store index into PEs
            parameter DATA_WIDTH = 10,                     // Width of memory register in each PE
            parameter SORT_CYCLES = 222,                   // Number of cycles to run sort
            parameter FIRST_IN_ROW = 0,                    // Index of first PE in this PE's row
            parameter COMPUTE_CYCLES = 3)                  // Specifies number of compute cycles        
           (input                   clk,
            input                   rst,
            input  [DATA_WIDTH-1:0]       rst_memory,            // Value of memory register after reset
            input [ADDR_WIDTH+DATA_WIDTH-1:0]  i_PE_l,
            input [ADDR_WIDTH+DATA_WIDTH-1:0]  i_PE_r,
            input [ADDR_WIDTH+DATA_WIDTH-1:0]  i_PE_u,
            input [ADDR_WIDTH+DATA_WIDTH-1:0]  i_PE_d,
            output [ADDR_WIDTH+DATA_WIDTH-1:0] o_PE);

    parameter WIDTH            = ADDR_WIDTH + DATA_WIDTH;
    parameter MAX_INT          = N;     // Reserved for NOP keys
    parameter STATE_TOP_END    = 5;
    parameter STATE_TOP_START  = 3;
    parameter STATE_BOTTOM_END = 2;

    // High state
    parameter PUT_ADDR  = 3'b111;
    parameter PUSH_ADDR = 3'b000;
    parameter LOAD_DATA = 3'b011;
    parameter GET_DATA  = 3'b001;
    parameter COMPUTE   = 3'b010;

    // Low state
    parameter SORT      = 3'b000;
    parameter ROW_ALIGN = 3'b001;       // State when aligning each column's data to appropriate row
    parameter COL_ALIGN = 3'b010;       // State when aligning each row's data to appropriate column
    parameter NOP       = 3'b111;       // Do nothing (during COMPUTE)

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

    wire lt_l = (o_PE[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]);
    wire lt_r = (o_PE[WIDTH-1:DATA_WIDTH] < i_PE_r[WIDTH-1:DATA_WIDTH]);
    wire lt_u = (o_PE[WIDTH-1:DATA_WIDTH] < i_PE_u[WIDTH-1:DATA_WIDTH]);
    wire lt_d = (o_PE[WIDTH-1:DATA_WIDTH] < i_PE_d[WIDTH-1:DATA_WIDTH]);

    reg [STATE_TOP_END:0] state;
    reg [STATE_TOP_END:0] next_state;
    reg [3:0] inst_ROM [SORT_CYCLES-1:0];

    wire                rst_counter = (state != next_state) | rst;
    wire [ADDR_WIDTH-1:0] clk_counter;
    counter #(ADDR_WIDTH) counter_init (.clk(clk),
                                        .rst(rst_counter),
                                        .counter(clk_counter));

    wire [WIDTH-1:0] app_reg;
    reg [WIDTH-1:0] comm_reg;
    application #(.N(N), 
                  .I(I), 
                  .DATA_WIDTH(DATA_WIDTH), 
                  .ADDR_WIDTH(ADDR_WIDTH)) app_init (.clk(clk),
                                                     .rst(rst),
                                                     .runnable(state[STATE_TOP_END-1:STATE_TOP_START] == COMPUTE),
                                                     .comm_reg(comm_reg),
                                                     .app_reg(app_reg),
                                                     .is_write(is_write));

    assert_always assert_data_width_geq_addr_width (clk, (DATA_WIDTH >= ADDR_WIDTH));

    // TODO: implement writes via is_write



    initial begin
        
    end

    reg [WIDTH-1:0] addr_reg;    // Extra register needed for COL_ALIGN
    reg [DATA_WIDTH-1:0]   memory;      // Data held by processor I
    assign o_PE = addr_reg;
    
    // Initialize instruction ROM
    initial begin
        $readmemb(FILENAME, inst_ROM);
    end
    // Next-state logic for low state
    always @(*) begin
        case (state[STATE_BOTTOM_END:0])
        SORT: begin
            if (clk_counter == SORT_CYCLES) begin
                next_state[STATE_BOTTOM_END:0] = ROW_ALIGN;
            end else begin
                next_state[STATE_BOTTOM_END:0] = SORT;
            end
        end
        ROW_ALIGN: begin
            if (clk_counter == SQRT_N) begin
                next_state[STATE_BOTTOM_END:0] = COL_ALIGN;
            end else begin
                next_state[STATE_BOTTOM_END:0] = ROW_ALIGN;
            end
        end
        COL_ALIGN: begin
            if (clk_counter == SQRT_N) begin 
                if (state[STATE_TOP_END:STATE_TOP_START] == PUSH_ADDR) begin
                    next_state[STATE_BOTTOM_END:0] = SORT;
                end else begin
                    next_state[STATE_BOTTOM_END:0] = NOP;
                end
            end else begin
                next_state[STATE_BOTTOM_END:0] = COL_ALIGN;
            end
        end
        NOP: begin
            if (state[STATE_TOP_END:STATE_TOP_START] == PUSH_ADDR 
                || state[STATE_TOP_END:STATE_TOP_START] == GET_DATA) begin
                next_state[STATE_BOTTOM_END:0] = SORT;
            end else begin
                next_state[STATE_BOTTOM_END:0] = NOP;
            end
        end
    endcase 
    end

    // Next-state logic for high state
    always @(*) begin
        case(state[STATE_TOP_END:STATE_TOP_START])
        COMPUTE: begin
            if (clk_counter == COMPUTE_CYCLES) begin
                next_state[STATE_TOP_END:STATE_TOP_START] = PUT_ADDR;
            end else begin
                next_state[STATE_TOP_END:STATE_TOP_START] = COMPUTE;
            end
        end
        PUT_ADDR: begin
            // Load target and source address into addr_reg
            next_state[STATE_TOP_END:STATE_TOP_START] = PUSH_ADDR;
        end
        PUSH_ADDR: begin
            if (clk_counter == SQRT_N && state[STATE_BOTTOM_END:0] == COL_ALIGN) begin
                if (state[STATE_TOP_END:STATE_BOTTOM_END] == PUSH_ADDR) begin
                    next_state[STATE_TOP_END:STATE_TOP_START] = LOAD_DATA;
                end else if (state[STATE_TOP_END:STATE_BOTTOM_END] == GET_DATA) begin
                    next_state[STATE_TOP_END:STATE_TOP_START] = COMPUTE;
                end
            end else begin
                next_state[STATE_TOP_END:STATE_TOP_START] = PUSH_ADDR;
            end
        end
        GET_DATA: begin
            if (clk_counter == SQRT_N && state[STATE_BOTTOM_END:0] == COL_ALIGN) begin
                next_state[STATE_TOP_END:STATE_TOP_START] = COMPUTE;
            end else begin
                next_state[STATE_TOP_END:STATE_TOP_START] = GET_DATA;
            end            
        end
        LOAD_DATA: begin
            next_state[STATE_TOP_END:STATE_TOP_START] = GET_DATA;
        end
        endcase
    end


    always @(posedge clk) begin
        if (rst) begin
            state <= {COMPUTE, NOP};
            memory <= rst_memory;
        end else begin
            state <= next_state;
        end
    end

    // Addressing logic
    always @(posedge clk) begin
        if (state[STATE_TOP_END:STATE_TOP_START] == PUT_ADDR) begin
            // Load destination and source addresses
            addr_reg[WIDTH-1:DATA_WIDTH] <= app_reg[WIDTH-1:DATA_WIDTH];
            addr_reg[DATA_WIDTH-1:DATA_WIDTH-ADDR_WIDTH] <= I[ADDR_WIDTH-1:0];
        end else if (state[STATE_TOP_END:STATE_TOP_START] == LOAD_DATA) begin
            addr_reg <= {addr_reg[DATA_WIDTH-1:DATA_WIDTH-ADDR_WIDTH], memory};
        end else if (state[STATE_BOTTOM_END:0] == SORT) begin
            case(inst_ROM[clk_counter]) 
            s_l: begin
                addr_reg <= i_PE_l;
            end
            s_r: begin
                addr_reg <= i_PE_r;
            end
            s_u: begin
                addr_reg <= i_PE_u;
            end
            s_d: begin
                addr_reg <= i_PE_d;
            end
            slt_l: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] < i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
                                                : addr_reg;
            end
            slt_r: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] < i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
                                                : addr_reg;                
            end
            slt_u: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] < i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
                                                : addr_reg;                
            end
            slt_d: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] < i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
                                                : addr_reg;                
            end
            sgt_l: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] > i_PE_l[WIDTH-1:DATA_WIDTH]) ? i_PE_l
                                                : addr_reg;
            end
            sgt_r: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] > i_PE_r[WIDTH-1:DATA_WIDTH]) ? i_PE_r
                                                : addr_reg;                 
            end
            sgt_u: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] > i_PE_u[WIDTH-1:DATA_WIDTH]) ? i_PE_u
                                                : addr_reg; 
            end
            sgt_d: begin
                addr_reg <= (addr_reg[WIDTH-1:DATA_WIDTH] > i_PE_d[WIDTH-1:DATA_WIDTH]) ? i_PE_d
                                                : addr_reg; 
            end
            nop: begin
                addr_reg <= addr_reg;
            end
            endcase
        end else if (state[STATE_BOTTOM_END:0] == ROW_ALIGN) begin
            if (addr_reg[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
                // addr_reg holds no value, should look to see if PE_u has something for it
                if (i_PE_u[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW) begin
                    addr_reg <= i_PE_u;
                end else begin
                    addr_reg[WIDTH-1:DATA_WIDTH] <= MAX_INT;
                end
            end else if (addr_reg[WIDTH-1:DATA_WIDTH] < FIRST_IN_ROW + SQRT_N && addr_reg[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW) begin
                // addr_reg's key-value pair is in proper position, do nothing
                addr_reg <= addr_reg;
            end else if (addr_reg[WIDTH-1:DATA_WIDTH] >= FIRST_IN_ROW + SQRT_N) begin
                // addr_reg's key-value pair is too high up, move it down if possible
                if (i_PE_d[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
                    addr_reg <= i_PE_d;
                end else begin
                    addr_reg <= addr_reg;
                end
            end else begin
                // Shouldn't get here ever
                addr_reg <= addr_reg;
            end
        end else if (state[STATE_BOTTOM_END:0] == COL_ALIGN) begin
            if (addr_reg[WIDTH-1:DATA_WIDTH] == I) begin
                // addr_reg holds the right value, copy into comm_reg
                comm_reg <= addr_reg;
                // Discard addr_reg
                addr_reg[WIDTH-1:DATA_WIDTH] <= MAX_INT;
            end else if (addr_reg[WIDTH-1:DATA_WIDTH] == MAX_INT) begin
                // addr_reg holds no value
                // should look to see if PE_l or PE_r has something for it
                if (i_PE_l[WIDTH-1:DATA_WIDTH] >= I) begin
                    addr_reg <= i_PE_l;
                end else if (i_PE_r[WIDTH-1:DATA_WIDTH] <= I) begin
                    addr_reg <= i_PE_r;
                end
            end else begin
                // addr_reg holds some value that is not MAX_INT and is not I
                // try to exchange with neighbors if possible
                if (addr_reg[WIDTH-1:DATA_WIDTH] > I) begin
                    // should move right
                    if (i_PE_r[WIDTH-1:DATA_WIDTH] == MAX_INT || i_PE_r[WIDTH-1:DATA_WIDTH] <= I) begin
                        addr_reg <= i_PE_r;
                    end else begin
                        // no space in right neighbor, can't move
                        addr_reg <= addr_reg;
                    end
                end else begin
                    // should move left
                    if (i_PE_l[WIDTH-1:DATA_WIDTH] == MAX_INT || i_PE_l[WIDTH-1:DATA_WIDTH] >= I) begin
                        addr_reg <= i_PE_l;
                    end else begin
                        // no space in left neighbor, can't move
                        addr_reg <= addr_reg;
                    end
                end
            end
        end
    end
endmodule

// User application module
module application #(parameter N = 1024,
                     parameter I = 0,
                     parameter DATA_WIDTH = 10,
                     parameter ADDR_WIDTH = 10) 
                    (input clk,
                     input rst,
                     input runnable,
                     input  [ADDR_WIDTH+DATA_WIDTH-1:0] comm_reg,
                     output reg [ADDR_WIDTH+DATA_WIDTH-1:0] app_reg,
                     output is_write);
    always @(posedge clk) begin
        if (runnable) begin
            app_reg <= 0;
    end
    end
endmodule
