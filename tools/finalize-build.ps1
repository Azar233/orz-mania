$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/prepare-runtime.ps1"
# Only the output just linked contains the current icon-rendering entry point.
$entries = @(foreach ($profile in @('release','debug')) {
    $path = Join-Path $root "target/$profile/bin/main.exe"
    if (Test-Path -LiteralPath $path) { Get-Item -LiteralPath $path }
})
if ($entries.Count -gt 0) {
    $entry = $entries | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    & "$PSScriptRoot/set-app-icon.ps1" -SourceImage (Join-Path $root 'assets/branding/icon.svg') -Executable $entry.FullName
}
