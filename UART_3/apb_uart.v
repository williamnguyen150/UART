module apb_uart (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [3:0]  pstrb,
    input  wire [31:0] pwdata,
    output wire        pready,
    output wire        pslverr,
    output wire [31:0] prdata,
    input  wire        rx,
    input  wire        cts_n,
    output wire        tx,
    output wire        rts_n,
    output wire        irq
);
    wire        access, write, write_en, read_en, interrupt;
    wire [11:0] addr;
    wire [3:0]  strb;
    wire [31:0] w_data, r_data;
    wire [7:0]  rx_data, tx_data;
    wire        parity_error, frame_error, tx_done, rx_busy, rx_done_stat;
    wire        tx_start, rx_en, soft_rst, num_stop_bit, parity_en, parity_type;
    wire [15:0] bauddiv;
    wire [1:0]  num_data_bit;

    apb_slave u_apb_slave (
        .clk(pclk), .rst_n(presetn), .pselect(psel), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
        .prdata(prdata), .pslverr(pslverr), .pready(pready), .irq(irq),
        .r_data(r_data), .write_en(write_en), .read_en(read_en), .interrupt(interrupt),
        .access(access), .write(write), .addr(addr), .strb(strb), .w_data(w_data)
    );

    apb_regs u_apb_regs (
        .clk(pclk), .rst_n(presetn), .access(access), .write(write),
        .addr(addr), .strb(strb), .w_data(w_data), .r_data(r_data),
        .write_en(write_en), .read_en(read_en), .interrupt(interrupt),
        .rx_data(rx_data), .parity_error(parity_error), .frame_error(frame_error),
        .tx_done(tx_done), .rx_busy(rx_busy), .tx_start(tx_start), .rx_en(rx_en),
        .rx_done_out(rx_done_stat), .soft_rst(soft_rst), .bauddiv(bauddiv),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit), .parity_en(parity_en),
        .parity_type(parity_type), .tx_data(tx_data)
    );

    uart_tx u_uart_tx (
        .clk(pclk), .rst_n(presetn), .baud_div(bauddiv), .parity_en(parity_en),
        .parity_type(parity_type), .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .tx_start(tx_start), .tx_data(tx_data), .soft_rst(soft_rst), .cts_n(cts_n),
        .tx_done(tx_done), .tx(tx)
    );

    uart_rx u_uart_rx (
        .clk(pclk), .rst_n(presetn), .soft_rst(soft_rst), .rx_en(rx_en),
        .rx_done_flag(rx_done_stat), .parity_en(parity_en), .parity_type(parity_type),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit), .baud_div(bauddiv),
        .rx(rx), .rx_data(rx_data), .rx_busy(rx_busy), .frame_error(frame_error),
        .parity_error(parity_error), .rts_n(rts_n)
    );
endmodule