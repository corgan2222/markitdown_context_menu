BeforeAll {
    . "$PSScriptRoot/../src/Launcher.ps1" -AsModule
}

Describe 'Get-LauncherArgs' {
    It 'accepts the DOCX comments action' {
        (Get-LauncherArgs -Argv @('comments','C:\review.docx')).Mode | Should -Be 'comments'
    }
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
