# Split-File

Splits a large file into numbered parts, or joins them back together.

## Syntax

```powershell
.\Split-File.ps1
    -Mode Split
    -InputFile <String>
    [[-PartCount] <Int32>]
    [-Clean]
    [<CommonParameters>]

.\Split-File.ps1
    -Mode Join
    [-Clean]
    [<CommonParameters>]

.\Split-File.ps1
    -Clean
    [<CommonParameters>]
```

## Examples

```powershell
.\Split-File.ps1 -Mode Split -InputFile "C:\WorkingDirectory\Source.ISO"
```

Splits `Source.ISO` into 2 equal parts and saves them to `Parts\`.

```powershell
.\Split-File.ps1 -Mode Split -InputFile "C:\WorkingDirectory\Source.ISO" -PartCount 4
```

Splits `Source.ISO` into 4 parts and saves them to `Parts\`.

```powershell
.\Split-File.ps1 -Mode Split -InputFile "C:\WorkingDirectory\Source.ISO" -Clean
```

Clears `Parts\` and `Output\` first, then splits `Source.ISO` into 2 parts.

```powershell
.\Split-File.ps1 -Mode Join
```

Reads part files from `Parts\` and reassembles the original file into `Output\`.

```powershell
.\Split-File.ps1 -Mode Join -Clean
```

Clears `Output\` first, then reassembles the original file into `Output\`.

```powershell
.\Split-File.ps1 -Clean
```

Deletes all files from `Parts\` and `Output\` without splitting or joining.
