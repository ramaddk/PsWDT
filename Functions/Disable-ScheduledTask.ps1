function Disable-ScheduledTask {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateBackup
    )
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Get-Command Backup-ScheduledTaskState -ErrorAction SilentlyContinue)) {
            Backup-ScheduledTaskState -TaskName $TaskName
        }
        
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        if ($task) {
            Disable-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
            return $true
        } else {
            throw "Scheduled task not found: $TaskName"
        }
    } catch {
        throw "Failed to disable scheduled task $TaskName : $_"
    }
}
