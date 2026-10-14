module tx_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire tx_start,
	 input  wire parity_en,
    input  wire cnt_tick,
    input  wire baud_tick,
    output reg  tx_done,
    output reg  en_reg,
    output reg  en_cnt,
    output reg  [1:0] out_mode,
    output reg  load_mode,
    output reg  baud_mode
);
    localparam S0_IDLE  = 2'b00;
    localparam S1_START = 2'b01;
    localparam S2_TRANS = 2'b10;
    localparam S3_STOP  = 2'b11;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S0_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        // Default outputs
        tx_done   = 1'b0;
        en_reg    = 1'b0;
        en_cnt    = 1'b0;
        out_mode  = 2'b11;
        load_mode = 1'b0;
        baud_mode = 1'b0;
        next_state = state;

        case (state)
            S0_IDLE: begin
                tx_done   = 1'b0;
                en_reg    = 1'b0;
                en_cnt    = 1'b0;
                out_mode  = 2'b11;
                if (tx_start == 1'b1)
                    next_state = S1_START;
            end
            
            S1_START: begin
                tx_done   = 1'b0;
                en_reg    = cnt_tick;
                en_cnt    = 1'b1;
                out_mode  = 2'b10;
                load_mode = 1'b1;
                baud_mode = 1'b0;
                if (cnt_tick == 1'b1)
                    next_state = S2_TRANS;
            end
            
            S2_TRANS: begin
                tx_done   = 1'b0;
                en_reg    = cnt_tick;
                en_cnt    = 1'b1;
                out_mode  = (baud_tick && parity_en) ? 2'b01 : 2'b00;
                load_mode = 1'b0;
                baud_mode = 1'b0;
                if (cnt_tick == 1'b1 && baud_tick == 1'b1)
                    next_state = S3_STOP;
            end
            
            S3_STOP: begin
                tx_done   = cnt_tick;
                en_reg    = 1'b0;
                en_cnt    = 1'b1;
                out_mode  = 2'b11;
                baud_mode = 1'b1;
                if (cnt_tick == 1'b1 && baud_tick == 1'b1)
                    next_state = S0_IDLE;
            end
        endcase
    end
endmodule