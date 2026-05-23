# Unregister-EventLogSource

Unregisters a Windows event log source.

## Syntax

```plaintext
.\Unregister-EventLogSource.ps1
    -Source <String>
    [-Force]
    [<CommonParameters>]
```

## Examples

```powershell
.\Unregister-EventLogSource.ps1 -Source MyApp
```

Prompts for confirmation, then removes the event source registration for "MyApp".

```powershell
.\Unregister-EventLogSource.ps1 -Source MyApp -WhatIf
```

Shows what would happen without making any changes.

```powershell
.\Unregister-EventLogSource.ps1 -Source MyApp -Force
```

Removes the event source registration without prompting for confirmation.
