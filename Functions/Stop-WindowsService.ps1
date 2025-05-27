function Stop-WindowsService {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceName,
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateBackup
    )
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Get-Command Backup-ServiceState -ErrorAction SilentlyContinue)) {
            Backup-ServiceState -ServiceName $ServiceName
        }
        
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($service) {
            # Stop the service
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            
            # Disable the service
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            
            return $true
        } else {
            throw "Windows service not found: $ServiceName"
        }
    } catch {
        throw "Failed to stop Windows service $ServiceName : $_"
    }
}
