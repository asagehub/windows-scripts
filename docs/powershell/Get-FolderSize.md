# Get-FolderSize

Returns all folders sorted by size, largest first.

## Syntax

```powershell
.\Get-FolderSize.ps1
    [[-Path] <String>]
    [[-Top] <Int32>]
    [-NoRecurse]
    [[-OutputPath] <String>]
    [<CommonParameters>]
```

## Examples

```powershell
.\Get-FolderSize.ps1 -Path "C:\" -Top 50
```

Returns the 50 largest folders under `C:\`.

```powershell
.\Get-FolderSize.ps1 -Path "C:\" -Top 50 -NoRecurse
```

Returns the 50 largest folders by direct file size only (subfolders excluded).

```powershell
.\Get-FolderSize.ps1 -Path "C:\" -OutputPath "C:\Temp\result.csv"
```

Exports the results to a CSV file.
