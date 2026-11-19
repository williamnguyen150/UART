module tx_datapath (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       soft_rst,
    input  wire [7:0] tx_data,
    input  wire [1:0] num_data_bit,
    input  wire       parity_type,
    input  wire       load_mode,
    input  wire       en_reg,
    input  wire [1:0] out_mode,
    output reg        tx
);
    reg [7:0] shift_reg;
    reg parity_reg;
    wire parity_calc;

    wire [7:0] data_mask = (num_data_bit == 2'd0) ? 8'h1F :
                           (num_data_bit == 2'd1) ? 8'h3F :
                           (num_data_bit == 2'd2) ? 8'h7F : 8'hFF;

    assign parity_calc = parity_type ? ~^(tx_data & data_mask) : ^(tx_data & data_mask);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 8'hFF;
            parity_reg <= 1'b0;
        end else if (soft_rst) begin
            shift_reg  <= 8'hFF;
            parity_reg <= 1'b0;
        end else if (en_reg) begin
            if (load_mode) begin
                shift_reg  <= tx_data;
                parity_reg <= parity_calc;
            end else begin
                shift_reg <= {1'b1, shift_reg[7:1]};
            end
        end
    end

    always @(*) begin
        case (out_mode)
            2'b00: tx = shift_reg[0]; 
            2'b01: tx = parity_reg;   
            2'b10: tx = 1'b0;         
            2'b11: tx = 1'b1;         
        endcase
    end
endmodule
