# Define primary clock on port 'clk' (20.0 ns = 50 MHz)
create_clock -name clk -period 20.0 [get_ports clk]

# Constrain all non-clock input ports and all output ports
set_input_delay 2.0 -clock clk [get_ports {rst_n pselect penable pwrite paddr[*] pstrb[*] pwdata[*] rx cts_n}]
set_output_delay 2.0 -clock clk [all_outputs]
