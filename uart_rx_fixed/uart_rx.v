module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_en,         // Cho phép thu
    input  wire        parity_en,     // Cho phép kiểm tra parity
    input  wire        parity_type,   // 0: Even, 1: Odd
    input  wire [1:0]  num_data_bit,  // Cấu hình số bit dữ liệu
    input  wire        num_stop_bit,  // Cấu hình số bit stop
    input  wire [13:0] baud_div,      // Hệ số chia baud rate
    input  wire        rx,            // Chân nhận tín hiệu nối tiếp vật lý
    output wire [7:0]  rx_data,       // Dữ liệu nhận song song (8-bit)
    output wire        rx_done,       // Cờ báo hoàn tất nhận 1 khung
    output wire        frame_error,   // Cờ báo lỗi khung (Frame Error)
    output wire        parity_error   // Cờ báo lỗi Parity
);

    // Khai báo các đường dây nội bộ (internal wires) để liên kết giữa các khối con
    wire        stable_rx;
    wire        fall_edge_rx;
    wire        en_shift;
    wire        en_cnt;
    wire        cnt_mode;
    wire        baud_mode;
    wire        max_baud = baud_mode ? num_stop_bit : (num_data_bit + parity_en + 2'd4);
    wire        cnt_tick;
    wire        half_cnt_tick;
    wire        baud_tick;
    wire [8:0]  shift_out;
    wire        invalid;

    assign rx_data = shift_out [7:0];

    // ==========================================
    // 1. Khối Đồng bộ & Phát hiện cạnh xuống (Sync & Edge Detect)
    // ==========================================
    sync_edge_det u_sync_edge (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx            (rx),
        .stable_rx     (stable_rx),
        .fall_edge_rx  (fall_edge_rx)
    );

    // ==========================================
    // 2. Khối Tạo nhịp Baud & Bộ đếm chia tần (Baud & Divider Counter)
    // ==========================================
    div_counter div_cnt (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_en         (rx_en),
        .en_cnt        (en_cnt),
        .cnt_mode      (cnt_mode),
        .baud_div      (baud_div),
        .cnt_tick      (cnt_tick),
        .half_cnt_tick (half_cnt_tick),
    );

    baud_counter baud_cnt (
        .clk            (clk),
        .rst_n          (rst_n & rx_en),
        .max_baud       (max_baud),
        .cnt_tick       (cnt_tick),
        .baud_tick      (baud_tick)
    );

    // ==========================================
    // 3. Khối Thanh ghi dịch SIPO (Serial in Parallel out)
    // ==========================================
    sipo_reg u_sipo (
        .clk           (clk),
        .rst_n         (rst_n),
        .en_shift      (en_shift),
        .stable_rx     (stable_rx),
        .rx_data       (shift_out)
    );

    // ==========================================
    // 4. Khối Kiểm tra Parity (Parity Check)
    // ==========================================
    parity_check u_parity_check (
        .data_in       (shift_out),
        .parity_type   (parity_type),
        .num_data_bit  (num_data_bit),
        .invalid       (invalid)
    );

    // ==========================================
    // 5. Khối Điều khiển trung tâm FSM (Control)
    // ==========================================
    uart_rx_controller FSM (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_en         (rx_en),
        .parity_en     (parity_en),
        .fall_edge_rx  (fall_edge_rx),
        .stable_rx     (stable_rx),
        .cnt_tick      (cnt_tick),
        .half_cnt_tick (half_cnt_tick),
        .en_shift      (en_shift),
        .en_cnt        (en_cnt),
        .cnt_mode      (cnt_mode),
        .baud_mode     (baud_mode),
        .rx_done       (rx_done),
        .frame_error   (frame_error),
        .parity_error  (parity_error),
        .invalid       (invalid)
    );

endmodule
