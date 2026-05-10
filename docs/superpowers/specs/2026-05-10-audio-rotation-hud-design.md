# Audio, Rotation, and Held Block HUD Design

## Context

The current project is a Vivado 2018.3 mixed-language Minisys FPGA port of the FmcPGA Minecraft-like renderer. The Verilog top-level owns Minisys board IO, TFT timing, frame-buffer address mapping, and RGB output. The VHDL `fmcpga_core_flat` wrapper owns the original render pipeline, map storage, player state, and display buffers.

The Minisys board includes a buzzer connected to FPGA pin A19. The buzzer is driven by a digital signal whose frequency determines the audible pitch. The current project does not expose this pin in the top-level module or XDC.

The requested feature set is:

1. Background music inspired by the feel of Minecraft music.
2. Interaction sound effects inspired by the feel of Minecraft effects.
3. Rotatable view control.
4. A visible in-hand indicator for the currently selected block.

The audio implementation will use original simplified melodies and short generated tones. It will not copy Minecraft's original music, sound samples, or exact protected arrangements.

## Goals

1. Add a `buzzer` output on Minisys pin A19.
2. Generate simple background music on the buzzer using note tables and square-wave tone generation.
3. Generate short interaction sound effects for place and dig actions.
4. Add `SW[6]` as a view-mode switch:
   - `SW[6] = 0`: S1-S4 keep their existing movement behavior.
   - `SW[6] = 1`: S1/S2 rotate view left/right, and S3/S4 rotate view up/down.
5. Display the currently selected block in the lower-right area of the TFT output as a compact HUD overlay.
6. Keep the original FmcPGA ray-tracing pipeline stable and avoid changing the high-risk `pipeline_process.vhd` module.

## Non-Goals

1. Do not play sampled PCM audio.
2. Do not implement I2S, external DAC, or multi-channel audio output.
3. Do not reproduce Minecraft's original copyrighted music or sound assets.
4. Do not render a full 3D first-person hand model.
5. Do not change the core map format, texture ROM format, or ray traversal pipeline.

## Architecture

The feature will be implemented as a conservative Verilog board-level extension plus a small VHDL control update.

Audio will live in `rtl/audio/`. A music player emits note requests from a small ROM-style table. A sound-effect player emits short event-driven tone sequences. A mixer chooses sound effects over background music, then a tone generator converts the selected frequency into a buzzer square wave.

Rotation will reuse the existing `angle_lr_offset` and `angle_ud_offset` inputs to `player_state_updater`. The Verilog top will pass a new `view_mode_in` signal to `fmcpga_core_flat`. The flat wrapper will gate movement and rotation based on that mode.

The held-block HUD will live in the TFT output path, after RGB444 framebuffer read and before RGB323 conversion. It will overlay a stable lower-right square region using a simple block-id color palette. This avoids modifying the ray tracer or display-buffer write path.

## Controls

Existing physical controls remain:

```text
S1 -> btn_up
S2 -> btn_down
S3 -> btn_left
S4 -> btn_right
S5 -> btn_action
S6 -> btn_reset
SW[4:0] -> selected block id
SW[5] -> dig mode
```

New control:

```text
SW[6] -> view mode
```

Final gameplay mapping:

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
  S5: place selected block
  SW[5]: dig selected block while asserted
  SW[4:0]: selected block id
  S6: reset
