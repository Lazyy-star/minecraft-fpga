if {![file exists ./reports]} {
  file mkdir ./reports
}

launch_runs synth_1
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/fmcpga_tft_synth_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_synth_timing.rpt

launch_runs impl_1
wait_on_run impl_1
open_run impl_1
report_utilization -file reports/fmcpga_tft_impl_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_impl_timing.rpt

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

puts "Build complete. Check reports/ and the impl_1 bitstream output."
