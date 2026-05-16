#Requires -Version 3.0

<#
.SYNOPSIS
    Creates one or more dummy files of a specified size for disk space testing.

.DESCRIPTION
    Creates binary files at the specified path to consume actual disk space.
    Intended for verifying disk space monitoring programs by artificially reducing
    free space on a drive.

    By default, each file is written in 64 MB zero-filled chunks, guaranteeing real
    cluster allocation (no sparse files). A disk free-space check is performed before
    creation.

    When -Fast is specified, the file is extended to the target size via SetLength()
    without writing data. NTFS allocates all clusters immediately and the OS guarantees
    that reads return zeros (via the Valid Data Length mechanism) — no old data is ever
    exposed. This is near-instant for any file size and requires no elevated privileges,
    but the target volume must be NTFS.

    Output objects can be piped to further commands:
        .\New-DummyFile.ps1 -Path C:\Temp -Size 1GB | Select-Object Name, Length

.PARAMETER Path
    Directory where the dummy file(s) will be created.

.PARAMETER Size
    File size as a human-readable string. Supported suffixes: B, KB, MB, GB, TB
    (case-insensitive). Decimal values are accepted (e.g. "1.5GB").
    A bare integer with no suffix is treated as bytes.

.PARAMETER Count
    Number of dummy files to create. Default: 1.
    When Count is 1, the file is named <FileName>.bin.
    When Count is greater than 1, files are named <FileName>_001.bin,
    <FileName>_002.bin, etc. with zero-padded indices.

.PARAMETER Name
    File name when Count is 1, or filename prefix when Count is greater than 1.
    Do not include an extension; .bin is appended automatically. Default: "dummy".
    Alias: FileName

.PARAMETER ChunkSize
    Size of each write buffer in bytes. Default: 64 MB. Accepts values between 1 MB
    and 256 MB. Larger values reduce loop iterations and PowerShell overhead; smaller
    values reduce peak memory usage. Ignored when -Fast is used.

.PARAMETER Fast
    Creates the file near-instantly by allocating disk space without writing data.
    Requires an NTFS volume; no elevated privileges are needed.

    FileStream.SetLength() allocates all NTFS clusters immediately, so disk monitoring
    programs report the space as consumed. Reads between the start of the file and EOF
    are guaranteed by the OS to return zeros via the Valid Data Length (VDL) mechanism —
    previously deleted data on disk is never exposed.

.PARAMETER Force
    Overwrites existing files without prompting.

.INPUTS
    None

.OUTPUTS
    System.IO.FileInfo

.EXAMPLE
    .\New-DummyFile.ps1 -Path C:\Temp -Size 1GB
    Creates C:\Temp\dummy.bin (1 GB).

.EXAMPLE
    .\New-DummyFile.ps1 -Path C:\Temp -Size 500MB -Count 3
    Creates C:\Temp\dummy_001.bin, dummy_002.bin, dummy_003.bin (500 MB each).

.EXAMPLE
    .\New-DummyFile.ps1 -Path C:\Temp -Size 2GB -Name testdata -Force
    Creates C:\Temp\testdata.bin (2 GB), overwriting if it already exists.

.EXAMPLE
    .\New-DummyFile.ps1 -Path C:\Temp -Size 100MB -Count 5 | Remove-Item
    Creates 5 dummy files and immediately deletes them (pipeline usage).

.EXAMPLE
    .\New-DummyFile.ps1 -Path C:\Temp -Size 2TB -Fast
    Creates C:\Temp\dummy.bin (2 TB) near-instantly. Requires an NTFS volume.

