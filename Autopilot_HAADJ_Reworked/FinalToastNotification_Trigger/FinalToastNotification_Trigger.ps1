<#
.SYNOPSIS
  ScriptName: FinalToastNotification_Trigger.ps1
.DESCRIPTION
  This script runs detection every 300 secs to check if the required apps from Intune are installed on the device.
  When the detection returns success, it triggers the FinalToastNotification.ps1 which was already sent to device as part of the AADHybridLockOOBE package.
.OUTPUT
   When all the required apps are detected on the device, the script tiggers FinalToastNotification.ps1 to give the toast notifcation popup to user stating device is ready for use. 
.NOTES
  Version:        1.0
  Author:         Joymalya Basu Roy, Wojciech Maciejewski
  Creation Date:  28-06-2021
#>

function Test-AppInstall {
$AppInstall = 0

#KnowBe4Phish
$One = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{06942E16-52E6-4192-9CC8-2A8174F05E39}" -ErrorAction Ignore | Select-Object -ExpandProperty DisplayName
If($One -ne $null)
{
$AppInstall++
}

#Kollective SD ECDN Agent
$Two = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{9831D06A-EBB6-4D8E-9740-15B9404D6F3C}" -ErrorAction Ignore | Select-Object -ExpandProperty DisplayVersion
If($Two -ne $null)
{
$AppInstall++
}

#Configure Teams Firewall
$Three = Get-Item -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Atos-win32-ConfigureTeamsFirewall.log" -ErrorAction Ignore
If($Three -ne $null)
{
$AppInstall++
}

#OTIS Wallpaper
$Four = Get-Item -Path "C:\Windows\Web\Otis Wallpaper\" -ErrorAction Ignore
If($Four -ne $null)
{
$AppInstall++
}

#Company Portal
$Five = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction Ignore
If($Five -ne $null)
{
$AppInstall++
}
#Check if all
If ($AppInstall -ge 5)
{
return "OK"
}
else
{
return "Not OK"
}
}

do
{
Start-Sleep -Seconds 300
$AppInstallStatus = ""
$AppInstallStatus = Test-AppInstall
}
until ($AppInstallStatus -eq "OK")

# Trigger Final Toast Notification script
C:\ProgramData\AADHybridLockOOBE\FinalToastNotification.ps1

# Create file for IME detection 
mkdir C:\ProgramData\FinalToastNotification