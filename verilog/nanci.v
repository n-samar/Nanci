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

module PE #(parameter N = 1024,                      // Total number of PEs
            parameter SQRT_N = 32,                 // Side-length of mesh (= sqrt(N))
            parameter I = 0,                      // Index of this PE
            parameter ADDR_WIDTH = 10,             // Width required to store index into PEs
            parameter SORT_CYCLES = 222,            // Number of cycles to run sort
            parameter COMPUTE_CYCLES = 3)         // Specifies number of compute cycles 
           (input                   clk,
            input                   rst,
            input [ADDR_WIDTH-1:0]  i_PE_l,
            input [ADDR_WIDTH-1:0]  i_PE_r,
            input [ADDR_WIDTH-1:0]  i_PE_u,
            input [ADDR_WIDTH-1:0]  i_PE_d,
            output [ADDR_WIDTH-1:0] o_PE);

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

    wire lt_l = (o_PE < i_PE_l);
    wire lt_r = (o_PE < i_PE_r);
    wire lt_u = (o_PE < i_PE_u);
    wire lt_d = (o_PE < i_PE_d);

    reg [STATE_TOP_END:0]          state;
    reg [STATE_TOP_END:0]          next_state;

    wire                rst_counter = (state != next_state) | rst;
    wire [ADDR_WIDTH-1:0] clk_counter;
    counter #(ADDR_WIDTH) counter_init (.clk(clk),
                                        .rst(rst_counter),
                                        .counter(clk_counter));

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
            state <= {COMPUTE, SORT};
        end else begin
            state <= next_state;
        end
    end
endmodule