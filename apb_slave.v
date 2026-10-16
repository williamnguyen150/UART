module apb_slave (
    input clk, 
    input rst_n, 

    // apb_master com
    input             pselect, 
    input             penable, 
    input             pwrite, 
    input      [5:0]  paddr, 
    input      [3:0]  pstrb, 
    input      [31:0] pwdata, 

    output reg [31:0] prdata, 
    output reg        pslverr, 
    output reg        pready, 
    output            pirq, 

    // apb_regs com
    input      [31:0] r_data, 
    input             write_en, 
    input             read_en, 
    input             interrupt, 

    output reg        access, 
    output reg        write, 
    output reg [5:0]  addr, 
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

    always @(state or pselect or penable or pwrite or paddr or pstrb or pwdata 
                                or r_data or write_en or read_en) begin
        access = 1'd0;
        write = 1'd0;
        addr = 6'd0;
        strb = 4'd0;
        w_data = 32'd0;
        prdata = 32'd0;
        pslverr = 1'd0;
        pready = 1'd0;
        case (state)
            IDLE: begin
                write = 1'd0;
                prdata = 32'd0;
                pslverr = 1'd0;
                pready = 1'd0;
            end
            SETUP: begin
                access = pselect & penable;
                write = pwrite;
                addr = paddr;
                strb = pstrb;
                w_data = pwdata;
                prdata = (pselect & ~pwrite) ? r_data : 32'd0;
                pready = 1'd1;
                pslverr = pselect & penable & (pwrite ? ~write_en : ~read_en);
            end
        endcase
    end

    assign pirq = interrupt;
endmodule

