# New-DummyFile

Creates one or more dummy files of a specified size for disk space testing.

## Syntax

```powershell
.\New-DummyFile.ps1
    -Path <String>
    -Size <String>
    [[-Count] <Int32>]
    [[-Name] <String>]
    [[-ChunkSize] <Int64>]
    [-Fast]
    [-Force]
    [<CommonParameters>]
```

## Examples

```powershell
.\New-DummyFile.ps1 -Path C:\Temp -Size 1GB
```

Creates `C:\Temp\dummy.bin`.

```powershell
.\New-DummyFile.ps1 -Path C:\Temp -Size 500MB -Count 3
```

Creates `C:\Temp\dummy_001.bin`, `dummy_002.bin`, `dummy_003.bin` (500 MB each).

```powershell
.\New-DummyFile.ps1 -Path C:\Temp -Size 1GB -Name testdata -Force
```

Creates `C:\Temp\testdata.bin`, overwriting if it already exists.

```powershell
.\New-DummyFile.ps1 -Path C:\Temp -Size 2TB -Fast
```

Creates `C:\Temp\dummy.bin` (2 TB) near-instantly. Requires an NTFS volume.
