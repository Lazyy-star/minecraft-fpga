# Audio, Rotation, and Held Block HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add buzzer-based background music and interaction sounds, `SW[6]` view rotation mode, and a lower-right selected-block HUD to the Minisys FmcPGA TFT project.

**Architecture:** Keep the ray-tracing pipeline stable. Add Verilog audio and HUD modules at the board shell, and make a small VHDL wrapper change to route existing button inputs either to movement or to view angle offsets. Use static PowerShell checks before Vivado synthesis.

**Tech Stack:** Vivado 2018.3, Verilog, VHDL 2008, PowerShell static checks, Minisys `xc7a100tfgg484-1`, buzzer on pin A19.

---

## File Structure

- Create `rtl/audio/buzzer_tone_gen.v`: turns a selected divider into a buzzer square wave.
- Create `rtl/audio/music_player.v`: emits a slow original square-wave melody as divider values.
- Create `rtl/audio/sfx_player.v`: emits short place and dig effect divider values.
- Create `rtl/audio/audio_controller.v`: gives sound effects priority over music and drives the buzzer.
- Create `rtl/adapter/held_block_hud_overlay.v`: overlays a selected-block color square onto RGB444 TFT pixels.
- Create `scripts/check_audio_rotation_hud.ps1`: verifies audio, rotation, HUD, XDC, and project-script wiring.
- Create `docs/build-notes/audio-rotation-hud.md`: documents controls, audio behavior, and hardware checks.
- Modify `rtl/top/minisys_fmcpga_tft_top.v`: add `buzzer`, audio wiring, `SW[6]` view mode, and HUD insertion.
- Modify `rtl/vhdl/fmcpga_core_flat.vhd`: add `view_mode_in` and route buttons to movement or angle offsets.
- Modify `constraints/minisys_fmcpga_tft.xdc`: constrain `buzzer` to A19.
- Modify `scripts/create_fmcpga_tft_project.tcl`: include `rtl/audio/*.v`.
- Modify `README.md` and `docs/build-notes/fmcpga-minisys-tft.md`: document new features.

## Task 1: Add the Static Check First

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\scripts\check_audio_rotation_hud.ps1`

- [ ] **Step 1: Create the failing static check**

Create `scripts\check_audio_rotation_hud.ps1` with:

```powershell
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$topPath = Join-Path $root "rtl\top\minisys_fmcpga_tft_top.v"
$flatPath = Join-Path $root "rtl\vhdl\fmcpga_core_flat.vhd"
$xdcPath = Join-Path $root "constraints\minisys_fmcpga_tft.xdc"
$projectPath = Join-Path $root "scripts\create_fmcpga_tft_project.tcl"
$hudPath = Join-Path $root "rtl\adapter\held_block_hud_overlay.v"
$audioDir = Join-Path $root "rtl\audio"

$top = Get-Content -LiteralPath $topPath -Raw
$flat = Get-Content -LiteralPath $flatPath -Raw
$xdc = Get-Content -LiteralPath $xdcPath -Raw
$project = Get-Content -LiteralPath $projectPath -Raw

$requiredFiles = @(
    "buzzer_tone_gen.v",
    "music_player.v",
    "sfx_player.v",
    "audio_controller.v"
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $audioDir $file
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Missing audio module: $path"
        exit 1
    }
}

if (-not (Test-Path -LiteralPath $hudPath)) {
    Write-Host "Missing HUD overlay: $hudPath"
    exit 1
}

$requiredTopPatterns = @(
    "output wire\s+buzzer",
    "\.view_mode_in\(sw\[6\]\)",
    "audio_controller\s+u_audio",
    "held_block_hud_overlay\s+u_hud",
    "\.buzzer\(buzzer\)",
    "\.selected_block\(sw\[4:0\]\)",
    "btn_action_d",
    "dig_d"
)

