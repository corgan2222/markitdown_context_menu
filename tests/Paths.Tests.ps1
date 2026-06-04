BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Paths.psm1" -Force
}

Describe 'Paths' {
    It 'install dir is under LOCALAPPDATA' {
        $env:LOCALAPPDATA = 'C:\Users\test\AppData\Local'
        Get-InstallDir | Should -Be 'C:\Users\test\AppData\Local\MarkItDownMenu'
    }
    It 'derives settings, queue, and log paths from the install dir' {
        $env:LOCALAPPDATA = 'C:\Users\test\AppData\Local'
        $root = Get-InstallDir
        Get-SettingsPath | Should -Be (Join-Path $root 'settings.json')
        Get-QueuePath    | Should -Be (Join-Path $root 'queue.txt')
        Get-LogPath      | Should -Be (Join-Path $root 'markitdown-menu.log')
    }
}
