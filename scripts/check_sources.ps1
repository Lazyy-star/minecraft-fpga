$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    "rtl\tft\tft_clock_gen.v",
    "rtl\tft\tft_timing.v",
    "rtl\adapter\fmcpga_tft_read_mapper.v",
    "rtl\adapter\fmcpga_rgb444_to_rgb323.v",
    "rtl\top\fmcpga_frame_test_top.v",
    "rtl\top\minisys_fmcpga_tft_top.v",
    "rtl\ip_replacements\clk_ppl_generator.v",
    "rtl\ip_replacements\display_ram.v",
    "rtl\ip_replacements\map_ram.v",
    "rtl\ip_replacements\texture_rom.v",
    "rtl\ip_replacements\txt_idx_map_rom.v",
    "rtl\ip_replacements\divider_gen.v",
    "rtl\vhdl\fmcpga_core_flat.vhd",
    "mem\map_test.mem",
    "mem\textures.mem",
    "mem\txt_idx_map.mem",
    "constraints\minisys_fmcpga_tft.xdc",
    "vendor\FmcPGA\src\hdl\general\types.vhd",
    "vendor\FmcPGA\src\hdl\general\constants.vhd",
    "vendor\FmcPGA\src\hdl\pipeline\pipeline_process.vhd",
    "vendor\FmcPGA\res\coe\map_test.coe",
    "vendor\FmcPGA\res\coe\textures.coe",
    "vendor\FmcPGA\res\coe\txt_idx_map.coe",
    "scripts\create_fmcpga_tft_project.tcl",
    "scripts\create_fmcpga_tft_smoke_project.tcl",
    "scripts\check_control_mapping.ps1",
    "scripts\check_display_pipeline.ps1"
)

$missing = @()
foreach ($path in $required) {
    $full = Join-Path $root $path
    if (-not (Test-Path -LiteralPath $full)) {
        $missing += $path
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Missing required files:"
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$flat = Get-Content -LiteralPath (Join-Path $root "rtl\vhdl\fmcpga_core_flat.vhd") -Raw
$forbidden = @("entity top_module", "architecture Behavioral of top_module", "vgaout.", "spi_cs =>", "anodes_n =>", "segs_n =>")
foreach ($pattern in $forbidden) {
    if ($flat.Contains($pattern)) {
        Write-Host "Unexpected original top-level reference in fmcpga_core_flat.vhd: $pattern"
        exit 1
    }
}

Write-Host "Source check passed."
