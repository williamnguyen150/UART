module uart_rx_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_en,
    input  wire       parity_en,
    input  wire       fall_edge_rx,
    input  wire       stable_rx,
    input  wire       cnt_tick,
    input  wire       half_cnt_tick,
    input  wire       baud_tick,
    output reg        en_shift,
    output reg        en_cnt,
    output reg        cnt_mode,
    output reg        baud_mode,
    output reg        rx_done,
    output reg        frame_error,
    output reg        parity_error,
    input  wire       invalid
);
    localparam [2:0] 
        S0_IDLE    = 3'b000,
        S1_START   = 3'b001,
        S2_RECEIVE = 3'b010,
        S3_STOP    = 3'b011,
        S4_END     = 3'b100;

    reg [2:0] state, next_state;

    always @(posedge clk) begin
        if (!rst_n) state <= S0_IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state   = state;
        en_shift     = 1'b0;
        en_cnt       = 1'b0;
        cnt_mode     = 1'b0;
        baud_mode    = 1'b0;
        rx_done      = 1'b0;
        frame_error  = 1'b0;
        parity_error = 1'b0;
        
        case (state)
            S0_IDLE: begin
                rx_done   = 1'b0;
                parity_error = 1'b0;
                en_cnt    = 1'b0;
                en_shift  = 1'b0;
                if (rx_en && fall_edge_rx) next_state = S1_START;
                frame_error = 1'b0;
            end

            S1_START: begin
                rx_done   = 1'b0;
                en_cnt    = 1'b1;
                cnt_mode  = 1'b0;
                baud_mode = 1'b0;
                frame_error = 1'b0;
                if (half_cnt_tick && (!stable_rx)) begin
                    next_state = S2_RECEIVE;
                end else if (half_cnt_tick && stable_rx) begin
                    next_state = S0_IDLE; // Nhiễu ở bit start, quay về idle
                end
            end

            S2_RECEIVE: begin
                rx_done   = 1'b0;
                en_cnt    = 1'b1;
                cnt_mode  = 1'b1;
                baud_mode = 1'b0;
                en_shift  = cnt_tick;
                if (cnt_tick && baud_tick) next_state = S3_STOP;
                frame_error = 1'b0;
            end

            S3_STOP: begin
                rx_done   = 1'b0;
                en_shift  = 1'b0;
                en_cnt    = 1'b1;
                cnt_mode  = 1'b1;
                baud_mode = 1'b1;
                if (cnt_tick && baud_tick) next_state = S4_END;
                frame_error = cnt_tick ? (frame_error | ~stable_rx) : frame_error;
            end

            S4_END: begin
                en_cnt       = 1'b1;
                cnt_mode     = 1'b0;
                en_shift     = 1'b0;
                rx_done      = half_cnt_tick;
                parity_error = parity_en & invalid;
                if (half_cnt_tick) next_state = S0_IDLE;
            end
        endcase
    end
endmodule