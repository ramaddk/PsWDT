function Set-RegistryValue {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        $Value,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("String", "ExpandString", "Binary", "DWord", "QWord", "MultiString")]
        [string]$Type,
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateBackup
    )
    
    try {
        # Create backup if requested
        if ($CreateBackup -and (Get-Command Backup-RegistryValue -ErrorAction SilentlyContinue)) {
            Backup-RegistryValue -Path $Path -Name $Name -NewValue $Value -Type $Type
        }
        
        # Create registry path if it doesn't exist
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        # Set registry value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        throw "Failed to set registry value [$Path] $Name : $_"
    }
}