foreach ($pattern in $requiredTopPatterns) {
    if ($top -notmatch $pattern) {
        Write-Host "Missing top-level audio/rotation/HUD pattern: $pattern"
        exit 1
    }
}

$requiredFlatPatterns = @(
    "view_mode_in: in std_logic",
    "move_lr_offset <= 0 when view_mode_in = '1'",
    "move_fb_offset <= 0 when view_mode_in = '1'",
    "angle_lr_offset <= 127 when view_mode_in = '1' and btn_right = '1'",
    "angle_ud_offset <= 127 when view_mode_in = '1' and btn_front = '1'"
)

foreach ($pattern in $requiredFlatPatterns) {
    if ($flat -notmatch $pattern) {
        Write-Host "Missing flat-wrapper rotation pattern: $pattern"
        exit 1
    }
}

if ($xdc -notmatch "PACKAGE_PIN A19 \[get_ports buzzer\]") {
    Write-Host "Missing buzzer A19 constraint"
    exit 1
}

if ($project -notmatch "rtl/audio/\*.v") {
    Write-Host "Vivado project script does not add rtl/audio/*.v"
    exit 1
}

Write-Host "Audio, rotation, and HUD check passed."
```

- [ ] **Step 2: Run the check to confirm it fails before implementation**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL with `Missing audio module` or `Missing top-level audio/rotation/HUD pattern`.

- [ ] **Step 3: Commit the failing check**

Run:

```powershell
git add scripts\check_audio_rotation_hud.ps1
git commit -m "test: add audio rotation hud static check"
```

Expected: commit succeeds with only the check script staged.

## Task 2: Add Buzzer Tone Generation

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\rtl\audio\buzzer_tone_gen.v`

- [ ] **Step 1: Create the tone generator module**

Create `rtl\audio\buzzer_tone_gen.v` with:

```verilog
module buzzer_tone_gen (
    input  wire        clk,
    input  wire        rst,
    input  wire        tone_enable,
    input  wire [31:0] half_period_cycles,
    output reg         buzzer
);
    reg [31:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 32'd0;
            buzzer <= 1'b0;
        end else if (!tone_enable || half_period_cycles == 32'd0) begin
            counter <= 32'd0;
            buzzer <= 1'b0;
        end else if (counter >= half_period_cycles) begin
            counter <= 32'd0;
            buzzer <= ~buzzer;
        end else begin
            counter <= counter + 32'd1;
        end
    end
endmodule
```

- [ ] **Step 2: Run the static check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL, now reporting the next missing audio module.

- [ ] **Step 3: Commit the tone generator**

Run:

```powershell
git add rtl\audio\buzzer_tone_gen.v
git commit -m "feat: add buzzer tone generator"
```

Expected: commit succeeds.

