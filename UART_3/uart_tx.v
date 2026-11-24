module uart_tx (
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] baud_div,
    input  wire parity_en,
    input  wire parity_type,
    input  wire [1:0] num_data_bit,
    input  wire       num_stop_bit,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    input  wire soft_rst, 
    input  wire cts_n, 
    output wire tx_done,
    output wire tx
);
    wire cnt_tick, baud_tick, en_cnt, load_mode, en_reg, baud_mode;
    wire [1:0] out_mode;
    wire [3:0] max_baud;

    // ---> [THÊM]: Bộ đồng bộ 2-FF cho cts_n (bắt buộc theo spec để chống metastable)
    reg cts_ff1, cts_ff2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cts_ff1 <= 1'b1;
            cts_ff2 <= 1'b1;
        end else begin
            cts_ff1 <= cts_n;
            cts_ff2 <= cts_ff1;
        end
    end

    assign max_baud = baud_mode ? num_stop_bit : (num_data_bit + parity_en + 4'h5);

    tx_fsm u_control (
        .clk(clk), .rst_n(rst_n), .soft_rst(soft_rst),
        .cts_n(cts_ff2), // ---> [SỬA]: Dùng cts_n đã đồng bộ
        .tx_start(tx_start), .parity_en(parity_en),
        .cnt_tick(cnt_tick), .baud_tick(baud_tick),
        .tx_done(tx_done), .en_reg(en_reg), .en_cnt(en_cnt),
        .out_mode(out_mode), .load_mode(load_mode), .baud_mode(baud_mode)
    );

    counter u_counter (
        .clk(clk), .rst_n(rst_n), .soft_rst(soft_rst),
        .en_cnt(en_cnt), .max_cnt(baud_div), .cnt_tick(cnt_tick)
    );

    baud_counter u_baud_counter (
        .clk(clk), .rst_n(rst_n), .soft_rst(soft_rst),
        .cnt_tick(cnt_tick), .max_baud(max_baud), .baud_tick(baud_tick)
    );

    tx_datapath u_datapath (
        .clk(clk), .rst_n(rst_n), .soft_rst(soft_rst),
        .tx_data(tx_data),
        .num_data_bit(num_data_bit), // ---> [THÊM]: Nối num_data_bit
        .parity_type(parity_type),
        .load_mode(load_mode), .en_reg(en_reg), .out_mode(out_mode),
        .tx(tx)
    );
endmodule