.NOTES
    Default mode writes zero bytes in chunks, which forces NTFS to allocate real disk
    clusters. This is intentional: sparse files would not reduce reported free space
    and would not be useful for monitoring tests.

    -Fast mode uses SetLength() to allocate clusters without writing data. NTFS
    allocates all clusters immediately and the OS Valid Data Length mechanism ensures
    reads always return zeros — no stale disk data is ever exposed.

    Known limitations (apply equally to both modes):
    - NTFS-compressed volumes: zero bytes compress efficiently, so actual disk space
      consumed may be significantly less than the requested file size.
    - Thin-provisioned storage (VMware thin disk, Hyper-V dynamic VHDX, SAN/cloud thin
      provisioning): NTFS reports clusters as allocated, but the underlying storage may
      not reserve physical blocks until data is written. This is a storage-layer concern
      outside the script's control.
    - Windows Server Data Deduplication: space is correctly consumed at file creation
      time; a background dedup job may reclaim it hours or days later.
#>

[CmdletBinding(SupportsShouldProcess)]
[OutputType([System.IO.FileInfo])]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Size,

    [ValidateRange(1, 2147483647)]
    [int]$Count = 1,

    [Alias('FileName')]
    [ValidateNotNullOrEmpty()]
    [string]$Name = 'dummy',

    [ValidateRange(1MB, 256MB)]
    [long]$ChunkSize = 64MB,

    [switch]$Fast,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 }