## Task 3: Add Background Music Player

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\rtl\audio\music_player.v`

- [ ] **Step 1: Create the music player module**

Create `rtl\audio\music_player.v` with:

```verilog
module music_player (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    output reg         tone_enable,
    output reg  [31:0] half_period_cycles
);
    localparam integer NOTE_TICKS = 25_000_000;
    localparam [31:0] REST = 32'd0;
    localparam [31:0] C4   = 32'd191_113;
    localparam [31:0] D4   = 32'd170_262;
    localparam [31:0] E4   = 32'd151_686;
    localparam [31:0] G4   = 32'd127_552;
    localparam [31:0] A4   = 32'd113_636;
    localparam [31:0] C5   = 32'd95_556;

    reg [24:0] tick_count;
    reg [4:0]  note_index;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_count <= 25'd0;
            note_index <= 5'd0;
        end else if (!enable) begin
            tick_count <= 25'd0;
            note_index <= note_index;
        end else if (tick_count == NOTE_TICKS - 1) begin
            tick_count <= 25'd0;
            note_index <= (note_index == 5'd23) ? 5'd0 : note_index + 5'd1;
        end else begin
            tick_count <= tick_count + 25'd1;
        end
    end

    always @* begin
        case (note_index)
            5'd0:  half_period_cycles = E4;
            5'd1:  half_period_cycles = REST;
            5'd2:  half_period_cycles = G4;
            5'd3:  half_period_cycles = REST;
            5'd4:  half_period_cycles = A4;
            5'd5:  half_period_cycles = REST;
            5'd6:  half_period_cycles = G4;
            5'd7:  half_period_cycles = REST;
            5'd8:  half_period_cycles = E4;
            5'd9:  half_period_cycles = REST;
            5'd10: half_period_cycles = D4;
            5'd11: half_period_cycles = REST;
            5'd12: half_period_cycles = C4;
            5'd13: half_period_cycles = REST;
            5'd14: half_period_cycles = D4;
            5'd15: half_period_cycles = REST;
            5'd16: half_period_cycles = E4;
            5'd17: half_period_cycles = G4;
            5'd18: half_period_cycles = C5;
            5'd19: half_period_cycles = REST;
            5'd20: half_period_cycles = A4;
            5'd21: half_period_cycles = REST;
            5'd22: half_period_cycles = G4;
            default: half_period_cycles = REST;
        endcase
        tone_enable = enable && half_period_cycles != REST;
    end
endmodule
```

- [ ] **Step 2: Run the static check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL, now reporting the next missing audio module.

- [ ] **Step 3: Commit the music player**

Run:

```powershell
git add rtl\audio\music_player.v
git commit -m "feat: add buzzer background music player"
```

Expected: commit succeeds.

## Task 4: Add Interaction Sound Effects

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\rtl\audio\sfx_player.v`

- [ ] **Step 1: Create the sound-effect player**

Create `rtl\audio\sfx_player.v` with:

```verilog
module sfx_player (
    input  wire        clk,
    input  wire        rst,
    input  wire        place_event,
    input  wire        dig_event,
    output reg         active,
    output reg         tone_enable,
    output reg  [31:0] half_period_cycles
);
    localparam [1:0] SFX_NONE  = 2'd0;
    localparam [1:0] SFX_PLACE = 2'd1;
    localparam [1:0] SFX_DIG   = 2'd2;

    localparam integer STEP_TICKS = 5_000_000;
    localparam [31:0] E5 = 32'd75_843;
    localparam [31:0] C5 = 32'd95_556;
    localparam [31:0] A4 = 32'd113_636;
    localparam [31:0] G3 = 32'd255_102;
    localparam [31:0] C3 = 32'd382_226;

    reg [1:0] effect;
    reg [2:0] step_index;
    reg [22:0] step_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            effect <= SFX_NONE;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (place_event) begin
            effect <= SFX_PLACE;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (dig_event) begin
            effect <= SFX_DIG;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (effect != SFX_NONE) begin
            if (step_count == STEP_TICKS - 1) begin
                step_count <= 23'd0;
                if (step_index == 3'd2) begin
                    effect <= SFX_NONE;
                    step_index <= 3'd0;
                end else begin
                    step_index <= step_index + 3'd1;
                end
            end else begin
                step_count <= step_count + 23'd1;
            end
        end
    end

    always @* begin
        active = effect != SFX_NONE;
        tone_enable = active;
        case (effect)
            SFX_PLACE: begin
                case (step_index)
                    3'd0: half_period_cycles = C5;
                    3'd1: half_period_cycles = E5;
                    default: half_period_cycles = A4;
                endcase
            end
            SFX_DIG: begin
                case (step_index)
                    3'd0: half_period_cycles = G3;
                    3'd1: half_period_cycles = C3;
                    default: half_period_cycles = G3;
                endcase
            end
            default: begin
                half_period_cycles = 32'd0;
                tone_enable = 1'b0;
            end
        endcase
    end
endmodule
```

- [ ] **Step 2: Run the static check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL, now reporting `audio_controller.v` or top-level wiring.

- [ ] **Step 3: Commit the sound-effect player**

Run:

```powershell
git add rtl\audio\sfx_player.v
git commit -m "feat: add buzzer sound effects"
```

Expected: commit succeeds.

## Task 5: Add Audio Controller

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\rtl\audio\audio_controller.v`

- [ ] **Step 1: Create the audio controller**

Create `rtl\audio\audio_controller.v` with:

```verilog
module audio_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire        music_enable,
    input  wire        place_event,
    input  wire        dig_event,
    input  wire [4:0]  selected_block,
    output wire        buzzer
);
    wire        music_tone_enable;
    wire [31:0] music_half_period;
    wire        sfx_active;
    wire        sfx_tone_enable;
    wire [31:0] sfx_half_period;
    wire        mixed_enable;
    wire [31:0] mixed_half_period;

    music_player u_music (
        .clk(clk),
        .rst(rst),
        .enable(music_enable),
        .tone_enable(music_tone_enable),
        .half_period_cycles(music_half_period)
    );

    sfx_player u_sfx (
        .clk(clk),
        .rst(rst),
        .place_event(place_event),
        .dig_event(dig_event),
        .active(sfx_active),
        .tone_enable(sfx_tone_enable),
        .half_period_cycles(sfx_half_period)
    );

    assign mixed_enable = sfx_active ? sfx_tone_enable : music_tone_enable;
    assign mixed_half_period = sfx_active ? sfx_half_period : music_half_period;

    buzzer_tone_gen u_tone (
        .clk(clk),
        .rst(rst),
        .tone_enable(mixed_enable),
        .half_period_cycles(mixed_half_period),
        .buzzer(buzzer)
    );
