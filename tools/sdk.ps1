function Find-CangjieSdk {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $candidates = @($env:CANGJIE_HOME, (Join-Path $projectRoot '.tools/cangjie'))
    $compiler = Get-Command cjc.exe -ErrorAction SilentlyContinue
    if ($compiler) { $candidates += (Split-Path (Split-Path $compiler.Source -Parent) -Parent) }
    # Optional development-workspace fallback; a downloaded project uses the installed SDK.
    $candidates += (Join-Path $projectRoot '../../.tools/cangjie')
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath "$candidate/bin/cjc.exe") -and
            (Test-Path -LiteralPath "$candidate/tools/bin/cjpm.exe")) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Cangjie SDK 1.0.5 Windows x64 is required. Install it and load envsetup.ps1, or set CANGJIE_HOME. See README.md.'
}
