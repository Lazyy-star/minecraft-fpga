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

puts "Boot status for: [current_hw_device]"

set interesting_props [list \
  PROGRAM.FILE \
  PROGRAM.HW_CFGMEM_TYPE \
]

foreach prop [list_property [current_hw_device]] {
  if {[regexp -nocase {(DONE|STATUS|BOOT|MODE|CONFIG)} $prop]} {
    lappend interesting_props $prop
  }
}

foreach prop [lsort -unique $interesting_props] {
  if {[catch {set value [get_property $prop [current_hw_device]]} err]} {
    puts "$prop: <unavailable>"
  } else {
    puts "$prop: $value"
  }
}

puts "If DONE is 0 or CONFIG_STATUS shows a mode/configuration error after power-on, check the Minisys boot-mode jumper before changing the bitstream."
