# Clock - 50 MHz board oscillator
set_property PACKAGE_PIN N18 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name clk [get_ports clk]

# Reset - PL_KEY1 (active low)
set_property PACKAGE_PIN P16 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# LEDs (active low)
set_property PACKAGE_PIN P15 [get_ports led_alert_n]
set_property IOSTANDARD LVCMOS33 [get_ports led_alert_n]
set_property PACKAGE_PIN U12 [get_ports led_active_n]
set_property IOSTANDARD LVCMOS33 [get_ports led_active_n]

# Alert outputs - routed to JP1 GPIO expansion header
# These can be probed with a logic analyzer during demo
set_property PACKAGE_PIN N17 [get_ports alert_syn_fin]
set_property IOSTANDARD LVCMOS33 [get_ports alert_syn_fin]

set_property PACKAGE_PIN P18 [get_ports alert_syn_rst]
set_property IOSTANDARD LVCMOS33 [get_ports alert_syn_rst]

set_property PACKAGE_PIN R16 [get_ports alert_null_scan]
set_property IOSTANDARD LVCMOS33 [get_ports alert_null_scan]

set_property PACKAGE_PIN R17 [get_ports alert_xmas_scan]
set_property IOSTANDARD LVCMOS33 [get_ports alert_xmas_scan]

set_property PACKAGE_PIN T16 [get_ports alert_forbidden]
set_property IOSTANDARD LVCMOS33 [get_ports alert_forbidden]

set_property PACKAGE_PIN U17 [get_ports tcp_alert_any]
set_property IOSTANDARD LVCMOS33 [get_ports tcp_alert_any]

set_property PACKAGE_PIN W18 [get_ports alert_udp_forbidden]
set_property IOSTANDARD LVCMOS33 [get_ports alert_udp_forbidden]

set_property PACKAGE_PIN W19 [get_ports alert_udp_short]
set_property IOSTANDARD LVCMOS33 [get_ports alert_udp_short]

set_property PACKAGE_PIN Y18 [get_ports alert_udp_zero]
set_property IOSTANDARD LVCMOS33 [get_ports alert_udp_zero]

set_property PACKAGE_PIN Y19 [get_ports udp_alert_any]
set_property IOSTANDARD LVCMOS33 [get_ports udp_alert_any]