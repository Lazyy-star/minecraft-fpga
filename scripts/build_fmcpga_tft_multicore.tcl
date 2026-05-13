set thread_count 8
if {[llength $argv] >= 1} {
  set thread_count [lindex $argv 0]
}

puts "Using Vivado thread count: $thread_count"
set_param general.maxThreads $thread_count

source scripts/create_fmcpga_tft_project.tcl

reset_run synth_1
launch_runs synth_1 -jobs $thread_count
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/fmcpga_tft_synth_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_synth_timing.rpt

reset_run impl_1
launch_runs impl_1 -jobs $thread_count
wait_on_run impl_1
open_run impl_1
report_utilization -file reports/fmcpga_tft_impl_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_impl_timing.rpt

launch_runs impl_1 -to_step write_bitstream -jobs $thread_count
wait_on_run impl_1

puts "Build complete."
puts "Bitstream: vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit"
