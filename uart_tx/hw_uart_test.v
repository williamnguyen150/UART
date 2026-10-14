
module hw_uart_test #(
    parameter CLK_FREQ  = 50_000_000, 
    parameter BAUD_RATE = 115200      
)(
    input  wire clk,
    //input  wire rst_n,
    output wire tx,
    output wire led                 
);


    localparam [15:0] BAUD_DIV = CLK_FREQ / BAUD_RATE;

    localparam [7:0] ASCII_CHAR = 8'h41; 
    
    reg  tx_start;
    wire tx_done;
    wire rst_n = 1'b1;
    localparam TIMER_MAX = CLK_FREQ / 2;
    reg [$clog2(TIMER_MAX)-1:0] timer;
    reg led_state;
    
    assign led = led_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer     <= 0;
            tx_start  <= 1'b0;
            led_state <= 1'b0;
        end else begin
            tx_start <= 1'b0; 
            
            if (timer == TIMER_MAX - 1) begin
                timer     <= 0;
                led_state <= ~led_state; 
                tx_start  <= 1'b1;       
            end else begin
                timer <= timer + 1;
            end
        end
    end

    uart_tx u_uart_tx (
        .clk          (clk),
        .rst_n        (rst_n),
        
        .baud_div     (BAUD_DIV),
        .parity_en    (1'b0),         
        .num_data_bit (2'd11),         
        .num_stop_bit (4'd0),         
        .parity_type  (1'b0),         
        
        .tx_start     (tx_start),
        .tx_data      (ASCII_CHAR),
        .tx_done      (tx_done),
        .tx           (tx)
    );

endmodule