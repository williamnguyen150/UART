module hw_uart_rx #(
    parameter CLK_FREQ      = 50_000_000, // 50m clock
    parameter BAUD_RATE     = 115200,     // baud rate
    parameter EXPECTED_CHAR = 8'b01010101 // ASCII for 'U' 
)(
    input  wire clk,
//    input  wire rst_n,
    input  wire rx,             
    
    output reg        correct_led,  // Active-low
    output wire       rx_done,      // Active-low
    output wire       frame_error,  // Active-low
    output wire       parity_error, // Active-low
    output reg  [7:0] debug_leds    // Active-high
);
	wire rst_n = 1'b1;
    localparam [13:0] BAUD_DIV_VAL = CLK_FREQ / BAUD_RATE;
    
    // --- 1. INTERNAL WIRES ---
    wire       rx_done_internal;
    wire       frame_error_internal;
    wire       parity_error_internal;
    wire [7:0] rx_data_internal; 

    uart_rx uart_rx_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx_en       (1'b1),           
        .parity_en   (1'b0),           
        .parity_type (1'b0),           
        .num_data_bit(2'b11),          
        .num_stop_bit(1'b0),           
        .baud_div    (BAUD_DIV_VAL),   
        .rx          (rx),             
        
        .rx_data     (rx_data_internal), 
        .rx_done     (rx_done_internal),          
        .frame_error (frame_error_internal),      
        .parity_error(parity_error_internal)      
    );

    assign rx_done      = ~rx_done_internal;
    assign frame_error  = ~frame_error_internal;
    assign parity_error = ~parity_error_internal;

    reg [25:0] timer_cnt;         
    reg [7:0]  latest_valid_data; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            correct_led       <= 1'b1;  // 1 = OFF (active-low)
            debug_leds        <= 8'h00; // 0 = OFF (active-high)
            timer_cnt         <= 26'd0;
            latest_valid_data <= 8'h00;
        end 
        else begin
            if (rx_done_internal) begin
                latest_valid_data <= rx_data_internal;
                
                if ((rx_data_internal == EXPECTED_CHAR) && !frame_error_internal && !parity_error_internal) begin
                    correct_led <= 1'b0; // Match found, lock LED ON (0)
                end
            end

            // 2. Timer: Update the physical LEDs once per second
            if (timer_cnt == (CLK_FREQ - 1)) begin
                timer_cnt <= 26'd0;
                // Pass data directly without inversion for active-high LEDs
                debug_leds <= latest_valid_data; 
            end else begin
                timer_cnt <= timer_cnt + 1;
            end
        end
    end

endmodule