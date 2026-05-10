# Minisys Minecraft Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the Minisys TFT Minecraft controls so S1-S4 only move, S5 places the selected block, `SW[4:0]` selects the block type, and one switch controls digging.

**Architecture:** Keep the existing Verilog board top and VHDL FmcPGA flat wrapper boundary. Add explicit flat control inputs for `place`, `dig`, and `selected_block`, then drive FmcPGA's existing `player_state_updater` manipulation ports from those signals.

**Tech Stack:** Vivado 2018.3, Verilog, VHDL 2008, PowerShell static checks, Minisys `xc7a100tfgg484-1`.

---

## File Structure

- Modify `C:\Users\32915\Desktop\shudiankeshe\rtl\top\minisys_fmcpga_tft_top.v`: keep S1-S4 as movement-only buttons; connect S5 to place; connect `SW[5]` to dig; connect `SW[4:0]` to selected block.
- Modify `C:\Users\32915\Desktop\shudiankeshe\rtl\vhdl\fmcpga_core_flat.vhd`: add flat ports `place_in`, `dig_in`, and `selected_block_in`; drive manipulation and selected block values from those new ports instead of temporary movement/up/down reuse.
- Create `C:\Users\32915\Desktop\shudiankeshe\scripts\check_control_mapping.ps1`: static check that the requested mapping is actually present.
- Modify `C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\fmcpga-minisys-tft.md`: document the final controls and rebuild commands.

## Control Mapping

Use the existing XDC mapping:

```text
S1 -> btn_up
S2 -> btn_down
S3 -> btn_left
S4 -> btn_right
S5 -> btn_action
S6 -> btn_reset
```

Final game mapping:

```text
S3 / btn_left   -> move forward
S4 / btn_right  -> move backward
S2 / btn_down   -> move left
S1 / btn_up     -> move right
S5 / btn_action -> place selected block
SW[4:0]         -> selected block id, clamped in hardware by using the lower 5 bits
SW[5]           -> dig selected block while asserted
S6 / btn_reset  -> reset
```

`SW[5]` is chosen for digging because all five user buttons are already assigned: S1-S4 for movement and S5 for placement. A switch is also easier to hold for repeated dig attempts.

## Task 1: Add a Failing Static Check

**Files:**
- Create: `C:\Users\32915\Desktop\shudiankeshe\scripts\check_control_mapping.ps1`

- [ ] **Step 1: Create the check script**

Create `scripts\check_control_mapping.ps1` with:

```powershell
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$topPath = Join-Path $root "rtl\top\minisys_fmcpga_tft_top.v"
$flatPath = Join-Path $root "rtl\vhdl\fmcpga_core_flat.vhd"

$top = Get-Content -LiteralPath $topPath -Raw
$flat = Get-Content -LiteralPath $flatPath -Raw

$requiredTopPatterns = @(
    "\.btn_front_in\(btn_left\)",
    "\.btn_back_in\(btn_right\)",
    "\.btn_left_in\(btn_down\)",
    "\.btn_right_in\(btn_up\)",
    "\.place_in\(btn_action\)",
    "\.dig_in\(sw\[5\]\)",
    "\.selected_block_in\(sw\[4:0\]\)"
)

foreach ($pattern in $requiredTopPatterns) {
    if ($top -notmatch $pattern) {
        Write-Host "Missing top-level mapping: $pattern"
        exit 1
    }
}

$requiredFlatPatterns = @(
    "place_in: in std_logic",
    "dig_in: in std_logic",
    "selected_block_in: in std_logic_vector\(4 downto 0\)",
    "left_click <= dig_in;",
    "right_click <= place_in;",
    "selected_block_int <= to_integer\(unsigned\(selected_block_in\)\);",
    "idx_target => idx_target_selected"
)

foreach ($pattern in $requiredFlatPatterns) {
    if ($flat -notmatch $pattern) {
        Write-Host "Missing flat-wrapper mapping: $pattern"
        exit 1
    }
}

Write-Host "Control mapping check passed."
```

- [ ] **Step 2: Run the check and verify it fails before implementation**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\32915\Desktop\shudiankeshe\scripts\check_control_mapping.ps1
```

Expected: FAIL with a message such as `Missing top-level mapping: \.place_in\(btn_action\)`.

## Task 2: Extend the VHDL Flat Wrapper Interface

**Files:**
- Modify: `C:\Users\32915\Desktop\shudiankeshe\rtl\vhdl\fmcpga_core_flat.vhd`

- [ ] **Step 1: Add flat control ports**

In `fmcpga_core_flat.vhd`, change the entity port list from:

```vhdl
btn_front_in, btn_back_in, btn_left_in, btn_right_in, btn_up_in, btn_down_in: in std_logic;

disp_read_clk: in std_logic;
```

to:

```vhdl
btn_front_in, btn_back_in, btn_left_in, btn_right_in, btn_up_in, btn_down_in: in std_logic;
place_in, dig_in: in std_logic;
selected_block_in: in std_logic_vector(BLOCK_TYPE_RADIX - 1 downto 0);

