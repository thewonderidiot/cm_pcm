set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rxd]
set_property IOSTANDARD LVCMOS33 [get_ports txd]
set_property PACKAGE_PIN A18 [get_ports rst]
set_property PACKAGE_PIN V8 [get_ports rxd]
set_property PACKAGE_PIN J18 [get_ports txd]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property IOSTANDARD LVCMOS33 [get_ports dbg]
set_property PACKAGE_PIN G17 [get_ports dbg]

set_property IOSTANDARD LVCMOS33 [get_ports lock]
set_property PACKAGE_PIN C16 [get_ports lock]
