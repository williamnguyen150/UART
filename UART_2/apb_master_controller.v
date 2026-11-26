module apb_master_controller (
    input            clk, 
    input            rst_n, 
    input      [2:0] cnt, 
    input            pwrite, 
    input            en_spi_to_buff, 
    output reg       en_apb_to_buff, 
    output reg       pselect, 
    output reg       penable
);
    localparam [1:0] 
        S0_IDLE   = 3'b000,
        S1_SETUP  = 3'b001,
        S2_ACCESS = 3'b010;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= S0_IDLE;
        else 
            state <= next_state;
    end

    always @(*) begin
        next_state     = state;
        en_apb_to_buff = 0;
        pselect        = 0;
        penable        = 0;

        case (state)
            S0_IDLE: begin
                if (en_spi_to_buff & (pwrite == 0 && cnt == 3'd0
                                    || pwrite == 1 && cnt == 3'd5)) 
                    next_state = S1_SETUP;
                en_apb_to_buff = 0;
                pselect        = 0;
                penable        = 0;
            end
            
            S1_SETUP: begin
                next_state     = S2_ACCESS;
                en_apb_to_buff = 0;
                pselect        = 1;
                penable        = 0;
            end

            S2_ACCESS: begin
                next_state     = S0_IDLE;
                en_apb_to_buff = 1;
                pselect        = 1;
                penable        = 1;
            end
        endcase
    end
endmodule