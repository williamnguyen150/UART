module tx_datapath (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       soft_rst,
    input  wire [7:0] tx_data,
    input  wire [1:0] num_data_bit, // ---> [THÊM]: Để biết độ dài data
    input  wire       parity_type, 
    input  wire       load_mode,
    input  wire       en_reg,
    input  wire [1:0] out_mode,
    output reg        tx
);
    reg [7:0] shift_reg;
    reg       parity_reg;
    reg       parity_raw;
    wire      parity_calc;

    // ---> [SỬA]: Tính parity chỉ trên các bit dữ liệu có nghĩa (tránh XOR nhầm bit rác)
    always @(*) begin
        case (num_data_bit)
            2'b00:   parity_raw = ^tx_data[4:0]; // 5-bit
            2'b01:   parity_raw = ^tx_data[5:0]; // 6-bit
            2'b10:   parity_raw = ^tx_data[6:0]; // 7-bit
            default: parity_raw = ^tx_data[7:0]; // 8-bit
        endcase
    end
    
    // ---> [SỬA]: Chuẩn spec HTML: 1 = Even (chẵn), 0 = Odd (lẻ)
    assign parity_calc = parity_type ? parity_raw : ~parity_raw;

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
                shift_reg  <= {1'b1, shift_reg[7:1]};
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