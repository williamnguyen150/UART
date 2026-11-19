module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        soft_rst, 
    input  wire        rx_en,
    input  wire        parity_en,
    input  wire        parity_type,
    input  wire [1:0]  num_data_bit,
    input  wire        num_stop_bit,
    input  wire [15:0] baud_div,
    input  wire        rx,
    output wire [7:0]  rx_data,
    output wire        rx_done,
    output wire        rx_busy,
    output wire        frame_error,
    output wire        parity_error,
    output wire        rts_n
);
    wire        stable_rx;
    wire        fall_edge_rx;
    wire        en_shift;
    wire        en_cnt;
    wire        cnt_mode;
    wire        baud_mode;
    wire [3:0]  max_baud = baud_mode ? {3'd0, num_stop_bit} : ({2'd0, num_data_bit} + {3'd0, parity_en} + 4'd4);
    wire        cnt_tick;
    wire        half_cnt_tick;
    wire        baud_tick;
    wire [8:0]  shift_out;
    wire        invalid;

    // Right-align received bits for 5/6/7/8-bit frames with or without parity
    wire [7:0] raw_aligned = parity_en ? shift_out[7:0] : shift_out[8:1];
    assign rx_data = raw_aligned >> (2'd3 - num_data_bit);
    assign rts_n   = rx_en;

    sync_edge_det u_sync_edge (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx            (rx),
        .stable_rx     (stable_rx),
        .fall_edge_rx  (fall_edge_rx)
    );

    div_counter div_cnt (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_en         (rx_en & ~soft_rst),
        .en_cnt        (en_cnt),
        .cnt_mode      (cnt_mode),
        .baud_div      (baud_div),
        .cnt_tick      (cnt_tick),
        .half_cnt_tick (half_cnt_tick)
    );

    baud_counter baud_cnt (
        .clk            (clk),
        .rst_n          (rst_n),
        .soft_rst       (soft_rst | ~rx_en), 
        .max_baud       (max_baud),
        .cnt_tick       (cnt_tick),
        .baud_tick      (baud_tick)
    );

    sipo_reg u_sipo (
        .clk           (clk),
        .rst_n         (rst_n),
        .en_shift      (en_shift),
        .stable_rx     (stable_rx),
        .rx_data       (shift_out)
    );

    parity_check u_parity_check (
        .data_in       (shift_out),
        .parity_type   (parity_type),
        .num_data_bit  (num_data_bit),
        .invalid       (invalid)
    );

    uart_rx_controller FSM (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_en         (rx_en & ~soft_rst),
        .parity_en     (parity_en),
        .fall_edge_rx  (fall_edge_rx),
        .stable_rx     (stable_rx),
        .cnt_tick      (cnt_tick),
        .half_cnt_tick (half_cnt_tick),
        .baud_tick     (baud_tick),
        .en_shift      (en_shift),
        .en_cnt        (en_cnt),
        .cnt_mode      (cnt_mode),
        .baud_mode     (baud_mode),
        .rx_busy       (rx_busy),
        .rx_done       (rx_done),
        .frame_error   (frame_error),
        .parity_error  (parity_error),
        .invalid       (invalid)
    );
endmodule
