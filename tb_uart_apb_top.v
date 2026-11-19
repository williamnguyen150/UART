`timescale 1ns/1ps
// Testbench uart_apb_top theo ban do thanh ghi moi (apb_regs: TXDATA..IER), loopback tx -> rx
module tb_uart_apb_top;
    // chi so thanh ghi (paddr[5:0] = chi so, khop apb_regs.v)
    localparam A_TXDATA = 6'd0, A_RXDATA = 6'd1, A_CONFIG = 6'd2, A_CTRL = 6'd3,
               A_STATUS = 6'd4, A_BAUD = 6'd5, A_IER = 6'd6;
    // STATUS: [0]tx_done [1]rx_done [2]parity_err [3]rx_busy [4]tx_dis [5]rx_dis [6]frame_err [7]overrun
    localparam [15:0] BAUD_SOFT = 16'd434;      // gia tri sau soft_rst
    localparam integer CLK_NS = 10;
    localparam integer BIT_CLKS = 435;          // baud_div + 1

    reg clk = 0, rst_n = 0;
    reg pselect = 0, penable = 0, pwrite = 0;
    reg [5:0] paddr = 0; reg [3:0] pstrb = 0; reg [31:0] pwdata = 0;
    wire [31:0] prdata; wire pslverr, pready, pirq, tx, rts_n;
    reg cts_n = 0, force_en = 0, force_rx = 1;
    wire rx = force_en ? force_rx : tx;
    integer errors = 0, checks = 0;

    uart_apb_top dut (.clk(clk), .rst_n(rst_n), .pselect(pselect), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata), .prdata(prdata),
        .pslverr(pslverr), .pready(pready), .pirq(pirq), .rx(rx), .cts_n(cts_n),
        .tx(tx), .rts_n(rts_n));
    always #(CLK_NS/2) clk = ~clk;

    reg [31:0] rd; reg last_err;
    task apb_write(input [5:0] a, input [31:0] d, input [3:0] s);
    begin
        @(posedge clk); #1; pselect=1; penable=0; pwrite=1; paddr=a; pwdata=d; pstrb=s;
        @(posedge clk); #1; penable=1;
        @(posedge clk); last_err = pslverr; #1; pselect=0; penable=0; pwrite=0;
    end endtask
    task apb_read(input [5:0] a);
    begin
        @(posedge clk); #1; pselect=1; penable=0; pwrite=0; paddr=a; pstrb=4'h0;
        @(posedge clk); #1; penable=1; #1; rd = prdata; last_err = pslverr;
        @(posedge clk); #1; pselect=0; penable=0;
    end endtask
    task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
        checks = checks + 1;
        if (got !== exp) begin errors = errors + 1;
            $display("[FAIL] %0s: got 0x%0h, expected 0x%0h  (t=%0t)", name, got, exp, $time); end
        else $display("[ OK ] %0s = 0x%0h", name, got);
    end endtask

    task soft_reset; begin apb_write(A_CTRL, 32'h100, 4'b0010); repeat (4) @(posedge clk); end endtask
    task configure(input [1:0] db, input stop2, input pen, input even);
    begin apb_write(A_CONFIG, {25'd0, 1'b0, 1'b0, ~even, pen, stop2, db}, 4'b0001); end endtask
    // doi STATUS & mask == val toi da n lan doc
    task wait_status(input [7:0] mask, input [7:0] val, input integer n, output integer ok);
        integer i;
    begin ok = 0; for (i = 0; i < n && !ok; i = i + 1) begin apb_read(A_STATUS); if ((rd[7:0] & mask) == val) ok = 1; end end endtask

    task send_and_check(input [7:0] data, input [1:0] db, input pen);
        integer ok; reg [7:0] exp_d;
    begin
        exp_d = data & (8'hFF >> (3 - db));
        apb_write(A_TXDATA, {24'd0, data}, 4'b0001);
        apb_write(A_CTRL, 32'h1, 4'b0001);                 // start_tx
        wait_status(8'h02, 8'h02, 3000, ok);                // doi rx_done
        if (!ok) begin errors = errors + 1; checks = checks + 1; $display("[FAIL] timeout RX 0x%0h", data); end
        else begin
            apb_read(A_STATUS);                             // doc va xoa co loi
            check("par_err  ", rd[2], 1'b0); check("frame_err", rd[6], 1'b0);
            apb_read(A_RXDATA); check("rx_data  ", rd[7:0], exp_d);
            apb_read(A_STATUS); check("rx_done=0", rd[1], 1'b0);
        end
        wait_status(8'h01, 8'h01, 3000, ok);                // doi tx_done = 1 (ranh)
    end endtask

    integer ok, i;
    initial begin
        $dumpfile("tb_uart_apb_top.vcd"); $dumpvars(0, tb_uart_apb_top);
        repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);

        $display("\n--- T1: gia tri reset va doc/ghi thanh ghi ---");
        apb_read(A_STATUS); check("STATUS reset", rd[7:0], 8'h01);
        apb_read(A_CONFIG); check("CONFIG reset", rd, 32'd0);
        apb_read(A_BAUD);   check("BAUD reset (spec 0x900D)", rd[15:0], 16'h900D);
        apb_write(A_IER, 32'h7, 4'b0001); apb_read(A_IER); check("IER rb", rd, 32'h7);
        apb_write(A_IER, 32'h0, 4'b0001);
        apb_read(6'd9);  check("PSLVERR doc dia chi ngoai", last_err, 1'b1);
        apb_write(A_RXDATA, 32'd0, 4'b0001); check("PSLVERR ghi RXDATA (RO)", last_err, 1'b1);
        apb_write(A_STATUS, 32'd0, 4'b0001); check("PSLVERR ghi STATUS (RO)", last_err, 1'b1);

        $display("\n--- T2: ghi BAUD (div_int != 0 phai ghi duoc) ---");
        apb_write(A_BAUD, 32'd15, 4'b0011); check("PSLVERR ghi BAUD=15", last_err, 1'b0);
        apb_read(A_BAUD); check("BAUD readback", rd[15:0], 16'd15);

        soft_reset;
        apb_read(A_BAUD); check("BAUD sau soft_rst", rd[15:0], BAUD_SOFT);

        $display("\n--- T3: loopback 8N1 ---");
        configure(2'd3, 0, 0, 1); apb_read(A_CONFIG); check("CONFIG rb", rd, 32'h03);
        send_and_check(8'h55, 2'd3, 0);
        send_and_check(8'hA3, 2'd3, 0);
        send_and_check(8'hFF, 2'd3, 0);
        send_and_check(8'h00, 2'd3, 0);
        $display("\n--- T4: 8E1 / 8O1 ---");
        configure(2'd3, 0, 1, 1); send_and_check(8'h5A, 2'd3, 1); send_and_check(8'hC7, 2'd3, 1);
        configure(2'd3, 0, 1, 0); send_and_check(8'h3C, 2'd3, 1); send_and_check(8'h81, 2'd3, 1);
        $display("\n--- T5: 8N2 va 7N1 ---");
        configure(2'd3, 1, 0, 0); send_and_check(8'hB4, 2'd3, 0);
        configure(2'd2, 0, 0, 0); send_and_check(8'h5B, 2'd2, 0);
        configure(2'd3, 0, 0, 0);

        $display("\n--- T6: loi APB khi dang ban (E3/E4) ---");
        apb_write(A_TXDATA, 32'h42, 4'b0001); apb_write(A_CTRL, 32'h1, 4'b0001);
        repeat (6) @(posedge clk);
        apb_write(A_TXDATA, 32'h99, 4'b0001); check("PSLVERR ghi TXDATA khi dang phat", last_err, 1'b1);
        apb_write(A_CONFIG, 32'h0, 4'b0001);  check("PSLVERR ghi CONFIG khi dang phat", last_err, 1'b1);
        wait_status(8'h02, 8'h02, 3000, ok); apb_read(A_RXDATA); check("rx 0x42", rd[7:0], 8'h42);
        wait_status(8'h01, 8'h01, 3000, ok);

        $display("\n--- T7: cts_n chan phat ---");
        cts_n = 1; apb_write(A_TXDATA, 32'h77, 4'b0001); apb_write(A_CTRL, 32'h1, 4'b0001);
        repeat (BIT_CLKS * 12) @(posedge clk);
        check("tx giu o 1 khi cts_n=1", tx, 1'b1);
        apb_read(A_STATUS); check("tx_done=0 khi cho cts", rd[0], 1'b0);
        cts_n = 0;
        wait_status(8'h02, 8'h02, 3000, ok); apb_read(A_RXDATA); check("rx 0x77 sau cts_n=0", rd[7:0], 8'h77);
        wait_status(8'h01, 8'h01, 3000, ok);

        $display("\n--- T8: ngat (soft_rst truoc de khoi anh huong boi treo cts_n o T7) ---");
        soft_reset; configure(2'd3, 0, 0, 1);
        apb_write(A_IER, 32'h1, 4'b0001); #20; check("pirq tx_done_ie (tx_done=1)", pirq, 1'b1);
        apb_write(A_IER, 32'h0, 4'b0001); #20; check("pirq tat IER", pirq, 1'b0);
        apb_write(A_IER, 32'h2, 4'b0001);
        apb_write(A_TXDATA, 32'h31, 4'b0001); apb_write(A_CTRL, 32'h1, 4'b0001);
        wait_status(8'h02, 8'h02, 3000, ok); #20; check("pirq rx_done_ie", pirq, 1'b1);
        apb_read(A_RXDATA); #20; check("pirq ha sau doc RXDATA", pirq, 1'b0);
        apb_write(A_IER, 32'h0, 4'b0001);
        wait_status(8'h01, 8'h01, 3000, ok);

        $display("\n--- T9: xung nhieu 0,3 bit khong duoc tao khung ---");
        force_en = 1; force_rx = 1; #(5*CLK_NS);
        force_rx = 0; #(0.3 * BIT_CLKS * CLK_NS); force_rx = 1; #(14.0 * BIT_CLKS * CLK_NS);
        apb_read(A_STATUS); check("rx_done sau nhieu", rd[1], 1'b0); check("rx_busy sau nhieu", rd[3], 1'b0);
        force_en = 0;

        repeat (20) @(posedge clk);
        $display("\n==== %0d checks, %0d errors ====", checks, errors);
        if (errors == 0) $display("ALL TESTS PASSED"); else $display("TESTS FAILED");
        $finish;
    end
    initial begin #200_000_000; $display("[FAIL] global timeout"); $finish; end
endmodule