endmodule
```

The `selected_block` input is intentionally present in the controller interface so future block-specific effects can be added without changing the top-level audio wiring. It does not affect the first implementation.

- [ ] **Step 2: Run the static check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL, now reporting missing top-level, HUD, XDC, project, or VHDL wiring.

- [ ] **Step 3: Commit the audio controller**

Run:

```powershell
git add rtl\audio\audio_controller.v
git commit -m "feat: add buzzer audio controller"
```

Expected: commit succeeds.

## Task 6: Wire Audio Into the Top Level and XDC

**Files:**
- Modify: `D:\codes\mc\minecraft-fpga\rtl\top\minisys_fmcpga_tft_top.v`
- Modify: `D:\codes\mc\minecraft-fpga\constraints\minisys_fmcpga_tft.xdc`
- Modify: `D:\codes\mc\minecraft-fpga\scripts\create_fmcpga_tft_project.tcl`

- [ ] **Step 1: Add the top-level buzzer port**

In `rtl\top\minisys_fmcpga_tft_top.v`, change the last port from:

```verilog
    output wire        TFT_MODE_O
);
```

to:

```verilog
    output wire        TFT_MODE_O,
    output wire        buzzer
);
```

- [ ] **Step 2: Add audio event edge detection**

After the existing `current_item_ones` wire declaration, add:

```verilog
    reg btn_action_d;
    reg dig_d;
    wire place_event;
    wire dig_event;
```

After the display timing `always` block, add:

```verilog
    always @(posedge clk_100m or posedge rst) begin
        if (rst) begin
            btn_action_d <= 1'b0;
            dig_d <= 1'b0;
        end else begin
            btn_action_d <= btn_action;
            dig_d <= sw[5];
        end
    end

    assign place_event = btn_action & ~btn_action_d;
    assign dig_event = sw[5] & ~dig_d;
