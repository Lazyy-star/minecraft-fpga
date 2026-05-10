$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$topPath = Join-Path $root "rtl\top\minisys_fmcpga_tft_top.v"
$top = Get-Content -LiteralPath $topPath -Raw

$requiredPatterns = @(
    "wire\s+hs_raw;",
    "wire\s+vs_raw;",
    "wire\s+video_on_raw;",
    "reg\s+hs_d;",
    "reg\s+vs_d;",
    "reg\s+video_on_d;",
    "\.hsync\(hs_raw\)",
    "\.vsync\(vs_raw\)",
    "\.video_on\(video_on_raw\)",
    "\.video_on\(video_on_raw\)",
    "src_active_d <= src_active;",
    "video_on_d <= video_on_raw;",
    "hs_d <= hs_raw;",
    "vs_d <= vs_raw;",
    "assign TFT_CLK_O = ~clk_tft;",
    "assign TFT_DE_O = video_on_d;",
    "assign TFT_HSYNC_O = hs_d;",
    "assign TFT_VSYNC_O = vs_d;"
)

foreach ($pattern in $requiredPatterns) {
    if ($top -notmatch $pattern) {
        Write-Host "Missing display pipeline pattern: $pattern"
        exit 1
    }
}

Write-Host "Display pipeline check passed."
