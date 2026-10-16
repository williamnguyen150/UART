module Test (
    // Xung nhịp và Reset từ kit DE2-115
    input  wire CLOCK_50,
    input  wire [0:0] KEY,    // KEY[0] mặc định là tích cực mức thấp (rst_n)

    // Các chân vật lý của UART kết nối ra ngoài (GPIO hoặc cổng RS232 trên kit)
    output wire UART_TXD,
    input  wire UART_RXD
);

    // =========================================================
    // 1. KHAI BÁO BUS APB TỪ NIOS V XUỐNG APB_SLAVE
    // =========================================================
    wire [31:0] apb_paddr;
    wire        apb_psel;
    wire        apb_penable;
    wire        apb_pwrite;
    wire [3:0]  apb_pstrb;
    wire [31:0] apb_pwdata;
    wire [31:0] apb_prdata;
    wire        apb_pready;
    wire        apb_pslverr;
    wire        apb_pirq;

    // =========================================================
    // 2. KHAI BÁO DÂY NỐI NỘI BỘ GIỮA APB_SLAVE VÀ APB_REGS
    // =========================================================
    wire        int_access;
    wire        int_write;
    wire [5:0]  int_addr;
    wire [3:0]  int_strb;
    wire [31:0] int_w_data;
    wire [31:0] int_r_data;
    wire        int_write_en;
    wire        int_read_en;
    wire        int_interrupt;

    // =========================================================
    // 3. KHAI BÁO DÂY CHỜ CHO MODULE UART_CORE THỰC TẾ
    // =========================================================
    wire [7:0]  uart_rx_data;
    wire        uart_parity_error;
    wire        uart_frame_error;
    wire        uart_tx_done;
    wire        uart_rx_done;
    
    wire        uart_tx_start;
    wire        uart_rx_en;
    wire [13:0] uart_bauddiv;
    wire [1:0]  uart_num_data_bit;
    wire        uart_num_stop_bit;
    wire        uart_parity_en;
    wire        uart_parity_type;
    wire [7:0]  uart_tx_data;

    // =========================================================
    // INSTANCE 1: HỆ THỐNG NIOS V (Platform Designer)
    // =========================================================
    test_mp u0_nios_system (
        .clk_clk         (CLOCK_50),
        .reset_reset_n     (~KEY[0]),
        
        // Export APB Bus (Tên cổng này phụ thuộc vào cách bạn đặt tên Export trong Qsys)
        .apb_bus_paddr     (apb_paddr),
        .apb_bus_psel      (apb_psel),
        .apb_bus_penable   (apb_penable),
        .apb_bus_pwrite    (apb_pwrite),
        .apb_bus_pstrb     (apb_pstrb),
        .apb_bus_pwdata    (apb_pwdata),
        .apb_bus_prdata    (apb_prdata),
        .apb_bus_pready    (apb_pready),
        .apb_bus_pslverr   (apb_pslverr),
        .apb_bus_pirq      (apb_pirq)      // Nối chân ngắt
    );

    // =========================================================
    // INSTANCE 2: MODULE APB SLAVE
    // =========================================================
    apb_slave u1_apb_slave (
        .clk        (CLOCK_50),
        .rst_n      (~KEY[0]),

        // Giao tiếp với Nios V
        // Lưu ý: CPU trả ra paddr 32-bit, nhưng module chỉ lấy 6-bit [5:0]
        .pselect    (apb_psel),
        .penable    (apb_penable),
        .pwrite     (apb_pwrite),
        .paddr      (apb_paddr[5:0]), 
        .pstrb      (apb_pstrb),
        .pwdata     (apb_pwdata),
        .prdata     (apb_prdata),
        .pslverr    (apb_pslverr),
        .pready     (apb_pready),
        .pirq       (apb_pirq),

        // Giao tiếp với APB_REGS
        .r_data     (int_r_data),
        .write_en   (int_write_en),
        .read_en    (int_read_en),
        .interrupt  (int_interrupt),
        .access     (int_access),
        .write      (int_write),
        .addr       (int_addr),
        .strb       (int_strb),
        .w_data     (int_w_data)
    );

    // =========================================================
    // INSTANCE 3: MODULE APB REGS
    // =========================================================
    apb_regs u2_apb_regs (
        .clk           (CLOCK_50),
        .rst_n         (~KEY[0]),

        // Giao tiếp với APB_SLAVE
        .access        (int_access),
        .write         (int_write),
        .addr          (int_addr),
        .strb          (int_strb),
        .w_data        (int_w_data),
        .r_data        (int_r_data),
        .write_en      (int_write_en),
        .read_en       (int_read_en),
        .interrupt     (int_interrupt),
		  
		// Giao tiếp với UART_CORE (Cấp mức logic an toàn)
        // .rx_data       (8'd0), 
        // .parity_error  (1'b0),
        // .frame_error   (1'b0),
        // .tx_done       (1'b1), // Giả lập trạng thái bộ truyền đang rảnh
        // .rx_done       (1'b0), // Không có dữ liệu nhận
        // .tx_start      (),
        // .rx_en         (),
        // .bauddiv       (),
        // .num_data_bit  (),
        // .num_stop_bit  (),
        // .parity_en     (),
        // .parity_type   (),
        // .tx_data       ()

        // Giao tiếp với UART_CORE
        .rx_data       (uart_rx_data),
        .parity_error  (uart_parity_error),
        .frame_error   (uart_frame_error),
        .tx_done       (uart_tx_done),
        .rx_done       (uart_rx_done),
        .tx_start      (uart_tx_start),
        .rx_en         (uart_rx_en),
        .bauddiv       (uart_bauddiv),
        .num_data_bit  (uart_num_data_bit),
        .num_stop_bit  (uart_num_stop_bit),
        .parity_en     (uart_parity_en),
        .parity_type   (uart_parity_type),
        .tx_data       (uart_tx_data)
    );

    // =========================================================
    // INSTANCE 4: MODULE UART CORE (Logic vật lý)
    // Bạn cần instantiate module truyền/nhận UART thực tế của bạn tại đây
    // và nối với các dây uart_* ở trên, đồng thời nối với UART_TXD và UART_RXD
    // =========================================================
    
    uart_tx u3_uart_core_tx (
        .clk           (CLOCK_50),
        .rst_n         (~KEY[0]),
        .baud_div      (uart_bauddiv),
        .parity_en     (uart_parity_en),
        .num_data_bit  (uart_num_data_bit),
        .num_stop_bit  (uart_num_stop_bit),
        .tx_start      (uart_tx_start),
        .tx_data       (uart_tx_data),
        .parity_type   (uart_parity_type),
        .tx_done       (uart_tx_done),
        .tx            (UART_TXD)
    );

    uart_rx u4_uart_core_rx (
        .clk           (CLOCK_50),
        .rst_n         (~KEY[0]),
        .rx_en         (uart_rx_en),
        .parity_en     (uart_parity_en),
        .parity_type   (uart_parity_type),
        .num_data_bit  (uart_num_data_bit),
        .num_stop_bit  (uart_num_stop_bit),
        .baud_div      (uart_bauddiv),
        .rx            (UART_RXD),
        .rx_data       (uart_rx_data),
        .rx_done       (uart_rx_done),
        .frame_error   (uart_frame_error),
        .parity_error  (uart_parity_error) 
    );

endmodule