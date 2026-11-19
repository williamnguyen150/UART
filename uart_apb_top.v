// Top: APB slave + APB registers + UART TX + UART RX (khop RTL hien tai)
module uart_apb_top (
    input  wire        clk,
    input  wire        rst_n,
    // APB
    input  wire        pselect, penable, pwrite,
    input  wire [5:0]  paddr,
    input  wire [3:0]  pstrb,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pslverr, pready, pirq,
    // UART
    input  wire        rx,
    input  wire        cts_n,
    output wire        tx,
    output wire        rts_n
);
    wire        access, write, write_en, read_en, interrupt;
    wire [5:0]  addr;
    wire [3:0]  strb;
    wire [31:0] w_data, r_data;
    wire        tx_start, tx_done, rx_busy, rx_en;
    wire        parity_en, parity_type, num_stop_bit, parity_error, frame_error;
    wire [15:0] bauddiv;
    wire [1:0]  num_data_bit;
    wire [7:0]  tx_data, rx_data;
    wire        soft_rst;            // tu thanh ghi trong apb_regs

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
        .tx_done(tx_done), .rx_busy(rx_busy),
        .tx_start(tx_start), .rx_en(rx_en), .soft_rst(soft_rst), .bauddiv(bauddiv),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .parity_en(parity_en), .parity_type(parity_type), .tx_data(tx_data)
    );

    uart_tx u_uart_tx (
        .clk(clk), .rst_n(rst_n),
        .baud_div(bauddiv),
        .parity_en(parity_en), .parity_type(parity_type),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .tx_start(tx_start), .tx_data(tx_data),
        .soft_rst(soft_rst), .cts_n(cts_n),
        .tx_done(tx_done), .tx(tx)
    );

    uart_rx u_uart_rx (
        .clk(clk), .rst_n(rst_n), .soft_rst(soft_rst),
        .rx_en(rx_en), .parity_en(parity_en), .parity_type(parity_type),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .baud_div(bauddiv), .rx(rx),
        .rx_data(rx_data), .rx_busy(rx_busy),
        .frame_error(frame_error), .parity_error(parity_error), .rts_n(rts_n)
    );
endmodule
