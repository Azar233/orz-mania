$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$test = Join-Path $root ('artifacts/import-test-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path "$test/tools","$test/source/song","$test/empty" -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/import-songs.ps1" -Destination "$test/tools"
$importer = "$test/tools/import-songs.ps1"
[IO.File]::WriteAllText("$test/source/song/chart.osu", 'osu file format v14')
[IO.File]::WriteAllText("$test/source/song/audio.mp3", 'test-audio-copy')
& $importer -Source "$test/source"
if (@(Get-Content -LiteralPath "$test/Songs/catalog.txt").Count -ne 1) { throw 'Folder catalog failed' }
$audio = Get-ChildItem -LiteralPath "$test/Songs" -Filter audio.mp3 -Recurse
if ([IO.File]::ReadAllText($audio.FullName) -ne 'test-audio-copy') { throw 'Audio was not copied' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory("$test/source/song", "$test/good.osz")
& $importer -Source "$test/good.osz"
if (@(Get-Content -LiteralPath "$test/Songs/catalog.txt").Count -ne 2) { throw 'osz import failed' }
& $importer -Source "$test/Songs"
if (@(Get-Content -LiteralPath "$test/Songs/catalog.txt").Count -ne 2) { throw 'Local refresh duplicated songs' }
$zip = [IO.Compression.ZipFile]::Open("$test/bad.osz", [IO.Compression.ZipArchiveMode]::Create)
try { $null = $zip.CreateEntry('../escape.txt') } finally { $zip.Dispose() }
$rejected = $false
try { & $importer -Source "$test/bad.osz" } catch { $rejected = $true }
if (!$rejected -or (Test-Path -LiteralPath "$test/Songs/escape.txt")) { throw 'Archive traversal was not blocked' }
$rejected = $false
try { & $importer -Source "$test/empty" } catch { $rejected = $true }
if (!$rejected) { throw 'Empty folder was not rejected' }
Write-Output 'PASS folder import / audio copy / osz extraction / refresh / traversal rejection / empty input'
