module baud_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_en,
    input  wire [3:0]  max_baud,
    input  wire        cnt_tick,
    output wire        baud_tick
);
    reg [3:0] cnt;
    always @ (posedge clk) begin
        if (!rst_n | !rx_en) cnt <= 0;
        else cnt <= cnt_tick ? (baud_tick ? 0 : cnt + 1) : cnt;
    end
    assign baud_tick = (cnt == max_baud);
endmodule
