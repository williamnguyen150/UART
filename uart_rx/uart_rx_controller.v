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

    // Sequential block for state transitions and error flag registers
    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= S0_IDLE;
            frame_error  <= 1'b0;
            parity_error <= 1'b0;
        end else begin
            state        <= next_state;
            
            // Clear error flags upon returning to idle
            if (state == S0_IDLE) begin
                frame_error  <= 1'b0;
                parity_error <= 1'b0;
            end 
            // Latch frame error when sampling the stop bit
            else if (state == S3_STOP && cnt_tick && baud_tick) begin
                frame_error  <= ~stable_rx;
            end
            // Latch parity error at the end of the frame
            else if (state == S4_END && half_cnt_tick) begin
                parity_error <= parity_en & invalid;
            end
        end
    end

    // Combinational block for next-state logic and control signals only
    always @(*) begin
        next_state = state;
        en_shift   = 1'b0;
        en_cnt     = 1'b0;
        cnt_mode   = 1'b0;
        baud_mode  = 1'b0;
        rx_done    = 1'b0;
        
        case (state)
            S0_IDLE: begin
                en_cnt   = 1'b0;
                en_shift = 1'b0;
                if (rx_en && fall_edge_rx) begin
                    next_state = S1_START;
                end
            end

            S1_START: begin
                en_cnt    = 1'b1;
                cnt_mode  = 1'b0;
                baud_mode = 1'b0;
                if (rx_en && half_cnt_tick) begin
                    if (!stable_rx) begin
                        next_state = S2_RECEIVE;
                    end else begin
                        next_state = S0_IDLE; // Filter out noise on start bit
                    end
                end
            end

            S2_RECEIVE: begin
                en_cnt    = 1'b1;
                cnt_mode  = 1'b1;
                baud_mode = 1'b0;
                en_shift  = cnt_tick;
                if (rx_en && cnt_tick && baud_tick) begin
                    next_state = S3_STOP;
                end
            end

            S3_STOP: begin
                en_shift  = (~parity_en) & cnt_tick & baud_tick;
                en_cnt    = 1'b1;
                cnt_mode  = 1'b1;
                baud_mode = 1'b1;
                if (rx_en && cnt_tick && baud_tick) begin
                    next_state = S4_END;
                end
            end

            S4_END: begin
                en_cnt   = 1'b1;
                cnt_mode = 1'b0;
                en_shift = 1'b0;
                rx_done  = half_cnt_tick;
                if (rx_en && half_cnt_tick) begin
                    next_state = S0_IDLE;
                end
            end
        endcase
    end
endmodule