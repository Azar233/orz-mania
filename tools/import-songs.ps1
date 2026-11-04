param([string]$Source)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$songs = Join-Path $root 'Songs'
New-Item -ItemType Directory -Path $songs -Force | Out-Null
if ($Source) {
    $item = Get-Item -LiteralPath $Source
    $sourcePath = $item.FullName
    if ($sourcePath.StartsWith($songs + '\', [StringComparison]::OrdinalIgnoreCase) -or $sourcePath -eq $songs) {
        # Already local: only refresh the catalog.
    } elseif (!$item.PSIsContainer -and $item.Extension -eq '.osz') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $dest = Join-Path $songs ($item.BaseName + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
        $zip = [IO.Compression.ZipFile]::OpenRead($sourcePath)
        try {
            $total = 0L
            if ($zip.Entries.Count -gt 20000) { throw 'Archive contains too many files' }
            foreach ($entry in $zip.Entries) {
                $total += $entry.Length
                if ($total -gt 2GB) { throw 'Archive exceeds 2 GB' }
                $target = [IO.Path]::GetFullPath((Join-Path $dest $entry.FullName))
                if (!$target.StartsWith($dest + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive path' }
            }
        } finally { $zip.Dispose() }
        [IO.Compression.ZipFile]::ExtractToDirectory($sourcePath, $dest)
    } else {
        if (!$item.PSIsContainer) {
            if ($item.Extension -ne '.osu') { throw 'Choose a Songs folder, beatmap folder, .osu or .osz file' }
            $sourcePath = $item.Directory.FullName
        }
        $maps = @(Get-ChildItem -LiteralPath $sourcePath -Filter '*.osu' -File -Recurse)
        if (!$maps.Count) { throw 'No .osu beatmaps found' }
        $dirs = @($maps | ForEach-Object { $_.Directory.FullName } | Sort-Object -Unique)
        foreach ($dir in $dirs) {
            $dest = Join-Path $songs ((Split-Path $dir -Leaf) + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
            Copy-Item -LiteralPath $dir -Destination $dest -Recurse
        }
    }
}
$catalog = @(Get-ChildItem -LiteralPath $songs -Filter '*.osu' -Recurse -File | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\','/') })
[IO.File]::WriteAllLines((Join-Path $songs 'catalog.txt'), [string[]]$catalog, (New-Object Text.UTF8Encoding($false)))
Write-Output "Catalog: $($catalog.Count) beatmaps"

