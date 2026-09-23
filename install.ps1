[CmdletBinding()]
param(
    [string]$Sketchbook,
    [string]$ToolsFrom
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Download-Checked([string]$Url, [string]$Path, [string]$Checksum = '') {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'keypad-setup' } -Uri $Url -OutFile $Path
    if ($Checksum) {
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
        if ($actual -ine $Checksum) { throw "SHA256 mismatch for $Url" }
    }
}

function Get-ReleaseAsset([string]$Repository, [string]$Tag, [string]$Name) {
    $release = Invoke-RestMethod -Headers @{ 'User-Agent' = 'keypad-setup' } `
        -Uri "https://api.github.com/repos/$Repository/releases/tags/$Tag"
    $asset = $release.assets | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if (-not $asset) { throw "Release asset missing: $Repository/$Tag/$Name" }
    $sha = if ($asset.digest -like 'sha256:*') { $asset.digest.Substring(7) } else { '' }
    return @{ Url = $asset.browser_download_url; Sha256 = $sha }
}

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
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('keypad-setup-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
if (-not (Test-Path -LiteralPath $gccExe)) {
    # Identical toolchain source/version to the reference board setup.
    $index = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/openwch/board_manager_files/main/package_ch32v_index.json'
    $gcc = $index.packages[0].tools | Where-Object {
        $_.name -eq 'riscv-none-embed-gcc' -and $_.version -eq '8.2.0'
    } | Select-Object -First 1
    $archiveInfo = $gcc.systems | Where-Object { $_.host -eq 'i686-mingw32' } | Select-Object -First 1
    if (-not $archiveInfo) { throw 'Windows GCC 8.2.0 not found in WCH package index.' }
    $archive = Join-Path $tempRoot 'gcc.zip'
    Download-Checked $archiveInfo.url $archive ($archiveInfo.checksum -replace '^SHA-256:', '')
    $extract = Join-Path $tempRoot 'gcc'
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
    $exe = Get-ChildItem -LiteralPath $extract -Recurse -Filter 'riscv-none-embed-gcc.exe' |
        Select-Object -First 1
    if (-not $exe) { throw 'GCC executable not found in WCH archive.' }
    $gccSource = Split-Path (Split-Path $exe.FullName -Parent) -Parent
    if (Test-Path -LiteralPath $gccDest) { Remove-Item -LiteralPath $gccDest -Recurse -Force }
    Copy-Item -LiteralPath $gccSource -Destination $gccDest -Recurse -Force
}
if (-not (Test-Path -LiteralPath $gccExe)) { throw "Compiler installation failed at $gccExe" }

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
        switch ($name) {
            'wchisp.exe' {
                $asset = Get-ReleaseAsset 'ch32-rs/wchisp' 'nightly' 'wchisp-win-x64.zip'
                $zip = Join-Path $tempRoot 'wchisp.zip'
                Download-Checked $asset.Url $zip $asset.Sha256
                $extract = Join-Path $tempRoot 'wchisp'
                Expand-Archive -LiteralPath $zip -DestinationPath $extract
                $exe = Get-ChildItem -LiteralPath $extract -Recurse -Filter 'wchisp.exe' | Select-Object -First 1
                if (-not $exe) { throw 'wchisp.exe not found in downloaded archive.' }
                Copy-Item -LiteralPath $exe.FullName -Destination $target -Force
            }
            'CH375DLL64.dll' {
                $asset = Get-ReleaseAsset 'MeowKJ/BinaryKeyboard' 'toolchain-linux' 'CH375DLL64.dll'
                Download-Checked $asset.Url $target $asset.Sha256
            }
        }
    }
}
Write-Host "Installed keypad board to $dest. Restart Arduino IDE and select CH32X035F7P6 Keypad."
Write-Host 'For first-time USB ISP, install the WCH signed driver following the reference board instructions.'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
