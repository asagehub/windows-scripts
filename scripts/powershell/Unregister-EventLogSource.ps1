#Requires -Version 3.0

<#
.SYNOPSIS
    Unregisters a Windows event log source from the local computer.

.DESCRIPTION
    Removes a registered Windows event log source from this computer.
    The source entry is deleted from the Windows registry:
        HKLM\SYSTEM\CurrentControlSet\Services\EventLog\<Log>\<Source>

    This script only removes the source registration. It does not delete the
    event log itself or clear any existing log entries.

    This operation is irreversible. A confirmation prompt is shown by default
    because ConfirmImpact is set to High. Use -WhatIf to preview the action
    without making any changes. Use -Force to suppress the confirmation prompt
    in automated scripts.

    Requires administrator privileges.

.PARAMETER Source
    Name of the event source to unregister. Source names are case-insensitive.
    The source must have been registered on the local computer.

.PARAMETER Force
    Suppresses the automatic confirmation prompt. Intended for use in
    automated scripts where interactive prompts are not desired.

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    .\Unregister-EventLogSource.ps1 -Source MyApp
    Prompts for confirmation, then removes the event source registration for "MyApp".

.EXAMPLE
    .\Unregister-EventLogSource.ps1 -Source MyApp -WhatIf
    Shows what would happen without making any changes.

.EXAMPLE
    .\Unregister-EventLogSource.ps1 -Source MyApp -Force
    Removes the event source registration without prompting for confirmation.

.NOTES
    Administrator privileges are required to write to
    HKLM\SYSTEM\CurrentControlSet\Services\EventLog.

    Built-in system sources (e.g. 'PowerShell') cannot be removed by this script.

    If you intend to re-register the same source under a different log after
    deletion, a system reboot is required for the change to take effect.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Source,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 }
catch [System.IO.IOException] { <# No console handle attached (e.g. remote session, scheduled task) #> }

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator privileges are required. Run PowerShell as Administrator.'
}

# Prevent accidental deletion of built-in Windows event sources.
$protectedSources = @('PowerShell', 'Windows PowerShell')
if ($protectedSources -contains $Source) {
    throw "Cannot unregister built-in system source '$Source'."
}

# Verify the source is registered before attempting deletion.
# SourceExists() accesses HKLM\SYSTEM\CurrentControlSet\Services\EventLog,
# which may require administrator privileges on some systems.
$sourceRegistered = $false
try {
    $sourceRegistered = [System.Diagnostics.EventLog]::SourceExists($Source)
}
catch [System.Security.SecurityException] {
    throw "Insufficient privileges to check event source registration. Run as administrator."
}

if (-not $sourceRegistered) {
    Write-Warning "Event source '$Source' is not registered on this computer. Nothing to do."
    return
}

$logName = [System.Diagnostics.EventLog]::LogNameFromSourceName($Source, '.')

# When -Force is specified without an explicit -Confirm, suppress the automatic
# confirmation prompt that ConfirmImpact = 'High' would otherwise trigger.
if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
    $ConfirmPreference = 'None'
}

$target = "event source '$Source' in log '$logName'"
if ($PSCmdlet.ShouldProcess($target, 'Unregister event source (IRREVERSIBLE)')) {
    try {
        [System.Diagnostics.EventLog]::DeleteEventSource($Source)
        Write-Verbose "Successfully unregistered event source '$Source' from log '$logName'."
    }
    catch [System.Security.SecurityException] {
        throw "Insufficient privileges to unregister event source '$Source'. Run as administrator."
    }
    catch [System.InvalidOperationException] {
        throw "Registry is in an inconsistent state for source '$Source': $_"
    }
}
