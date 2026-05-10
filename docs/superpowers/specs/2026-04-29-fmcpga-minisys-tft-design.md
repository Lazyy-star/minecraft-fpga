# FmcPGA Minisys TFT Migration Design

## Context

The source project at `C:\Users\32915\Desktop\FmcPGA-main` is already an FPGA Minecraft-like voxel renderer. Its main RTL is VHDL 2008, with Vivado IP for clocks, block memories, ROMs, and division. The target board is Minisys with `XC7A100T-FGG484-1`, a 100 MHz clock on pin `Y18`, and a validated external TFT path using the files under `C:\Users\32915\Desktop\数电课设`.

The user wants the final result to become all Verilog/SystemVerilog, but approved a staged path: first make a mixed VHDL plus Verilog project run on the Minisys TFT, then gradually translate the VHDL core.

## Goals

1. Build a Vivado 2018.3 project for Minisys that displays the FmcPGA 3D renderer on the TFT panel.
2. Reuse the validated TFT clock, timing, and pinout from the existing Minisys TFT demo.
3. Keep the first hardware milestone conservative by preserving the FmcPGA VHDL render core.
4. Create boundaries that make later VHDL-to-Verilog conversion incremental rather than a full rewrite in one pass.

## Non-Goals

1. The first milestone does not need to translate every VHDL file to Verilog.
2. The first milestone does not need PS2 gamepad support; Minisys push buttons are enough for initial interaction.
3. The first milestone does not need perfect frame rate tuning, only a working image path and synthesizable design.
4. The first milestone does not need DDR3 or external SRAM; FmcPGA's BRAM-backed map, texture, and display buffers remain the storage target.

## Constraints

Vivado version is 2018.3. This affects VHDL 2008 compile settings and IP regeneration. The project must target `xc7a100tfgg484-1`.

The TFT color interface is 8-bit RGB with `TFT_R_O[2:0]`, `TFT_G_O[1:0]`, and `TFT_B_O[2:0]`. FmcPGA produces 12-bit RGB444, so the adapter truncates high bits into RGB323.

The validated TFT timing is 800x480 visible area at approximately 33.33 MHz pixel clock. FmcPGA renders a 320x240 frame buffer. The first mapping scales the render frame by 2x to 640x480 and places it centered in the TFT visible area, with 80 black pixels on the left and right.

## Architecture

The first milestone creates a mixed-language project with a Verilog board-level top and a VHDL core wrapper.

```text
Minisys pins
  -> Verilog top: minisys_fmcpga_tft_top
  -> Verilog TFT clock/timing: tft_clock_gen + tft_timing
  -> VHDL flat wrapper: fmcpga_core_flat
  -> Original FmcPGA VHDL render/control/storage modules
  -> RGB444 frame-buffer read data
  -> TFT RGB323 output
```

The Verilog top owns board-specific ports and TFT output pins. It instantiates the already validated TFT clock generator and timing generator. It also computes the FmcPGA display-buffer read address from TFT pixel coordinates:

```text
if 80 <= pix_x < 720 and 0 <= pix_y < 480:
    src_x = (pix_x - 80) >> 1
    src_y = pix_y >> 1
    read_addr = src_y * 320 + src_x
else:
    output black
```

The VHDL flat wrapper exists because the original top-level uses VHDL record ports such as `vga_t`, which are awkward to connect from Verilog. The wrapper exposes only plain `std_logic` and `std_logic_vector` ports for the Verilog top.

## Display Path

The original FmcPGA `display_buffers.vhd` stores two 320x240 buffers of 12-bit RGB. The TFT adapter reads one pixel per TFT pixel clock. Because the visible image is scaled 2x, each source pixel is read for two adjacent TFT x positions and for two adjacent TFT y lines. A one-cycle read latency is acceptable; the top registers `video_on` and RGB once before driving the TFT outputs.

The TFT outputs are:

```text
TFT_R_O = rgb444[11:9]
TFT_G_O = rgb444[7:6]
TFT_B_O = rgb444[3:1]
TFT_DE_O = video_on
TFT_CLK_O = clk_tft
TFT_ADJ_O = 1
TFT_MODE_O = 1
```

## Input Path

Initial input uses Minisys buttons:

```text
btn_up     -> FmcPGA up movement or view control
btn_down   -> FmcPGA down movement or view control
btn_left   -> FmcPGA left movement or view control
btn_right  -> FmcPGA right movement or view control
btn_action -> placement/destruction trigger
btn_reset  -> reset
```

The original PS2 gamepad SPI ports are not used in the first milestone. The adapter drives inactive defaults into any preserved gamepad inputs, or bypasses the gamepad update path with a simple button-driven player update wrapper.

## IP Strategy

Regenerate or replace these IPs in Vivado 2018.3:

1. `clk_ppl_generator`: 100 MHz input to the render pipeline clock. Start with 40 MHz to match `PPL_FREQ`.
2. `display_ram`: true dual-port 76800 x 12 block memory.
3. `map_ram`: dual-port 131072 x 5 block memory initialized from `res/coe/map_test.coe`.
4. `texture_rom`: single-port 8192 x 32 ROM initialized from `res/coe/textures.coe`.
5. `txt_idx_map_rom`: single-port 256 x 5 ROM initialized from `res/coe/txt_idx_map.coe`.
6. `divider_gen`: signed or unsigned pipelined divider matching the original generated IP port contract.

The existing Verilog `tft_clock_gen.v` is preferred for the TFT pixel clock because the user has already validated it on hardware.

## Verification

Verification is staged:

1. Rebuild and run the existing TFT bars project to prove the local Vivado 2018.3 flow and XDC still work.
2. Build a frame-buffer test pattern project that uses the same 320x240-to-800x480 scaling logic.
3. Compile the mixed-language project without the FmcPGA control changes.
4. Synthesize and implement the mixed-language project.
5. Program the board and verify that the TFT shows the FmcPGA scene, centered and scaled.
6. Verify reset, at least one movement control, and at least one block interaction or selected-item change.

## Risks

Vivado 2018.3 may require explicit VHDL 2008 settings for the FmcPGA files. The original project was developed with Vivado 2022.2, so generated IP metadata may need to be rebuilt from scratch rather than reused directly.

The FmcPGA render core depends on generated memory and divider latency. If regenerated IP latency differs, the pipeline can show wrong pixels or fail timing. The mitigation is to keep the original IP interfaces and inspect the original `.xci` settings before regeneration.

The first TFT adapter reads at 33.33 MHz while the render pipeline writes at 40 MHz. The existing double-buffer design supports independent read and write clocks, so the adapter should preserve that boundary.

## Later Verilog Conversion

After the mixed project runs on TFT, translate modules in this order:

1. Verilog wrappers and board top.
2. Small peripheral/control modules.
3. Display buffer and memory wrappers.
4. Player state and map modification modules.
5. Math helper modules and packages.
6. `pipeline_entrance.vhd` and `viewport_scanner.vhd`.
7. `pipeline_process.vhd`, only after golden-frame comparisons exist.

This order avoids translating the highest-risk render pipeline before the board, display, and memory contracts are proven.

## Documentation Status

This design document is written in `C:\Users\32915\Desktop\shudiankeshe`. The directory is not currently a git repository, so no design-document commit was created.
