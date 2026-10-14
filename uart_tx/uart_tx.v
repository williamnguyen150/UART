
module uart_tx (
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] baud_div,
    input  wire parity_en,
    input  wire [1:0] num_data_bit,//encoding data bit count, 00 -> 5, 01 -> 6,... 
    input  wire [3:0] num_stop_bit,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    input  wire parity_type,
    output wire tx_done,
    output wire tx
);

    wire cnt_tick;
    wire baud_tick;
    wire en_cnt;
    wire load_mode;
    wire en_reg;
    wire [1:0] out_mode;
    wire baud_mode;
    wire [3:0] max_baud;

    assign max_baud = baud_mode ? num_stop_bit : (num_data_bit + parity_en + 4'h5);

    tx_fsm u_control (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
		  .parity_en(parity_en),
        .cnt_tick(cnt_tick),
        .baud_tick(baud_tick),
        .tx_done(tx_done),
        .en_reg(en_reg),
        .en_cnt(en_cnt),
        .out_mode(out_mode),
        .load_mode(load_mode),
        .baud_mode(baud_mode)
    );

    counter u_counter (
        .clk(clk),
        .rst_n(rst_n),
        .en_cnt(en_cnt),
        .max_cnt(baud_div),
        .cnt_tick(cnt_tick)
    );

    baud_counter u_baud_counter (
        .clk(clk),
        .rst_n(rst_n),
        .cnt_tick(cnt_tick),
        .max_baud(max_baud),
        .baud_tick(baud_tick)
    );

    tx_datapath u_datapath (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .parity_type(parity_type),
        .load_mode(load_mode),
        .en_reg(en_reg),
        .out_mode(out_mode),
        .tx(tx)
    );

endmodule