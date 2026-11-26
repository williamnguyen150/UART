module spi_controller (
    input      clk, 
    input      rst_n, 
    input      sync_cs, 
    input      rise, 
    input      fall, 
    input      tick, 
    output reg en_mosi, 
    output reg en_miso, 
    output reg mode_miso, 
    output reg en_cbi, 
    output reg clr_cbi, 
    output reg en_cby, 
    output reg clr_cby, 
    output reg en_spi_to_buff
);
    localparam [1:0] 
        S0_IDLE    = 3'b000,
        S1_FILLOUT = 3'b001,
        S2_SHIFT   = 3'b010,
        S3_FILLIN  = 3'b011;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= S0_IDLE;
        else if (sync_cs) 
            state <= S0_IDLE;
        else 
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        en_mosi   = 0; 
        en_miso   = 0;
        mode_miso = 0;
        en_cbi    = 0;
        clr_cbi   = 0;
        en_cby    = 0;
        clr_cby   = 0;
        en_spi_to_buff = 0;

        case (state)
            S0_IDLE: begin
                next_state = S1_FILLOUT;
                en_mosi   = 0; 
                en_miso   = 0;
                mode_miso = 0;
                en_cbi    = 0;
                clr_cbi   = 1;
                en_cby    = 0;
                clr_cby   = 1;
                en_spi_to_buff = 0;
            end

            S1_FILLOUT: begin
                next_state = S2_SHIFT;
                en_mosi   = 0; 
                en_miso   = 1;
                mode_miso = 1;
                en_cbi    = 0;
                clr_cbi   = 0;
                en_cby    = 0;
                clr_cby   = 0;
                en_spi_to_buff = 0;
            end

            S2_SHIFT: begin
                if (tick) begin
                    if (fall) next_state = S1_FILLOUT;
                    if (rise) next_state = S3_FILLIN;
                end
                en_mosi   = rise; 
                en_miso   = fall;
                mode_miso = 0;
                en_cbi    = fall;
                clr_cbi   = 0;
                en_cby    = fall & tick;
                clr_cby   = 0;
                en_spi_to_buff = 0;
            end

            S3_FILLIN: begin
                next_state = S2_SHIFT;
                en_mosi   = 0; 
                en_miso   = 0;
                mode_miso = 0;
                en_cbi    = 0;
                clr_cbi   = 0;
                en_cby    = 0;
                clr_cby   = 0;
                en_spi_to_buff = 1;
            end
        endcase
    end
endmodule