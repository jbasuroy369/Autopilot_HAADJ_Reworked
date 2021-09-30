The bin folder contains the required DLL files and the company brand logo for the toast notification (the solution utilizes the MahApps.Metro framework)

The xaml folder contains the WPF xml file which is basically the structure of the custom OOBE like splash screen

The Set-AADHybridLockOOBE.ps1 script which gets executed by IME during device ESP. This script

	○ copies the content of the script package from IMECache to C:PrgramData location for later use, and then
	○ sets the Active Setup registry to run the Invoke-AADHybridLockOOBE.ps1 script on login event
	○ further, creates dummy files to block SCCM agent installation

The Invoke-AADHybridLockOOBE.ps1 script invoked on login as Active Setup command

	○ creates PS Instances (runspaces) which the AADHybridLockOOBE.ps1 script will utilize to display the OOBE splash screen.
	○ invokes AADHybridLockOOBE.ps1
	○ keeps the AADHybridLockOOBE.ps1 script alive to continue display the OOBE splash screen till the Hybrid Join process gets completed
	○ on detecting the success event ID, initiates a force restart
	○ before restart, sets up Run-Once key for InitialToastNotification.ps1 to display the Initial Toast Popup

The AADHybridLockOOBE.ps1 is the script which displays the custom OOBE like splash screen

The FinalToastNotification.ps1 is sent as part of this package to be locally available on the device which will be later used via trigger (PS wrapped as Win32 apps) from Intune. 
