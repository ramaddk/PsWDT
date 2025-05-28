<#
.SYNOPSIS
    PowerShell Windows Debloat Toolkit (PsWDT)
    
.DESCRIPTION
    A framework for disabling and removing unwanted Windows features, services, and bloatware
    
.NOTES
    Version:        1.0.0
    Creation Date:  2025-05-23
    Developed by ramaddk
#>
    
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string]$SettingsFile = "$PSScriptRoot\Settings\Default-Settings.xml",
    
    [Parameter(Mandatory=$false)]
    [switch]$NoRestart,
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent,
    
    [Parameter(Mandatory=$false)]
    [switch]$Undo
)

# Script Variables
$script:ScriptVersion = "1.0.0"
$script:ScriptName = "PowerShell Windows Debloat Toolkit"
$script:LogDir = "$PSScriptRoot\Logs"
$script:LogFile = "$script:LogDir\PsWDT_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:BackupDir = "$PSScriptRoot\Backups"
$script:BackupFile = "$script:BackupDir\PsWDT_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

# Import Functions
. "$PSScriptRoot\Functions\Write-Log.ps1"
. "$PSScriptRoot\Functions\Set-RegistryValue.ps1"
. "$PSScriptRoot\Functions\Disable-ScheduledTask.ps1"
. "$PSScriptRoot\Functions\Remove-WindowsApp.ps1"
. "$PSScriptRoot\Functions\Stop-WindowsService.ps1"
. "$PSScriptRoot\Functions\Run-Command.ps1"
. "$PSScriptRoot\Functions\Backup-State.ps1"
. "$PSScriptRoot\Functions\Undo-Changes.ps1"

# Create Log Directory if it doesn't exist
if (-not (Test-Path -Path $script:LogDir)) {
    New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null
}

# Create Backup Directory if it doesn't exist
if (-not (Test-Path -Path $script:BackupDir)) {
    New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null
}

# Handle Undo mode
if ($Undo) {
    $latestBackup = Get-LatestBackupFile -BackupDir $script:BackupDir
    
    if (-not $latestBackup) {
        Write-Host "No backup files found in $script:BackupDir" -ForegroundColor Red
        Write-Host "Cannot perform undo operation without a backup file." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "===================================================="
    Write-Host "$script:ScriptName v$script:ScriptVersion - UNDO MODE"
    Write-Host "===================================================="
    Write-Host "Found backup file: $(Split-Path -Leaf $latestBackup)"
    Write-Host ""
    
    if (-not $Silent) {
        $confirm = Read-Host "Do you want to restore settings from this backup? (Y/N)"
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Host "Undo operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    try {
        Write-Host "Loading backup state..." -ForegroundColor Yellow
        Load-BackupState -BackupFile $latestBackup
        
        Write-Host "Restoring registry values..." -ForegroundColor Yellow
        $regResult = Undo-RegistryChanges
        Write-Host "  Registry: $($regResult.Success)/$($regResult.Total) restored successfully" -ForegroundColor Green
        if ($regResult.Failed -gt 0) {
            Write-Host "  Registry: $($regResult.Failed) failed to restore" -ForegroundColor Red
        }
        
        Write-Host "Restoring services..." -ForegroundColor Yellow
        $svcResult = Undo-ServiceChanges
        Write-Host "  Services: $($svcResult.Success)/$($svcResult.Total) restored successfully" -ForegroundColor Green
        if ($svcResult.Failed -gt 0) {
            Write-Host "  Services: $($svcResult.Failed) failed to restore" -ForegroundColor Red
        }
        
        Write-Host "Restoring scheduled tasks..." -ForegroundColor Yellow
        $taskResult = Undo-ScheduledTaskChanges
        Write-Host "  Scheduled Tasks: $($taskResult.Success)/$($taskResult.Total) restored successfully" -ForegroundColor Green
        if ($taskResult.Failed -gt 0) {
            Write-Host "  Scheduled Tasks: $($taskResult.Failed) failed to restore" -ForegroundColor Red
        }
        
        Write-Host "Checking Windows apps..." -ForegroundColor Yellow
        $appResult = Undo-WindowsAppChanges
        Write-Host "  Windows Apps: $($appResult.Success)/$($appResult.Total) checked" -ForegroundColor Green
        if ($appResult.Failed -gt 0) {
            Write-Host "  Windows Apps: $($appResult.Failed) cannot be automatically restored" -ForegroundColor Red
        }
        
        Write-Host "Checking commands..." -ForegroundColor Yellow
        $cmdResult = Undo-CommandChanges
        if ($cmdResult.Total -gt 0) {
            Write-Host "  Commands: $($cmdResult.Total) commands were executed but cannot be automatically undone" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "===================================================="
        Write-Host "Undo operation completed successfully!"
        Write-Host "===================================================="
        
        if ((-not $NoRestart) -and (-not $Silent)) {
            $restart = Read-Host "Some changes may require a restart to take effect. Do you want to restart now? (Y/N)"
            if ($restart -eq "Y" -or $restart -eq "y") {
                Write-Host "Restarting computer..."
                Restart-Computer -Force
            }
        }
        
    } catch {
        Write-Host "Undo operation failed: $_" -ForegroundColor Red
        exit 1
    }
    
    exit 0
}

# Function to write to console and log
function Write-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Type = "Info"
    )
    
    Write-Log -Message $Message -Type $Type -LogFile $script:LogFile
    
    if (-not $Silent) {
        switch ($Type) {
            "Info" { Write-Host $Message }
            "Warning" { Write-Host $Message -ForegroundColor Yellow }
            "Error" { Write-Host $Message -ForegroundColor Red }
            "Success" { Write-Host $Message -ForegroundColor Green }
        }
    }
}

