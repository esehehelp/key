param([string]$Sketchbook)
$ErrorActionPreference = 'Stop'
# Same sketchbook lookup order as the reference board's setup.ps1.
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
Write-Host "Installing keypad board into $Sketchbook"
$source = Join-Path $PSScriptRoot 'hardware\key\ch32x035f7p6'
$reference = Join-Path $Sketchbook 'hardware\esehe\ch32x035f7p6'
$dest = Join-Path $Sketchbook 'hardware\key\ch32x035f7p6'
if (-not (Test-Path (Join-Path $reference 'tools\gcc\bin\riscv-none-embed-gcc.exe'))) {
    throw "Reference board compiler not found at $reference. Run its setup.bat using the same -Sketchbook path, or pass -Sketchbook to this script."
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $source '*') -Destination $dest
$gccDest = Join-Path $dest 'tools\gcc'
if (Test-Path -LiteralPath $gccDest) { Remove-Item -Recurse -Force -LiteralPath $gccDest }
Copy-Item -Recurse -Force -LiteralPath (Join-Path $reference 'tools\gcc') -Destination (Join-Path $dest 'tools')
foreach ($file in @('wchisp.exe', 'CH375DLL64.dll')) {
    Copy-Item -Force (Join-Path $reference "tools\$file") (Join-Path $dest 'tools')
}
Write-Host "Installed keypad board to $dest. Restart Arduino IDE."
