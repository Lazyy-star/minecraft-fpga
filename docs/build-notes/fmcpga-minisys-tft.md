# FmcPGA Minisys TFT Build Notes

## Toolchain

Vivado 2018.3
Part: xc7a100tfgg484-1
Board clock: 100 MHz on `clk_100m`

## Project Scripts

Smoke-test project:

```tcl
source scripts/create_fmcpga_tft_smoke_project.tcl
launch_runs synth_1
wait_on_run synth_1
```

Mixed FmcPGA TFT project:

```tcl
source scripts/create_fmcpga_tft_project.tcl
source scripts/run_fmcpga_tft_build.tcl
```

## IP Replacement Modules

This workspace uses source-level Verilog replacements instead of GUI-generated Vivado IP. The module names intentionally match the original FmcPGA IP instance names:

```text
clk_ppl_generator
display_ram
map_ram
texture_rom
txt_idx_map_rom
divider_gen
```

Source files:

```text
rtl/ip_replacements/clk_ppl_generator.v
rtl/ip_replacements/display_ram.v
rtl/ip_replacements/map_ram.v
rtl/ip_replacements/texture_rom.v
rtl/ip_replacements/txt_idx_map_rom.v
rtl/ip_replacements/divider_gen.v
```

Memory initialization files are converted from COE to MEM by:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/convert_coe_to_mem.ps1
```

The local copy of `pipeline_process.vhd` explicitly connects `m_axis_dout_tuser` to `open` so the divider replacement matches the original generated IP stub.

## Display Mapping

The TFT timing is 800x480. The FmcPGA frame buffer is 320x240 RGB444. `fmcpga_tft_read_mapper.v` maps it to a centered 640x480 image:

```text
left margin: 80 pixels
source x: (pix_x - 80) >> 1
source y: pix_y >> 1
frame address: source y * 320 + source x
```

The color adapter truncates RGB444 to TFT RGB323.

## Hardware Verification

Bitstream path:

```text
vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

Expected first hardware result:

```text
The TFT displays a centered scaled FmcPGA scene.
The left and right 80-pixel margins are black.
Reset returns the scene to the initial state.
At least one movement button changes the rendered view.
```

## Final Controls

```text
S1: move right
S2: move left
S3: move forward
S4: move backward
S5: action button
SW[4:0]: selected block id
SW[5]: action mode, 0 = place selected block, 1 = dig selected block
S6: reset
```

S1-S4 only move. S5 performs one action per press. With `SW[5] = 0`, S5 places the block selected by `SW[4:0]`. With `SW[5] = 1`, S5 digs the block selected by the crosshair.

Recommended block ids for `SW[4:0]` are `0` through `23`, matching the original FmcPGA block set. Higher values are representable in the 5-bit map storage but may not have valid texture mappings.
