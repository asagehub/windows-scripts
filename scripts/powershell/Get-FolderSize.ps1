#Requires -Version 5.1

<#
.SYNOPSIS
    Returns all folders sorted by size (including subfolders by default), largest first.

.DESCRIPTION
    Scans the root path and all subdirectories, calculates the total
    size of each folder, and outputs them as objects sorted by size descending.
    The root folder itself is included in the results with RelativePath set to '.'.

    By default, each folder's size includes all files in its subtree (direct files
    plus all descendant subfolders). Use -ExcludeSubfolders to revert to counting
    only the files directly in each folder.

    Reparse points (junctions and symbolic links) are not followed, preventing
    infinite loops and duplicate size counting.

    Output objects can be composed in the pipeline:
        .\Get-FolderSize.ps1 -Path C:\ | Where-Object SizeBytes -gt 1GB
        .\Get-FolderSize.ps1 -Path C:\ | Export-Csv result.csv -NoTypeInformation

.PARAMETER Path
    Root path to search. Defaults to the current directory.

.PARAMETER Top
    Number of largest folders to return. If omitted, all results are returned.

.PARAMETER ExcludeSubfolders
    If specified, each folder's size includes only files directly in that folder.
    Subfolders are excluded from the size calculation.
    By default (when this switch is omitted), the size includes all descendant files.

.PARAMETER CsvOutput
    If specified, exports results to this path as a CSV file.

.INPUTS
    None

.OUTPUTS
    PSCustomObject
        AbsolutePath : Full absolute path to the folder
        RelativePath : Path relative to the search root ('.' for the root itself)
        SizeBytes    : Total size in bytes (includes subfolders unless -ExcludeSubfolders)
        Size         : Human-readable size (B, KB, MB, or GB)
        FileCount    : Number of files counted (includes subfolders unless -ExcludeSubfolders)

.EXAMPLE
    .\Get-FolderSize.ps1 -Path "C:\" -Top 50
    Returns the 50 largest folders (cumulative size including subfolders) under C:\.

.EXAMPLE
    .\Get-FolderSize.ps1 -Path "C:\" -Top 50 -ExcludeSubfolders
    Returns the 50 largest folders by direct file size only (subfolders excluded).

.EXAMPLE
    .\Get-FolderSize.ps1 -Path "C:\Users\username" -CsvOutput "C:\Temp\result.csv"
    Searches under the specified user profile and also exports the results to a CSV file.

.EXAMPLE
    .\Get-FolderSize.ps1 -Path "C:\" -Verbose
    Runs with verbose output showing collection progress and elapsed time.

.NOTES
    By default, folder size is the sum of all files in the subtree (direct files
    plus all descendant subfolders). Use -ExcludeSubfolders to count direct files only.
    Both modes perform the same number of disk I/O operations; the difference is only
    an in-memory aggregation pass.
#>

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Get-Location).Path,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Top = [int]::MaxValue,
    [switch]$ExcludeSubfolders,
    [string]$CsvOutput = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Set console encoding to UTF-8 to prevent garbled output on Shift-JIS consoles
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$startTime = Get-Date
$skipCount = 0

