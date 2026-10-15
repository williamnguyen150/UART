module find_max_baud (
    input num_stop_bit, parity_en, baud_mode,
    input [1:0] num_data_bit,
    output [3:0] max_baud
);
    assign max_baud = baud_mode ? num_stop_bit : (num_data_bit + parity_en + 3'd4);

endmodule