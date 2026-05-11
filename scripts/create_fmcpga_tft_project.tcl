set project_name fmcpga_minisys_tft
set project_dir ./vivado_fmcpga_tft
set part_name xc7a100tfgg484-1

create_project $project_name $project_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
file mkdir ./reports

set vhdl_files [list \
  ./vendor/FmcPGA/src/hdl/general/types.vhd \
  ./vendor/FmcPGA/src/hdl/general/constants.vhd \
  ./vendor/FmcPGA/src/hdl/compute/angle_to_coord.vhd \
  ./vendor/FmcPGA/src/hdl/compute/angle_to_lookat_relative.vhd \
  ./vendor/FmcPGA/src/hdl/compute/viewport_params.vhd \
  ./vendor/FmcPGA/src/hdl/control/frequency_divider.vhd \
  ./vendor/FmcPGA/src/hdl/control/inventory_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/player_pose_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/player_state_updater.vhd \
  ./vendor/FmcPGA/src/hdl/control/crosshair_object_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/map_modifier.vhd \
  ./vendor/FmcPGA/src/hdl/display/display_buffers.vhd \
  ./vendor/FmcPGA/src/hdl/peripheral/debounced_button.vhd \
  ./vendor/FmcPGA/src/hdl/pipeline/viewport_scanner.vhd \
  ./vendor/FmcPGA/src/hdl/pipeline/pipeline_entrance.vhd \
  ./vendor/FmcPGA/src/hdl/pipeline/pipeline_process.vhd \
  ./rtl/vhdl/fmcpga_core_flat.vhd \
]
add_files -norecurse $vhdl_files
set_property file_type {VHDL 2008} [get_files $vhdl_files]

add_files -norecurse [glob ./rtl/tft/*.v]
add_files -norecurse [glob ./rtl/adapter/*.v]
add_files -norecurse [glob ./rtl/audio/*.v]
add_files -norecurse [glob ./rtl/ip_replacements/*.v]
add_files -norecurse ./rtl/top/minisys_fmcpga_tft_top.v
add_files -fileset constrs_1 -norecurse ./constraints/minisys_fmcpga_tft.xdc

set_property top minisys_fmcpga_tft_top [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: $project_dir/$project_name.xpr"
puts "Top module: minisys_fmcpga_tft_top"
