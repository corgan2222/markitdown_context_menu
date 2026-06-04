# uninstall.ps1 — removes registry entries, the install dir, and the shortcut.
#Requires -Version 7.0
$dest = Join-Path $env:LOCALAPPDATA 'MarkItDownMenu'
$reg = Join-Path $dest 'src/modules/Registry.psm1'
if (Test-Path $reg) {
    Import-Module $reg -Force
    foreach ($e in @(Get-RegisteredExtensions)) { Unregister-MenuForExtension -Extension $e }
    Unregister-MenuForFolder
}
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MarkItDown Context Menu.lnk'
if (Test-Path $lnk) { Remove-Item $lnk -Force }
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Write-Host "Uninstalled."
