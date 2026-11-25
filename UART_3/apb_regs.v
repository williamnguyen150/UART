module apb_regs (
    input clk, 
    input rst_n, 

    // apb_slave com
    input             access, 
    input             write, 
    input      [11:0] addr, 
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
    input             rx_busy, 
    input             rx_done,

    output            tx_start, 
    output            rx_full, 
    output            rx_en, 
    output            soft_rst, 
    output     [15:0] bauddiv, 
    output     [1:0]  num_data_bit, 
    output            num_stop_bit, 
    output            parity_en, 
    output            parity_type, 
    output     [7:0]  tx_data
);
    // ***********************
    // **   APB Registers   **
    // ***********************
    localparam  A_TXDATA = 12'h00, 
                A_RXDATA = 12'h04, 
                A_CONFIG = 12'h08, 
                A_CTRL   = 12'h0C, 
                A_STATUS = 12'h10, 
                A_BAUD   = 12'h14,
                A_IER    = 12'h18;
    // TXDATA
    reg [7:0] TX_DATA;
    // RXDATA
    reg [7:0] RX_DATA;
    // CONFIG
    reg [1:0]  DATALEN;
    reg STOP2, PARITY_EN, PARITY_TYPE, TX_DIS, RX_DIS;
    // CTRL
    reg TX_START, SOFT_RST;
    // STATUS
    reg TX_DONE, RX_DONE;
    reg PARITY_ERROR, FRAME_ERROR;
    wire RX_BUSY = rx_busy;
    reg OVERRUN;
    // IER
    reg TX_DONE_IE, RX_DONE_IE, ERR_IE;
    // BAUDIV[15:12] = div_frac, BAUDDIV[11:0] = div_int
    // => baud_div = 16 x div_int + div_frac, baud_rate = f_pclk / baud_div for both tx, rx
    reg [15:0] BAUDDIV;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            RX_DATA <= 8'd0;
        else if (SOFT_RST) 
            RX_DATA <= 8'd0;
        else if (rx_done & ~RX_DONE) 
            RX_DATA <= rx_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            TX_DONE <= 1'd1;
        else if (SOFT_RST | tx_done) 
            TX_DONE <= 1'd1;
        else if (TX_START) 
            TX_DONE <= 1'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            RX_DONE <= 1'd0;
        else if (SOFT_RST) 
            RX_DONE <= 1'd0;
        else if (rx_done) 
            RX_DONE <= 1'd1;
        else if ((addr == A_RXDATA) & ~write & access) 
            RX_DONE <= 1'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PARITY_ERROR <= 1'd0;
            FRAME_ERROR <= 1'd0;
            OVERRUN <= 1'd0;
        end else if (SOFT_RST) begin
            PARITY_ERROR <= 1'd0;
            FRAME_ERROR <= 1'd0;
            OVERRUN <= 1'd0;
        end else if (rx_done) begin
            PARITY_ERROR <= parity_error;
            FRAME_ERROR <= frame_error;
            OVERRUN <= RX_DONE;
        end else if ((addr == A_RXDATA) & ~write & access) begin
            PARITY_ERROR <= 1'd0;
            FRAME_ERROR <= 1'd0;
            OVERRUN <= 1'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            SOFT_RST <= 1'd0;
        else if (access & write & (addr == A_CTRL) & strb[1]) 
            SOFT_RST <= w_data[8];
        else 
            SOFT_RST <= 1'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            TX_START <= 1'd0;
        else if (SOFT_RST | (access & write & (addr == A_CTRL) & strb[1] & w_data[8])) 
            TX_START <= 1'd0;
        else if (access & write & (addr == A_CTRL) & strb[0] & write_en) 
            TX_START <= w_data[0];
        else 
            TX_START <= 1'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            TX_DATA <= 8'd0;
            BAUDDIV <= 16'h900D;
            DATALEN <= 2'd0;
            STOP2 <= 1'd0;
            PARITY_EN <= 1'd0;
            PARITY_TYPE <= 1'd0;
            TX_DIS <= 1'd0;
            RX_DIS <= 1'd0;
            TX_DONE_IE <= 1'd0;
            RX_DONE_IE <= 1'd0;
            ERR_IE <= 1'd0;
        end else if (SOFT_RST) begin
            TX_DATA <= 8'd0;
            BAUDDIV <= 16'h900D;
            DATALEN <= 2'd0;
            STOP2 <= 1'd0;
            PARITY_EN <= 1'd0;
            PARITY_TYPE <= 1'd0;
            TX_DIS <= 1'd0;
            RX_DIS <= 1'd0;
            TX_DONE_IE <= 1'd0;
            RX_DONE_IE <= 1'd0;
            ERR_IE <= 1'd0;
        end else if (access & write & write_en) begin
            case (addr)
                A_TXDATA: begin
                    if (strb[0]) TX_DATA <= w_data[7:0]; 
                end
                A_CONFIG: begin
                    if (strb[0]) 
                        {RX_DIS, TX_DIS, PARITY_TYPE, PARITY_EN, STOP2, DATALEN} <= w_data[6:0];
                end
                A_BAUD: begin
                    if (strb[1]) BAUDDIV[15:8] <= w_data[15:8];
                    if (strb[0]) BAUDDIV[7:0] <= w_data[7:0];
                end
                A_IER: begin
                    if (strb[0]) {ERR_IE, RX_DONE_IE, TX_DONE_IE} <= w_data[2:0];
                end
            endcase
        end
    end


    // ***********************
    // **   APB Slave com   **
    // ***********************
    assign interrupt = (TX_DONE_IE & TX_DONE) | (RX_DONE_IE & RX_DONE) 
                        | (ERR_IE & (PARITY_ERROR | FRAME_ERROR | OVERRUN));
    
    // Tính giá trị BAUD sau khi ghép byte lane để kiểm tra E5 (div_int == 0)
    wire [15:0] next_bauddiv = {
        strb[1] ? w_data[15:8] : BAUDDIV[15:8],
        strb[0] ? w_data[7:0]  : BAUDDIV[7:0]
    };

    always @(*) begin
        case (addr)
            A_TXDATA: begin
                read_en = 1;
                write_en = TX_DONE;
                r_data = {24'd0, TX_DATA};
            end
            A_RXDATA: begin
                read_en = 1;
                write_en = 0;
                r_data = {24'd0, RX_DATA};
            end
            A_CONFIG: begin
                read_en = 1;
                write_en = ~strb[0] | (TX_DONE & ~RX_BUSY);
                r_data = {25'd0, RX_DIS, TX_DIS, PARITY_TYPE, PARITY_EN, STOP2, DATALEN};
            end
            A_CTRL: begin
                read_en = 1;
                // Chỉ báo lỗi E3 khi TX_DONE=0 và đang ghi bit start_tx (strb[0]=1 & w_data[0]=1)
                // Ghi vào bit [8] soft_reset luôn được phép
                write_en = TX_DONE | (strb[1] & w_data[8]) | ~(strb[0] & w_data[0]);
                r_data = 32'b0; // đọc CTRL luôn trả về 0 theo spec
            end
            A_STATUS: begin
                read_en = 1;
                write_en = 0;
                r_data = {24'd0, OVERRUN, FRAME_ERROR, RX_DIS, TX_DIS, RX_BUSY, PARITY_ERROR, RX_DONE, TX_DONE};
            end
            A_BAUD: begin
                read_en = 1;
                write_en = ~(strb[0] | strb[1]) | (TX_DONE & ~RX_BUSY & (|next_bauddiv[11:0]));
                r_data = {16'd0, BAUDDIV};
            end
            A_IER: begin
                read_en = 1;
                write_en = 1;
                r_data = {29'd0, ERR_IE, RX_DONE_IE, TX_DONE_IE};
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
    assign tx_start = TX_START & ~TX_DIS & TX_DONE;
    assign rx_full = RX_DONE;
    assign rx_en = ~RX_DIS;
    assign bauddiv = {BAUDDIV[11:0], 4'b0} + BAUDDIV[15:12];
    assign num_data_bit = DATALEN;
    assign num_stop_bit = STOP2;
    assign parity_en = PARITY_EN;
    assign parity_type = PARITY_TYPE;
    assign tx_data = TX_DATA;
    assign soft_rst = SOFT_RST;

endmodule