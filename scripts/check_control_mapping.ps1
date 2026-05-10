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
    "selected_block_in: in std_logic_vector\(BLOCK_TYPE_RADIX - 1 downto 0\)",
    "action_pulse_ppl <= action_sync_2 and not action_sync_2_d;",
    "valid_target <= valid_sel and action_pulse_ppl;",
    "block_p_target <= block_p_sel when dig_in = '1' else block_p_inc;",
    "left_click <= '0';",
    "right_click <= '0';",
    "selected_block_int <= to_integer\(unsigned\(selected_block_in\)\);",
    "idx_target_selected <= 0 when dig_in = '1' else selected_block_int;",
    "idx_target => idx_target_selected"
)

foreach ($pattern in $requiredFlatPatterns) {
    if ($flat -notmatch $pattern) {
        Write-Host "Missing flat-wrapper mapping: $pattern"
        exit 1
    }
}

Write-Host "Control mapping check passed."
