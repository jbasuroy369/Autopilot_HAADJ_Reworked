# Autopilot_HAADJ_Reworked

Only if the backend Hybrid join process gets completed before the device completes the device ESP phase (that is AAD Connect picked up the on-prem computer object that is created by the Intune ODJ connector and synced it to AAD BEFORE device ESP completes), we can be assured that the device will get the required AzureAD PRT on the initial user sign-in to Windows that is presented to the user post the device ESP phase.

However, if the device does not stays locked in the device ESP phase for long enough to buffer this backend sync delay, then the user sign-in event (login to Windows post completing device ESP) won't fetch the device the required user token (Azure AD PRT).

Considering this is true fact for most Hybrid Azure AD join provisioning, you might be looking at ways to prevent users from start using the system, since the device is not production ready in any sense. Without AzureAD PRT, the device cannot connect with the M365 services.

This solution ensures that the end-user is presented with the Desktop screen only when the device has completed the Hybrid Join process by

	• masking the Desktop screen on initial Windows login with a custom Windows 10 OOBE look-a-like screen
	• disabling user activity till the setup completes by hiding the taskbar and cursor
	• monitoring status of the Hybrid join process in backend, and finally
	• restarting the device when it detects the Hybrid join process has finished

![image](https://user-images.githubusercontent.com/86624602/135493888-e23ba744-2122-4ebe-9aa5-b03e0742e086.png)

This ensures that when the device finally comes back post the reboot, the user sign-in will fetch the device the required Azure AD PRT to start communicating with the M365 services.

