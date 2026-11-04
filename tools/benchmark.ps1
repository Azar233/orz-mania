param(
    [string]$Label = 'current',
    [ValidateRange(30,2000)][int]$FPS = 240,
    [ValidateSet('normal','marathon')][string]$Song = 'marathon',
    [ValidateSet('720p','1440p')][string]$Size = '720p',
    [int]$Processors = 0,
    [switch]$Predecode
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid benchmark label' }
$outDir = Join-Path $root "artifacts/bench-$Label"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $root 'artifacts/bench-stage.txt'),'loading')
$previousProcessors = $env:cjProcessorNum
try {
    if ($Processors -gt 0) { $env:cjProcessorNum = "$Processors" }
    $audioMode = if ($Predecode) { "predecode" } else { "stream" }
    $proc = Start-Process -FilePath (Join-Path $root 'target/release/bin/main.exe') -ArgumentList @('--benchmark',"$FPS",$Song,$Size,$audioMode) -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outDir 'console.txt') -RedirectStandardError (Join-Path $outDir 'errors.txt')
} finally { $env:cjProcessorNum = $previousProcessors }
$processHandle = $proc.Handle
$rows = [Collections.Generic.List[object]]::new()
$watch = [Diagnostics.Stopwatch]::StartNew()
$lastTime = 0.0
$lastCPU = 0.0
$logical = [Environment]::ProcessorCount
while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 200
    $proc.Refresh()
    if ($proc.HasExited) { break }
    $now = $watch.Elapsed.TotalSeconds
    $cpu = $proc.TotalProcessorTime.TotalSeconds
    $stage = [IO.File]::ReadAllText((Join-Path $root 'artifacts/bench-stage.txt'))
    $usage = 100.0 * ($cpu - $lastCPU) / ($now - $lastTime)
    $rows.Add([pscustomobject]@{ Stage=$stage; Seconds=$now; CPU_OneCorePct=$usage; CPU_MachinePct=$usage/$logical; WorkingMiB=$proc.WorkingSet64/1MB; PrivateMiB=$proc.PrivateMemorySize64/1MB; Threads=$proc.Threads.Count })
    $lastTime=$now; $lastCPU=$cpu
}
$proc.WaitForExit()
$rows | Export-Csv -LiteralPath (Join-Path $outDir 'process.csv') -NoTypeInformation -Encoding UTF8
if ($proc.ExitCode -ne 0) { Get-Content -LiteralPath (Join-Path $outDir 'console.txt'); throw "Benchmark failed: $($proc.ExitCode)" }
Copy-Item -LiteralPath (Join-Path $root 'artifacts/bench-frames.csv') -Destination (Join-Path $outDir 'frames.csv')
function Percentile($Values,$Fraction) {
    $ordered=@($Values | Sort-Object)
    $ordered[[Math]::Min($ordered.Count-1,[int][Math]::Ceiling(($ordered.Count-1)*$Fraction))]
}
$frames=Import-Csv -LiteralPath (Join-Path $outDir 'frames.csv')
$summary=foreach ($stage in @('library','gameplay')) {
    $samples=@($rows | Where-Object Stage -eq $stage)
    $render=@($frames | Where-Object stage -eq $stage)
    [pscustomobject]@{
        Stage=$stage; FPSCap=$FPS; Size=$Size; LogicalCPUs=$logical
        CPU_OneCorePct=($samples.CPU_OneCorePct | Measure-Object -Average).Average
        CPU_MachinePct=($samples.CPU_MachinePct | Measure-Object -Average).Average
        WorkingMiB=($samples.WorkingMiB | Measure-Object -Average).Average
        PrivateMiB=($samples.PrivateMiB | Measure-Object -Average).Average
        PrivatePeakMiB=($samples.PrivateMiB | Measure-Object -Maximum).Maximum
        Threads=($samples.Threads | Measure-Object -Maximum).Maximum
        FPS=1000.0/(($render | ForEach-Object {[double]$_.frame_ms} | Measure-Object -Average).Average)
        WorkP50ms=Percentile @($render | ForEach-Object {[double]$_.work_ms}) 0.5
        WorkP95ms=Percentile @($render | ForEach-Object {[double]$_.work_ms}) 0.95
        WorkP99ms=Percentile @($render | ForEach-Object {[double]$_.work_ms}) 0.99
        FrameP99ms=Percentile @($render | ForEach-Object {[double]$_.frame_ms}) 0.99
    }
}
$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outDir 'summary.json') -Encoding UTF8
$summary | Format-Table Stage,FPS,CPU_MachinePct,PrivateMiB,Threads,WorkP95ms,FrameP99ms -AutoSize
Get-Content -LiteralPath (Join-Path $outDir 'console.txt')
