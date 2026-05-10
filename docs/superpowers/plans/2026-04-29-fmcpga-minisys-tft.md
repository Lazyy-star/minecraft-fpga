# FmcPGA Minisys TFT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Vivado 2018.3 mixed-language project that displays the FmcPGA 3D voxel renderer on the validated Minisys TFT panel.

**Architecture:** Keep the FmcPGA VHDL renderer for the first milestone, wrap it with flat ports, and connect it to a Verilog Minisys TFT top. Reuse the existing TFT clock, timing, and XDC files that already display color bars on hardware.

**Tech Stack:** Vivado 2018.3, Verilog, VHDL 2008, Xilinx 7-series PLL, Xilinx block memory generator, Xilinx divider generator, Minisys `xc7a100tfgg484-1`.

---

## File Structure

Create the implementation under `C:\Users\32915\Desktop\shudiankeshe`:

- `rtl/tft/tft_clock_gen.v`: copied from the validated Minisys TFT demo.
- `rtl/tft/tft_timing.v`: copied from the validated Minisys TFT demo.
- `rtl/top/minisys_fmcpga_tft_top.v`: new Verilog board top for Minisys TFT.
- `rtl/top/fmcpga_frame_test_top.v`: new Verilog smoke-test top for frame scaling before wiring the VHDL core.
- `rtl/adapter/fmcpga_tft_read_mapper.v`: new Verilog coordinate mapper from 800x480 TFT pixels to 320x240 frame-buffer addresses.
- `rtl/adapter/fmcpga_rgb444_to_rgb323.v`: new Verilog color truncation adapter.
- `rtl/vhdl/fmcpga_core_flat.vhd`: new VHDL wrapper exposing FmcPGA frame-buffer and controls as flat ports.
- `vendor/FmcPGA/src/hdl/**`: copied FmcPGA VHDL source.
- `vendor/FmcPGA/res/coe/**`: copied FmcPGA COE memory initialization files.
- `constraints/minisys_fmcpga_tft.xdc`: copied and renamed from `minisys_minecraft_tft.xdc`, with top-port names kept aligned.
- `scripts/create_fmcpga_tft_project.tcl`: new Vivado 2018.3 project script.
- `scripts/check_sources.ps1`: new local source sanity checker.
- `docs/build-notes/fmcpga-minisys-tft.md`: build notes and IP settings captured during implementation.

## Task 1: Import Source Tree

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\tft\tft_clock_gen.v`
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\tft\tft_timing.v`
- Create: `C:\Users\32915\Desktop\shudiankeshe\constraints\minisys_fmcpga_tft.xdc`
- Create: `C:\Users\32915\Desktop\shudiankeshe\vendor\FmcPGA\src\hdl\...`
- Create: `C:\Users\32915\Desktop\shudiankeshe\vendor\FmcPGA\res\coe\...`

- [ ] **Step 1: Create implementation directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path `
  'C:\Users\32915\Desktop\shudiankeshe\rtl\tft',`
  'C:\Users\32915\Desktop\shudiankeshe\rtl\top',`
  'C:\Users\32915\Desktop\shudiankeshe\rtl\adapter',`
  'C:\Users\32915\Desktop\shudiankeshe\rtl\vhdl',`
  'C:\Users\32915\Desktop\shudiankeshe\constraints',`
  'C:\Users\32915\Desktop\shudiankeshe\scripts',`
  'C:\Users\32915\Desktop\shudiankeshe\vendor\FmcPGA',`
  'C:\Users\32915\Desktop\shudiankeshe\docs\build-notes'
```

Expected: PowerShell prints the created directories without errors.

- [ ] **Step 2: Copy validated TFT modules**

Run:

```powershell
Copy-Item -LiteralPath 'C:\Users\32915\Desktop\数电课设\rtl\tft_clock_gen.v' `
  -Destination 'C:\Users\32915\Desktop\shudiankeshe\rtl\tft\tft_clock_gen.v' -Force
Copy-Item -LiteralPath 'C:\Users\32915\Desktop\数电课设\rtl\tft_timing.v' `
  -Destination 'C:\Users\32915\Desktop\shudiankeshe\rtl\tft\tft_timing.v' -Force
