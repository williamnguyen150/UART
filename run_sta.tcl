read_liberty /home/icy/OpenSTA/test/sky130hd/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog /home/icy/Downloads/UART_2/uart_apb_top_netlist.v
link_design uart_apb_top
read_sdc /home/icy/Downloads/UART_2/constraints.sdc

# Check for unconstrained paths or missing clock definitions
check_setup -verbose

# Report worst Setup (max) and Hold (min) timing paths
report_checks -path_delay max -fields {slew cap input_pins} -digits 3
report_checks -path_delay min -fields {slew cap input_pins} -digits 3

# Print summary slack metrics
report_worst_slack -max
report_worst_slack -min
report_tns
report_wns
exit
