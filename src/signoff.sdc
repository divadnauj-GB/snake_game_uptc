read_sdc $::env(SCRIPTS_DIR)/base.sdc


set_clock_uncertainty 0.2 [get_clocks $::env(CLOCK_PORT)]

# Fix reset delay
set_input_delay 1.5 -clock [get_clocks $::env(CLOCK_PORT)] {rst_n}

# Longer delays for input IOs as we expect to drive them on clock falling edge
# Note "setup" is actually 1 clock cycle minus setup, so this requires a setup
# period of 35% of the clock cycle
set input_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.65]
set input_hold_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]
set_input_delay -clock [get_clocks $::env(CLOCK_PORT)] -max $input_setup_delay_value {uio_in ui_in}
set_input_delay -clock [get_clocks $::env(CLOCK_PORT)] -min $input_hold_delay_value {uio_in ui_in}

# Longer output delay on bidi IOs to improve coherence
set output_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.65]
set output_hold_delay_value 1
set_output_delay -clock [get_clocks $::env(CLOCK_PORT)] -max $output_setup_delay_value { uio_out uio_oe uo_out}
set_output_delay -clock [get_clocks $::env(CLOCK_PORT)] -min $output_hold_delay_value {uio_out uio_oe uo_out}

# Lower delay on SPI clock output because it can be driven at negedge for timing tweaking
#set spi_clk_setup_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]
#set_output_delay -clock [get_clocks $::env(CLOCK_PORT)] -max $spi_clk_setup_delay_value {uio_out[3]}

set_max_transition 1.5 [current_design]
set_max_fanout 16 [current_design]


# ── Reset and enable are async → false paths ──────────────────────
#set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports ena]

set_propagated_clock [all_clocks]
set_load 0.19 [all_outputs]