catch [System.IO.IOException] { <# No console handle attached (e.g. remote session, scheduled task) #> }

function ConvertTo-Bytes {
    <#
    .SYNOPSIS
        Converts a human-readable size string to bytes.
    #>
    [OutputType([long])]
    param([string]$SizeString)

    if ($SizeString -notmatch '^(\d+(?:\.\d+)?)\s*(TB|GB|MB|KB|B)?$') {
        throw "Invalid size format: '$SizeString'. Use a number optionally followed by B, KB, MB, GB, or TB (e.g. '1GB', '500MB', '4096')."
    }

    $value = [double]$Matches[1]
    $unit  = if ($Matches[2]) { $Matches[2].ToUpper() } else { 'B' }

    $multiplier = switch ($unit) {
        'TB' { 1TB }
        'GB' { 1GB }
        'MB' { 1MB }
        'KB' { 1KB }
        'B'  { 1L  }
        default { throw "Unrecognised unit: '$unit'." }
    }

    return [long]($value * $multiplier)
}

function Write-DummyFile {
    <#
    .SYNOPSIS
        Creates a zero-filled file of the specified size.
    #>
    param(
        [string]$FilePath,
        [long]$SizeBytes,
        [long]$ChunkSize,
        [string]$Activity,
        [int]$ProgressId = 0,
        [int]$ParentProgressId = -1
    )

    $buffer  = New-Object byte[] $ChunkSize

    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList (
        $FilePath,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $written = 0L
        $lastPct = -1
        while ($written -lt $SizeBytes) {
            $toWrite = [Math]::Min($ChunkSize, $SizeBytes - $written)
            $stream.Write($buffer, 0, [int]$toWrite)
            $written += $toWrite

            $pct = [int](($written / $SizeBytes) * 100)
            if ($pct -ne $lastPct) {
                Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $Activity `
                    -Status ("{0:N1} MB / {1:N1} MB" -f ($written / 1MB), ($SizeBytes / 1MB)) `
                    -PercentComplete $pct
                $lastPct = $pct
            }
        }
    }
    finally {
        # Dispose flushes the buffer internally; an explicit Flush() here would
        # prevent Dispose() from running if Flush() itself raised an exception.
        $stream.Dispose()
        Write-Progress -Id $ProgressId -Activity $Activity -Completed
    }
}

function Write-FastFile {
    <#
    .SYNOPSIS
        Allocates a file of the specified size without writing data.
    .NOTES
        Uses FileStream.SetLength() to allocate NTFS clusters immediately.
        The OS Valid Data Length (VDL) mechanism guarantees that reads between the
        start of the file and EOF return zeros — no previously deleted data is exposed.
        No elevated privileges required.
    #>
    param(
        [string]$FilePath,
        [long]$SizeBytes,
        [string]$Activity,
        [int]$ProgressId = 0,
        [int]$ParentProgressId = -1
    )

    Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $Activity `
        -Status 'Allocating clusters...' -PercentComplete 0

    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList (
        $FilePath,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $stream.SetLength($SizeBytes)
    }
    finally {
        $stream.Dispose()
    }

    Write-Progress -Id $ProgressId -Activity $Activity -Completed
}

# Validate and resolve the target directory
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Path not found or is not a directory: $Path"
}
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

# Parse the size string
$sizeBytes = ConvertTo-Bytes -SizeString $Size
if ($sizeBytes -le 0) {
    throw "Size must be greater than 0."
}

# Check available disk space for the total number of files
$totalRequired  = [decimal]$sizeBytes * $Count
$driveRoot      = [System.IO.Path]::GetPathRoot($resolvedPath)
$availableBytes = (New-Object -TypeName System.IO.DriveInfo -ArgumentList $driveRoot).AvailableFreeSpace
if ($totalRequired -gt $availableBytes) {
    $reqStr  = if ($totalRequired -ge 1GB) { '{0:N2} GB' -f ($totalRequired / 1GB) }
               elseif ($totalRequired -ge 1MB) { '{0:N2} MB' -f ($totalRequired / 1MB) }
               else { "$totalRequired B" }
    $freeStr = if ($availableBytes -ge 1GB) { '{0:N2} GB' -f ($availableBytes / 1GB) }
               elseif ($availableBytes -ge 1MB) { '{0:N2} MB' -f ($availableBytes / 1MB) }
               else { "$availableBytes B" }
    throw "Insufficient disk space. Required: $reqStr, Available: $freeStr"
}

# Build the list of target file paths
$indexPad = [Math]::Max(3, $Count.ToString().Length)
$filePaths = for ($i = 1; $i -le $Count; $i++) {
    if ($Count -eq 1) {
        Join-Path $resolvedPath "$Name.bin"
    }
    else {
        $idx = $i.ToString().PadLeft($indexPad, '0')
        Join-Path $resolvedPath "${Name}_${idx}.bin"
    }
}

# Check for existing files before starting any writes
foreach ($fp in $filePaths) {
    if ((Test-Path -LiteralPath $fp) -and -not $Force) {
        throw "File already exists: $fp. Use -Force to overwrite."
    }
}

# Create the files
$useFast = $Fast.IsPresent
$parentProgressId = if ($Count -gt 1) { 0 } else { -1 }
$fileIndex = 0
foreach ($fp in $filePaths) {
    $fileIndex++
    $leafName = [System.IO.Path]::GetFileName($fp)
    $activity = "Creating $leafName"

    if ($Count -gt 1) {
        $outerPct = [int](($fileIndex - 1) / $Count * 100)
        Write-Progress -Id 0 -Activity "Creating $Count dummy files" `
            -Status "File $fileIndex of $Count : $leafName" `
            -PercentComplete $outerPct
    }

    if ($PSCmdlet.ShouldProcess($fp, 'Create dummy file')) {
        try {
            if ($useFast) {
                Write-FastFile -FilePath $fp -SizeBytes $sizeBytes -Activity $activity `
                    -ProgressId 1 -ParentProgressId $parentProgressId
            }
            else {
                Write-DummyFile -FilePath $fp -SizeBytes $sizeBytes -ChunkSize $ChunkSize `
                    -Activity $activity -ProgressId 1 -ParentProgressId $parentProgressId
            }
        }
        catch {
            # Remove the incomplete file so a failed run leaves no partial data
            if (Test-Path -LiteralPath $fp) {
                Remove-Item -LiteralPath $fp -Force -ErrorAction SilentlyContinue
            }
            throw
        }
        Write-Verbose "Created: $fp ($sizeBytes bytes)"
        Get-Item -LiteralPath $fp
    }
}
if ($Count -gt 1) {
    Write-Progress -Id 0 -Activity "Creating $Count dummy files" -Completed
}
