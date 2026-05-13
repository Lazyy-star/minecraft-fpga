set bit_file [file normalize "./vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit"]
set flash_dir [file normalize "./vivado_fmcpga_tft/flash"]
set mcs_file [file normalize "$flash_dir/minisys_fmcpga_tft_top.mcs"]

set cfgmem_part_name "n25q64-3.3v-spi-x1_x2_x4"
set cfgmem_size_mbit 64
set cfgmem_interface "SPIx1"

if {[info exists minisys_cfgmem_part_name]} {
  set cfgmem_part_name $minisys_cfgmem_part_name
}

if {[info exists minisys_cfgmem_size_mbit]} {
  set cfgmem_size_mbit $minisys_cfgmem_size_mbit
}

if {[info exists minisys_cfgmem_interface]} {
  set cfgmem_interface $minisys_cfgmem_interface
}

if {[llength $argv] >= 1} {
  set cfgmem_part_name [lindex $argv 0]
}

if {[llength $argv] >= 2} {
  set cfgmem_size_mbit [lindex $argv 1]
}

if {![file exists $bit_file]} {
  error "Bitstream not found: $bit_file. Build the project before programming SPI Flash."
}

file mkdir $flash_dir

puts "Bitstream: $bit_file"
puts "MCS output: $mcs_file"
puts "Cfgmem part: $cfgmem_part_name"
puts "Cfgmem size: $cfgmem_size_mbit Mbit"
puts "Cfgmem interface: $cfgmem_interface"

set cfgmem_search_patterns [list \
  $cfgmem_part_name \
  "n25q64-3.3v-spi-x1_x2_x4" \
  "n25q64-3.3v*" \
  "*n25q64*3.3v*" \
  "*n25q*64*3.3v*" \
  "n25q32-3.3v-spi-x1_x2_x4" \
  "n25q32-3.3v*" \
  "*n25q32*3.3v*" \
  "*n25q*32*3.3v*" \
  "n25q128-3.3v-spi-x1_x2_x4_x8" \
  "n25q128-3.3v*" \
  "*n25q128*3.3v*" \
  "*n25q*128*3.3v*" \
  "*n25q128*" \
  "*n25q*128*" \
  "*mt25ql128*" \
  "*mt25q*128*" \
  "*s25fl128*" \
  "*w25q128*" \
  "*mx25l128*" \
]

set cfgmem_part ""
foreach cfgmem_pattern $cfgmem_search_patterns {
  set cfgmem_parts [get_cfgmem_parts -quiet $cfgmem_pattern]
  if {[llength $cfgmem_parts] > 0} {
    set cfgmem_part [lindex $cfgmem_parts 0]
    break
  }
}

if {$cfgmem_part eq ""} {
  puts "Could not find the Minisys SPI Flash cfgmem part using these patterns:"
  foreach cfgmem_pattern $cfgmem_search_patterns {
    puts "  $cfgmem_pattern"
  }
  puts "Run these in Vivado Tcl Console and choose the closest board Flash part:"
  puts "  get_cfgmem_parts *n25q*"
  puts "  get_cfgmem_parts *64*"
  puts "Then retry with:"
  puts "  set minisys_cfgmem_part_name <Vivado cfgmem part name>"
  puts "  set minisys_cfgmem_size_mbit 64"
  puts "  source scripts/program_fmcpga_tft_flash.tcl"
  error "Vivado cfgmem part not found for Minisys SPI Flash."
}

puts "Resolved cfgmem part: $cfgmem_part"

write_cfgmem \
  -force \
  -format mcs \
  -size $cfgmem_size_mbit \
  -interface $cfgmem_interface \
  -loadbit "up 0x0 $bit_file" \
  -file $mcs_file

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
set_property PROGRAM.ERASE 1 $hw_cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $hw_cfgmem
set_property PROGRAM.VERIFY 1 $hw_cfgmem
set_property PROGRAM.CHECKSUM 0 $hw_cfgmem

set hw_cfgmem_type [get_property PROGRAM.HW_CFGMEM_TYPE [current_hw_device]]
set cfgmem_part_obj [get_property CFGMEM_PART $hw_cfgmem]
set cfgmem_mem_type [get_property MEM_TYPE $cfgmem_part_obj]
set hw_device_program_file [get_property PROGRAM.FILE [current_hw_device]]

if {$hw_cfgmem_type ne $cfgmem_mem_type || $hw_device_program_file eq ""} {
  puts "Preparing FPGA configuration memory access bitstream..."
  create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]
  program_hw_devices [current_hw_device]
  refresh_hw_device [current_hw_device]
}

puts "Programming SPI Flash. This can take several minutes..."
program_hw_cfgmem -hw_cfgmem $hw_cfgmem

puts "Programmed SPI Flash with: $mcs_file"
puts "Set the Minisys programming jumper for SPI Flash boot, then power-cycle the board to verify persistent startup."