Copy-Item -LiteralPath 'C:\Users\32915\Desktop\数电课设\constraints\minisys_minecraft_tft.xdc' `
  -Destination 'C:\Users\32915\Desktop\shudiankeshe\constraints\minisys_fmcpga_tft.xdc' -Force
```

Expected: The three files exist in the new workspace.

- [ ] **Step 3: Copy FmcPGA HDL and resources**

Run:

```powershell
Copy-Item -LiteralPath 'C:\Users\32915\Desktop\FmcPGA-main\src' `
  -Destination 'C:\Users\32915\Desktop\shudiankeshe\vendor\FmcPGA\src' -Recurse -Force
Copy-Item -LiteralPath 'C:\Users\32915\Desktop\FmcPGA-main\res' `
  -Destination 'C:\Users\32915\Desktop\shudiankeshe\vendor\FmcPGA\res' -Recurse -Force
```

Expected: `vendor\FmcPGA\src\hdl\top_module.vhd` and `vendor\FmcPGA\res\coe\textures.coe` exist.

- [ ] **Step 4: Record import checkpoint**

Run:

```powershell
Get-ChildItem -LiteralPath 'C:\Users\32915\Desktop\shudiankeshe' -Recurse -File |
  Select-Object FullName,Length |
  Out-File -LiteralPath 'C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\imported-files.txt' -Encoding utf8
```

Expected: `docs\build-notes\imported-files.txt` lists copied Verilog, VHDL, XDC, and COE files.

## Task 2: Add TFT Frame Read Adapters

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\adapter\fmcpga_tft_read_mapper.v`
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\adapter\fmcpga_rgb444_to_rgb323.v`

- [ ] **Step 1: Create the TFT-to-frame-buffer mapper**

Create `rtl\adapter\fmcpga_tft_read_mapper.v` with:

```verilog
module fmcpga_tft_read_mapper (
    input  wire        clk,
    input  wire        rst,
    input  wire        video_on,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    output reg         src_active,
    output reg [16:0]  src_addr
);
    localparam integer TFT_W = 800;
    localparam integer TFT_H = 480;
    localparam integer SRC_W = 320;
    localparam integer SRC_H = 240;
    localparam integer X_PAD = (TFT_W - SRC_W * 2) / 2;

    wire in_x = (pix_x >= X_PAD[9:0]) && (pix_x < (X_PAD + SRC_W * 2));
    wire in_y = (pix_y < (SRC_H * 2));
    wire [8:0] src_x = (pix_x - X_PAD[9:0]) >> 1;
    wire [7:0] src_y = pix_y[8:1];
    wire [16:0] row_base = {src_y, 8'b0} + {src_y, 6'b0};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            src_active <= 1'b0;
            src_addr <= 17'd0;
        end else begin
            src_active <= video_on && in_x && in_y;
            src_addr <= row_base + src_x;
        end
    end
endmodule
```

- [ ] **Step 2: Create the RGB truncation adapter**

Create `rtl\adapter\fmcpga_rgb444_to_rgb323.v` with:

```verilog
module fmcpga_rgb444_to_rgb323 (
    input  wire        active,
    input  wire [11:0] rgb444,
    output wire [2:0]  tft_r,
    output wire [1:0]  tft_g,
    output wire [2:0]  tft_b
);
    assign tft_r = active ? rgb444[11:9] : 3'b000;
    assign tft_g = active ? rgb444[7:6]  : 2'b00;
    assign tft_b = active ? rgb444[3:1]  : 3'b000;
endmodule
```

- [ ] **Step 3: Run syntax scan**

Run:

