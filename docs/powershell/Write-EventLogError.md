# Write-EventLogError

Writes error entries to a Windows event log.

## Syntax

```plaintext
.\Write-EventLogError.ps1
    [[-LogName] <String>]
    [[-Source] <String>]
    [[-Count] <Int64>]
    [[-EventId] <Int32>]
    [[-Message] <String>]
    [<CommonParameters>]
```

## Examples

```powershell
.\Write-EventLogError.ps1
```

Writes one error entry to the Application log with default settings.

```powershell
.\Write-EventLogError.ps1 -LogName System -Count 3
```

Writes three error entries to the System log.

```powershell
.\Write-EventLogError.ps1 -LogName Application -Source MyApp -EventId 1001 -Count 5
```

Writes five error entries to the Application log under the source "MyApp".

```powershell
.\Write-EventLogError.ps1 -WhatIf
```

Shows what would be written without actually writing to the event log.
