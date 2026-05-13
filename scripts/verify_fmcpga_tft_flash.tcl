set bit_file [file normalize "./vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit"]
set mcs_file [file normalize "./vivado_fmcpga_tft/flash/minisys_fmcpga_tft_top.mcs"]

set cfgmem_part_name "n25q64-3.3v-spi-x1_x2_x4"

if {[info exists minisys_cfgmem_part_name]} {
  set cfgmem_part_name $minisys_cfgmem_part_name
}

if {[llength $argv] >= 1} {
  set cfgmem_part_name [lindex $argv 0]
}

if {![file exists $bit_file]} {
  error "Bitstream not found: $bit_file. Build the project before verifying SPI Flash."
}

if {![file exists $mcs_file]} {
  error "MCS file not found: $mcs_file. Run scripts/program_fmcpga_tft_flash.tcl first."
}

puts "Bitstream: $bit_file"
puts "MCS to verify: $mcs_file"
puts "Cfgmem part: $cfgmem_part_name"

set cfgmem_parts [get_cfgmem_parts -quiet $cfgmem_part_name]
if {[llength $cfgmem_parts] == 0} {
  error "Vivado cfgmem part not found: $cfgmem_part_name."
}
set cfgmem_part [lindex $cfgmem_parts 0]

open_hw

set hw_servers [get_hw_servers -quiet]
if {[llength $hw_servers] == 0} {
  connect_hw_server
} else {
  current_hw_server [lindex $hw_servers 0]
  puts "Using existing hardware server: [current_hw_server]"
}

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

set existing_cfgmem [get_property PROGRAM.HW_CFGMEM [current_hw_device]]
if {$existing_cfgmem ne ""} {
  delete_hw_cfgmem $existing_cfgmem
}

create_hw_cfgmem -hw_device [current_hw_device] $cfgmem_part
set hw_cfgmem [get_property PROGRAM.HW_CFGMEM [current_hw_device]]

set_property PROGRAM.FILES [list $mcs_file] $hw_cfgmem
if {[catch {set_property PROGRAM.FILE $mcs_file $hw_cfgmem} program_file_result]} {
  puts "Skipping legacy PROGRAM.FILE property: $program_file_result"
}
set_property PROGRAM.ADDRESS_RANGE {use_file} $hw_cfgmem
set_property PROGRAM.BLANK_CHECK 0 $hw_cfgmem
set_property PROGRAM.ERASE 0 $hw_cfgmem
set_property PROGRAM.CFG_PROGRAM 0 $hw_cfgmem
set_property PROGRAM.VERIFY 1 $hw_cfgmem
set_property PROGRAM.CHECKSUM 0 $hw_cfgmem

puts "Preparing FPGA configuration memory access bitstream..."
create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]

puts "Verifying SPI Flash contents against: $mcs_file"
program_hw_cfgmem -hw_cfgmem $hw_cfgmem

puts "SPI Flash verify completed successfully. Flash contents match the MCS file."
