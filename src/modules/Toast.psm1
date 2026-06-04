function Show-Toast {
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message, [switch]$Error)
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $template.GetElementsByTagName('text')
        $texts.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $texts.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('MarkItDown.ContextMenu')
        $notifier.Show($toast)
    }
    catch {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = if ($Error) { 'Error' } else { 'Information' }
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', $icon) | Out-Null
    }
}

Export-ModuleMember -Function Show-Toast