```powershell
Select-String -Path 'C:\Users\32915\Desktop\shudiankeshe\rtl\adapter\*.v' -Pattern 'TO' + 'DO|TB' + 'D'
```

Expected: No matches.

## Task 3: Build a TFT Frame-Mapper Smoke Test

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\top\fmcpga_frame_test_top.v`
- Modify: `C:\Users\32915\Desktop\shudiankeshe\constraints\minisys_fmcpga_tft.xdc`

- [ ] **Step 1: Create a Verilog-only frame mapper test top**

Create `rtl\top\fmcpga_frame_test_top.v` with:

```verilog
module fmcpga_frame_test_top (
    input  wire       clk_100m,
    input  wire       btn_reset,
    output wire [2:0] TFT_R_O,
    output wire [1:0] TFT_G_O,
    output wire [2:0] TFT_B_O,
    output wire       TFT_CLK_O,
    output wire       TFT_ADJ_O,
    output wire       TFT_DE_O,
    output wire       TFT_HSYNC_O,
    output wire       TFT_VSYNC_O,
    output wire       TFT_MODE_O
);
    wire clk_tft;
    wire locked;
    wire rst = btn_reset | ~locked;
    wire video_on;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire src_active;
    wire [16:0] src_addr;
    wire [11:0] rgb444;

    tft_clock_gen u_clk (.clk_100m(clk_100m), .rst(btn_reset), .clk_tft(clk_tft), .locked(locked));
    tft_timing u_timing (.clk(clk_tft), .rst(rst), .hsync(TFT_HSYNC_O), .vsync(TFT_VSYNC_O),
                         .video_on(video_on), .pix_x(pix_x), .pix_y(pix_y));
    fmcpga_tft_read_mapper u_map (.clk(clk_tft), .rst(rst), .video_on(video_on),
                                  .pix_x(pix_x), .pix_y(pix_y), .src_active(src_active), .src_addr(src_addr));

    assign rgb444 = {src_addr[8:5], src_addr[12:9], src_addr[4:1]};
    fmcpga_rgb444_to_rgb323 u_rgb (.active(src_active), .rgb444(rgb444),
                                   .tft_r(TFT_R_O), .tft_g(TFT_G_O), .tft_b(TFT_B_O));

    assign TFT_CLK_O = clk_tft;
    assign TFT_DE_O = video_on;
    assign TFT_ADJ_O = 1'b1;
    assign TFT_MODE_O = 1'b1;
endmodule
```

- [ ] **Step 2: Check the top ports match the XDC**

Run:

```powershell
Select-String -Path 'C:\Users\32915\Desktop\shudiankeshe\constraints\minisys_fmcpga_tft.xdc' `
  -Pattern 'TFT_R_O|TFT_G_O|TFT_B_O|TFT_CLK_O|TFT_DE_O|TFT_HSYNC_O|TFT_VSYNC_O|TFT_MODE_O|TFT_ADJ_O|clk_100m|btn_reset'
```

Expected: Every listed top-level port appears in the XDC.

## Task 4: Add Vivado Project Script

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\scripts\create_fmcpga_tft_project.tcl`

- [ ] **Step 1: Create the project script**

Create `scripts\create_fmcpga_tft_project.tcl` with:

```tcl
set project_name fmcpga_minisys_tft
set project_dir ./vivado_fmcpga_tft
set part_name xc7a100tfgg484-1

