function Remove-WindowsApp {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateBackup
    )
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Get-Command Backup-WindowsAppState -ErrorAction SilentlyContinue)) {
            Backup-WindowsAppState -AppName $AppName
        }
        
        # Check if the app exists
        $app = Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue
        
        if ($app) {
            # Remove the app
            Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
            return $true
        } else {
            throw "Windows app not found: $AppName"
        }
    } catch {
        throw "Failed to remove Windows app $AppName : $_"
    }
}