function Format-SizeLabel ([long]$bytes) {
    if     ($bytes -ge 1GB) { '{0:N2} GB' -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { '{0:N2} MB' -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { '{0:N2} KB' -f ($bytes / 1KB) }
    else                    { '{0} B'     -f $bytes }
}

# Validate path
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Path not found or is not a directory: $Path"
}
$Path = (Resolve-Path -LiteralPath $Path).Path

# Collect all subdirectories using BFS, never recursing into reparse points.
# Get-ChildItem -Recurse follows junctions before filtering, so we enumerate
# manually to guarantee no junction is entered.
Write-Verbose "Collecting folders under: $Path"
$allSubDirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
$bfsQueue = [System.Collections.Generic.Queue[string]]::new()
$bfsQueue.Enqueue($Path)
while ($bfsQueue.Count -gt 0) {
    $current = $bfsQueue.Dequeue()
    try {
        foreach ($child in ([System.IO.DirectoryInfo]::new($current)).EnumerateDirectories()) {
            if (-not ($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $allSubDirs.Add($child)
                $bfsQueue.Enqueue($child.FullName)
            }
        }
    }
    catch {
        $skipCount++
        Write-Verbose "Skipped (access error): $current — $_"
    }
}

# Include the root folder itself as a candidate
$rootItem = Get-Item -LiteralPath $Path
$allFolders = @($rootItem) + $allSubDirs

Write-Verbose "Folders found: $($allFolders.Count)"

# Calculate direct-file size for every folder
$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$total = $allFolders.Count

for ($i = 0; $i -lt $total; $i++) {
    $folder = $allFolders[$i]
    $pct = if ($total -gt 0) { [int](($i / $total) * 100) } else { 100 }

    Write-Progress -Activity 'Calculating folder sizes' `
        -Status $folder.FullName `
        -PercentComplete $pct

    try {
        $fileErrors = [System.Collections.ArrayList]::new()
        $files = @(
            Get-ChildItem -LiteralPath $folder.FullName -File -Force `
                -ErrorAction SilentlyContinue -ErrorVariable +fileErrors
        )
        $skipCount += $fileErrors.Count

        $sizeBytes = 0L
        foreach ($f in $files) { $sizeBytes += $f.Length }

        $relPath = if ($folder.FullName -eq $Path) {
            '.'
        } else {
            $folder.FullName.Substring($Path.Length).TrimStart('\')
        }

        [void]$results.Add([PSCustomObject]@{
            PSTypeName   = 'FolderSizeInfo'
            AbsolutePath = $folder.FullName
            RelativePath = $relPath
            SizeBytes    = $sizeBytes
            Size         = Format-SizeLabel $sizeBytes
            FileCount    = $files.Count
        })
    }
    catch {
        $skipCount++
        Write-Verbose "Skipped: $($folder.FullName) — $_"
    }
}

Write-Progress -Activity 'Calculating folder sizes' -Completed

# Aggregate subtree sizes bottom-up when subfolders are not excluded
if (-not $ExcludeSubfolders) {
    $cumBytes = @{}
    $cumCount = @{}
    foreach ($r in $results) {
        $cumBytes[$r.AbsolutePath] = $r.SizeBytes
        $cumCount[$r.AbsolutePath] = $r.FileCount
    }
    $results |
        Sort-Object { $_.AbsolutePath.Length } -Descending |
        ForEach-Object {
            $parent = [System.IO.Path]::GetDirectoryName($_.AbsolutePath)
            if ($cumBytes.ContainsKey($parent)) {
                $cumBytes[$parent] += $cumBytes[$_.AbsolutePath]
                $cumCount[$parent] += $cumCount[$_.AbsolutePath]
            }
        }
    foreach ($r in $results) {
        $r.SizeBytes  = $cumBytes[$r.AbsolutePath]
        $r.FileCount  = $cumCount[$r.AbsolutePath]
        $r.Size       = Format-SizeLabel $r.SizeBytes
    }
}

# Output top N results sorted by size descending
$sorted = $results | Sort-Object -Property SizeBytes -Descending | Select-Object -First $Top
$sorted

# Report skipped folders and elapsed time
if ($skipCount -gt 0) {
    Write-Warning "$skipCount folder(s) were skipped due to access errors."
}
Write-Verbose ('Completed in {0:hh\:mm\:ss}' -f ((Get-Date) - $startTime))

# Export to CSV if requested
if ($CsvOutput) {
    try {
        $sorted | Export-Csv -Path $CsvOutput -Encoding UTF8 -NoTypeInformation
        Write-Verbose "CSV exported to: $CsvOutput"
    }
    catch {
        Write-Error "Failed to export CSV: $_"
    }
}
