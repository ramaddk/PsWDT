function Initialize-BackupSystem {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupDir,
        
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    
    if (-not (Test-Path -Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }
    
    $script:BackupData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Registry = @()
        Services = @()
        ScheduledTasks = @()
        WindowsApps = @()
        Commands = @()
    }
}

function Save-BackupState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    
    try {
        $script:BackupData | ConvertTo-Json -Depth 10 | Set-Content -Path $BackupFile -Encoding UTF8
        return $true
    } catch {
        throw "Failed to save backup state: $_"
    }
}

function Backup-RegistryValue {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$NewValue,
        
        [Parameter(Mandatory=$true)]
        [string]$Type
    )
    
    try {
        $originalValue = $null
        $originalType = $null
        $exists = $false
        
        if (Test-Path -Path $Path) {
            $property = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($property) {
                $originalValue = $property.$Name
                $originalType = (Get-Item -Path $Path).GetValueKind($Name).ToString()
                $exists = $true
            }
        }
        
        $backupEntry = @{
            Path = $Path
            Name = $Name
            OriginalValue = $originalValue
            OriginalType = $originalType
            NewValue = $NewValue
            NewType = $Type
            Exists = $exists
        }
        
        $script:BackupData.Registry += $backupEntry
        return $true
    } catch {
        throw "Failed to backup registry value [$Path] $Name : $_"
    }
}

function Backup-ServiceState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($service) {
            $backupEntry = @{
                ServiceName = $ServiceName
                OriginalStatus = $service.Status.ToString()
                OriginalStartType = $service.StartType.ToString()
                Exists = $true
            }
        } else {
            $backupEntry = @{
                ServiceName = $ServiceName
                OriginalStatus = $null
                OriginalStartType = $null
                Exists = $false
            }
        }
        
        $script:BackupData.Services += $backupEntry
        return $true
    } catch {
        throw "Failed to backup service state $ServiceName : $_"
    }
}

function Backup-ScheduledTaskState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        if ($task) {
            $backupEntry = @{
                TaskName = $TaskName
                OriginalState = $task.State.ToString()
                Exists = $true
            }
        } else {
            $backupEntry = @{
                TaskName = $TaskName
                OriginalState = $null
                Exists = $false
            }
        }
        
        $script:BackupData.ScheduledTasks += $backupEntry
        return $true
    } catch {
        throw "Failed to backup scheduled task state $TaskName : $_"
    }
}

function Backup-WindowsAppState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AppName
    )
    
    try {
        $app = Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue
        
        if ($app) {
            $backupEntry = @{
                AppName = $AppName
                PackageFullName = $app.PackageFullName
                Version = $app.Version
                Exists = $true
            }
        } else {
            $backupEntry = @{
                AppName = $AppName
                PackageFullName = $null
                Version = $null
                Exists = $false
            }
        }
        
        $script:BackupData.WindowsApps += $backupEntry
        return $true
    } catch {
        throw "Failed to backup Windows app state $AppName : $_"
    }
}

function Backup-CommandState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    
    $backupEntry = @{
        Command = $Command
        Description = $Description
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $script:BackupData.Commands += $backupEntry
    return $true
}