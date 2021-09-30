<#
.SYNOPSIS
  
  ScriptName: Set-AADHybridLockOOBE.ps1

.DESCRIPTION
  
  The script copies the content of the AADHybridLockOOBE app package to C:\ProgramData\AADHybridLockOOBE and 

	• sets up Active Setup for Invoke-AADHybridLockOOBE.ps1 which invokes AADHybridLockOOBE.ps1 to display the custom OOBE splash screen on login.
	• sets up blockers to delay SCCM agent installation. [Comment out the section if yours is not a co-managed environment!]  

.OUTPUT

  Log file stored in C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-AADHybridLockOOBE.log> which can be used for Intune detection.

.NOTES
  
  Version:        1.0
  Author:         Joymalya Basu Roy
  Creation Date:  28-06-2021

#>

# If running as a 32-bit process on an x64 system, re-launch as a 64-bit process

if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Logging Preparation

$AppName = "Set-AADHybridLockOOBE"
$Log_FileName = "$AppName.log"
$Log_Path = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\"
$TestPath = "$Log_Path\$Log_Filename"
$BreakingLine="- - "*10
$SubBreakingLine=". . "*10
$SectionLine="* * "*10

If(!(Test-Path $TestPath))
{
New-Item -Path $Log_Path -Name $Log_FileName -ItemType "File" -Force
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Message
    )
$timestamp = Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss"
Add-Content -Path $TestPath -Value "$timestamp : $Message"
}

# Start logging [Same file can be used for IME detection]

Write-Log "Begin processing app..."
Write-Log $SectionLine

# Get current Script run location

If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation } [string]$mypath = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
Write-Log "Current script invoke location is $mypath"

# Move contents from IME location to PrograData for later use

Copy-Item -Path "$mypath" -Destination "C:\ProgramData\AADHybridLockOOBE" -Recurse
Write-Log "Copied content to C:\ProgramData\AADHybridLockOOBE"

# Create dummy files to disable SCCM agent installation [Comment out the section if yours is not a co-managed environment!]

fsutil file createnew c:\Windows\ccm 0
fsutil file createnew c:\Windows\ccmsetup 0
Write-Log "Created dummy files to disable SCCM agent installation"

# Set AADHybridLockOOBE (Invoke-AADHybridLockOOBE.ps1) as Active Setup 

New-Item -Path "HKLM:Software\Microsoft\Active Setup\Installed Components\AADHybridLockOOBE" -Force

$RegPath = "HKLM:Software\Microsoft\Active Setup\Installed Components\AADHybridLockOOBE"
$Value = 'powershell.exe -executionpolicy bypass -windowstyle Hidden -nologo -file "C:\ProgramData\AADHybridLockOOBE\Invoke-AADHybridLockOOBE.ps1"'

Set-ItemProperty -Path $RegPath -Name '(Default)' -Value 'AADHybridLockOOBE' -Force
Set-ItemProperty -Path $RegPath -Name 'Version' -Value '1,0' -Force
Set-ItemProperty -Path $RegPath -Name 'StubPath' -Value $Value -Force

Write-Log "Setting Active Setup component for the app"
Write-Log "HKLM:Software\Microsoft\Active Setup\Installed Components\AADHybridLockOOBE"
Write-Log "End of script execution..."
