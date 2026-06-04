BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Registry.psm1" -Force
    $script:root = 'HKCU:\Software\MarkItDownMenuTest\Classes'
}
AfterAll {
    if (Test-Path 'HKCU:\Software\MarkItDownMenuTest') {
        Remove-Item 'HKCU:\Software\MarkItDownMenuTest' -Recurse -Force
    }
}

Describe 'Extension menu roundtrip' {
    It 'registers, lists, and unregisters an extension' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        Get-RegisteredExtensions -ClassesRoot $script:root | Should -Contain '.pdf'

        $cmd = (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDown\command").'(default)'
        $cmd | Should -Match 'save'
        (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDownOptions").SubCommands | Should -Be ''
        (Get-ChildItem "$script:root\SystemFileAssociations\.pdf\shell\MarkItDownOptions\shell").Count | Should -Be 3

        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
        Get-RegisteredExtensions -ClassesRoot $script:root | Should -Not -Contain '.pdf'
    }

    It 'writes a per-role Icon value on each verb when Icons are given' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open'; settings='Settings' }
        $icons = @{ direct='d.ico'; options='o.ico'; save='s.ico'; clip='c.ico'; open='p.ico'; settings='g.ico' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -Icons $icons -ClassesRoot $script:root
        $shell = "$script:root\SystemFileAssociations\.pdf\shell"
        (Get-ItemProperty "$shell\MarkItDown").Icon | Should -Be 'd.ico'
        (Get-ItemProperty "$shell\MarkItDownOptions").Icon | Should -Be 'o.ico'
        (Get-ItemProperty "$shell\MarkItDownOptions\shell\01_save").Icon | Should -Be 's.ico'
        (Get-ItemProperty "$shell\MarkItDownOptions\shell\02_clip").Icon | Should -Be 'c.ico'
        (Get-ItemProperty "$shell\MarkItDownOptions\shell\03_open").Icon | Should -Be 'p.ico'
        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
    }

    It 'omits the Icon value when no Icons are given' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDown").PSObject.Properties.Name | Should -Not -Contain 'Icon'
        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
    }

    It 'adds a settings sub-entry only when a SettingsCommand is given' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open'; settings='Settings' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -SettingsCommand 'wscript gui.vbs' -ClassesRoot $script:root
        $sub = "$script:root\SystemFileAssociations\.pdf\shell\MarkItDownOptions\shell"
        (Get-ChildItem $sub).Count | Should -Be 4
        (Get-ItemProperty "$sub\04_settings\command").'(default)' | Should -Be 'wscript gui.vbs'
        (Get-ItemProperty "$sub\04_settings").MUIVerb | Should -Be 'Settings'
        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
    }
}

Describe 'Folder menu roundtrip' {
    It 'registers and unregisters the folder menu' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForFolder -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        (Test-Path "$script:root\Directory\shell\MarkItDown") | Should -BeTrue
        Unregister-MenuForFolder -ClassesRoot $script:root
        (Test-Path "$script:root\Directory\shell\MarkItDown") | Should -BeFalse
    }
}
