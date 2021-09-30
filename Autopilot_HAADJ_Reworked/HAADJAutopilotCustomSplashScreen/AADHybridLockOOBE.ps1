<#
.SYNOPSIS
  
  ScriptName: AADHybridLockOOBE.ps1

.DESCRIPTION
  
  This script mimics a Windows 10 style full screen OOBE page post the 1st user sign-in to Windows during Autopilot Hybrid AADJ device provisioning, post device ESP. 
  Instead of getting the usual Desktop screen, this script presents the user instead with a OOBE lookalike custom splash screen and keeps the device locked to this screen till the device completes the automatic device registration succesfully.
  The taskbar and mouse cursor is hidden and the user is left with no easy override method. Further, for the entire duration for which this script runs, the screen is prevented from going to sleep.

  This is actually work of Trevor Jones which can be found here at https://github.com/SMSAgentSoftware/CustomW10UpgradeSplashScreen
  I have only modified the solution/scripts for the purpose of Intune Autopilot Hybrid Azure AD Join. 
  
.OUTPUT
  
.NOTES
  Version:        1.0
  Author:         Joymalya Basu Roy
  Creation Date:  28-06-2021
#>

Param($DeviceName)

# Location of script run

$Source = $PSScriptRoot

# Load MahApps dll

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing,System.DirectoryServices.AccountManagement
Add-Type -Path "$Source\bin\System.Windows.Interactivity.dll"
Add-Type -Path "$Source\bin\ControlzEx.dll"
Add-Type -Path "$Source\bin\MahApps.Metro.dll"

# Add custom type to hide the taskbar
# Thanks to https://stackoverflow.com/questions/25499393/make-my-wpf-application-full-screen-cover-taskbar-and-title-bar-of-window

$CSharpSource = @"
using System;
using System.Runtime.InteropServices;

public class Taskbar
{
    [DllImport("user32.dll")]
    private static extern int FindWindow(string className, string windowText);
    [DllImport("user32.dll")]
    private static extern int ShowWindow(int hwnd, int command);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 1;

    protected static int Handle
    {
        get
        {
            return FindWindow("Shell_TrayWnd", "");
        }
    }

    private Taskbar()
    {
        // hide ctor
    }

    public static void Show()
    {
        ShowWindow(Handle, SW_SHOW);
    }

    public static void Hide()
    {
        ShowWindow(Handle, SW_HIDE);
    }
}
"@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $CSharpSource -Language CSharp

# Add custom type to prevent the screen from sleeping

$code=@' 
using System;
using System.Runtime.InteropServices;

public class DisplayState
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto,SetLastError = true)]
    public static extern void SetThreadExecutionState(uint esFlags);

    public static void KeepDisplayAwake()
    {
        SetThreadExecutionState(
            0x00000002 | 0x80000000);
    }

    public static void Cancel()
    {
        SetThreadExecutionState(0x80000000);
    }
}
'@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $code -Language CSharp

# Load the main window XAML code

[XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\xaml\SplashScreen.xaml") 

# Create a synchronized hash table and add the WPF window and its named elements to it

$UI = [System.Collections.Hashtable]::Synchronized(@{})
$UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | 
    ForEach-Object -Process {
        $UI.$($_.Name) = $UI.Window.FindName($_.Name)
    }

# Find screen by DeviceName

$Screens = [System.Windows.Forms.Screen]::AllScreens
$Screen = $Screens | Where {$_.DeviceName -eq $DeviceName}

# Get the bounds of the primary screen

$script:Bounds = $Screen.Bounds

# Set initial values

$UI.MainTextBlock.MaxWidth = $Bounds.Width
$UI.TextBlock2.MaxWidth = $Bounds.Width
$UI.TextBlock3.MaxWidth = $Bounds.Width
$UI.TextBlock4.MaxWidth = $Bounds.Width
$UI.TextBlock2.Text = "Time Elapsed."
$UI.TextBlock3.Text = "00:00:00"
$UI.TextBlock4.Text = "Do not disconnect device from network. If it takes more than 4 hours, contact Service Desk."


# Show opening salutation

$UI.MainTextBlock.Text = "Hi there..."

# Create OOBE screen animations

$FadeinAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(0,1,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
$FadeOutAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(1,0,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
$ColourBrighterAnimation = [System.Windows.Media.Animation.ColorAnimation]::new("#012a47","#1271b5",[System.Windows.Duration]::new([Timespan]::FromSeconds(10)))
$ColourDarkerAnimation = [System.Windows.Media.Animation.ColorAnimation]::new("#1271b5","#012a47",[System.Windows.Duration]::new([Timespan]::FromSeconds(10)))


# An array of sentences to display, in order. Leave the first one blank as the 0 index gets skipped.

$TextArray = @(
    ""
    "The device completed joining the domain"
    "Waiting for AAD Connect sync to happen"
    "The process may take more than 30 minutes..."
    "We will restart your PC when done"
    "Should anything go wrong..."
    "...please contact the HelpDesk"
    "Now might be a good time to get a coffee :)"
)


# Start a timer used to control when the sentences are changed.

$TimerCode = {
    
    # The IF statement number should equal the number of sentences in the TextArray
    If ($i -lt 7)
    {
        $FadeoutAnimation.Add_Completed({            
            $UI.MaintextBlock.Opacity = 0
            $UI.MaintextBlock.Text = $TextArray[$i]
            $UI.MaintextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)

        })   
        $UI.MaintextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeoutAnimation) 
    }
    # The final sentence to display ongoing
    ElseIf ($i -eq 7)
    {       
            $FadeoutAnimation.Add_Completed({            
                $UI.MaintextBlock.Opacity  = 0
                $UI.MaintextBlock.Text = "Hybrid Azure AD Join in progress"
                $UI.MaintextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
                $UI.ProgressRing.IsActive = $True

            })
          
        $UI.MaintextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeoutAnimation)

    }
    Else
    {}

    $ColourBrighterAnimation.Add_Completed({            
        $UI.Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourDarkerAnimation)
    })   
    $UI.Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourBrighterAnimation)

    $Script:i++

}

$DispatchTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatchTimer.Interval = [TimeSpan]::FromSeconds(20)
$DispatchTimer.Add_Tick($TimerCode)

# Start a stopwatch timer. This is used to show total elapsed time.

$Stopwatch = New-Object System.Diagnostics.Stopwatch
$Stopwatch.Start()
$TimerCode2 = {
    $UI.TextBlock3.Text = "$($Stopwatch.Elapsed.Hours.ToString('00')):$($Stopwatch.Elapsed.Minutes.ToString('00')):$($Stopwatch.Elapsed.Seconds.ToString('00'))"
}

$DispatcherTimer2 = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimer2.Interval = [TimeSpan]::FromSeconds(1)
$DispatcherTimer2.Add_Tick($TimerCode2)

# Event: Window loaded

$UI.Window.Add_Loaded({
    
    # Activate the window to bring it to the fore
    
    $This.Activate()

    # Fill the screen
    
    $This.Left = $Bounds.Left
    $This.Top = $Bounds.Top
    $This.Height = $Bounds.Height
    $This.Width = $Bounds.Width

    # Hide the taskbar
    
    [TaskBar]::Hide()

    # Hide the mouse cursor
    
    [System.Windows.Forms.Cursor]::Hide()

    # Keep Display awake
    
    [DisplayState]::KeepDisplayAwake()

    # Begin animations
    
    $UI.MaintextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $UI.TextBlock2.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $UI.TextBlock3.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $UI.TextBlock4.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $UI.ProgressRing.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $ColourBrighterAnimation.Add_Completed({            
        $UI.Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourDarkerAnimation)
    })   
    $UI.Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourBrighterAnimation)

})

# Display the window

$DispatchTimer.Start()
$DispatcherTimer2.Start()
$UI.Window.ShowDialog()