module apb_regs (
    input clk, 
    input rst_n, 

    // apb_slave com
    input             access, 
    input             write, 
    input      [11:0]  addr, 
    input      [3:0]  strb, 
    input      [31:0] w_data, 

    output reg [31:0] r_data, 
    output reg        write_en, 
    output reg        read_en, 
    output reg        interrupt, 

    // uart_core com
    input      [7:0]  rx_data, 
    input             parity_error, 
    input             frame_error, 
    input             tx_done, 
    input             rx_busy, 

    output            tx_start, 
    output            rx_en,
    output            rx_done_out, // ---> [THÊM]: Báo cho uart_rx biết CPU chưa đọc data
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
    localparam  A_TXDATA = 12'h000, 
                A_RXDATA = 12'h004, 
                A_CONFIG = 12'h008, 
                A_CTRL   = 12'h00C, 
                A_STATUS = 12'h010, 
                A_BAUD   = 12'h014,
                A_IER    = 12'h018;
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
    // BAUD
    reg [15:0] BAUDDIV;

    reg rx_busy_old;
    wire rx_done = rx_busy_old & ~rx_busy & ~RX_DIS;
    wire rd_rxdata = access & ~write & (addr == A_RXDATA) & read_en;
    wire soft_rst_req = access & write & (addr == A_CTRL) & strb[1] & w_data[8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            rx_busy_old <= 1'b0;
        else if (SOFT_RST)
            rx_busy_old <= 1'b0;
        else 
            rx_busy_old <= rx_busy;
    end

    // ---> [SỬA]: Cập nhật RX_DATA, các cờ lỗi, và logic OVERRUN đúng chuẩn
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RX_DATA      <= 8'd0;
            RX_DONE      <= 1'b0;
            PARITY_ERROR <= 1'b0;
            FRAME_ERROR  <= 1'b0;
            OVERRUN      <= 1'b0;
        end else if (SOFT_RST) begin
            RX_DATA      <= 8'd0;
            RX_DONE      <= 1'b0;
            PARITY_ERROR <= 1'b0;
            FRAME_ERROR  <= 1'b0;
            OVERRUN      <= 1'b0;
        end else if (rd_rxdata) begin // Chỉ xóa cờ khi đọc RXDATA, KHÔNG xóa khi đọc STATUS
            RX_DONE      <= 1'b0;
            PARITY_ERROR <= 1'b0;
            FRAME_ERROR  <= 1'b0;
            OVERRUN      <= 1'b0;
        end else if (rx_done) begin
            if (!RX_DONE) begin
                RX_DATA      <= rx_data;
                RX_DONE      <= 1'b1;
                PARITY_ERROR <= parity_error;
                FRAME_ERROR  <= frame_error;
            end else begin
                OVERRUN      <= 1'b1; // Giữ nguyên RX_DATA cũ, bật cờ Overrun
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            TX_DONE <= 1'b1; // Mặc định rảnh
        else if (SOFT_RST | tx_done) 
            TX_DONE <= 1'b1;
        else if (TX_START & ~TX_DIS) 
            TX_DONE <= 1'b0;
    end

    // ---> [SỬA]: Tách SOFT_RST để xử lý ưu tiên
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            SOFT_RST <= 1'b0;
        else if (soft_rst_req) 
            SOFT_RST <= 1'b1;
        else 
            SOFT_RST <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            TX_START <= 1'b0;
        else if (SOFT_RST | soft_rst_req) // ---> [SỬA]: Ghi đồng thời soft_rst thì hủy lệnh start_tx
            TX_START <= 1'b0;
        else if (access & write & (addr == A_CTRL) & strb[0] & write_en) 
            TX_START <= w_data[0];
        else 
            TX_START <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            TX_DATA     <= 8'd0;
            BAUDDIV     <= 16'h900D;
            DATALEN     <= 2'd0;
            STOP2       <= 1'b0;
            PARITY_EN   <= 1'b0;
            PARITY_TYPE <= 1'b0;
            TX_DIS      <= 1'b0;
            RX_DIS      <= 1'b0;
            TX_DONE_IE  <= 1'b0;
            RX_DONE_IE  <= 1'b0;
            ERR_IE      <= 1'b0;
        end else if (SOFT_RST) begin
            TX_DATA     <= 8'd0;
            BAUDDIV     <= 16'h900D;
            DATALEN     <= 2'd0;
            STOP2       <= 1'b0;
            PARITY_EN   <= 1'b0;
            PARITY_TYPE <= 1'b0;
            TX_DIS      <= 1'b0;
            RX_DIS      <= 1'b0;
            TX_DONE_IE  <= 1'b0;
            RX_DONE_IE  <= 1'b0;
            ERR_IE      <= 1'b0;
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
                    if (strb[0]) BAUDDIV[7:0]  <= w_data[7:0];
                end
                A_IER: begin
                    if (strb[0]) {ERR_IE, RX_DONE_IE, TX_DONE_IE} <= w_data[2:0];
                end
            endcase
        end
    end

    // ---> [SỬA]: Sửa logic AND thành OR cho các cờ lỗi ngắt (ERR_IE)
    wire irq_next = (TX_DONE_IE & TX_DONE) | (RX_DONE_IE & RX_DONE) 
                  | (ERR_IE & (PARITY_ERROR | FRAME_ERROR | OVERRUN));

    // ---> [SỬA]: Chốt irq qua Flip-Flop để tránh glitch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            interrupt <= 1'b0;
        else if (SOFT_RST)
            interrupt <= 1'b0;
        else
            interrupt <= irq_next;
    end

    // Giải mã địa chỉ và kiểm tra lỗi E1 - E5
    wire [15:0] next_bauddiv = {
        strb[1] ? w_data[15:8] : BAUDDIV[15:8],
        strb[0] ? w_data[7:0]  : BAUDDIV[7:0]
    };

    always @(*) begin
        case (addr)
            A_TXDATA: begin
                read_en  = 1'b1;
                write_en = (strb == 4'b0000) | TX_DONE; // ---> [SỬA]: E3 - Lỗi nếu ghi khi TX_DONE=0
                r_data   = {24'd0, TX_DATA};
            end
            A_RXDATA: begin
                read_en  = 1'b1;
                write_en = 1'b0; // ---> [SỬA]: E2 - Ghi vào Read-Only
                r_data   = {24'd0, RX_DATA};
            end
            A_CONFIG: begin
                read_en  = 1'b1;
                write_en = ~strb[0] | (TX_DONE & ~RX_BUSY); // ---> [SỬA]: E4 - Lỗi nếu đổi config khi đang bận
                r_data   = {25'd0, RX_DIS, TX_DIS, PARITY_TYPE, PARITY_EN, STOP2, DATALEN};
            end
            A_CTRL: begin
                read_en  = 1'b1;
                // ---> [SỬA]: E3 & Ưu tiên soft_rst - Lỗi nếu kích start_tx khi bận, TRỪ KHI có kèm soft_rst
                write_en = (strb[1] & w_data[8]) | ~(strb[0] & w_data[0] & ~TX_DONE);
                r_data   = 32'd0;
            end
            A_STATUS: begin
                read_en  = 1'b1;
                write_en = 1'b0; // ---> [SỬA]: E2 - Ghi vào Read-Only
                r_data   = {24'd0, OVERRUN, FRAME_ERROR, RX_DIS, TX_DIS, RX_BUSY, PARITY_ERROR, RX_DONE, TX_DONE};
            end
            A_BAUD: begin
                read_en  = 1'b1;
                // ---> [SỬA]: E4 & E5 - Xóa &w_data[11:0]. Phải báo lỗi nếu chia cho 0
                write_en = (~(strb[0] | strb[1]) | (TX_DONE & ~RX_BUSY)) & (next_bauddiv != 16'd0);
                r_data   = {16'd0, BAUDDIV};
            end
            A_IER: begin
                read_en  = 1'b1;
                write_en = 1'b1;
                r_data   = {29'd0, ERR_IE, RX_DONE_IE, TX_DONE_IE};
            end
            default: begin
                // ---> [SỬA]: E1 - Địa chỉ rác ngoài bảng
                read_en  = 1'b0; 
                write_en = 1'b0; 
                r_data   = 32'd0;
            end
        endcase
    end

    // ---> [SỬA]: Cập nhật các cờ điều khiển Core
    assign tx_start     = TX_START & ~TX_DIS & TX_DONE;
    assign rx_en        = ~RX_DIS; // rx_en không bị tắt bởi RX_DONE nữa
    assign rx_done_out  = RX_DONE; // Truyền xuống Core để điều khiển rts_n
    assign bauddiv      = BAUDDIV;
    assign num_data_bit = DATALEN;
    assign num_stop_bit = STOP2;
    assign parity_en    = PARITY_EN;
    assign parity_type  = PARITY_TYPE;
    assign tx_data      = TX_DATA;
    assign soft_rst     = SOFT_RST;

endmodule