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
    "\.video_active\(video_on_d\)",
    "\.frame_active\(src_active_d\)",
    "\.buzzer\(buzzer\)",
    "\.selected_block\(sw\[4:0\]\)",
    "\.active\(video_on_d\)",
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
