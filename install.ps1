[CmdletBinding()]
param(
    [string]$Sketchbook,
    [string]$ToolsFrom
)
$ErrorActionPreference = 'Stop'

# Use the same sketchbook search as the reference board setup.
if (-not $Sketchbook) {
    $cliConfig = Join-Path $env:USERPROFILE '.arduinoIDE\arduino-cli.yaml'
    if (Test-Path -LiteralPath $cliConfig) {
        $line = Get-Content -LiteralPath $cliConfig |
            Where-Object { $_ -match '^\s*user:\s*(.+?)\s*$' } | Select-Object -First 1
        if ($line -and $line -match '^\s*user:\s*["'']?(.+?)["'']?\s*$') {
            $Sketchbook = [Environment]::ExpandEnvironmentVariables($Matches[1])
        }
    }
    if (-not $Sketchbook) {
        $prefs = Join-Path $env:LOCALAPPDATA 'Arduino15\preferences.txt'
        if (Test-Path -LiteralPath $prefs) {
            $line = Get-Content -LiteralPath $prefs |
                Where-Object { $_ -like 'sketchbook.path=*' } | Select-Object -First 1
            if ($line) { $Sketchbook = $line.Substring('sketchbook.path='.Length) }
        }
    }
    if (-not $Sketchbook) {
        $Sketchbook = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Arduino'
    }
}
$Sketchbook = [IO.Path]::GetFullPath($Sketchbook)
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'hardware\key\ch32x035f7p6'))
$dest = [IO.Path]::GetFullPath((Join-Path $Sketchbook 'hardware\key\ch32x035f7p6'))
$reference = Join-Path $Sketchbook 'hardware\esehe\ch32x035f7p6'
$shared = Join-Path $env:LOCALAPPDATA 'CH32X035\tools'
Write-Host "Sketchbook: $Sketchbook"
Write-Host "Board source: $source"
Write-Host "Board destination: $dest"
if (-not (Test-Path -LiteralPath (Join-Path $source 'boards.txt'))) {
    throw "Board files are missing. Run setup.bat from an extracted checkout of this repository, not from Downloads by itself."
}

# Always update the board files, even if the reference platform lives elsewhere.
New-Item -ItemType Directory -Force -Path $dest | Out-Null
if (-not $source.Equals($dest, [StringComparison]::OrdinalIgnoreCase)) {
    Copy-Item -Recurse -Force -Path (Join-Path $source '*') -Destination $dest
}

# Prefer an already-installed toolchain in the keypad board; otherwise reuse
# the reference board or the WCH Board Manager's riscv-none-embed-gcc tool.
$gccDest = Join-Path $dest 'tools\gcc'
$gccExe = Join-Path $gccDest 'bin\riscv-none-embed-gcc.exe'
if (-not (Test-Path -LiteralPath $gccExe)) {
    $candidates = @()
    if ($ToolsFrom) { $candidates += (Join-Path $ToolsFrom 'tools\gcc'); $candidates += $ToolsFrom }
    $candidates += (Join-Path $reference 'tools\gcc')
    $wchTools = Join-Path $env:LOCALAPPDATA 'Arduino15\packages\WCH\tools\riscv-none-embed-gcc'
    if (Test-Path -LiteralPath $wchTools) {
        $candidates += @(Get-ChildItem -LiteralPath $wchTools -Directory | Sort-Object Name -Descending | ForEach-Object { $_.FullName })
    }
    $gccSource = $candidates | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ 'bin\riscv-none-embed-gcc.exe')
    } | Select-Object -First 1
    if ($gccSource) {
        if (Test-Path -LiteralPath $gccDest) { Remove-Item -LiteralPath $gccDest -Recurse -Force }
        Copy-Item -LiteralPath $gccSource -Destination $gccDest -Recurse -Force
        Write-Host "Compiler: $gccSource"
    }
}
if (-not (Test-Path -LiteralPath $gccExe)) {
    throw "Board files installed to $dest, but compiler not found. Pass -ToolsFrom <reference board directory> or install the WCH compiler."
}

$toolsDest = Join-Path $dest 'tools'
foreach ($name in @('wchisp.exe', 'CH375DLL64.dll')) {
    $target = Join-Path $toolsDest $name
    if (Test-Path -LiteralPath $target) { continue }
    $paths = @()
    if ($ToolsFrom) { $paths += (Join-Path $ToolsFrom "tools\$name"); $paths += (Join-Path $ToolsFrom $name) }
    $paths += (Join-Path $reference "tools\$name")
    $paths += (Join-Path $shared $name)
    $found = $paths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($found) {
        Copy-Item -LiteralPath $found -Destination $target -Force
        Write-Host "$name`: $found"
    } else {
        throw "Board/compiler installed, but $name not found. Pass -ToolsFrom <reference board directory> or install the reference tools."
    }
}
Write-Host "Installed keypad board to $dest. Restart Arduino IDE and select CH32X035F7P6 Keypad."
