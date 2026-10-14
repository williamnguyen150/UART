module sipo_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en_shift,
    input  wire        stable_rx,
    output reg  [8:0]  rx_data
);
    always @(posedge clk) begin
        if (!rst_n) rx_data <= 9'd0;
        else if (en_shift) begin
            rx_data <= {stable_rx, rx_data[8:1]}; // LSB first
        end
    end
endmodule