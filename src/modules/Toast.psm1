# src/modules/Toast.psm1
# Non-blocking Windows notification.
#
# Note: the WinRT toast API (Windows.UI.Notifications) is NOT available in
# PowerShell 7 (pwsh) — the launcher runs under pwsh, so it always threw and
# fell back to a modal MessageBox the user had to click away. We use a tray
# balloon instead: on Windows 10/11 it surfaces as a real notification in the
# Action Center, is non-blocking, and dismisses itself.

function Show-Toast {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [switch]$Error
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $tipIcon = if ($Error) { [System.Windows.Forms.ToolTipIcon]::Error } else { [System.Windows.Forms.ToolTipIcon]::Info }
        $sysIcon = if ($Error) { [System.Drawing.SystemIcons]::Error }      else { [System.Drawing.SystemIcons]::Information }

        $ni = New-Object System.Windows.Forms.NotifyIcon
        $ni.Icon    = $sysIcon
        $ni.Visible = $true
        $ni.ShowBalloonTip(5000, $Title, $Message, $tipIcon)

        # Keep the icon alive long enough for Windows to render the balloon,
        # then clean up. Non-blocking for the user (the launcher runs hidden).
        Start-Sleep -Milliseconds 5000
        $ni.Dispose()
    }
    catch {
        # Never pop a modal dialog: just log. The conversion already happened.
        try {
            $log = Join-Path $env:LOCALAPPDATA 'MarkItDownMenu\toast-error.log'
            Add-Content -Path $log -Value ("{0}`t{1}`t{2}" -f (Get-Date -Format s), $Title, $_.Exception.Message) -Encoding utf8
        } catch { }
    }
}

Export-ModuleMember -Function Show-Toast
