$ErrorActionPreference = "Stop"

function Convert-CoeToMem {
    param (
        [string]$InputPath,
        [string]$OutputPath
    )

    $text = Get-Content -LiteralPath $InputPath -Raw
    $text = $text -replace "`r", ""
    $radixMatch = [regex]::Match($text, "(?i)memory_initialization_radix\s*=\s*(\d+)")
    if (-not $radixMatch.Success) {
        throw "No memory_initialization_radix found in $InputPath"
    }

    $radix = [int]$radixMatch.Groups[1].Value
    if (($radix -ne 2) -and ($radix -ne 10) -and ($radix -ne 16)) {
        throw "Only radix 2, 10, and 16 COE files are supported. $InputPath uses radix $radix"
    }

    $vectorMatch = [regex]::Match($text, "(?is)memory_initialization_vector\s*=\s*(.*?)(?:;)?\s*$")
    if (-not $vectorMatch.Success) {
        throw "No memory_initialization_vector found in $InputPath"
    }

    $values = $vectorMatch.Groups[1].Value -split "[,\s]+" | Where-Object { $_ -ne "" }
    $hexValues = foreach ($value in $values) {
        $clean = $value.Trim() -replace "_", ""
        if ($radix -eq 16) {
            $clean
        } elseif ($radix -eq 10) {
            [Convert]::ToString([Convert]::ToInt64($clean, 10), 16)
        } else {
            [Convert]::ToString([Convert]::ToInt64($clean, 2), 16)
        }
    }
    Set-Content -LiteralPath $OutputPath -Value ($hexValues -join "`n") -Encoding ascii
}

$root = Split-Path -Parent $PSScriptRoot
Convert-CoeToMem `
    -InputPath (Join-Path $root "vendor\FmcPGA\res\coe\map_test.coe") `
    -OutputPath (Join-Path $root "mem\map_test.mem")
Convert-CoeToMem `
    -InputPath (Join-Path $root "vendor\FmcPGA\res\coe\textures.coe") `
    -OutputPath (Join-Path $root "mem\textures.mem")
Convert-CoeToMem `
    -InputPath (Join-Path $root "vendor\FmcPGA\res\coe\txt_idx_map.coe") `
    -OutputPath (Join-Path $root "mem\txt_idx_map.mem")

Write-Host "Converted COE files to MEM files."
