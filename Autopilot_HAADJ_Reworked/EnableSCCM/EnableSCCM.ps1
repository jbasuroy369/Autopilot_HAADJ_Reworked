<#
.SYNOPSIS

  ScriptName: EnableSCCM.ps1

.DESCRIPTION

  The script deletes the Dummy Files which where created by AADHybridLockOOBE package during device ESP and thus makes the device eligible for the automatic SCCM client agent push.

.NOTES

  Version:        1.0
  Author:         Joymalya Basu Roy
  Creation Date:  

#>

# Delete the Dummy Files to enable SCCM agent installation

Remove-item c:\Windows\ccm
Remove-item c:\Windows\ccmsetup

# Create IME detection

mkdir C:\ProgramData\SCCMEnabled