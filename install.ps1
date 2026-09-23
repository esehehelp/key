param([string]$Sketchbook = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Arduino'))
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'hardware\key\ch32x035f7p6'
$reference = Join-Path $Sketchbook 'hardware\esehe\ch32x035f7p6'
$dest = Join-Path $Sketchbook 'hardware\key\ch32x035f7p6'
if (-not (Test-Path (Join-Path $reference 'tools\gcc\bin\riscv-none-embed-gcc.exe'))) {
    throw "Install ../ch32x035f7p6-micro-devboard (setup.bat) to $Sketchbook first."
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $source '*') $dest
Copy-Item -Recurse -Force (Join-Path $reference 'tools\gcc') (Join-Path $dest 'tools')
foreach ($file in @('wchisp.exe', 'CH375DLL64.dll')) {
    Copy-Item -Force (Join-Path $reference "tools\$file") (Join-Path $dest 'tools')
}
Write-Host "Installed keypad board to $dest. Restart Arduino IDE."
