param([switch]$Run, [switch]$Verify)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
. "$PSScriptRoot/sdk.ps1"
$sdkRoot = Find-CangjieSdk
& "$sdkRoot/envsetup.ps1"
& "$sdkRoot/tools/bin/cjpm.exe" build
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
if ($Verify) { & './target/release/bin/main.exe' --verify; if ($LASTEXITCODE -ne 0) { throw 'Verification failed' } }
if ($Run) { & './target/release/bin/main.exe' }