# Display script header
Write-Message -Message "===================================================="
Write-Message -Message "$script:ScriptName v$script:ScriptVersion"
Write-Message -Message "===================================================="
Write-Message -Message "Starting script execution at $(Get-Date)"
Write-Message -Message "Using settings file: $SettingsFile"

# Check if settings file exists
if (-not (Test-Path -Path $SettingsFile)) {
    Write-Message -Message "Settings file not found: $SettingsFile" -Type "Error"
    exit 1
}

# Import settings file
try {
    Write-Message -Message "Importing settings file..."
    [xml]$Settings = Get-Content -Path $SettingsFile
    Write-Message -Message "Settings file imported successfully" -Type "Success"
} catch {
    Write-Message -Message "Failed to import settings file: $_" -Type "Error"
    exit 1
}

# Initialize backup system for normal operation
Initialize-BackupSystem -BackupDir $script:BackupDir -BackupFile $script:BackupFile

# Process settings
Write-Message -Message "Processing settings..."
$totalItems = 0
$completedItems = 0
$failedItems = 0

foreach ($category in $Settings.DebloatSettings.Category) {
    Write-Message -Message "`nProcessing category: $($category.Name)"
    
    foreach ($item in $category.Item) {
        $totalItems++
        $itemName = $item.Name
        $itemType = $item.Type
        $itemValue = $item.Value
        $itemDescription = $item.Description
        
        Write-Message -Message "  Processing item: $itemName ($itemType)"
        Write-Message -Message "  Description: $itemDescription"
        
        try {
            switch ($itemType) {
                "Registry" {
                    $path = $item.Path
                    $registryValueName = $item.SelectSingleNode("Name[2]").InnerText
                    $type = $item.ValueType
                    Set-RegistryValue -Path $path -Name $registryValueName -Value $itemValue -Type $type -CreateBackup
                }
                "ScheduledTask" {
                    Disable-ScheduledTask -TaskName $itemValue -CreateBackup
                }
                "WindowsApp" {
                    Remove-WindowsApp -AppName $itemValue -CreateBackup
                }
                "WindowsService" {
                    Stop-WindowsService -ServiceName $itemValue -CreateBackup
                }
                "Command" {
                    Run-Command -Command $itemValue -Description $itemDescription -CreateBackup
                }
                default {
                    Write-Message -Message "    Unknown item type: $itemType" -Type "Warning"
                    $failedItems++
                    continue
                }
            }
            
            Write-Message -Message "    Completed successfully" -Type "Success"
            $completedItems++
        } catch {
            Write-Message -Message "    Failed: $_" -Type "Error"
            $failedItems++
        }
    }
}

# Save backup state
if ($completedItems -gt 0) {
    try {
        Save-BackupState -BackupFile $script:BackupFile
        Write-Message -Message "Backup saved to: $script:BackupFile" -Type "Success"
    } catch {
        Write-Message -Message "Failed to save backup: $_" -Type "Warning"
    }
}

# Display summary
Write-Message -Message "`n===================================================="
Write-Message -Message "Execution Summary:"
Write-Message -Message "  Total items: $totalItems"
Write-Message -Message "  Completed successfully: $completedItems"
Write-Message -Message "  Failed: $failedItems"
Write-Message -Message "===================================================="
Write-Message -Message "Script execution completed at $(Get-Date)"

# Prompt for restart if needed and not suppressed
if ((-not $NoRestart) -and ($completedItems -gt 0) -and (-not $Silent)) {
    $restart = Read-Host "Some changes may require a restart to take effect. Do you want to restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Message -Message "Restarting computer..."
        Restart-Computer -Force
    }
}
