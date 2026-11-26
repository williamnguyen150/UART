module apb_data_buffer (
    input             clk, 
    input             rst_n, 
    
    // SPI com
    input             en_spi_to_buff, 
    input       [2:0] cnt, 
    input       [7:0] mosi_data, 

    output reg  [7:0] miso_data, 

    // APB com
    input             en_apb_to_buff, 
    input      [31:0] prdata, 
    input             pslverr, 

    output      [2:0] b_cnt, 
    output reg        pwrite, 
    output reg [11:0] paddr, 
    output      [3:0] pstrb, 
    output reg [31:0] pwdata
);
    localparam [3:0] 
        B0 = 4'd0, 
        B1 = 4'd1, 
        B2 = 4'd2, 
        B3 = 4'd3, 
        B4 = 4'd4, 
        B5 = 4'd5, 
        B6 = 4'd6, 
        B7 = 4'd7;

    reg [7:0] mosi_data;
    reg [31:0] prdata_r;
    reg pslverr_r, cmd_err;

    assign b_cnt = cnt;
    assign pstrb = 4'b1111;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prdata_r <= 0;
            pslverr_r <= 0;
        end else if (en_apb_to_buff) begin
            prdata_r <= prdata;
            pslverr_r <= pslverr;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwrite <= 0;
            cmd_err <= 0;
            paddr <= 0;
            pwdata <= 0;
        end else if (en_spi_to_buff) begin
            case (cnt)
                B0: begin
                    pwrite <= mosi_data[7];
                    cmd_err <= |mosi_data[6:4];
                    paddr <= {6'd0, mosi_data[3:0], 2'd0};
                end
                B2: pwdata[31:24] <= mosi_data;
                B3: pwdata[23:16] <= mosi_data;
                B4: pwdata[15:8] <= mosi_data;
                B5: pwdata[7:0] <= mosi_data;
            endcase
        end
    end

    always @(*) begin
        case (cnt)
            B2: miso_data = prdata[31:24];
            B3: miso_data = prdata[23:16];
            B4: miso_data = prdata[15:8];
            B5: miso_data = prdata[7:0];
            B6: miso_data = {6'd0, cmd_err, pslverr_r};
            default: miso_data = 0;
        endcase
    end
endmodule