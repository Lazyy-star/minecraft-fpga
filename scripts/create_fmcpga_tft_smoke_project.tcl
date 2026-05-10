set project_name fmcpga_minisys_tft_smoke
set project_dir ./vivado_fmcpga_tft_smoke
set part_name xc7a100tfgg484-1

create_project $project_name $project_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]
file mkdir ./reports

add_files -norecurse [glob ./rtl/tft/*.v]
add_files -norecurse [glob ./rtl/adapter/*.v]
add_files -norecurse ./rtl/top/fmcpga_frame_test_top.v
add_files -fileset constrs_1 -norecurse ./constraints/minisys_fmcpga_tft.xdc

set_property top fmcpga_frame_test_top [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: $project_dir/$project_name.xpr"
puts "Top module: fmcpga_frame_test_top"
