# install.ps1 — copies files to %LOCALAPPDATA%\MarkItDownMenu, registers defaults, adds a shortcut.
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
Import-Module (Join-Path $src 'src/modules/Paths.psm1') -Force
Import-Module (Join-Path $src 'src/modules/Config.psm1') -Force
Import-Module (Join-Path $src 'src/modules/I18n.psm1') -Force
Import-Module (Join-Path $src 'src/modules/Registry.psm1') -Force

$dest = Get-InstallDir
New-Item -ItemType Directory -Path $dest -Force | Out-Null
foreach ($d in 'src','config','lang') {
    Copy-Item -Path (Join-Path $src $d) -Destination $dest -Recurse -Force
}

$settings = Get-Settings -Path (Get-SettingsPath)
$code   = Resolve-Language -Setting $settings.Language -Available @('de','en')
$S      = Import-Language -LangDir (Join-Path $dest 'lang') -Code $code
$labels = @{ direct=$S['menu.direct']; options=$S['menu.options']; save=$S['menu.save']; clip=$S['menu.clip']; open=$S['menu.open'] }
$launcherCmd = 'wscript "' + (Join-Path $dest 'src\HiddenLaunch.vbs') + '"'

$defaults = '.pdf','.docx','.xlsx','.pptx','.png','.jpg','.html','.csv'
foreach ($e in $defaults) { Register-MenuForExtension -Extension $e -DefaultMode $settings.DefaultAction -Labels $labels -LauncherCommand $launcherCmd }
Register-MenuForFolder -DefaultMode $settings.DefaultAction -Labels $labels -LauncherCommand $launcherCmd

# Start-menu shortcut to the GUI
$lnkDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$lnk = Join-Path $lnkDir 'MarkItDown Context Menu.lnk'
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = 'pwsh.exe'
$sc.Arguments  = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dest 'src\Configure.ps1') + '"'
$sc.WorkingDirectory = $dest
$sc.Save()

Write-Host "Installed to $dest. Defaults registered. Open 'MarkItDown Context Menu' from the Start menu to configure."
