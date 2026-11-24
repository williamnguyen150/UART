module apb_slave (
    input clk, 
    input rst_n, 

    // apb_master com
    input             pselect, 
    input             penable, 
    input             pwrite, 
    input      [11:0]  paddr, 
    input      [3:0]  pstrb, 
    input      [31:0] pwdata, 

    output reg [31:0] prdata, 
    output reg        pslverr, 
    output reg        pready, 
    output            irq, 

    // apb_regs com
    input      [31:0] r_data, 
    input             write_en, 
    input             read_en, 
    input             interrupt, 

    output reg        access, 
    output reg        write, 
    output reg [11:0] addr, 
    output reg [3:0]  strb, 
    output reg [31:0] w_data
);
    localparam IDLE = 1'b0, SETUP = 1'b1;

    reg state;
    wire next_state;

    assign next_state = pselect ? SETUP : IDLE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end

    always @(*) begin
        access  = 1'd0;
        write   = 1'd0;
        addr    = 12'd0;
        strb    = 4'd0;
        w_data  = 32'd0;
        prdata  = 32'd0;
        pslverr = 1'd0;
        pready  = 1'd1;

        case (state)
            IDLE: begin
                pready = 1'd1; // APB luôn sẵn sàng
            end
            SETUP: begin
                // ---> [SỬA]: access chỉ bằng 1 ở pha Access (pselect & penable) để apb_regs không bị ghi nhầm ở pha Setup
                access = pselect & penable;
                write  = pwrite;
                addr   = paddr;
                strb   = pstrb;
                w_data = pwdata;

                // ---> [SỬA]: Chỉ xuất prdata khi ở pha Access và là lệnh đọc. Tránh đẩy rác ra bus.
                prdata = (pselect & penable & ~pwrite) ? r_data : 32'd0;
                
                // ---> [SỬA]: Lỗi pslverr chỉ kích hoạt đúng pha Access
                pslverr = pselect & penable & (pwrite ? ~write_en : ~read_en);
            end
        endcase
    end

    assign irq = interrupt;
endmodule