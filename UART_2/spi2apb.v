module spi2apb (
    input             clk, 
    input             rst_n, 

    // SPI com
    input             spi_cs_n, 
    input             spi_sclk, 
    input             spi_mosi, 

    output            spi_miso, 

    // APB slave com
    input  reg [31:0] prdata, 
    input  reg        pslverr, 
    input  reg        pready, 

    output            pselect, 
    output            penable, 
    output            pwrite, 
    output     [11:0] paddr, 
    output     [3:0]  pstrb, 
    output     [31:0] pwdata, 
);
    wire sync_cs;
    wire sync_sclk;
    wire sync_mosi;
    wire rise, fall;

    reg [7:0] mosi_reg;
    reg [7:0] miso_reg;

    wire en_mosi;
    wire en_miso;
    wire mode_miso;
    wire [7:0] miso_data;

    reg [2:0] bit_cnt;
    reg [2:0] cnt;
    wire [2:0] b_cnt;
    wire en_apb_to_buff;
    wire en_spi_to_buff;
    wire en_cbi, clr_cbi;
    wire en_cby, clr_cby;

    wire tick = bit_cnt == 3'd7;

    assign spi_miso = miso_reg[7];

    sync_edge_det u_sync_cs (
        .clk(clk),
        .rst_n(rst_n),
        .rx(spi_cs_n),
        .stable_rx(sync_cs),
        .fall_edge_rx(), 
        .rise_edge_rx()
    );
    sync_edge_det u_sync_sclk (
        .clk(clk),
        .rst_n(rst_n),
        .rx(spi_sclk),
        .stable_rx(sync_sclk),
        .fall_edge_rx(fall), 
        .rise_edge_rx(rise)
    );
    sync_edge_det u_sync_mosi (
        .clk(clk),
        .rst_n(rst_n),
        .rx(spi_mosi),
        .stable_rx(sync_mosi),
        .fall_edge_rx(), 
        .rise_edge_rx()
    );

    spi_controller u_spi_controller (
        .clk(clk), 
        .rst_n(rst_n), 
        .sync_cs(sync_cs), 
        .rise(rise), 
        .fall(fall), 
        .tick(tick), 
        .en_mosi(en_mosi), 
        .en_miso(en_miso), 
        .mode_miso(mode_miso), 
        .en_cbi(en_cbi), 
        .clr_cbi(clr_cbi), 
        .en_cby(en_cby), 
        .clr_cby(clr_cby), 
        .en_spi_to_buff(en_spi_to_buff)
    );

    apb_master_controller u_apb_master_controller (
        .clk(clk), 
        .rst_n(rst_n), 
        .cnt(b_cnt), 
        .pwrite(pwrite), 
        .en_spi_to_buff(en_spi_to_buff), 
        .en_apb_to_buff(en_apb_to_buff), 
        .pselect(pselect), 
        .penable(penable)
    );

    apb_data_buffer u_apb_data_buffer (
        .clk(clk), 
        .rst_n(rst_n), 
        // SPI com
        .en_spi_to_buff(en_spi_to_buff), 
        .cnt(cnt), 
        .mosi_data(mosi_reg), 
        .miso_data(miso_data), 
        // APB com
        .en_apb_to_buff(en_apb_to_buff), 
        .prdata(prdata), 
        .pslverr(pslverr), 
        .b_cnt(b_cnt), 
        .pwrite(pwrite), 
        .paddr(paddr), 
        .pstrb(pstrb), 
        .pwdata(pwdata)
    );


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            mosi_reg <= 8'd0;
        else if (en_mosi) 
            mosi_reg <= {mosi_reg[6:0], sync_mosi};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            miso_reg <= 8'd0;
        else if (sync_cs) 
            miso_reg <= 8'd0;
        else if (en_mosi) 
            miso_reg <= mode_miso ? miso_data : {miso_reg[6:0], 1'b0};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            cnt <= 0;
        else if (clr_cby | (cnt == 3'd6)) 
            cnt <= 0;
        else if (en_cby) 
            cnt <= cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            bit_cnt <= 0;
        else if (clr_cbi) 
            bit_cnt <= 0;
        else if (en_cbi) 
            bit_cnt <= bit_cnt + 1'b1;
    end
endmodule