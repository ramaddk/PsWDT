function Load-BackupState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    
    try {
        if (-not (Test-Path -Path $BackupFile)) {
            throw "Backup file not found: $BackupFile"
        }
        
        $backupContent = Get-Content -Path $BackupFile -Raw -Encoding UTF8
        $script:BackupData = $backupContent | ConvertFrom-Json
        return $true
    } catch {
        throw "Failed to load backup state: $_"
    }
}

function Undo-RegistryChanges {
    $successCount = 0
    $failureCount = 0
    
    foreach ($entry in $script:BackupData.Registry) {
        try {
            if ($entry.Exists) {
                if (Test-Path -Path $entry.Path) {
                    Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.OriginalValue -Type $entry.OriginalType -Force
                } else {
                    New-Item -Path $entry.Path -Force | Out-Null
                    Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.OriginalValue -Type $entry.OriginalType -Force
                }
            } else {
                if (Test-Path -Path $entry.Path) {
                    $property = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
                    if ($property) {
                        Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force
                    }
                }
            }
            $successCount++
        } catch {
            Write-Warning "Failed to restore registry value [$($entry.Path)] $($entry.Name): $_"
            $failureCount++
        }
    }
    
    return @{
        Success = $successCount
        Failed = $failureCount
        Total = $script:BackupData.Registry.Count
    }
}

function Undo-ServiceChanges {
    $successCount = 0
    $failureCount = 0
    
    foreach ($entry in $script:BackupData.Services) {
        try {
            if ($entry.Exists) {
                $service = Get-Service -Name $entry.ServiceName -ErrorAction SilentlyContinue
                if ($service) {
                    Set-Service -Name $entry.ServiceName -StartupType $entry.OriginalStartType -ErrorAction Stop
                    
                    if ($entry.OriginalStatus -eq "Running" -and $service.Status -ne "Running") {
                        Start-Service -Name $entry.ServiceName -ErrorAction Stop
                    } elseif ($entry.OriginalStatus -eq "Stopped" -and $service.Status -eq "Running") {
                        Stop-Service -Name $entry.ServiceName -Force -ErrorAction Stop
                    }
                }
            }
            $successCount++
        } catch {
            Write-Warning "Failed to restore service $($entry.ServiceName): $_"
            $failureCount++
        }
    }
    
    return @{
        Success = $successCount
        Failed = $failureCount
        Total = $script:BackupData.Services.Count
    }
}

function Undo-ScheduledTaskChanges {
    $successCount = 0
    $failureCount = 0
    
    foreach ($entry in $script:BackupData.ScheduledTasks) {
        try {
            if ($entry.Exists) {
                $task = Get-ScheduledTask -TaskName $entry.TaskName -ErrorAction SilentlyContinue
                if ($task) {
                    if ($entry.OriginalState -eq "Ready" -and $task.State -eq "Disabled") {
                        Enable-ScheduledTask -TaskName $entry.TaskName -ErrorAction Stop | Out-Null
                    }
                }
            }
            $successCount++
        } catch {
            Write-Warning "Failed to restore scheduled task $($entry.TaskName): $_"
            $failureCount++
        }
    }
    
    return @{
        Success = $successCount
        Failed = $failureCount
        Total = $script:BackupData.ScheduledTasks.Count
    }
}

function Undo-WindowsAppChanges {
    $successCount = 0
    $failureCount = 0
    
    foreach ($entry in $script:BackupData.WindowsApps) {
        try {
            if ($entry.Exists) {
                $app = Get-AppxPackage -Name $entry.AppName -ErrorAction SilentlyContinue
                if (-not $app) {
                    Write-Warning "Cannot restore Windows app $($entry.AppName) - app packages cannot be automatically reinstalled. Manual reinstallation required."
                    $failureCount++
                } else {
                    $successCount++
                }
            } else {
                $successCount++
            }
        } catch {
            Write-Warning "Failed to check Windows app $($entry.AppName): $_"
            $failureCount++
        }
    }
    
    return @{
        Success = $successCount
        Failed = $failureCount
        Total = $script:BackupData.WindowsApps.Count
    }
}

function Undo-CommandChanges {
    $successCount = 0
    $failureCount = 0
    
    foreach ($entry in $script:BackupData.Commands) {
        Write-Warning "Command '$($entry.Description)' was executed but cannot be automatically undone. Manual reversal may be required."
        $failureCount++
    }
    
    return @{
        Success = $successCount
        Failed = $failureCount
        Total = $script:BackupData.Commands.Count
    }
}

function Get-LatestBackupFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupDir
    )
    
    if (-not (Test-Path -Path $BackupDir)) {
        return $null
    }
    
    $backupFiles = Get-ChildItem -Path $BackupDir -Filter "PsWDT_Backup_*.json" | Sort-Object LastWriteTime -Descending
    
    if ($backupFiles.Count -gt 0) {
        return $backupFiles[0].FullName
    }
    
    return $null
}