```

- [ ] **Step 3: Instantiate the audio controller**

Before `fmcpga_core_flat u_core`, add:

```verilog
    audio_controller u_audio (
        .clk(clk_100m),
        .rst(rst),
        .music_enable(1'b1),
        .place_event(place_event),
        .dig_event(dig_event),
        .selected_block(sw[4:0]),
        .buzzer(buzzer)
    );
```

- [ ] **Step 4: Add the buzzer XDC constraint**

In `constraints\minisys_fmcpga_tft.xdc`, after the clock section, add:

```tcl
## Buzzer
set_property PACKAGE_PIN A19 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
```

- [ ] **Step 5: Add audio sources to the Vivado project script**

In `scripts\create_fmcpga_tft_project.tcl`, after:

```tcl
add_files -norecurse [glob ./rtl/adapter/*.v]
```

add:

```tcl
add_files -norecurse [glob ./rtl/audio/*.v]
```

- [ ] **Step 6: Run the static check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: FAIL, now reporting HUD or rotation wiring.

- [ ] **Step 7: Commit audio wiring**

Run:

```powershell
git add rtl\top\minisys_fmcpga_tft_top.v constraints\minisys_fmcpga_tft.xdc scripts\create_fmcpga_tft_project.tcl
git commit -m "feat: wire buzzer audio output"
```

Expected: commit succeeds.

## Task 7: Add View Rotation Mode

**Files:**
- Modify: `D:\codes\mc\minecraft-fpga\rtl\vhdl\fmcpga_core_flat.vhd`
- Modify: `D:\codes\mc\minecraft-fpga\rtl\top\minisys_fmcpga_tft_top.v`

- [ ] **Step 1: Add the VHDL flat-wrapper port**

In `rtl\vhdl\fmcpga_core_flat.vhd`, change:

```vhdl
        place_in, dig_in: in std_logic;
        selected_block_in: in std_logic_vector(BLOCK_TYPE_RADIX - 1 downto 0);
```

to:

```vhdl
        place_in, dig_in: in std_logic;
        view_mode_in: in std_logic;
        selected_block_in: in std_logic_vector(BLOCK_TYPE_RADIX - 1 downto 0);
```

- [ ] **Step 2: Replace movement and angle assignments**

Replace the current assignments:

```vhdl
        move_lr_offset <= 127 when btn_right = '1' else -128 when btn_left = '1' else 0;
        move_fb_offset <= 127 when btn_front = '1' else -128 when btn_back = '1' else 0;
        move_ud_offset <= 0;
        angle_lr_offset <= 0;
        angle_ud_offset <= 0;
```

with:

```vhdl
        move_lr_offset <= 0 when view_mode_in = '1' else
            127 when btn_right = '1' else
            -128 when btn_left = '1' else
            0;
        move_fb_offset <= 0 when view_mode_in = '1' else
            127 when btn_front = '1' else
            -128 when btn_back = '1' else
            0;
        move_ud_offset <= 0;
        angle_lr_offset <= 127 when view_mode_in = '1' and btn_right = '1' else
            -128 when view_mode_in = '1' and btn_left = '1' else
            0;
        angle_ud_offset <= 127 when view_mode_in = '1' and btn_front = '1' else
            -128 when view_mode_in = '1' and btn_back = '1' else
            0;
```

- [ ] **Step 3: Wire `SW[6]` from the Verilog top**

In the `fmcpga_core_flat u_core` instance in `rtl\top\minisys_fmcpga_tft_top.v`, after:

```verilog
        .dig_in(sw[5]),
```

add:

```verilog
        .view_mode_in(sw[6]),
```

- [ ] **Step 4: Update LED debug output**

Replace:

```verilog
    assign led_y = {sw[5], btn_action, sw[4:0], src_active};
```

with:

```verilog
    assign led_y = {sw[6], sw[5], btn_action, sw[4:0]};
```

This makes view mode visible on `led_y[7]`.

- [ ] **Step 5: Run control and feature checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_control_mapping.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: first check passes, second check still fails if HUD is not implemented yet.

- [ ] **Step 6: Commit rotation mode**

Run:

```powershell
git add rtl\vhdl\fmcpga_core_flat.vhd rtl\top\minisys_fmcpga_tft_top.v
git commit -m "feat: add switchable view rotation mode"
```

Expected: commit succeeds.

## Task 8: Add Held Block HUD Overlay

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\rtl\adapter\held_block_hud_overlay.v`
- Modify: `D:\codes\mc\minecraft-fpga\rtl\top\minisys_fmcpga_tft_top.v`

- [ ] **Step 1: Create the HUD overlay module**

Create `rtl\adapter\held_block_hud_overlay.v` with:

```verilog
module held_block_hud_overlay (
    input  wire        active,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [4:0]  selected_block,
    input  wire [11:0] rgb_in,
    output wire [11:0] rgb_out
);
    localparam [9:0] HUD_X0 = 10'd704;
    localparam [9:0] HUD_Y0 = 10'd384;
    localparam [9:0] HUD_SIZE = 10'd56;
    localparam [9:0] HUD_X1 = HUD_X0 + HUD_SIZE;
    localparam [9:0] HUD_Y1 = HUD_Y0 + HUD_SIZE;

    wire in_hud = active && pix_x >= HUD_X0 && pix_x < HUD_X1 && pix_y >= HUD_Y0 && pix_y < HUD_Y1;
    wire border = in_hud && (
        pix_x < HUD_X0 + 10'd4 ||
        pix_x >= HUD_X1 - 10'd4 ||
        pix_y < HUD_Y0 + 10'd4 ||
        pix_y >= HUD_Y1 - 10'd4
    );
    wire highlight = in_hud && !border && (pix_x < HUD_X0 + 10'd10 || pix_y < HUD_Y0 + 10'd10);

    reg [11:0] block_color;

    always @* begin
        case (selected_block)
            5'd0:  block_color = 12'h000;
            5'd1:  block_color = 12'h6a4;
            5'd2:  block_color = 12'h573;
            5'd3:  block_color = 12'h875;
            5'd4:  block_color = 12'h888;
            5'd5:  block_color = 12'hb74;
            5'd6:  block_color = 12'h3b3;
            5'd7:  block_color = 12'h222;
            5'd8:  block_color = 12'h39f;
            5'd9:  block_color = 12'h26c;
            5'd10: block_color = 12'hf53;
            5'd11: block_color = 12'hfa0;
            5'd12: block_color = 12'hdc8;
            5'd13: block_color = 12'h8a8;
            5'd14: block_color = 12'hecc;
            5'd15: block_color = 12'hddd;
            5'd16: block_color = 12'h111;
            5'd17: block_color = 12'h963;
            5'd18: block_color = 12'h4a4;
            5'd19: block_color = 12'hcc9;
            5'd20: block_color = 12'h9df;
            5'd21: block_color = 12'h36a;
            5'd22: block_color = 12'h25d;
            5'd23: block_color = 12'hd33;
            default: block_color = 12'hf0f;
        endcase
    end

    assign rgb_out =
        border ? 12'h111 :
        highlight ? 12'hfff :
        in_hud ? block_color :
        rgb_in;
endmodule
```

- [ ] **Step 2: Add delayed pixel coordinates in the top**

In `rtl\top\minisys_fmcpga_tft_top.v`, after:

```verilog
    reg  vs_d;
```

add:

```verilog
    reg [9:0] pix_x_d;
    reg [9:0] pix_y_d;
```

Inside the existing `always @(posedge clk_tft or posedge rst)` reset branch, add:

```verilog
            pix_x_d <= 10'd0;
            pix_y_d <= 10'd0;
```

Inside the non-reset branch, add:

```verilog
            pix_x_d <= pix_x;
            pix_y_d <= pix_y;
```

- [ ] **Step 3: Insert HUD before RGB conversion**

After the framebuffer data wires, add:

```verilog
    wire [11:0] hud_rgb444;
```

Before `fmcpga_rgb444_to_rgb323 u_rgb`, add:

```verilog
    held_block_hud_overlay u_hud (
        .active(src_active_d),
        .pix_x(pix_x_d),
        .pix_y(pix_y_d),
        .selected_block(sw[4:0]),
        .rgb_in(fb_rgb444),
        .rgb_out(hud_rgb444)
    );
```

Change the RGB converter connection from:

```verilog
        .rgb444(fb_rgb444),
```

to:

```verilog
        .rgb444(hud_rgb444),
```

- [ ] **Step 4: Run display and feature checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_display_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected: both checks pass if all prior wiring is complete.

- [ ] **Step 5: Commit HUD overlay**

Run:

```powershell
git add rtl\adapter\held_block_hud_overlay.v rtl\top\minisys_fmcpga_tft_top.v
git commit -m "feat: add selected block hud overlay"
```

Expected: commit succeeds.

## Task 9: Update Documentation

**Files:**
- Create: `D:\codes\mc\minecraft-fpga\docs\build-notes\audio-rotation-hud.md`
- Modify: `D:\codes\mc\minecraft-fpga\README.md`
- Modify: `D:\codes\mc\minecraft-fpga\docs\build-notes\fmcpga-minisys-tft.md`

- [ ] **Step 1: Create feature build notes**

Create `docs\build-notes\audio-rotation-hud.md` with:

```markdown
# Audio, Rotation, and Held Block HUD Notes

## Audio

The Minisys buzzer is driven from FPGA pin A19 through the top-level `buzzer` output.

The implementation uses square-wave tones:

- Background music is a slow original melody generated by `rtl/audio/music_player.v`.
- Place and dig effects are generated by `rtl/audio/sfx_player.v`.
- Sound effects take priority over music in `rtl/audio/audio_controller.v`.

The audio is inspired by the calm pacing and simple cues of voxel sandbox games. It does not use Minecraft music, samples, or exact arrangements.

## Controls

```text
SW[6] = 0:
  S1: move right
  S2: move left
  S3: move forward
  S4: move backward

SW[6] = 1:
  S1: rotate view right
  S2: rotate view left
  S3: rotate view up
  S4: rotate view down

Always:
  S5: place selected block and play place sound
  SW[5]: dig mode and play dig sound on rising edge
  SW[4:0]: selected block id
  S6: reset
```

## HUD

The lower-right TFT overlay shows a color-coded square for `SW[4:0]`. It is inserted after framebuffer read and before RGB444-to-RGB323 conversion.

## Checks

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_audio_rotation_hud.ps1
```

Expected:

```text
Audio, rotation, and HUD check passed.
```
```

- [ ] **Step 2: Update README controls and layout**

In `README.md`, add `rtl/audio/` to the directory layout:

```markdown
- `rtl/audio/`: buzzer background music and interaction sound-effect modules
```

Replace the Controls section with:

```markdown
## Controls

- `S1`: move right, or rotate view right when `SW[6] = 1`
- `S2`: move left, or rotate view left when `SW[6] = 1`
- `S3`: move forward, or rotate view up when `SW[6] = 1`
- `S4`: move backward, or rotate view down when `SW[6] = 1`
- `S5`: action button, places the selected block
- `S6`: reset
- `SW[4:0]`: selected block id, recommended range `0` to `23`
- `SW[5]`: action mode, `0` = place selected block, `1` = dig selected block
- `SW[6]`: view mode, `0` = movement, `1` = rotate view

The lower-right TFT HUD shows the current `SW[4:0]` selected block. The buzzer on pin A19 plays background music and short interaction sounds.
```

- [ ] **Step 3: Update existing build notes**

Append this section to `docs\build-notes\fmcpga-minisys-tft.md`:

```markdown
## Audio, Rotation, and Held Block HUD

The top-level design now drives the Minisys buzzer on pin A19 through `buzzer`.

`SW[6]` selects movement or view-rotation mode. In movement mode, S1-S4 move the player. In view mode, S1-S4 rotate the camera and do not move the player.

The selected block is shown by a lower-right TFT HUD overlay. The HUD uses a compact RGB444 color palette keyed by `SW[4:0]`.

Run `scripts/check_audio_rotation_hud.ps1` after changes to audio, controls, display overlay, or project source lists.
```

- [ ] **Step 4: Commit documentation**

Run:

```powershell
git add README.md docs\build-notes\fmcpga-minisys-tft.md docs\build-notes\audio-rotation-hud.md
git commit -m "docs: describe audio rotation and hud controls"
```

Expected: commit succeeds.

## Task 10: Run Full Static Verification

**Files:**
- Run-only task.

- [ ] **Step 1: Run all existing checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_sources.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_display_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_control_mapping.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_requested_adjustments.ps1
powershell -ExecutionPolicy Bypass -File scripts\check_audio_rotation_hud.ps1
```

Expected:

```text
Source check passed.
Display pipeline check passed.
Control mapping check passed.
Requested adjustment check passed.
Audio, rotation, and HUD check passed.
```

- [ ] **Step 2: Check git status**

Run:

```powershell
git status --short
```

Expected: no uncommitted files except intentional Vivado-generated directories if synthesis has been run locally.

## Task 11: Rebuild Vivado Project

**Files:**
- Run-only task.

- [ ] **Step 1: Recreate the Vivado project**

In Vivado 2018.3 Tcl Console, run:

```tcl
cd D:/codes/mc/minecraft-fpga
source scripts/create_fmcpga_tft_project.tcl
```

Expected:

```text
Created Vivado project: ./vivado_fmcpga_tft/fmcpga_minisys_tft.xpr
Top module: minisys_fmcpga_tft_top
```

- [ ] **Step 2: Run synthesis and implementation**

In the same Vivado Tcl Console, run:

```tcl
source scripts/run_fmcpga_tft_build.tcl
```

Expected: synthesis, implementation, and bitstream generation complete. Generated bitstream path:

```text
vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

- [ ] **Step 3: If synthesis reports an unused `selected_block` warning in `audio_controller.v`, accept it**

Expected: `selected_block` may be unused in the first audio controller. That is intentional because the controller interface reserves block-specific effects for a later feature. Do not remove it unless the top-level check script is updated at the same time.

## Task 12: Hardware Verification

**Files:**
- Run-only task.

- [ ] **Step 1: Program the board**

In Vivado Tcl Console, run:

```tcl
open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE {D:/codes/mc/minecraft-fpga/vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
```

Expected: the board programs without hardware-manager errors.

- [ ] **Step 2: Verify audio**

Expected results:

```text
After reset, the buzzer plays a sparse background melody.
Pressing S5 plays a short higher-place sound.
Switching SW[5] from 0 to 1 plays a short lower-dig sound once.
Holding SW[5] does not continuously restart the dig sound.
```

- [ ] **Step 3: Verify rotation mode**

Expected results:

```text
With SW[6] = 0, S1-S4 move the player as before.
With SW[6] = 1, S1-S4 rotate the view and do not translate the player.
LED Y7 follows SW[6].
```

- [ ] **Step 4: Verify HUD**

Expected results:

```text
The lower-right TFT area contains a bordered selected-block square.
Changing SW[4:0] changes the square color.
The main 3D scene remains centered, scaled, and stable.
```

## Self-Review

Spec coverage:

- Background music is implemented by Tasks 2, 3, 5, and 6.
- Interaction sound effects are implemented by Tasks 4, 5, and 6.
- Rotation view mode is implemented by Task 7.
- Held selected block display is implemented by Task 8.
- Documentation and verification are implemented by Tasks 9 through 12.

Placeholder scan:

- No unresolved placeholder markers are present.

Type consistency:

- `selected_block` is 5 bits in Verilog and remains sourced from `sw[4:0]`.
- `view_mode_in` is a VHDL `std_logic` and is driven by one Verilog bit, `sw[6]`.
- `buzzer` is a one-bit top-level output constrained to A19.
- HUD pixels remain RGB444 before the existing RGB323 conversion.
