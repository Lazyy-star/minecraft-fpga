set bit_file [file normalize "./vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit"]

if {![file exists $bit_file]} {
  error "Bitstream not found: $bit_file"
}

open_hw
connect_hw_server

set targets [get_hw_targets *]
if {[llength $targets] == 0} {
  error "No hardware target found. Check board power, JTAG cable, USB driver, and that no other Vivado session owns the cable."
}

current_hw_target [lindex $targets 0]
open_hw_target [current_hw_target]

set devices [get_hw_devices]
if {[llength $devices] == 0} {
  error "No hardware device found. Check board power, JTAG cable, and drivers."
}

current_hw_device [lindex $devices 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE $bit_file [current_hw_device]
program_hw_devices [current_hw_device]

puts "Programmed hardware device with: $bit_file"
