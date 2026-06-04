# src/modules/Icons.psm1 — pick context-menu icons that match the Windows theme.

function Test-DarkMode {
    # AppsUseLightTheme: 1 = light apps, 0 = dark apps. Missing -> assume light.
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    try {
        $v = (Get-ItemProperty -Path $key -Name 'AppsUseLightTheme' -ErrorAction Stop).AppsUseLightTheme
        return ($v -eq 0)
    } catch { return $false }
}

function Get-IconSet {
    # Returns icon paths per menu role. Dark mode -> white icons, else black.
    # Only four art assets exist per theme (main / options / save / clipboard),
    # so "open" reuses the save icon and "settings" reuses the options icon.
    param(
        [Parameter(Mandatory)][string]$ImagesDir,
        [switch]$Dark
    )
    $f = { param($n) Join-Path $ImagesDir $n }
    if ($Dark) {
        @{
            direct   = & $f 'markdown-icon_inverted.ico'
            options  = & $f 'markdown-icon_white_options.ico'
            save     = & $f 'markdown-icon_white_speichern_save.ico'
            clip     = & $f 'markdown-icon_white_clipboard.ico'
            open     = & $f 'markdown-icon_white_speichern_save.ico'
            settings = & $f 'markdown-icon_white_options.ico'
        }
    } else {
        @{
            direct   = & $f 'markdown-icon_black.ico'
            options  = & $f 'markdown-icon_black_options.ico'
            save     = & $f 'markdown-icon_black_save.ico'
            clip     = & $f 'markdown-icon_black_clipboard.ico'
            open     = & $f 'markdown-icon_black_save.ico'
            settings = & $f 'markdown-icon_black_options.ico'
        }
    }
}

Export-ModuleMember -Function Test-DarkMode, Get-IconSet
