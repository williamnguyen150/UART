module counter (
    input  wire clk,
    input  wire rst_n,
    input  wire en_cnt,
    input  wire [15:0] max_cnt, // baud_div
    output wire cnt_tick
);
    reg [15:0] count_val;

	assign cnt_tick = en_cnt & (count_val == max_cnt);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count_val <= 0;
        else if (en_cnt) begin
            if (cnt_tick)
                count_val <= 0;
            else
                count_val <= count_val + 1;
        end
    end
endmodule