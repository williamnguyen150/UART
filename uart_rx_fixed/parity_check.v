module parity_check (
    input  wire [8:0]  data_in,
    input  wire        parity_type, // 0: Even, 1: Odd
    input  wire [1:0]  num_data_bit,
    output reg         invalid      // Cờ báo lỗi parity
);
    wire [3:0] data_len = {2'b00, num_data_bit} + 4'd5;
    reg calc_parity;

    always @(*) begin
        case (data_len)
            4'd5:    calc_parity = ^data_in[7:3];
            4'd6:    calc_parity = ^data_in[7:2];
            4'd7:    calc_parity = ^data_in[7:1];
            default: calc_parity = ^data_in[7:0];
        endcase
        if (parity_type) calc_parity = ~calc_parity;

        // Bit parity được đặt ở vị trí ngay sau dữ liệu
        invalid = (calc_parity != data_in[8]);
    end
endmodule
