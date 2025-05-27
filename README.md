# PowerShell Windows Debloat Toolkit (PsWDT)

A PowerShell framework for disabling and removing unwanted Windows features, services, and bloatware.

## Overview

PsWDT is designed to be a flexible and reusable toolkit for debloating Windows installations. It works by processing a settings file that defines various actions to perform, such as:

- Modifying registry values
- Disabling scheduled tasks
- Removing Windows Store apps
- Stopping and disabling Windows services
- Running custom PowerShell commands

## Usage

### Basic Usage

```powershell
.\PsWDT.ps1
```

This will run the toolkit using the default settings file located at `.\Settings\Default-Settings.xml`.

### Advanced Usage

```powershell
.\PsWDT.ps1 -SettingsFile "C:\path\to\your\custom-settings.xml" -NoRestart -Silent
```

Parameters:
- `-SettingsFile`: Specify a custom settings file path
- `-NoRestart`: Suppress the restart prompt at the end of execution
- `-Silent`: Run in silent mode (no console output)

## Settings File Format

The settings file uses XML format to define categories and items to process. Each item has a type, value, and description.

Example:

```xml
<?xml version="1.0" encoding="utf-8"?>
<DebloatSettings>
    <Category Name="Privacy">
        <Item>
            <Name>DisableTelemetry</Name>
            <Type>Registry</Type>
            <Path>HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection</Path>
            <Name>AllowTelemetry</Name>
            <Value>0</Value>
            <ValueType>DWord</ValueType>
            <Description>Disable Windows telemetry and data collection</Description>
        </Item>
        <!-- More items -->
    </Category>
    <!-- More categories -->
</DebloatSettings>
```

### Supported Item Types

1. **Registry**: Modify registry values
   - Required fields: Path, Name, Value, ValueType
   - ValueType can be: String, ExpandString, Binary, DWord, QWord, MultiString

2. **ScheduledTask**: Disable Windows scheduled tasks
   - Required fields: Value (task path)

3. **WindowsApp**: Remove Windows Store apps
   - Required fields: Value (app name)

4. **WindowsService**: Stop and disable Windows services
   - Required fields: Value (service name)

5. **Command**: Run custom PowerShell commands
   - Required fields: Value (command to execute)

## Creating Custom Settings Files

You can create your own custom settings files based on the default one. Simply copy `Default-Settings.xml`, modify it to suit your needs, and provide the path to the new file when running the toolkit.

## Logs

The toolkit creates detailed logs in the `Logs` directory. Log files are named with a timestamp to avoid overwriting previous logs.

## Notes

- Many operations require administrative privileges. Run PowerShell as Administrator.
- Some changes may require a system restart to take effect.
- Use at your own risk. Always test in a controlled environment before using in production.