```

## Audio Design

The top-level module will add:

```verilog
output wire buzzer
```

The XDC will add:

```tcl
set_property PACKAGE_PIN A19 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
```

The audio subsystem will run from `clk_100m`. It will expose event inputs from existing controls:

```verilog
audio_controller u_audio (
    .clk(clk_100m),
    .rst(rst),
    .music_enable(1'b1),
    .place_event(place_event),
    .dig_active(sw[5]),
    .dig_event(dig_event),
    .selected_block(sw[4:0]),
    .buzzer(buzzer)
);
```

`place_event` will be a one-clock pulse on the rising edge of `btn_action`. `dig_event` will be a one-clock pulse on the rising edge of `sw[5]`, so holding dig does not continuously restart the sound effect.

The background music will be a slow, sparse, original melody using simple integer frequency values. It will include rests so the buzzer is not constantly active. The effect is intentionally simple because the board output is a buzzer, not a speaker DAC.

Sound-effect priority:

1. Place effect.
2. Dig effect.
3. Background music.

When an effect is active, the background music continues stepping internally but is muted at the mixer output. After the effect ends, the buzzer returns to the current background note.

## Rotation Design

`fmcpga_core_flat` will gain:

```vhdl
view_mode_in: in std_logic;
```

When `view_mode_in = '0'`, current movement behavior remains:

```vhdl
move_lr_offset <= 127 when btn_right = '1' else -128 when btn_left = '1' else 0;
move_fb_offset <= 127 when btn_front = '1' else -128 when btn_back = '1' else 0;
angle_lr_offset <= 0;
angle_ud_offset <= 0;
```

When `view_mode_in = '1'`, movement offsets become zero and button inputs drive rotation:

```vhdl
move_lr_offset <= 0;
move_fb_offset <= 0;
angle_lr_offset <= 127 when btn_right = '1' else -128 when btn_left = '1' else 0;
angle_ud_offset <= 127 when btn_front = '1' else -128 when btn_back = '1' else 0;
```

The design keeps vertical movement disabled. It only changes view angles.

## Held Block HUD Design

The Verilog top currently reads `fb_rgb444` from the FmcPGA display buffer and sends it directly into `fmcpga_rgb444_to_rgb323`. The HUD overlay will be inserted between those two steps:

```text
fb_rgb444
  -> held_block_hud_overlay
  -> rgb444_with_hud
  -> fmcpga_rgb444_to_rgb323
```

The overlay module will receive:

```verilog
input wire        active;
input wire [9:0]  pix_x;
input wire [9:0]  pix_y;
input wire [4:0]  selected_block;
input wire [11:0] rgb_in;
output wire [11:0] rgb_out;
```

The HUD region will be a fixed lower-right square in TFT coordinates. It will draw:

1. A dark border.
2. A filled inner square colored by `selected_block`.
3. A small highlight edge to make the square visible over bright backgrounds.

The palette will map block ids 0 through 23 to approximate RGB444 colors. Values above the known range will wrap or use a fallback magenta/white debug color. The HUD will be visible only when `active` is high.

This implementation deliberately uses a color palette instead of sampling the texture ROM. Texture-ROM sampling can be added later after the simple overlay is proven.

## Files

Expected new files:

```text
rtl/audio/buzzer_tone_gen.v
rtl/audio/music_player.v
rtl/audio/sfx_player.v
rtl/audio/audio_controller.v
rtl/adapter/held_block_hud_overlay.v
scripts/check_audio_rotation_hud.ps1
docs/build-notes/audio-rotation-hud.md
```

Expected modified files:

```text
rtl/top/minisys_fmcpga_tft_top.v
rtl/vhdl/fmcpga_core_flat.vhd
constraints/minisys_fmcpga_tft.xdc
scripts/create_fmcpga_tft_project.tcl
README.md
docs/build-notes/fmcpga-minisys-tft.md
```

## Verification

Static verification will include a PowerShell check script that confirms:

1. `buzzer` exists in the top-level port list.
2. `buzzer` is constrained to pin A19.
3. `rtl/audio/*.v` is added to the Vivado project script.
4. `audio_controller` is instantiated in `minisys_fmcpga_tft_top.v`.
5. `view_mode_in` is wired from `sw[6]` to `fmcpga_core_flat`.
6. `angle_lr_offset` and `angle_ud_offset` are no longer fixed to zero.
7. `held_block_hud_overlay` is inserted before RGB444-to-RGB323 conversion.

Build verification will reuse:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_sources.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_display_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_control_mapping.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_requested_adjustments.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_audio_rotation_hud.ps1
```

Hardware verification will confirm:

1. Background music is audible after reset.
2. S5 triggers a place sound.
3. Switching `SW[5]` on triggers a dig sound.
4. With `SW[6] = 0`, S1-S4 move as before.
5. With `SW[6] = 1`, S1-S4 rotate view and do not move the player.
6. The lower-right HUD changes color when `SW[4:0]` changes.
7. TFT rendering remains centered and stable.

## Risks

1. The buzzer can only produce square-wave tones. The music and sound effects will be recognizable as simple cues, not high-fidelity audio.
2. If `btn_action` and `sw[5]` are not debounced in the Verilog audio event path, effects may retrigger. The implementation should add edge detection and use existing debounced signals where practical.
3. `SW[6]` changes the meaning of movement buttons. The documentation and LED debug output should make this mode visible enough for hardware testing.
4. HUD overlay timing must use pixel signals aligned with `fb_rgb444`; otherwise the HUD can shift by one pixel or appear with stale color. The implementation should use the same delayed active/video timing stage already used for framebuffer data.
5. The existing `$readmemh` absolute paths in IP replacement modules remain a separate portability issue and should be fixed in a follow-up or before broad reuse.

## Self-Review

Spec coverage:

- Background music is covered by the audio subsystem and `music_player`.
- Interaction sound effects are covered by `sfx_player` and event inputs.
- Rotation is covered by `SW[6]` view mode and `angle_lr_offset` / `angle_ud_offset`.
- Held selected block display is covered by `held_block_hud_overlay`.

Placeholder scan:

- No unresolved placeholder markers remain.

Consistency:

- The design uses `clk_100m` for audio and the existing `clk_tft` display path for HUD placement.
- The selected block source remains `sw[4:0]`.
- The design does not alter `pipeline_process.vhd`.
