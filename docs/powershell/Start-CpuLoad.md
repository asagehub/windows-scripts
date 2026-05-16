# Start-CpuLoad

Maintains a target CPU usage percentage for a specified duration.

## Syntax

```powershell
.\Start-CpuLoad.ps1
    -Percent <Int32>
    -Seconds <Int32>
    [[-Cores] <Int32>]
    [<CommonParameters>]

.\Start-CpuLoad.ps1
    -Percent <Int32>
    -Minutes <Int32>
    [[-Cores] <Int32>]
    [<CommonParameters>]
```

## Examples

```powershell
.\Start-CpuLoad.ps1 -Percent 80 -Minutes 15
```

Maintains 80% CPU usage for 15 minutes.

```powershell
.\Start-CpuLoad.ps1 -Percent 50 -Seconds 30
```

Maintains 50% CPU usage for 30 seconds.
