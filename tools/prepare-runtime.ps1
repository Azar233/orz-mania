$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/sdk.ps1"
$sdkRoot = Find-CangjieSdk
foreach ($profile in @('release','debug')) {
    $bin = Join-Path $projectRoot "target/$profile/bin"
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    Get-ChildItem -LiteralPath "$projectRoot/vendor/SDL/.sdl3" -Filter '*.dll' | Copy-Item -Destination $bin -Force
    Get-ChildItem -LiteralPath "$sdkRoot/runtime/lib/windows_x86_64_cjnative" -Filter '*.dll' | Copy-Item -Destination $bin -Force
    Copy-Item -LiteralPath "$sdkRoot/LICENSE" -Destination "$bin/Cangjie-LICENSE.txt" -Force
    Copy-Item -LiteralPath "$sdkRoot/Open_Source_Software_Notice.docx" -Destination $bin -Force
}
& "$PSScriptRoot/import-songs.ps1"