create_project $project_name $project_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse [glob ./rtl/tft/*.v]
add_files -norecurse [glob ./rtl/adapter/*.v]
add_files -norecurse ./rtl/top/fmcpga_frame_test_top.v
add_files -fileset constrs_1 -norecurse ./constraints/minisys_fmcpga_tft.xdc

set_property top fmcpga_frame_test_top [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: $project_dir/$project_name.xpr"
puts "Top module: fmcpga_frame_test_top"
```

- [ ] **Step 2: Create the smoke-test project**

Run from `C:\Users\32915\Desktop\shudiankeshe` in Vivado Tcl Shell:

```tcl
source scripts/create_fmcpga_tft_project.tcl
```

Expected: Vivado creates `vivado_fmcpga_tft\fmcpga_minisys_tft.xpr` and sets `fmcpga_frame_test_top` as the top.

- [ ] **Step 3: Synthesize the smoke test**

Run in Vivado Tcl Shell:

```tcl
launch_runs synth_1
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/frame_test_utilization.rpt
```

Expected: `synth_1` completes successfully and the utilization report is written.

## Task 5: Create the VHDL Flat Core Wrapper

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\vhdl\fmcpga_core_flat.vhd`
- Modify later: `C:\Users\32915\Desktop\shudiankeshe\scripts\create_fmcpga_tft_project.tcl`

- [ ] **Step 1: Create a flat VHDL entity for Verilog integration**

Create `rtl\vhdl\fmcpga_core_flat.vhd` with this entity and architecture scaffold:

```vhdl
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fmcpga_core_flat is
    port (
        clk_sys: in std_logic;
        rst: in std_logic;
        btn_front_in: in std_logic;
        btn_back_in: in std_logic;
        btn_left_in: in std_logic;
        btn_right_in: in std_logic;
        btn_up_in: in std_logic;
        btn_down_in: in std_logic;
        disp_read_clk: in std_logic;
        disp_read_en: in std_logic;
        disp_read_addr: in std_logic_vector(16 downto 0);
        disp_read_data: out std_logic_vector(11 downto 0);
        fps_hundreds: out std_logic_vector(3 downto 0);
        fps_tens: out std_logic_vector(3 downto 0);
        fps_ones: out std_logic_vector(3 downto 0);
        current_item_ones: out std_logic_vector(3 downto 0)
    );
end entity;

architecture Behavioral of fmcpga_core_flat is
begin
    -- Replace this scaffold by moving the original top_module internals here.
    -- Keep the public ports flat so Verilog can instantiate the wrapper.
    disp_read_data <= (others => '0');
    fps_hundreds <= (others => '0');
    fps_tens <= (others => '0');
    fps_ones <= (others => '0');
    current_item_ones <= (others => '0');
end architecture;
```

- [ ] **Step 2: Move original top internals into the wrapper**

Edit `fmcpga_core_flat.vhd` by copying declarations and architecture logic from `vendor\FmcPGA\src\hdl\top_module.vhd`, then remove these original top-only elements:

```vhdl
vgaout: out vga_t;
anodes_n: out std_logic_vector(7 downto 0);
segs_n: out std_logic_vector(0 to 7);
spi_cs, spi_clk, spi_mosi: out std_logic;
spi_miso: in std_logic;
vga_scan: vga_scanner
seven_segs_driver: seven_segments_display_driver
gp_ps2: gamepad
```

Wire the existing `display_buffers` read side to the new flat ports:

```vhdl
clk_read => disp_read_clk,
en_read => disp_read_en,
addr_read => disp_read_addr,
dout_read => disp_read_data,
```

Keep the render/write side unchanged:

```vhdl
clk_write => clk_ppl,
en_write => disp_buf_write_enable,
we_write => "1",
addr_write => disp_buf_write_addr,
din_write => disp_buf_write_data,
clk_ppl => clk_ppl,
rst => rst,
enable => pipeline_enable,
swap_sync => end_of_frame
```

- [ ] **Step 3: Replace gamepad-driven control with button defaults**

Inside `fmcpga_core_flat.vhd`, drive the existing `player_state_updater` with button-derived integer offsets:

```vhdl
move_lr_offset <= 127 when btn_right = '1' else -128 when btn_left = '1' else 0;
move_fb_offset <= 127 when btn_front = '1' else -128 when btn_back = '1' else 0;
move_ud_offset <= 127 when btn_up = '1' else -128 when btn_down = '1' else 0;
angle_lr_offset <= 0;
angle_ud_offset <= 0;
left_click <= btn_down;
right_click <= btn_up;
last_item_click <= '0';
next_item_click <= btn_right;
```

Map those signals into `player_state_updater`:

```vhdl
enable => '1',
left_click => left_click,
right_click => right_click,
last_item_click => last_item_click,
next_item_click => next_item_click,
move_lr_offset => move_lr_offset,
move_fb_offset => move_fb_offset,
move_ud_offset => move_ud_offset,
angle_lr_offset => angle_lr_offset,
angle_ud_offset => angle_ud_offset
```

Expected: The wrapper has no record ports and no board-specific VGA/TFT pins.

## Task 6: Create the Mixed-Language TFT Top

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\rtl\top\minisys_fmcpga_tft_top.v`
- Modify: `C:\Users\32915\Desktop\shudiankeshe\scripts\create_fmcpga_tft_project.tcl`

- [ ] **Step 1: Create the top module**

Create `rtl\top\minisys_fmcpga_tft_top.v` with:

```verilog
module minisys_fmcpga_tft_top (
    input  wire       clk_100m,
    input  wire       btn_reset,
    input  wire       btn_up,
    input  wire       btn_down,
    input  wire       btn_left,
    input  wire       btn_right,
    input  wire       btn_action,
    output wire [2:0] TFT_R_O,
    output wire [1:0] TFT_G_O,
    output wire [2:0] TFT_B_O,
    output wire       TFT_CLK_O,
    output wire       TFT_ADJ_O,
    output wire       TFT_DE_O,
    output wire       TFT_HSYNC_O,
    output wire       TFT_VSYNC_O,
    output wire       TFT_MODE_O
);
    wire clk_tft;
    wire locked;
    wire rst = btn_reset | ~locked;
    wire video_on;
    wire video_on_d;
    wire src_active;
    reg  src_active_d;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire [16:0] fb_addr;
    wire [11:0] fb_rgb444;

    tft_clock_gen u_clk (.clk_100m(clk_100m), .rst(btn_reset), .clk_tft(clk_tft), .locked(locked));
    tft_timing u_timing (.clk(clk_tft), .rst(rst), .hsync(TFT_HSYNC_O), .vsync(TFT_VSYNC_O),
                         .video_on(video_on), .pix_x(pix_x), .pix_y(pix_y));
    fmcpga_tft_read_mapper u_map (.clk(clk_tft), .rst(rst), .video_on(video_on),
                                  .pix_x(pix_x), .pix_y(pix_y), .src_active(src_active), .src_addr(fb_addr));

    always @(posedge clk_tft or posedge rst) begin
        if (rst) begin
            src_active_d <= 1'b0;
        end else begin
            src_active_d <= src_active;
        end
    end

    fmcpga_core_flat u_core (
        .clk_sys(clk_100m),
        .rst(rst),
        .btn_front_in(btn_up),
        .btn_back_in(btn_down),
        .btn_left_in(btn_left),
        .btn_right_in(btn_right),
        .btn_up_in(btn_action),
        .btn_down_in(1'b0),
        .disp_read_clk(clk_tft),
        .disp_read_en(src_active),
        .disp_read_addr(fb_addr),
        .disp_read_data(fb_rgb444),
        .fps_hundreds(),
        .fps_tens(),
        .fps_ones(),
        .current_item_ones()
    );

    fmcpga_rgb444_to_rgb323 u_rgb (.active(src_active_d), .rgb444(fb_rgb444),
                                   .tft_r(TFT_R_O), .tft_g(TFT_G_O), .tft_b(TFT_B_O));

    assign TFT_CLK_O = clk_tft;
    assign TFT_DE_O = video_on;
    assign TFT_ADJ_O = 1'b1;
    assign TFT_MODE_O = 1'b1;
endmodule
```

- [ ] **Step 2: Update the project script to include VHDL**

Change `scripts\create_fmcpga_tft_project.tcl` to this mixed-language source list:

```tcl
set project_name fmcpga_minisys_tft
set project_dir ./vivado_fmcpga_tft
set part_name xc7a100tfgg484-1

create_project $project_name $project_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set vhdl_files [list \
  ./vendor/FmcPGA/src/hdl/general/types.vhd \
  ./vendor/FmcPGA/src/hdl/general/constants.vhd \
  ./vendor/FmcPGA/src/hdl/compute/angle_to_coord.vhd \
  ./vendor/FmcPGA/src/hdl/compute/angle_to_lookat_relative.vhd \
  ./vendor/FmcPGA/src/hdl/compute/viewport_params.vhd \
  ./vendor/FmcPGA/src/hdl/control/crosshair_object_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/frequency_divider.vhd \
  ./vendor/FmcPGA/src/hdl/control/inventory_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/map_modifier.vhd \
  ./vendor/FmcPGA/src/hdl/control/player_pose_register.vhd \
  ./vendor/FmcPGA/src/hdl/control/player_state_updater.vhd \
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
add_files -norecurse ./rtl/top/minisys_fmcpga_tft_top.v
add_files -fileset constrs_1 -norecurse ./constraints/minisys_fmcpga_tft.xdc

set_property top minisys_fmcpga_tft_top [current_fileset]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: $project_dir/$project_name.xpr"
puts "Top module: minisys_fmcpga_tft_top"
```

Expected: Vivado compile order places `types.vhd` before modules that use `work.types`.

## Task 7: Regenerate Vivado 2018.3 IP

**Files:**
- Modify project IP catalog state under `C:\Users\32915\Desktop\shudiankeshe\vivado_fmcpga_tft`
- Update: `C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\fmcpga-minisys-tft.md`

- [ ] **Step 1: Create required IP names**

In Vivado 2018.3 GUI or Tcl, create IPs with these exact module names because the VHDL instantiates them by component name:

```text
clk_ppl_generator
display_ram
map_ram
texture_rom
txt_idx_map_rom
divider_gen
```

Expected: The project contains XCI files whose generated top modules match those names.

- [ ] **Step 2: Configure memory IPs**

Use these dimensions:

```text
display_ram: true dual-port RAM, write width 12, read width 12, depth 76800, no initialization required
map_ram: true dual-port RAM, width 5, depth 131072, initialize from vendor/FmcPGA/res/coe/map_test.coe
texture_rom: single-port ROM, width 32, depth 8192, initialize from vendor/FmcPGA/res/coe/textures.coe
txt_idx_map_rom: single-port ROM, width 5, depth 256, initialize from vendor/FmcPGA/res/coe/txt_idx_map.coe
```

Expected: Generated stubs match the component port lists used in `top_module.vhd` and `display_buffers.vhd`.

- [ ] **Step 3: Configure clock and divider IPs**

Use these settings:

```text
clk_ppl_generator: 100 MHz input, 40 MHz output, ports clk_sys/reset/clk_ppl/locked
divider_gen: preserve original generated interface used by pipeline_process.vhd
```

Inspect `vendor\FmcPGA\src\hdl\pipeline\pipeline_process.vhd` and original `C:\Users\32915\Desktop\FmcPGA-main\ips\divider_gen\divider_gen_stub.vhdl` before finalizing divider settings.

Expected: Synthesis does not report missing modules for `clk_ppl_generator`, `display_ram`, `map_ram`, `texture_rom`, `txt_idx_map_rom`, or `divider_gen`.

- [ ] **Step 4: Record IP settings**

Create `docs\build-notes\fmcpga-minisys-tft.md` with:

```markdown
# FmcPGA Minisys TFT Build Notes

## Toolchain

Vivado 2018.3
Part: xc7a100tfgg484-1

## Generated IP

clk_ppl_generator: 100 MHz input, 40 MHz output
display_ram: true dual-port RAM, 76800 x 12
map_ram: true dual-port RAM, 131072 x 5, initialized from vendor/FmcPGA/res/coe/map_test.coe
texture_rom: single-port ROM, 8192 x 32, initialized from vendor/FmcPGA/res/coe/textures.coe
txt_idx_map_rom: single-port ROM, 256 x 5, initialized from vendor/FmcPGA/res/coe/txt_idx_map.coe
divider_gen: interface matched to original FmcPGA divider_gen_stub.vhdl
```

## Task 8: Build and Hardware Verify

**Files:**
- Update: `C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\fmcpga-minisys-tft.md`

- [ ] **Step 1: Run synthesis**

Run in Vivado Tcl Shell:

```tcl
launch_runs synth_1
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/fmcpga_tft_synth_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_synth_timing.rpt
```

Expected: `synth_1` completes. If timing fails at synthesis, the report identifies the failing clock path.

- [ ] **Step 2: Run implementation**

Run in Vivado Tcl Shell:

```tcl
launch_runs impl_1
wait_on_run impl_1
open_run impl_1
report_utilization -file reports/fmcpga_tft_impl_utilization.rpt
report_timing_summary -file reports/fmcpga_tft_impl_timing.rpt
```

Expected: `impl_1` completes. Timing should be non-negative for `clk_tft` and `clk_ppl`; if not, reduce `clk_ppl_generator` from 40 MHz to 30 MHz and rerun implementation.

- [ ] **Step 3: Generate bitstream**

Run:

```tcl
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

Expected: Vivado writes `vivado_fmcpga_tft\fmcpga_minisys_tft.runs\impl_1\minisys_fmcpga_tft_top.bit`.

- [ ] **Step 4: Program and verify TFT output**

Program the board with the generated bitstream. Expected hardware result:

```text
The TFT displays a centered 640x480 scaled FmcPGA scene.
The left and right 80-pixel margins are black.
Reset returns the scene to the initial state.
At least one movement button changes the rendered view.
```

- [ ] **Step 5: Record hardware result**

Append this template to `docs\build-notes\fmcpga-minisys-tft.md` with actual observations:

```markdown
## Hardware Verification

Bitstream path: vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
TFT image: centered scaled scene visible
Reset: verified
Movement: verified with button input
Known issues: none observed during first smoke test
```

## Task 9: Prepare the Verilog Conversion Backlog

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\verilog-conversion-backlog.md`

- [ ] **Step 1: Create the conversion backlog**

Create `docs\build-notes\verilog-conversion-backlog.md` with:

```markdown
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
```

- [ ] **Step 2: Confirm no placeholders remain**

Run:

```powershell
Select-String -Path 'C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\*.md' -Pattern 'TO' + 'DO|TB' + 'D|implement la' + 'ter'
```

Expected: No matches.

## Self-Review

Spec coverage:

- Minisys board, Vivado 2018.3, TFT-first target, and `xc7a100tfgg484-1` are covered by Tasks 1, 4, 7, and 8.
- Reuse of validated TFT modules is covered by Tasks 1 through 4.
- Mixed VHDL plus Verilog architecture is covered by Tasks 5 and 6.
- 320x240 to 800x480 centered 2x mapping is covered by Tasks 2 and 3.
- Vivado IP regeneration is covered by Task 7.
- Hardware verification is covered by Task 8.
- Later all-Verilog migration is covered by Task 9.

Placeholder scan:

- The plan contains no unresolved placeholder markers.

Type consistency:

- Verilog top ports match `minisys_minecraft_tft.xdc` TFT naming.
- The frame-buffer address width is 17 bits and RGB width is 12 bits, matching FmcPGA `types.vhd` and `display_buffers.vhd`.
- The VHDL wrapper uses flat `std_logic` and `std_logic_vector` ports so Verilog can instantiate it.