disp_read_clk: in std_logic;
```

- [ ] **Step 2: Add selected block helper signals**

Near the existing control signals:

```vhdl
signal left_click, right_click, last_item_click, next_item_click: std_logic;
```

add:

```vhdl
signal selected_block_int: int;
signal idx_target_selected: int;
```

- [ ] **Step 3: Drive explicit manipulation controls**

Replace the current bottom control assignments:

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

with:

```vhdl
move_lr_offset <= 127 when btn_right = '1' else -128 when btn_left = '1' else 0;
move_fb_offset <= 127 when btn_front = '1' else -128 when btn_back = '1' else 0;
move_ud_offset <= 0;
angle_lr_offset <= 0;
angle_ud_offset <= 0;
left_click <= dig_in;
right_click <= place_in;
last_item_click <= '0';
next_item_click <= '0';
selected_block_int <= to_integer(unsigned(selected_block_in));
idx_target_selected <= selected_block_int when right_click = '1' else idx_target;
```

- [ ] **Step 4: Route selected block into map modification**

In the `player_state_updater` port map, replace:

```vhdl
idx_target => idx_target,
```

with:

```vhdl
idx_target => idx_target,
```

Keep this port map unchanged because `player_state_updater` still determines whether the target is `block_p_inc` for place or `block_p_sel` for dig. Then replace the `map_modifier` connection:

```vhdl
idx_target => idx_target,
```

with:

```vhdl
idx_target => idx_target_selected,
```

Expected: Digging writes block id `0`; placing writes `SW[4:0]` instead of the internal inventory register.

## Task 3: Update the Verilog Top-Level Wiring

**Files:**
- Modify: `C:\Users\32915\Desktop\shudiankeshe\rtl\top\minisys_fmcpga_tft_top.v`

- [ ] **Step 1: Connect explicit control ports**

In the `fmcpga_core_flat u_core` instance, keep the movement lines:

```verilog
.btn_front_in(btn_left),
.btn_back_in(btn_right),
.btn_left_in(btn_down),
.btn_right_in(btn_up),
.btn_up_in(1'b0),
.btn_down_in(1'b0),
```

Add these explicit gameplay controls after the button ports:

```verilog
.place_in(btn_action),
.dig_in(sw[5]),
.selected_block_in(sw[4:0]),
```

Expected: S1-S4 are not connected to place, dig, vertical movement, or block selection.

- [ ] **Step 2: Update LED debug output**

Replace:

```verilog
assign led_y = sw[7:0];
```

with:

```verilog
assign led_y = {sw[5], btn_action, sw[4:0], src_active};
```

Expected: Yellow LEDs show dig switch, place button, selected block id, and frame active status.

## Task 4: Verify Static Checks

**Files:**
- Run: `C:\Users\32915\Desktop\shudiankeshe\scripts\check_control_mapping.ps1`
- Run: `C:\Users\32915\Desktop\shudiankeshe\scripts\check_sources.ps1`

- [ ] **Step 1: Run control mapping check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\32915\Desktop\shudiankeshe\scripts\check_control_mapping.ps1
```

Expected:

```text
Control mapping check passed.
```

- [ ] **Step 2: Run source presence check**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\32915\Desktop\shudiankeshe\scripts\check_sources.ps1
```

Expected:

```text
Source check passed.
```

- [ ] **Step 3: Scan for unresolved placeholder markers**

Run:

```powershell
Select-String -Path C:\Users\32915\Desktop\shudiankeshe\rtl\**\*.*,C:\Users\32915\Desktop\shudiankeshe\scripts\*.ps1,C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\*.md -Pattern "TO" + "DO|TB" + "D|implement la" + "ter"
```

Expected: no matches.

## Task 5: Update Build Notes and Rebuild

**Files:**
- Modify: `C:\Users\32915\Desktop\shudiankeshe\docs\build-notes\fmcpga-minisys-tft.md`

- [ ] **Step 1: Add final control instructions**

Append this section to `docs\build-notes\fmcpga-minisys-tft.md`:

```markdown
## Final Controls

S1: move right
S2: move left
S3: move forward
S4: move backward
S5: place block
SW[4:0]: selected block id
SW[5]: dig selected block while asserted
S6: reset

S1-S4 only move. S5 only places. Digging is controlled by SW[5].
```

- [ ] **Step 2: Rebuild in Vivado 2018.3**

Run in Vivado Tcl Console:

```tcl
cd C:/Users/32915/Desktop/shudiankeshe
open_project vivado_fmcpga_tft/fmcpga_minisys_tft.xpr
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1
wait_on_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

Expected: bitstream regenerates at:

```text
C:/Users/32915/Desktop/shudiankeshe/vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

- [ ] **Step 3: Program the board**

Run:

```tcl
open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE {C:/Users/32915/Desktop/shudiankeshe/vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
```

Expected hardware behavior:

```text
S1 moves right.
S2 moves left.
S3 moves forward.
S4 moves backward.
S5 places the block selected by SW[4:0].
SW[5] digs the selected block while asserted.
S6 resets the scene.
```

## Self-Review

Spec coverage:

- S1-S4 movement-only mapping is covered by Tasks 2 and 3.
- S5 place is covered by Tasks 2 and 3.
- `SW[4:0]` selected block id is covered by Tasks 2 and 3.
- Separate dig control using another switch is covered by Tasks 2 and 3.
- Verification and rebuild are covered by Tasks 4 and 5.

Placeholder scan:

- The plan contains no unresolved placeholder markers.

Type consistency:

- Verilog passes `sw[4:0]`, which matches VHDL `std_logic_vector(BLOCK_TYPE_RADIX - 1 downto 0)`.
- Place and dig are one-bit `std_logic` controls in VHDL and one-bit wires in Verilog.
- `idx_target_selected` remains an `int`, matching the existing `map_modifier.idx_target` port.
