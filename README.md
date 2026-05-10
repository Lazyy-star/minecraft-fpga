# Minisys FmcPGA Minecraft TFT

This repository contains a Minisys `XC7A100T-FGG484-1` port of the FmcPGA Minecraft-like FPGA renderer.

The project keeps the original FmcPGA VHDL render core and wraps it with Verilog board-level logic for the Minisys TFT interface. Vivado generated run directories are intentionally not committed; use the Tcl scripts in `scripts/` to recreate the project.

## Hardware

- Board: Minisys, `xc7a100tfgg484-1`
- Toolchain: Vivado 2018.3
- Display: TFT interface from `constraints/minisys_fmcpga_tft.xdc`
- Main clock: 100 MHz on `clk_100m`

## Directory Layout

- `rtl/top/`: Minisys top modules
- `rtl/adapter/`: TFT frame-buffer mapping and color adapters
- `rtl/ip_replacements/`: Verilog replacements for original Vivado IP module names
- `rtl/vhdl/`: Flat VHDL wrapper around the FmcPGA core
- `vendor/FmcPGA/`: Imported FmcPGA HDL and resources
- `constraints/`: Minisys XDC constraints
- `mem/`: `$readmemh` memory initialization files converted from COE
- `scripts/`: Vivado and PowerShell helper scripts
- `docs/`: design notes, build notes, and implementation plans

## Controls

- `S1`: move right
- `S2`: move left
- `S3`: move forward
- `S4`: move backward
- `S5`: action button
- `S6`: reset
- `SW[4:0]`: selected block id, recommended range `0` to `23`
- `SW[5]`: action mode, `0` = place selected block, `1` = dig selected block

S5 performs one action per press. Digging is not continuous while `SW[5]` is held.

## Build

Open Vivado 2018.3 Tcl Console:

```tcl
cd C:/Users/32915/Desktop/shudiankeshe
source scripts/create_fmcpga_tft_project.tcl
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1
wait_on_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

The generated bitstream path is:

```text
vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

## Program Board

```tcl
open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE {C:/Users/32915/Desktop/shudiankeshe/vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
```

## Notes

The original FmcPGA project is GPL-licensed. This repository includes imported FmcPGA source and resources under `vendor/FmcPGA/`; keep the upstream license when publishing or redistributing.

