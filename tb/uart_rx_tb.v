`timescale 1ns/1ps
// Self-checking testbench for uart_rx (top module), 8-bit data configs:
// 8N1, 8N2, 8E1, 8O1, plus data patterns, error flags,
// baud-rate tolerance and back-to-back frames.

module uart_rx_tb;
    parameter BIT_CLKS = 32;                 // clocks per bit used by the DUT (baud_div)

    reg clk = 0;
    always #5 clk = ~clk;

    reg         rst_n        = 0;
    reg         rx_en        = 1;
    reg         parity_en    = 0;
    reg         parity_type  = 0;            // 0 = even, 1 = odd
    reg  [1:0]  num_data_bit = 2'b11;        // 00=5 01=6 10=7 11=8
    reg  [1:0]  cur_ndb      = 2'b11;        // data-bit config used by the tasks
    reg         num_stop_bit = 1'b0;         // 0 = 1 stop bit, 1 = 2 stop bits
    reg  [13:0] baud_div     = BIT_CLKS;
    reg         rx           = 1;
    wire [7:0]  rx_data;
    wire        rx_done, frame_error, parity_error;

    uart_rx dut (
        .clk(clk), .rst_n(rst_n), .rx_en(rx_en), .parity_en(parity_en),
        .parity_type(parity_type), .num_data_bit(num_data_bit),
        .num_stop_bit(num_stop_bit), .baud_div(baud_div), .rx(rx),
        .rx_data(rx_data), .rx_done(rx_done),
        .frame_error(frame_error), .parity_error(parity_error)
    );

    integer     done_cnt = 0;
    reg [7:0]   rec_data [0:15];
    reg         rec_fe   [0:15];
    reg         rec_pe   [0:15];  
    reg         pe_after;          
    reg [2:0]   post = 0;

    always @(posedge clk) begin
        if (rx_done) begin
            rec_data[done_cnt] <= rx_data;
            rec_fe[done_cnt]   <= frame_error;
            rec_pe[done_cnt]   <= parity_error;
            done_cnt           <= done_cnt + 1;
            post               <= 3'd4;
        end else if (post != 0) begin
            post <= post - 1;
            if (parity_error) pe_after <= 1'b1;
        end
    end

    task put_bit(input b, input integer n);   /
        begin rx = b; repeat (n) @(negedge clk); end
    endtask

    task send_frame(input [7:0] data, input pen, input ptype, input nstop,
                    input badstop, input badpar, input integer bitclk);
        integer k, nb;
        reg [7:0] d;
        begin
            nb = cur_ndb + 5;
            d  = data & (8'hFF >> (8 - nb));                        // only nb bits are sent
            put_bit(1'b0, bitclk);                                  // start
            for (k = 0; k < nb; k = k + 1) put_bit(d[k], bitclk);
            if (pen) put_bit((^d) ^ ptype ^ badpar, bitclk);        // parity
            put_bit(badstop ? 1'b0 : 1'b1, bitclk);                 // stop 1
            if (nstop) put_bit(badstop ? 1'b0 : 1'b1, bitclk);      // stop 2
            rx = 1'b1;
        end
    endtask

    task configure(input pen, input ptype, input nstop);
        begin
            @(negedge clk);
            parity_en = pen; parity_type = ptype; num_stop_bit = nstop;
            num_data_bit = cur_ndb; baud_div = BIT_CLKS;
            rx = 1'b1;
            repeat (4) @(negedge clk);
            done_cnt = 0; pe_after = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    integer total_fail = 0;
    integer errs;

    task report(input [8*24-1:0] name);
        begin
            if (errs == 0) $display("PASS  %0s", name);
            else begin $display("FAIL  %0s", name); total_fail = total_fail + 1; end
        end
    endtask

    task run_case(input [8*24-1:0] name, input [7:0] data, input pen, input ptype,
                  input nstop, input badstop, input badpar, input integer bitclk);
        reg [7:0] exp, got;
        begin
            errs = 0;
            exp = data & (8'hFF >> (8 - (cur_ndb + 5)));
            configure(pen, ptype, nstop);
            send_frame(data, pen, ptype, nstop, badstop, badpar, bitclk);
            repeat (3*BIT_CLKS) @(negedge clk);

            if (done_cnt !== 1) begin
                errs = errs + 1; $display("    ERROR: rx_done pulses = %0d (expected 1)", done_cnt);
            end else begin
                // APB model: right-align, unused bits = 0
                got = rec_data[0] >> (8 - (cur_ndb + 5));
                if (got !== exp) begin
                    errs = errs + 1; $display("    ERROR: rx_data = 0x%02h (raw 0x%02h) expected 0x%02h", got, rec_data[0], exp);
                end
                if (rec_fe[0] !== badstop) begin
                    errs = errs + 1; $display("    ERROR: frame_error = %b expected %b (at rx_done)", rec_fe[0], badstop);
                end
                if (rec_pe[0] !== (pen & badpar)) begin
                    errs = errs + 1;
                    $display("    ERROR: parity_error = %b expected %b (at rx_done)%0s",
                             rec_pe[0], pen & badpar, (pe_after && (pen & badpar)) ? " - flag only rises AFTER rx_done" : "");
                end
            end
            report(name);
        end
    endtask

    integer i;
    reg [7:0] pat [0:5];

    initial begin
        #(10 * BIT_CLKS * 20000);
        $display("TIMEOUT"); $finish;
    end

    initial begin
        pat[0]=8'h00; pat[1]=8'hFF; pat[2]=8'h01; pat[3]=8'h80; pat[4]=8'hA3; pat[5]=8'h5A;

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (5) @(negedge clk);

        $display("--- configs, symbol 'U' ---");
        //       name     data  pen ptype nstop badstop badpar bitclk
        run_case("8N1",   8'h55, 0,  0,    0,    0,      0,     BIT_CLKS);
        run_case("8N2",   8'h55, 0,  0,    1,    0,      0,     BIT_CLKS);
        run_case("8E1",   8'h55, 1,  0,    0,    0,      0,     BIT_CLKS);
        run_case("8O1",   8'h55, 1,  1,    0,    0,      0,     BIT_CLKS);

        $display("--- data patterns (8N1, 8E1, 8O1) ---");
        for (i = 0; i < 6; i = i + 1) begin
            run_case("8N1 pattern", pat[i], 0, 0, 0, 0, 0, BIT_CLKS);
            run_case("8E1 pattern", pat[i], 1, 0, 0, 0, 0, BIT_CLKS);
            run_case("8O1 pattern", pat[i], 1, 1, 0, 0, 0, BIT_CLKS);
        end

        $display("--- 7 data bits (unused bit forced to 0) ---");
        cur_ndb = 2'b10;
        run_case("7N1",   8'h55, 0,  0,    0,    0,      0,     BIT_CLKS);
        run_case("7N2",   8'h55, 0,  0,    1,    0,      0,     BIT_CLKS);
        run_case("7E1",   8'h55, 1,  0,    0,    0,      0,     BIT_CLKS);
        run_case("7O1",   8'h55, 1,  1,    0,    0,      0,     BIT_CLKS);
        for (i = 0; i < 6; i = i + 1) begin
            run_case("7N1 pattern", pat[i], 0, 0, 0, 0, 0, BIT_CLKS);
            run_case("7E1 pattern", pat[i], 1, 0, 0, 0, 0, BIT_CLKS);
        end
        run_case("7N1 bad stop",   8'h55, 0, 0, 0, 1, 0, BIT_CLKS);
        run_case("7E1 bad parity", 8'h55, 1, 0, 0, 0, 1, BIT_CLKS);
        cur_ndb = 2'b11;

        $display("--- error flags ---");
        run_case("8N1 bad stop",    8'h55, 0, 0, 0, 1, 0, BIT_CLKS);
        run_case("8N2 bad stop",    8'h55, 0, 0, 1, 1, 0, BIT_CLKS);
        run_case("8E1 bad parity",  8'h55, 1, 0, 0, 0, 1, BIT_CLKS);
        run_case("8O1 bad parity",  8'h55, 1, 1, 0, 0, 1, BIT_CLKS);
        run_case("8E1 bad parity A3", 8'hA3, 1, 0, 0, 0, 1, BIT_CLKS);

        $display("--- baud tolerance (TX bit length +-4 percent) ---");
        run_case("8N1 TX slow +4%", 8'h55, 0, 0, 0, 0, 0, BIT_CLKS + 1);
        run_case("8N1 TX fast -4%", 8'h55, 0, 0, 0, 0, 0, BIT_CLKS - 1);
        run_case("8E1 TX slow +4%", 8'hA3, 1, 0, 0, 0, 0, BIT_CLKS + 1);
        run_case("8E1 TX fast -4%", 8'hA3, 1, 0, 0, 0, 0, BIT_CLKS - 1);

        $display("--- glitch rejection (short low pulse on idle line) ---");
        errs = 0;
        configure(0, 0, 0);
        put_bit(1'b0, BIT_CLKS/4);
        put_bit(1'b1, 6*BIT_CLKS);
        if (done_cnt !== 0) begin errs = errs + 1; $display("    ERROR: glitch produced %0d rx_done", done_cnt); end
        report("glitch ignored");
        // and a valid frame still works afterwards
        run_case("8N1 after glitch", 8'h55, 0, 0, 0, 0, 0, BIT_CLKS);

        $display("--- rx_en low blocks reception ---");
        errs = 0;
        configure(0, 0, 0);
        rx_en = 0;
        send_frame(8'h55, 0, 0, 0, 0, 0, BIT_CLKS);
        repeat (3*BIT_CLKS) @(negedge clk);
        if (done_cnt !== 0) begin errs = errs + 1; $display("    ERROR: rx_done while rx_en=0"); end
        rx_en = 1;
        report("rx_en=0 ignored");

        if (total_fail == 0) $display("ALL TESTS PASSED");
        else                 $display("%0d TEST(S) FAILED", total_fail);
        $finish;
    end
endmodule
