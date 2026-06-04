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

    It 'writes the Icon value on every verb when IconPath is given' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        $icon = 'C:\path\markdown-icon.ico'
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -IconPath $icon -ClassesRoot $script:root
        $shell = "$script:root\SystemFileAssociations\.pdf\shell"
        (Get-ItemProperty "$shell\MarkItDown").Icon | Should -Be $icon
        (Get-ItemProperty "$shell\MarkItDownOptions").Icon | Should -Be $icon
        (Get-ItemProperty "$shell\MarkItDownOptions\shell\01_save").Icon | Should -Be $icon
        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
    }

    It 'omits the Icon value when no IconPath is given' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDown").PSObject.Properties.Name | Should -Not -Contain 'Icon'
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
