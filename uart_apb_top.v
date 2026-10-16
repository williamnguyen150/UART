// Top-level: APB slave + APB registers + UART TX + UART RX
module uart_apb_top (
    input  wire        clk,
    input  wire        rst_n,

    // APB interface
    input  wire        pselect,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [5:0]  paddr,
    input  wire [3:0]  pstrb,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pslverr,
    output wire        pready,
    output wire        pirq,

    // UART pins
    input  wire        rx,
    output wire        tx
);

    // apb_slave <-> apb_regs
    wire        access, write;
    wire [5:0]  addr;
    wire [3:0]  strb;
    wire [31:0] w_data, r_data;
    wire        write_en, read_en, interrupt;

    // apb_regs <-> uart core
    wire        tx_start, tx_done, rx_done;
    wire        rx_en, parity_en, parity_type, num_stop_bit;
    wire [13:0] bauddiv;
    wire [1:0]  num_data_bit;
    wire [7:0]  tx_data, rx_data;
    wire        parity_error, frame_error;

    apb_slave u_apb_slave (
        .clk(clk), .rst_n(rst_n),
        .pselect(pselect), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
        .prdata(prdata), .pslverr(pslverr), .pready(pready), .pirq(pirq),
        .r_data(r_data), .write_en(write_en), .read_en(read_en), .interrupt(interrupt),
        .access(access), .write(write), .addr(addr), .strb(strb), .w_data(w_data)
    );

    apb_regs u_apb_regs (
        .clk(clk), .rst_n(rst_n),
        .access(access), .write(write), .addr(addr), .strb(strb), .w_data(w_data),
        .r_data(r_data), .write_en(write_en), .read_en(read_en), .interrupt(interrupt),
        .rx_data(rx_data), .parity_error(parity_error), .frame_error(frame_error),
        .tx_done(tx_done), .rx_done(rx_done),
        .tx_start(tx_start), .rx_en(rx_en), .bauddiv(bauddiv),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .parity_en(parity_en), .parity_type(parity_type), .tx_data(tx_data)
    );

    uart_tx u_uart_tx (
        .clk(clk), .rst_n(rst_n),
        .baud_div({2'b00, bauddiv}),          // 14b -> 16b
        .parity_en(parity_en),
        .num_data_bit(num_data_bit),
        .num_stop_bit({3'b000, num_stop_bit}),// 1b -> 4b
        .tx_start(tx_start),
        .tx_data(tx_data),
        .parity_type(parity_type),
        .tx_done(tx_done),
        .tx(tx)
    );

    uart_rx u_uart_rx (
        .clk(clk), .rst_n(rst_n),
        .rx_en(rx_en),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .num_data_bit(num_data_bit),
        .num_stop_bit(num_stop_bit),
        .baud_div(bauddiv),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .frame_error(frame_error),
        .parity_error(parity_error)
    );

endmodule