[CmdletBinding()]
param(
    [string]$IcarusBin = 'C:\iverilog\bin'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $repoRoot 'build\display-tests'
$iverilog = Join-Path $IcarusBin 'iverilog.exe'
$vvp = Join-Path $IcarusBin 'vvp.exe'

if (-not (Test-Path -LiteralPath $iverilog)) {
    throw "Icarus compiler not found at $iverilog"
}
if (-not (Test-Path -LiteralPath $vvp)) {
    throw "Icarus runtime not found at $vvp"
}

$commonSources = @(
    (Join-Path $repoRoot 'rtl\core-v-mcu\soc\display_framebuffer.sv'),
    (Join-Path $repoRoot 'rtl\core-v-mcu\soc\display_palette.sv'),
    (Join-Path $repoRoot 'rtl\core-v-mcu\soc\display_tcdm_slave_core.sv')
)

function Invoke-DisplaySimulation {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Top,
        [Parameter(Mandatory)] [string[]]$Sources
    )

    $runDirectory = Join-Path $buildRoot $Name
    New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
    $output = Join-Path $runDirectory "$Name.vvp"

    Write-Host "Compiling $Name..."
    & $iverilog -g2012 -s $Top -o $output @Sources
    if ($LASTEXITCODE -ne 0) {
        throw "$Name compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running $Name..."
    Push-Location $runDirectory
    try {
        & $vvp $output
        if ($LASTEXITCODE -ne 0) {
            throw "$Name simulation failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

function Convert-PpmToPng {
    param(
        [Parameter(Mandatory)] [string]$PpmPath,
        [Parameter(Mandatory)] [string]$PngPath
    )

    Add-Type -AssemblyName System.Drawing
    $tokens = @((Get-Content -LiteralPath $PpmPath -Raw) -split '\s+' |
        Where-Object { $_ -ne '' })
    if ($tokens[0] -ne 'P3') {
        throw "Expected a P3 PPM image at $PpmPath"
    }

    $width = [int]$tokens[1]
    $height = [int]$tokens[2]
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $tokenIndex = 4

    try {
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $red = [int]$tokens[$tokenIndex]
                $green = [int]$tokens[$tokenIndex + 1]
                $blue = [int]$tokens[$tokenIndex + 2]
                $tokenIndex += 3
                $color = [System.Drawing.Color]::FromArgb($red, $green, $blue)
                $bitmap.SetPixel($x, $y, $color)
            }
        }
        $bitmap.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

Invoke-DisplaySimulation `
    -Name 'basic' `
    -Top 'display_tcdm_slave_tb' `
    -Sources ($commonSources + @(
        (Join-Path $repoRoot 'tests\display_tcdm_slave_tb.sv')
    ))

Invoke-DisplaySimulation `
    -Name 'image' `
    -Top 'display_framebuffer_image_tb' `
    -Sources ($commonSources + @(
        (Join-Path $repoRoot 'tests\display_framebuffer_image_tb.sv')
    ))

$ppmPath = Join-Path $buildRoot 'image\display_framebuffer_test.ppm'
$pngPath = Join-Path $buildRoot 'image\display_framebuffer_test.png'
Convert-PpmToPng -PpmPath $ppmPath -PngPath $pngPath

Invoke-DisplaySimulation `
    -Name 'spi' `
    -Top 'display_spi_streamer_tb' `
    -Sources ($commonSources + @(
        (Join-Path $repoRoot 'rtl\core-v-mcu\soc\display_spi_streamer.sv'),
        (Join-Path $repoRoot 'tests\display_spi_streamer_tb.sv')
    ))

Write-Host ''
Write-Host 'All display RTL simulations passed.'
Write-Host "Framebuffer preview: $pngPath"
