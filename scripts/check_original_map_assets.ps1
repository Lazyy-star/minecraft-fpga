$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$rootForward = $root -replace "\\", "/"

$expectedBlobs = @{
    "vendor/FmcPGA/res/coe/map_test.coe"    = "c968731af7f99313d58d5c8f7908af8542d3dced"
    "vendor/FmcPGA/res/coe/textures.coe"    = "b5f177d95d7ac62048db899a955e50e2a39c573f"
    "vendor/FmcPGA/res/coe/txt_idx_map.coe" = "1e8e7cd3161e0b85cea2107402bf020bdcb203ae"
    "mem/map_test.mem"                      = "8f1d3548a1664f24edb48b7fdb2389f31dabc7f2"
    "mem/textures.mem"                      = "d2bfb0ac1bf68666017e91ef24f2ef7eb03d5194"
    "mem/txt_idx_map.mem"                   = "d16736a37d280b3597cd68548be13d8231faa3f2"
}

foreach ($entry in $expectedBlobs.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Missing Gralerfics/FmcPGA map asset: $($entry.Key)"
        exit 1
    }

    $actual = git -C $root hash-object -- $entry.Key
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    if ($actual.Trim() -ne $entry.Value) {
        Write-Host "Map asset does not match Gralerfics/FmcPGA main: $($entry.Key)"
        Write-Host "Expected: $($entry.Value)"
        Write-Host "Actual:   $($actual.Trim())"
        exit 1
    }
}

$requiredReadmemh = @{
    "rtl\ip_replacements\map_ram.v" = "$rootForward/mem/map_test.mem"
    "rtl\ip_replacements\texture_rom.v" = "$rootForward/mem/textures.mem"
    "rtl\ip_replacements\txt_idx_map_rom.v" = "$rootForward/mem/txt_idx_map.mem"
}

foreach ($entry in $requiredReadmemh.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    $content = Get-Content -LiteralPath $path -Raw
    $pattern = [regex]::Escape('$readmemh("' + $entry.Value + '"')
    if ($content -notmatch $pattern) {
        Write-Host "Missing current-repo original asset path in $($entry.Key): $($entry.Value)"
        exit 1
    }
    if (-not (Test-Path -LiteralPath ($entry.Value -replace "/", "\"))) {
        Write-Host "Referenced map asset does not exist: $($entry.Value)"
        exit 1
    }
}

Write-Host "Gralerfics/FmcPGA map assets check passed."
