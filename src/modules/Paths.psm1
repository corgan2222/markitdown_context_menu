function Get-InstallDir { Join-Path $env:LOCALAPPDATA 'MarkItDownMenu' }
function Get-SettingsPath { Join-Path (Get-InstallDir) 'settings.json' }
function Get-QueuePath { Join-Path (Get-InstallDir) 'queue.txt' }
function Get-LogPath { Join-Path (Get-InstallDir) 'markitdown-menu.log' }

Export-ModuleMember -Function Get-InstallDir, Get-SettingsPath, Get-QueuePath, Get-LogPath
