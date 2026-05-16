# Start-MemoryLoad

Maintains a target physical memory usage percentage for a specified duration.

## Syntax

```plaintext
.\Start-MemoryLoad.ps1
    -Percent <Int32>
    -Seconds <Int32>
    [<CommonParameters>]

.\Start-MemoryLoad.ps1
    -Percent <Int32>
    -Minutes <Int32>
    [<CommonParameters>]
```

## Examples

```powershell
.\Start-MemoryLoad.ps1 -Percent 80 -Minutes 15
```

Maintains 80% memory usage for 15 minutes.

```powershell
.\Start-MemoryLoad.ps1 -Percent 70 -Seconds 30
```

Maintains 70% memory usage for 30 seconds.
