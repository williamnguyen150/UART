module baud_counter (
    input  wire clk,
    input  wire rst_n,
    input  wire cnt_tick,
    input  wire [3:0] max_baud,
    output wire baud_tick
);
    reg [3:0] count_val;

    assign baud_tick = (count_val == max_baud);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count_val <= 0;
        else if (cnt_tick) begin
            if (baud_tick)
                count_val <= 0;
            else
                count_val <= count_val + 1;
        end
    end
endmodule