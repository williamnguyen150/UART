module apb_regs (
    input clk, 
    input rst_n, 

    // apb_slave com
    input             access, 
    input             write, 
    input      [5:0]  addr, 
    input      [3:0]  strb, 
    input      [31:0] w_data, 

    output reg [31:0] r_data, 
    output reg        write_en, 
    output reg        read_en, 
    output            interrupt, 

    // uart_core com
    input      [7:0]  rx_data, 
    input             parity_error, 
    input             frame_error, 
    input             tx_done, 
    input             rx_done, 

    output            tx_start, 
    output            rx_en, 
    output     [13:0] bauddiv, 
    output     [1:0]  num_data_bit, 
    output            num_stop_bit, 
    output            parity_en, 
    output            parity_type, 
    output     [7:0]  tx_data
);
    // ***********************
    // **   APB Registers   **
    // ***********************
    localparam  A_CONFIG = 6'd0, 
                A_TXDATA = 6'd1, 
                A_RXDATA = 6'd2, 
                A_STATUS = 6'd3, 
                A_IRQEN = 6'd4, 
                A_IRQSTAT = 6'd5;
    // CONFIG
    reg [13:0] BAUDDIV;
    reg [1:0]  DATALEN;
    reg STOP2, PARITY_EN, PARITY_TYPE, TX_EN, RX_EN;
    // TXDATA
    wire [7:0] TX_DATA = w_data[7:0];
    // RXDATA
    wire [7:0] RX_DATA;
    wire PARITY_ERROR, FRAME_ERROR;
    // STATUS
    reg TX_BUSY;
    wire TX_FULL, TX_EMPTY, RX_FULL, RX_EMPTY;
    // IRQEN
    reg IR_EN;
    // IRQ_STAT
    reg TX_OVERRUN, RX_OVERRUN, CONFIG_OVERWRITE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            TX_BUSY <= 1'd0;
        else if (tx_done) 
            TX_BUSY <= 1'd0;
        else if (tx_start) 
            TX_BUSY <= 1'd1;
        else 
            TX_BUSY <= TX_BUSY;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            RX_OVERRUN <= 1'd0;
        else if (access & write & (addr == A_IRQSTAT) & strb[0]) 
            RX_OVERRUN <= RX_OVERRUN & ~w_data[1];
        else if (RX_EN & RX_FULL & rx_done) 
            RX_OVERRUN <= 1'd1;
        else 
            RX_OVERRUN <= RX_OVERRUN;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            CONFIG_OVERWRITE <= 1'd0;
        else if (access & write) begin
            if ((addr == A_IRQSTAT) & strb[0]) 
                CONFIG_OVERWRITE <= CONFIG_OVERWRITE & ~w_data[0];
            if ((addr == A_CONFIG) & |strb[3:1] & (TX_EN | RX_EN)) 
                CONFIG_OVERWRITE <= 1'd1;
        end else begin
            CONFIG_OVERWRITE <= CONFIG_OVERWRITE;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            BAUDDIV <= 14'd0;
            DATALEN <= 2'd0;
            STOP2 <= 1'd0;
            PARITY_EN <= 1'd0;
            PARITY_TYPE <= 1'd0;
            TX_EN <= 1'd0;
            RX_EN <= 1'd0;
            IR_EN <= 1'd0;
            TX_OVERRUN <= 1'd0;
        end else if (access & write) begin
            case (addr)
                A_CONFIG: begin
                    if (strb[3] & ~(TX_EN | RX_EN)) BAUDDIV[13:8] <= w_data[29:24];
                    if (strb[2] & ~(TX_EN | RX_EN)) BAUDDIV[7:0] <= w_data[23:16];
                    if (strb[1] & ~(TX_EN | RX_EN)) {DATALEN, STOP2, PARITY_EN, PARITY_TYPE} <= w_data[12:8];
                    if (strb[0]) {TX_EN, RX_EN} <= w_data[1:0];
                end
                A_TXDATA: begin
                    if (strb[0] & TX_FULL) TX_OVERRUN <= 1'd1;
                end
                A_IRQEN: begin
                    if (strb[0]) IR_EN <= w_data[0];
                end
                A_IRQSTAT: begin
                    if (strb[0]) TX_OVERRUN <= TX_OVERRUN & ~w_data[2];
                end
            endcase
        end
    end


    // ******************
    // **   FIFO com   **
    // ******************
    wire tx_read_en = TX_EN & ~TX_BUSY;
    wire tx_write_en = access & (addr == A_TXDATA) & strb[0] & write;
    wire rx_read_en = access & (addr == A_RXDATA) & ~write;
    wire rx_write_en = RX_EN & rx_done;

    tx_fifo #(.BIT_WIDTH(8), .TAP(4)) txfifo(
        .clk(clk), 
        .rst_n(rst_n), 
        .read_en(tx_read_en), 
        .write_en(tx_write_en), 
        .data_in(TX_DATA), 
        .data_out(tx_data), 
        .empty(TX_EMPTY), 
        .full(TX_FULL)
    );
    rx_fifo #(.BIT_WIDTH(10), .TAP(4)) rxfifo(
        .clk(clk), 
        .rst_n(rst_n), 
        .read_en(rx_read_en), 
        .write_en(rx_write_en), 
        .data_in({rx_data, parity_error, frame_error}), 
        .data_out({RX_DATA, PARITY_ERROR, FRAME_ERROR}), 
        .empty(RX_EMPTY), 
        .full(RX_FULL)
    );


    // ***********************
    // **   APB Slave com   **
    // ***********************
    assign interrupt = IR_EN & (TX_OVERRUN | RX_OVERRUN | CONFIG_OVERWRITE);
    always @(*) begin
        case (addr)
            A_CONFIG: begin
                read_en = 1;
                write_en = 1;
                r_data = {2'd0, BAUDDIV, 3'd0, DATALEN, STOP2, PARITY_EN, PARITY_TYPE, 6'd0, TX_EN, RX_EN};
            end
            A_TXDATA: begin
                read_en = 0;
                write_en = 1;
                r_data = 32'd0;
            end
            A_RXDATA: begin
                read_en = 1;
                write_en = 0;
                r_data = {22'd0, RX_DATA, PARITY_ERROR, FRAME_ERROR};
            end
            A_STATUS: begin
                read_en = 1;
                write_en = 0;
                r_data = {27'd0, TX_BUSY, TX_FULL, TX_EMPTY, RX_FULL, RX_EMPTY};
            end
            A_IRQEN: begin
                read_en = 1;
                write_en = 1;
                r_data = {31'd0, IR_EN};
            end
            A_IRQSTAT: begin
                read_en = 1;
                write_en = 1;
                r_data = {29'd0, TX_OVERRUN, RX_OVERRUN, CONFIG_OVERWRITE};
            end
            default: begin
                read_en = 0;
                write_en = 0;
                r_data = 32'd0;
            end
        endcase
    end


    // ***********************
    // **   UART core com   **
    // ***********************
    assign tx_start = TX_EN & ~TX_EMPTY & ~TX_BUSY;
    assign rx_en = RX_EN;
    assign bauddiv = BAUDDIV;
    assign num_data_bit = DATALEN;
    assign num_stop_bit = STOP2;
    assign parity_en = PARITY_EN;
    assign parity_type = PARITY_TYPE;

endmodule
