# Windows Scripts

A collection of useful Command shell and PowerShell scripts for development.

## PowerShell

### Utilities

| Script | Document | Description |
| --- | --- | --- |
| [Get-FolderSize.ps1](scripts/powershell/Get-FolderSize.ps1) | [Get-FolderSize.md](docs/powershell/Get-FolderSize.md) | Returns all folders sorted by size, largest first. |
| [Split-File.ps1](scripts/powershell/Split-File.ps1) | [Split-File.md](docs/powershell/Split-File.md) | Splits a large file into numbered parts, or joins them back together. |

### Testing

| Script | Document | Description |
| --- | --- | --- |
| [New-DummyFile.ps1](scripts/powershell/New-DummyFile.ps1) | [New-DummyFile.md](docs/powershell/New-DummyFile.md) | Creates one or more dummy files of a specified size for disk space testing. |
| [Start-CpuLoad.ps1](scripts/powershell/Start-CpuLoad.ps1) | [Start-CpuLoad.md](docs/powershell/Start-CpuLoad.md) | Maintains a target CPU usage percentage for a specified duration. |
| [Start-MemoryLoad.ps1](scripts/powershell/Start-MemoryLoad.ps1) | [Start-MemoryLoad.md](docs/powershell/Start-MemoryLoad.md) | Maintains a target physical memory usage percentage for a specified duration. |
| [Write-EventLogError.ps1](scripts/powershell/Write-EventLogError.ps1) | [Write-EventLogError.md](docs/powershell/Write-EventLogError.md) | Writes error entries to a Windows event log. |
| [Unregister-EventLogSource.ps1](scripts/powershell/Unregister-EventLogSource.ps1) | [Unregister-EventLogSource.md](docs/powershell/Unregister-EventLogSource.md) | Unregisters a Windows event log source. |

## License

[MIT License](LICENSE)
