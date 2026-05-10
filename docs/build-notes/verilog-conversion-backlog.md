# Verilog Conversion Backlog

## Conversion Order

1. Keep `minisys_fmcpga_tft_top.v`, `fmcpga_tft_read_mapper.v`, and `fmcpga_rgb444_to_rgb323.v` as the stable Verilog shell.
2. Convert small peripheral modules: `debounced_button.vhd`, `frequency_divider.vhd`, and seven-segment code if it is reintroduced.
3. Convert display wrappers: `display_buffers.vhd` after BRAM behavior is captured with a small simulation.
4. Convert control modules: `inventory_register.vhd`, `player_pose_register.vhd`, `map_modifier.vhd`, `crosshair_object_register.vhd`, and `player_state_updater.vhd`.
5. Convert compute helpers: `angle_to_coord.vhd`, `angle_to_lookat_relative.vhd`, and `viewport_params.vhd`.
6. Convert pipeline control: `viewport_scanner.vhd` and `pipeline_entrance.vhd`.
7. Convert `pipeline_process.vhd` last, using the mixed-language implementation as the visual golden reference.

## Golden Reference

The mixed-language TFT bitstream is the reference for visual behavior. After each converted module, rebuild and compare hardware behavior against the reference scene, reset behavior, and movement response.
