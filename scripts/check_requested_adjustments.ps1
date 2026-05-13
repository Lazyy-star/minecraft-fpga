$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$mapper = Get-Content -LiteralPath (Join-Path $root "rtl\adapter\fmcpga_tft_read_mapper.v") -Raw
$top = Get-Content -LiteralPath (Join-Path $root "rtl\top\minisys_fmcpga_tft_top.v") -Raw

if ($mapper -notmatch "SRC_H - 1") {
    Write-Host "Frame mapper does not flip source Y yet."
    exit 1
}

$expectedConnections = @(
    "\.btn_front_in\(btn_left\)",
    "\.btn_back_in\(btn_right\)",
    "\.btn_left_in\(btn_down\)",
    "\.btn_right_in\(btn_up\)",
    "\.view_mode_in\(view_mode\)"
)

foreach ($pattern in $expectedConnections) {
    if ($top -notmatch $pattern) {
        Write-Host "Missing expected button mapping: $pattern"
        exit 1
    }
}

Write-Host "Requested adjustment check passed."
