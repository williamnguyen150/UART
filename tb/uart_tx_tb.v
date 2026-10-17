`timescale 1ns/1ps
// Self-checking testbench for uart_tx (top module).
// Sends the symbol 'U' (0x55) with 8N1, 8N2, 7E1, 8E1, 8O1 and checks the
// serial line cycle-by-cycle against the expected frame.
//
// NOTE: in this design a bit lasts (baud_div + 1) clocks, so the testbench
// drives baud_div = BIT_CLKS - 1 to get BIT_CLKS clocks per bit.
module uart_tx_tb;
    parameter       BIT_CLKS  = 16;     // clock cycles per UART bit
    parameter [7:0] SYMBOL    = 8'h55;  // 'U'

    reg clk = 0;
    always #5 clk = ~clk;

    reg         rst_n        = 0;
    reg  [15:0] baud_div     = BIT_CLKS - 1;
    reg         parity_en    = 0;
    reg         parity_type  = 0;      // 0 = even, 1 = odd
    reg  [1:0]  num_data_bit = 2'b11;  // 00=5, 01=6, 10=7, 11=8
    reg         num_stop_bit = 1'd0;   // 0 = 1 stop bit
    reg         tx_start     = 0;
    reg  [7:0]  tx_data      = 8'hFF;
    wire        tx_done, tx;

    uart_tx dut (
        .clk(clk), .rst_n(rst_n), .baud_div(baud_div), .parity_en(parity_en),
        .num_data_bit(num_data_bit), .num_stop_bit(num_stop_bit),
        .tx_start(tx_start), .tx_data(tx_data), .parity_type(parity_type),
        .tx_done(tx_done), .tx(tx)
    );

    integer cfg_errors;
    integer total_fail = 0;

    // Check that tx holds 'exp' for one whole bit time (every clock).
    // done_mode: 0 = tx_done must stay low, 1 = tx_done must be high in the last
    //            clock of this bit, 2 = don't care.
    // Enters on the first clock of the bit, leaves on the first clock of the next.
    task chk_bit(input exp, input integer done_mode, input [8*8-1:0] what);
        integer j;
        begin
            for (j = 0; j < BIT_CLKS; j = j + 1) begin
                if (tx !== exp) begin
                    cfg_errors = cfg_errors + 1;
                    if (cfg_errors <= 6)
                        $display("    ERROR t=%0t %0s: tx=%b expected %b (clk %0d of bit)", $time, what, tx, exp, j);
                end
                if (done_mode == 0 && tx_done !== 1'b0) begin
                    cfg_errors = cfg_errors + 1;
                    if (cfg_errors <= 6) $display("    ERROR t=%0t %0s: tx_done high too early", $time, what);
                end
                if (done_mode == 1 && j == BIT_CLKS-1 && tx_done !== 1'b1) begin
                    cfg_errors = cfg_errors + 1;
                    if (cfg_errors <= 6) $display("    ERROR t=%0t %0s: tx_done not high at end of frame", $time, what);
                end
                @(negedge clk);
            end
        end
    endtask

    task run_cfg(input [8*6-1:0] name, input [1:0] ndb, input pen, input ptype,
                 input [3:0] nsb, input [7:0] data);
        integer nbits, k, i, wait_cnt;
        reg [7:0] mask;
        reg       par;
        begin
            nbits      = ndb + 5;
            mask       = 8'hFF >> (8 - nbits);
            par        = (^(data & mask)) ^ ptype;
            cfg_errors = 0;

            @(negedge clk);
            num_data_bit = ndb; parity_en = pen; parity_type = ptype;
            num_stop_bit = nsb; tx_data = data;
            repeat (4) @(negedge clk);

            if (tx !== 1'b1) begin
                cfg_errors = cfg_errors + 1;
                $display("    ERROR: line not idle-high before start");
            end

            tx_start = 1;
            @(negedge clk);
            tx_start = 0;
            wait_cnt = 0;
            while (tx !== 1'b0 && wait_cnt < 4) begin
                @(negedge clk);
                wait_cnt = wait_cnt + 1;
            end
            if (tx !== 1'b0) begin
                cfg_errors = cfg_errors + 1;
                $display("    ERROR: no start bit seen");
            end else begin
                chk_bit(1'b0, 0, "start");
                for (k = 0; k < nbits; k = k + 1) chk_bit(data[k], 0, "data");
                if (pen) chk_bit(par, 0, "parity");
                for (i = 0; i <= nsb; i = i + 1)
                    chk_bit(1'b1, (i == nsb) ? 1 : 2, "stop");
                for (i = 0; i < 2*BIT_CLKS; i = i + 1) begin
                    if (tx !== 1'b1 || tx_done !== 1'b0) begin
                        cfg_errors = cfg_errors + 1;
                        if (cfg_errors <= 6) $display("    ERROR: line/tx_done not idle after frame");
                    end
                    @(negedge clk);
                end
            end

            if (cfg_errors == 0) $display("PASS  %0s  data=0x%02h", name, data);
            else begin
                $display("FAIL  %0s  data=0x%02h  (%0d mismatching clocks)", name, data, cfg_errors);
                total_fail = total_fail + 1;
            end
        end
    endtask

    initial begin
        #(10 * BIT_CLKS * 2000);
        $display("TIMEOUT"); $finish;
    end

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);

        //(name,num_data_bit,parity_en,parity_type,num_stop_bit)
        run_cfg("8N1",  2'b11, 0,  0,    0,  SYMBOL);
        run_cfg("8N2",  2'b11, 0,  0,    1,  SYMBOL);
        run_cfg("7E1",  2'b10, 1,  0,    0,  SYMBOL);
        run_cfg("8E1",  2'b11, 1,  0,    0,  SYMBOL);
        run_cfg("8O1",  2'b11, 1,  1,    0,  SYMBOL);


        if (total_fail == 0) $display("ALL TESTS PASSED");
        else                 $display("%0d TEST(S) FAILED", total_fail);
        $finish;
    end
endmodule
