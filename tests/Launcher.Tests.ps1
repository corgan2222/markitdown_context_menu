BeforeAll {
    . "$PSScriptRoot/../src/Launcher.ps1" -AsModule
}

Describe 'Get-LauncherArgs' {
    It 'parses mode and path' {
        $a = Get-LauncherArgs -Argv @('save','C:\a\b.pdf')
        $a.Mode | Should -Be 'save'
        $a.Path | Should -Be 'C:\a\b.pdf'
    }
    It 'rejects an unknown mode' {
        { Get-LauncherArgs -Argv @('frobnicate','C:\x') } | Should -Throw
    }
    It 'requires a path' {
        { Get-LauncherArgs -Argv @('save') } | Should -Throw
    }
}
