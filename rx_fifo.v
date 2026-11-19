module rx_fifo #(parameter BIT_WIDTH = 8, TAP = 4) (
    input                        clk, 
    input                        rst_n, 
    input                        read_en, 
    input                        write_en, 
    input      [BIT_WIDTH - 1:0] data_in, 

    output     [BIT_WIDTH - 1:0] data_out, 
    output                       empty, 
    output                       full
);
    reg [$clog2(TAP):0] w_ptr;
    reg [$clog2(TAP):0] r_ptr;

    reg [BIT_WIDTH - 1:0] data[0:TAP - 1];

    assign empty = w_ptr == r_ptr;
    assign full = (w_ptr[$clog2(TAP) - 1:0] == r_ptr[$clog2(TAP) - 1:0]) 
                & (w_ptr[$clog2(TAP)] ^ r_ptr[$clog2(TAP)]);

    assign data_out = data[r_ptr[$clog2(TAP) - 1:0]];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            r_ptr <= 0;
        else if (!empty & read_en) begin
            r_ptr <= r_ptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            w_ptr <= 0;
        else if (!full & write_en) begin
            data[w_ptr[$clog2(TAP) - 1:0]] <= data_in;
            w_ptr <= w_ptr + 1'b1;
        end else begin
            w_ptr <= w_ptr;
        end
    end
endmodule
