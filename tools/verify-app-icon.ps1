$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
Add-Type -AssemblyName System.Drawing
if (-not ('OrzManiaWindowIconProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class OrzManiaWindowIconProbe {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr SendMessageW(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
'@
}
$proc = Start-Process -FilePath (Join-Path $root 'target/release/bin/main.exe') -ArgumentList '--readme-capture' -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'artifacts/readme-capture.log') -RedirectStandardError (Join-Path $root 'artifacts/readme-capture-errors.log')
$handle = $proc.Handle
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ($proc.MainWindowHandle -eq [IntPtr]::Zero -and -not $proc.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 50
        $proc.Refresh()
    }
    if ($proc.MainWindowHandle -eq [IntPtr]::Zero) { throw 'Game window was not created' }
    foreach ($kind in @(0,1)) {
        $native = [OrzManiaWindowIconProbe]::SendMessageW($proc.MainWindowHandle,0x7F,[IntPtr]$kind,[IntPtr]::Zero)
        if ($native -eq [IntPtr]::Zero) { throw "Missing native window icon: $kind" }
        $icon = [Drawing.Icon]::FromHandle($native)
        $bitmap = $icon.ToBitmap()
        try {
            $pink = 0
            for ($y=0; $y -lt $bitmap.Height; $y++) {
                for ($x=0; $x -lt $bitmap.Width; $x++) {
                    $pixel=$bitmap.GetPixel($x,$y)
                    if ($pixel.A -gt 100 -and $pixel.R -gt 150 -and $pixel.R -gt $pixel.G+10 -and $pixel.R -gt $pixel.B) { $pink++ }
                }
            }
            if ($pink -lt $bitmap.Width*$bitmap.Height*0.1) { throw 'Runtime icon does not contain the supplied pink artwork' }
            $bitmap.Save((Join-Path $root "artifacts/window-icon-$kind.png"),[Drawing.Imaging.ImageFormat]::Png)
            Write-Host "PASS native icon $kind : $($bitmap.Width)x$($bitmap.Height), pink pixels=$pink"
        } finally { $bitmap.Dispose(); $icon.Dispose() }
    }
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw "Showcase exited with $($proc.ExitCode)" }
    Get-Content -LiteralPath 'artifacts/readme-capture.log'
} finally { if (-not $proc.HasExited) { $proc.Kill(); $proc.WaitForExit() } }
