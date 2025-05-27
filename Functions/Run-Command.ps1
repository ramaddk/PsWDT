function Run-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "",
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateBackup
    )
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Get-Command Backup-CommandState -ErrorAction SilentlyContinue)) {
            Backup-CommandState -Command $Command -Description $Description
        }
        
        # Execute the command using Invoke-Expression
        $output = Invoke-Expression -Command $Command -ErrorAction Stop
        return $true
    } catch {
        throw "Failed to run command [$Command] : $_"
    }
}
