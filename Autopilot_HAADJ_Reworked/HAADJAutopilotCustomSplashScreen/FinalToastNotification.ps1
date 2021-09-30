<#
.SYNOPSIS

  ScriptName: FinalToastNotification.ps1

.DESCRIPTION

  Simple script to show a Toast Notification to end-user to signify that the device is ready for production use.
  The script stays up on the screen for a specified duration unless users clicks on it post which it closes and triggers a restart.

  Original credit to Trevor Jones for the script whcih can be found here at https://smsagent.blog/2018/02/01/create-a-custom-toast-notification-with-wpf-and-powershell/ which I took and adapted for my usecase.

.OUTPUT

.NOTES

  Version:        1.0
  Author:         Joymalya Basu Roy
  Creation Date:  08/09/2021

#>

# Load required assemblies

Add-Type –AssemblyName PresentationFramework, System.Windows.Forms

# Get current Script Run location

If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation } [string]$mypath = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

# User-populated variables. Set the Title, Test to be displayed on the notification and the duration for which the notification will stay up on the screen

$Title = "Message from IT"
$Text = "Hi $Env:Username, your device is now ready. Click here to restart and get started."
$Timeout = 1800

# Set screen working area, bounds and start and finish location of the window 'top' property (for animation)

$WindowHeight = 140
$WindowWidth = 480
$ImageHeight = 100
$ImageWidth = 100
$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$TopStart = $workingArea.Bottom
$TopFinish = $workingArea.Bottom – ($WindowHeight + 10)
$CloseFinish = $Bounds.Bottom

#  Path to the image to be displayed in the notification. Size should be 250*250 max.

$CustomImage = "$mypath\bin\Logo.png"

# Calculate element dimensions

$MainStackWidth = $WindowWidth – 10
$SecondStackWidth = $WindowWidth – $ImageWidth -10
$TextBoxWidth = $SecondStackWidth – 30

# Define the notification UI in Xaml

[XML]$Xaml = "
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
    Title='Druva Notification' Width='$WindowWidth' Height='$WindowHeight'
    WindowStyle='None' AllowsTransparency='True' Background='Transparent' Topmost='True' Opacity='0.9'>
    <Window.Resources>
        <Storyboard x:Name='ClosingAnimation' x:Key='ClosingAnimation' >
            <DoubleAnimation Duration='0:0:.5' Storyboard.TargetProperty='Top' From='$TopFinish' To='$CloseFinish' AccelerationRatio='.1'/>
        </Storyboard>
    </Window.Resources>
    <Window.Triggers>
        <EventTrigger RoutedEvent='Window.Loaded'>
            <BeginStoryboard>
                <Storyboard >
                    <DoubleAnimation Duration='0:0:.5' Storyboard.TargetProperty='Top' From='$TopStart' To='$TopFinish' AccelerationRatio='.1'/>
                </Storyboard>
            </BeginStoryboard>
        </EventTrigger>
    </Window.Triggers>
    <Grid>
    <Border BorderThickness='0' Background='#333333'>
      <StackPanel Margin='20,10,20,10' Orientation='Horizontal' Width='$MainStackWidth'>
        <Image x:Name='Logo' Width='$ImageWidth' Height='$ImageHeight'/>
        <StackPanel Width='$SecondStackWidth'>
            <TextBox Margin='5' MaxWidth='$TextBoxWidth' Background='#333333' BorderThickness='0' IsReadOnly='True' Foreground='White' FontSize='20' Text='$Title' FontWeight='Bold' HorizontalContentAlignment='Left' Width='Auto' HorizontalAlignment='Stretch' IsHitTestVisible='False'/>
            <TextBox Margin='5' MaxWidth='$TextBoxWidth' Background='#333333' BorderThickness='0' IsReadOnly='True' Foreground='LightGray' FontSize='14' Text='$Text' HorizontalContentAlignment='Left' TextWrapping='Wrap' IsHitTestVisible='False'/>
        </StackPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"

# Create a global hash table to add dispatcher to

$Global:UI = @{}

# Create the window

$Window = [Windows.Markup.XamlReader]::Load((New-Object –TypeName System.Xml.XmlNodeReader –ArgumentList $xaml))

# Set the image

$Logo = $Window.FindName('Logo')
$Logo.Source = $CustomImage

# Add the closing animation to the global variable

$UI.ClosingAnimation = $Window.FindName('ClosingAnimation')

# Window loaded

$Window.Add_Loaded({

    # Activate

    $This.Activate()
    
    # Play a sound

    $SoundFile = "$env:SystemDrive\Windows\Media\Windows Notify.wav"
    $SoundPlayer = New-Object System.Media.SoundPlayer –ArgumentList $SoundFile
    $SoundPlayer.Add_LoadCompleted({
        $This.Play()
        $This.Dispose()
    })
    $SoundPlayer.LoadAsync()

    # Set the location of the left property

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $this.Left = $workingarea.Width – ($this.ActualWidth + 10)

    # Create a dispatcher timer to begin notification closure after x seconds

    $UI.DispatcherTimer = New-Object –TypeName System.Windows.Threading.DispatcherTimer
    $UI.DispatcherTimer.Interval = [TimeSpan]::FromSeconds($Timeout)
    $UI.DispatcherTimer.Add_Tick({
        $UI.ClosingAnimation.Begin($Window)
    })
    $UI.DispatcherTimer.Start()

})

# Window closing

$Window.Add_Closing({
    # Stop the dispatcher timer
    $UI.DispatcherTimer.Stop()
    shutdown.exe /r /t 60 /f
})

# Closing animation is completed

$UI.ClosingAnimation.Add_Completed({
    $Window.Close()
    shutdown.exe /r /t 60 /f
})

# Window Mouse enter

$Window.Add_MouseEnter({
    # Change cursor to a hand
    $This.Cursor = 'Hand'
})


# Window mouse up (simulate click)
$Window.Add_MouseUp({
    $UI.DispatcherTimer.Stop()
    $This.Close()
    shutdown.exe /r /t 60 /f
})

# Display the notification

$null = $window.Dispatcher.InvokeAsync{$window.ShowDialog()}.Wait()

