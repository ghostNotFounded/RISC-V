current_design cpu

set clk_name clk
set clk_port clk
set clk_period 15.0

create_clock -name $clk_name -period $clk_period [get_ports $clk_port]
set_clock_uncertainty 0.25 [get_clocks $clk_name]
set_clock_transition 0.15 [get_clocks $clk_name]

set_input_delay -max 3.0 -clock $clk_name [all_inputs -no_clocks]
set_output_delay -max 3.0 -clock $clk_name [all_outputs]
