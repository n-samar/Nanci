
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
            parameter SORT_CYCLES = 222,                   // Number of cycles to run sort
            parameter FIRST_IN_ROW = 0,                    // Index of first PE in this PE's row
            parameter COMPUTE_CYCLES = 3)                  // Specifies number of compute cycles        
           (input                   clk,
            input                   rst,
            input [2*ADDR_WIDTH-1:0]  i_PE_l,
            input [2*ADDR_WIDTH-1:0]  i_PE_r,
            input [2*ADDR_WIDTH-1:0]  i_PE_u,
            input [2*ADDR_WIDTH-1:0]  i_PE_d,
            output [2*ADDR_WIDTH-1:0] o_PE);

    parameter MAX_INT          = N;     // Reserved for NOP keys
    parameter STATE_TOP_END    = 4;
    parameter STATE_TOP_START  = 3;
    parameter STATE_BOTTOM_END = 2;

    parameter PUSH_ADDR = 2'b00;
    parameter GET_DATA  = 2'b01;
    parameter COMPUTE   = 2'b10;

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

    wire lt_l = (o_PE < i_PE_l);
    wire lt_r = (o_PE < i_PE_r);
    wire lt_u = (o_PE < i_PE_u);
    wire lt_d = (o_PE < i_PE_d);

    reg [STATE_TOP_END:0]          state;
    reg [STATE_TOP_END:0]          next_state;
    reg [3:0]                      inst_ROM [SORT_CYCLES-1:0];

    wire                rst_counter = (state != next_state) | rst;
    wire [ADDR_WIDTH-1:0] clk_counter;
    counter #(ADDR_WIDTH) counter_init (.clk(clk),
                                        .rst(rst_counter),
                                        .counter(clk_counter));

    reg [2*ADDR_WIDTH-1:0] comm_reg;
    reg [2*ADDR_WIDTH-1:0] addr_reg;    // Extra register needed for COL_ALIGN
    assign o_PE = addr_reg;
    
    // Initialize instruction ROM
    initial begin
        $readmemb(FILENAME, inst_ROM);
    end
    // Next-state logic for state[STATE_BOTTOM_END:0]
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
            if (clk_counter == COMPUTE_CYCLES) begin
                next_state[STATE_BOTTOM_END:0] = SORT;
            end else begin
                next_state[STATE_BOTTOM_END:0] = NOP;
            end
        end
    endcase 
    end

    // Next-state logic for state[STATE_TOP_END:STATE_TOP_START]
    always @(*) begin
        case(state[STATE_TOP_END:STATE_TOP_START])
        COMPUTE: begin
            if (clk_counter == COMPUTE_CYCLES) begin
                next_state[STATE_TOP_END:STATE_TOP_START] = PUSH_ADDR;
            end else begin
                next_state[STATE_TOP_END:STATE_TOP_START] = COMPUTE;
            end
        end
        PUSH_ADDR: begin
            if (clk_counter == SQRT_N && state[STATE_BOTTOM_END:0] == COL_ALIGN) begin
                next_state[STATE_TOP_END:STATE_TOP_START] = GET_DATA;
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
        endcase
    end


    always @(posedge clk) begin
        if (rst) begin
            state <= {COMPUTE, NOP};
        end else begin
            state <= next_state;
        end
    end

    // Addressing logic
    always @(posedge clk) begin
        if (state[STATE_BOTTOM_END:0] == SORT) begin
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
                addr_reg <= (addr_reg < i_PE_l) ? i_PE_l
                                                : addr_reg;
            end
            slt_r: begin
                addr_reg <= (addr_reg < i_PE_r) ? i_PE_r
                                                : addr_reg;                
            end
            slt_u: begin
                addr_reg <= (addr_reg < i_PE_u) ? i_PE_u
                                                : addr_reg;                
            end
            slt_d: begin
                addr_reg <= (addr_reg < i_PE_d) ? i_PE_d
                                                : addr_reg;                
            end
            sgt_l: begin
                addr_reg <= (addr_reg > i_PE_l) ? i_PE_l
                                                : addr_reg;
            end
            sgt_r: begin
                addr_reg <= (addr_reg > i_PE_r) ? i_PE_r
                                                : addr_reg;                 
            end
            sgt_u: begin
                addr_reg <= (addr_reg > i_PE_u) ? i_PE_u
                                                : addr_reg; 
            end
            sgt_d: begin
                addr_reg <= (addr_reg > i_PE_d) ? i_PE_d
                                                : addr_reg; 
            end
            nop: begin
                addr_reg <= addr_reg;
            end
            endcase
        end else if (state[STATE_BOTTOM_END:0] == ROW_ALIGN) begin
            if (addr_reg == MAX_INT) begin
                // addr_reg holds no value, should look to see if PE_u has something for it
                if (i_PE_u >= FIRST_IN_ROW) begin
                    addr_reg <= i_PE_u;
                end else begin
                    addr_reg <= MAX_INT;
                end
            end else if (addr_reg < FIRST_IN_ROW + SQRT_N && addr_reg >= FIRST_IN_ROW) begin
                // addr_reg's key-value pair is in proper position, do nothing
                addr_reg <= addr_reg;
            end else if (addr_reg >= FIRST_IN_ROW + SQRT_N) begin
                // addr_reg's key-value pair is too high up, move it down if possible
                if (i_PE_d == MAX_INT) begin
                    addr_reg <= i_PE_d;
                end else begin
                    addr_reg <= addr_reg;
                end
            end else begin
                // Shouldn't get here ever
                addr_reg <= addr_reg;
            end
        end else if (state[STATE_BOTTOM_END:0] == COL_ALIGN) begin
            if (addr_reg == I) begin
                // addr_reg holds the right value, copy into comm_reg
                comm_reg <= addr_reg;
                // Discard addr_reg
                addr_reg <= MAX_INT;
            end else if (addr_reg == MAX_INT) begin
                // addr_reg holds no value
                // should look to see if PE_l or PE_r has something for it
                if (i_PE_l >= I) begin
                    addr_reg <= i_PE_l;
                end else if (i_PE_r <= I) begin
                    addr_reg <= i_PE_r;
                end
            end else begin
                // addr_reg holds some value that is not MAX_INT and is not I
                // try to exchange with neighbors if possible
                if (addr_reg > I) begin
                    // should move right
                    if (i_PE_r == MAX_INT || i_PE_r <= I) begin
                        addr_reg <= i_PE_r;
                    end else begin
                        // no space in right neighbor, can't move
                        addr_reg <= addr_reg;
                    end
                end else begin
                    // should move left
                    if (i_PE_l == MAX_INT || i_PE_l >= I) begin
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