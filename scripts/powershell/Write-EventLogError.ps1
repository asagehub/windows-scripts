#Requires -Version 3.0

<#
.SYNOPSIS
    Writes error entries to a Windows event log for testing or diagnostic purposes.

.DESCRIPTION
    Writes one or more Error-level entries to the specified Windows event log.
    Useful for testing, diagnostics, and validating that event log consumers
    (such as monitoring tools or SIEM systems) correctly receive error events.

    If the specified event source has not been registered yet, the script registers
    it automatically. Registering a new source requires administrator privileges.

    If the source is already registered under a different log, the script emits
    a warning and writes to the log where the source is actually registered.

.PARAMETER LogName
    Name of the Windows event log to write to (e.g. Application, System).
    The log must already exist on the local computer. Default: Application.

.PARAMETER Source
    Name of the event source to write under. If the source is not yet registered,
    the script registers it automatically (requires administrator privileges).
    Default: PowerShell.

.PARAMETER Count
    Number of error entries to write (Int64). Default: 1.

.PARAMETER EventId
    Event identifier for the written entries (0-65535). Default: 9999.

.PARAMETER Message
    Message text for the written entries.
    A descriptive default message is used when this parameter is omitted.

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    .\Write-EventLogError.ps1
    Writes one error entry to the Application log with default settings.

.EXAMPLE
    .\Write-EventLogError.ps1 -LogName System -Count 3
    Writes three error entries to the System log.

.EXAMPLE
    .\Write-EventLogError.ps1 -LogName Application -Source MyApp -EventId 1001 -Count 5
    Writes five error entries to the Application log under the source "MyApp".

.EXAMPLE
    .\Write-EventLogError.ps1 -WhatIf
    Shows what would be written without actually writing to the event log.

.NOTES
    Registering a new event source requires administrator privileges.
    Writing to the Security log requires SeAuditPrivilege; use the Application
    or System log for general testing.

    When a new source is registered, it is written to the Windows registry at:
        HKLM\SYSTEM\CurrentControlSet\Services\EventLog\<LogName>\<Source>
    This registration persists after the script completes.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$LogName = 'Application',

    [ValidateNotNullOrEmpty()]
    [string]$Source = 'PowerShell',

    [ValidateRange(1, [long]::MaxValue)]
    [long]$Count = 1,

    [ValidateRange(0, 65535)]
    [int]$EventId = 9999,

    [ValidateNotNullOrEmpty()]
    [string]$Message = 'Test error event written by Write-EventLogError.ps1.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 }
catch [System.IO.IOException] { <# No console handle attached (e.g. remote session, scheduled task) #> }

# Verify the target log exists on the local computer.
if (-not [System.Diagnostics.EventLog]::Exists($LogName)) {
    throw "Event log '$LogName' does not exist on this computer."
}

# Check whether the event source is already registered.
# SourceExists() accesses HKLM\SYSTEM\CurrentControlSet\Services\EventLog,
# which may require administrator privileges on some systems.
$sourceRegistered = $false
try {
    $sourceRegistered = [System.Diagnostics.EventLog]::SourceExists($Source)
}
catch [System.Security.SecurityException] {
    throw "Insufficient privileges to check event source registration. Run as administrator."
}

if ($sourceRegistered) {
    # A source can only be registered to one log at a time.
    # Warn and redirect if it points to a different log than requested.
    $registeredLog = [System.Diagnostics.EventLog]::LogNameFromSourceName($Source, '.')
    if ($registeredLog -ne $LogName) {
        Write-Warning ("Source '$Source' is already registered under log '$registeredLog', " +
                       "not '$LogName'. Events will be written to '$registeredLog'.")
        $LogName = $registeredLog
    }
}
else {
    # Register the source under the requested log. Requires administrator privileges.
    if ($PSCmdlet.ShouldProcess("event source '$Source' under log '$LogName'", 'Register event source')) {
        Write-Verbose "Registering event source '$Source' under log '$LogName'."
        try {
            [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
        }
        catch [System.Security.SecurityException] {
            throw "Insufficient privileges to register event source '$Source'. Run as administrator."
        }
    }
}

# Write the error entries.
$target = "event log '$LogName' (Source: $Source, EventId: $EventId)"
$eventLog = New-Object -TypeName System.Diagnostics.EventLog -ArgumentList $LogName, '.', $Source
try {
    for ($i = 1; $i -le $Count; $i++) {
        if ($PSCmdlet.ShouldProcess($target, 'Write error entry')) {
            $eventLog.WriteEntry($Message, [System.Diagnostics.EventLogEntryType]::Error, $EventId)
            Write-Verbose ("Written error entry {0}/{1} to {2}." -f $i, $Count, $target)
        }
    }
}
finally {
    $eventLog.Dispose()
}
