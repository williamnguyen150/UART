module sync_edge_det (
    input  wire clk,
    input  wire rst_n,
    input  wire rx,
    output reg  stable_rx,
    output wire fall_edge_rx
);
    reg rx_ff1, rx_ff2;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_ff1    <= 1'b1;
            rx_ff2    <= 1'b1;
            stable_rx <= 1'b1;
        end else begin
            rx_ff1    <= rx;
            rx_ff2    <= rx_ff1;
            stable_rx <= rx_ff2;
        end
    end

    // Phát hiện cạnh xuống (từ 1 xuống 0)
    assign fall_edge_rx = ~rx_ff2 & stable_rx;
endmodule