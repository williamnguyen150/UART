module div_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_en,
    input  wire        en_cnt,
    input  wire        cnt_mode,   // 0: count to half baud_div, 1: count to baud_div
    input  wire [13:0] baud_div,   // max_cnt
    output wire        cnt_tick,
    output wire        half_cnt_tick
);
    reg [13:0] cnt;
    wire [13:0] max_cnt = cnt_mode ? baud_div : (baud_div >> 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n | !rx_en) 
            cnt <= 14'd0;
        else begin
            if (cnt_mode) 
                cnt <= cnt_tick ? 14'b0 : cnt + 1;
            else 
                cnt <= half_cnt_tick ? 14'b0 : cnt + 1;
        end
    end

    assign cnt_tick = cnt_mode ? (cnt == max_cnt) : 1'b0;
    assign half_cnt_tick = cnt_mode ? 1'b0 : (cnt == max_cnt);
endmodule
