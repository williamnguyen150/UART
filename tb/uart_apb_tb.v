`timescale 1ns/1ps
// Self-checking testbench for uart_apb_top (TX looped back into RX)
module uart_apb_tb;

    // Register addresses
    localparam A_CONFIG  = 6'd0, A_TXDATA = 6'd1, A_RXDATA  = 6'd2,
               A_STATUS  = 6'd3, A_IRQEN  = 6'd4, A_IRQSTAT = 6'd5;

    localparam BAUDDIV = 14'd15;   // small divider for fast simulation

    reg         clk = 0, rst_n = 0;
    reg         pselect = 0, penable = 0, pwrite = 0;
    reg  [5:0]  paddr = 0;
    reg  [3:0]  pstrb = 0;
    reg  [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire        pslverr, pready, pirq;
    wire        tx;
    wire        rx = tx;           // loopback

    integer errors = 0;
    integer checks = 0;

    uart_apb_top dut (
        .clk(clk), .rst_n(rst_n),
        .pselect(pselect), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
        .prdata(prdata), .pslverr(pslverr), .pready(pready), .pirq(pirq),
        .rx(rx), .tx(tx)
    );

    always #10 clk = ~clk;          // 50 MHz

    // ---------------- APB tasks ----------------
    reg [31:0] rd;
    reg        last_err;

    task apb_write(input [5:0] addr, input [31:0] data, input [3:0] strb);
    begin
        @(posedge clk); #1;
        pselect = 1; penable = 0; pwrite = 1; paddr = addr; pwdata = data; pstrb = strb;
        @(posedge clk); #1;
        penable = 1;
        @(posedge clk);            // access phase sampled at this edge
        last_err = pslverr;
        #1;
        pselect = 0; penable = 0; pwrite = 0;
    end
    endtask

    task apb_read(input [5:0] addr);
    begin
        @(posedge clk); #1;
        pselect = 1; penable = 0; pwrite = 0; paddr = addr; pstrb = 4'h0;
        @(posedge clk); #1;
        penable = 1;
        #1;
        rd = prdata;
        last_err = pslverr;
        @(posedge clk); #1;
        pselect = 0; penable = 0;
    end
    endtask

    task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
        checks = checks + 1;
        if (got !== exp) begin
            errors = errors + 1;
            $display("[FAIL] %0s: got 0x%0h, expected 0x%0h  (t=%0t)", name, got, exp, $time);
        end else
            $display("[ OK ] %0s = 0x%0h", name, got);
    end
    endtask

    // CONFIG word: {2'b0, bauddiv, 3'b0, datalen, stop2, parity_en, parity_type, 6'b0, tx_en, rx_en}
    function [31:0] cfg(input [1:0] datalen, input stop2, input pen, input ptype,
                        input txen, input rxen);
        cfg = {2'b00, BAUDDIV, 3'b000, datalen, stop2, pen, ptype, 6'b0, txen, rxen};
    endfunction

    task configure(input [1:0] datalen, input stop2, input pen, input ptype);
    begin
        apb_write(A_CONFIG, 32'd0, 4'b0001);                 // disable TX/RX first
        apb_write(A_CONFIG, cfg(datalen, stop2, pen, ptype, 1'b0, 1'b0), 4'b1111);
        apb_write(A_CONFIG, cfg(datalen, stop2, pen, ptype, 1'b1, 1'b1), 4'b0001);
    end
    endtask

    // Send one byte through TX and read it back from RX FIFO
    task send_and_check(input [7:0] data, input [1:0] datalen, input pen, input ptype);
        integer timeout;
        reg [7:0] mask, exp_data;
    begin
        mask     = 8'hFF >> (3 - datalen);
        exp_data = data & mask;
        apb_write(A_TXDATA, {24'd0, data}, 4'b0001);

        // wait until RX FIFO not empty (STATUS bit0 = RX_EMPTY)
        timeout = 0;
        rd = 32'h1;
        while (rd[0] && timeout < 5000) begin
            apb_read(A_STATUS);
            timeout = timeout + 1;
        end
        if (timeout >= 5000) begin
            errors = errors + 1; checks = checks + 1;
            $display("[FAIL] timeout waiting for RX of 0x%0h", data);
        end else begin
            apb_read(A_RXDATA);          // {.., data[9:2], parity_err[1], frame_err[0]}
            check("rx_data  ", rd[9:2], exp_data);
            check("par_err  ", rd[1],   1'b0);
            check("frame_err", rd[0],   1'b0);
            // popping happens on read; make sure FIFO drained
            apb_read(A_STATUS);
            check("rx_empty ", rd[0],   1'b1);
        end
    end
    endtask

    // ---------------- Stimulus ----------------
	initial begin
 	   $dumpfile("uart_apb_tb.vcd");
 	   $dumpvars(0, uart_apb_tb); 


        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // ---- 1. Register reset values / readback ----
        $display("\n--- Test 1: register access ---");
        apb_read(A_CONFIG);  check("CONFIG reset", rd, 32'd0);
        apb_read(A_STATUS);  check("STATUS reset", rd[4:0], 5'b00101); // TX_EMPTY, RX_EMPTY
        apb_write(A_IRQEN, 32'd1, 4'b0001);
        apb_read(A_IRQEN);   check("IRQEN rb   ", rd, 32'd1);
        apb_write(A_IRQEN, 32'd0, 4'b0001);

        // invalid address -> slave error
        apb_read(6'd40);     check("PSLVERR bad addr", last_err, 1'b1);
        apb_write(A_RXDATA, 32'd0, 4'b0001); check("PSLVERR write RO", last_err, 1'b1);

        // ---- 2. 8N1 loopback ----
        $display("\n--- Test 2: 8N1 ---");
        configure(2'd3, 1'b0, 1'b0, 1'b0);
        apb_read(A_CONFIG);
        check("CONFIG rb  ", rd, cfg(2'd3, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1));
        send_and_check(8'h55, 2'd3, 1'b0, 1'b0);
        send_and_check(8'hA3, 2'd3, 1'b0, 1'b0);
        send_and_check(8'hFF, 2'd3, 1'b0, 1'b0);
        send_and_check(8'h00, 2'd3, 1'b0, 1'b0);

        // ---- 3. 8E1 ----
        $display("\n--- Test 3: 8E1 ---");
        configure(2'd3, 1'b0, 1'b1, 1'b0);
        send_and_check(8'h5A, 2'd3, 1'b1, 1'b0);
        send_and_check(8'hC7, 2'd3, 1'b1, 1'b0);

        // ---- 4. 8O1 ----
        $display("\n--- Test 4: 8O1 ---");
        configure(2'd3, 1'b0, 1'b1, 1'b1);
        send_and_check(8'h3C, 2'd3, 1'b1, 1'b1);
        send_and_check(8'h81, 2'd3, 1'b1, 1'b1);

        // ---- 5. 8N2 ----
        $display("\n--- Test 5: 8N2 ---");
        configure(2'd3, 1'b1, 1'b0, 1'b0);
        send_and_check(8'hB4, 2'd3, 1'b0, 1'b0);

        // ---- 6. 7N1 ----
        $display("\n--- Test 6: 7N1 ---");
        configure(2'd2, 1'b0, 1'b0, 1'b0);
        send_and_check(8'h5B, 2'd2, 1'b0, 1'b0);

        // ---- 7. back-to-back via TX FIFO ----
        $display("\n--- Test 7: back-to-back (8N1) ---");
        configure(2'd3, 1'b0, 1'b0, 1'b0);
        apb_write(A_TXDATA, 32'h11, 4'b0001);
        apb_write(A_TXDATA, 32'h22, 4'b0001);
        apb_write(A_TXDATA, 32'h33, 4'b0001);
        begin : wait3
            integer i;
            for (i = 0; i < 3000; i = i + 1) @(posedge clk);
        end
        apb_read(A_RXDATA); check("burst[0]", rd[9:2], 8'h11);
        apb_read(A_RXDATA); check("burst[1]", rd[9:2], 8'h22);
        apb_read(A_RXDATA); check("burst[2]", rd[9:2], 8'h33);

        // ---- 8. TX overrun interrupt ----
        $display("\n--- Test 8: TX FIFO overrun / IRQ ---");
        apb_write(A_IRQEN, 32'd1, 4'b0001);
        repeat (8) apb_write(A_TXDATA, 32'hEE, 4'b0001);  // more than FIFO depth
        apb_read(A_IRQSTAT); check("TX_OVERRUN set", rd[2], 1'b1);
        check("pirq", pirq, 1'b1);
        apb_write(A_IRQSTAT, 32'h4, 4'b0001);             // clear bit2
        apb_read(A_IRQSTAT); check("TX_OVERRUN clr", rd[2], 1'b0);

        repeat (20) @(posedge clk);
        $display("\n==== %0d checks, %0d errors ====", checks, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED");
        $finish;
    end

    // watchdog
    initial begin
        #50_000_000;
        $display("[FAIL] global timeout");
        $finish;
    end

endmodule
