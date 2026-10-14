module tx_datapath (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] tx_data,
    input  wire parity_type,
    input  wire load_mode,
    input  wire en_reg,
    input  wire [1:0] out_mode,
    output reg  tx
);
    reg [7:0] shift_reg;
    reg parity_reg;
    wire parity_calc;
    
    assign parity_calc = parity_type ? ~(^tx_data) : (^tx_data);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'hFF;
            parity_reg <= 1'b0;
        end else if (en_reg) begin
            if (load_mode) begin
                shift_reg <= tx_data;
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