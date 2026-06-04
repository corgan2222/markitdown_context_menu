BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Converter.psm1" -Force
}

Describe 'Get-OutputPath' {
    It 'replaces the extension with .md in the same folder' {
        Get-OutputPath -InputPath 'C:\a\b\report.pdf' | Should -Be 'C:\a\b\report.md'
    }
    It 'handles names with dots' {
        Get-OutputPath -InputPath 'C:\a\my.notes.v2.docx' | Should -Be 'C:\a\my.notes.v2.md'
    }
}

Describe 'Get-FilesToConvert' {
    It 'returns the single file for a file path' {
        $f = Join-Path $TestDrive 'x.pdf'; Set-Content $f 'x'
        (Get-FilesToConvert -Path $f -Extensions @('.pdf')).Count | Should -Be 1
    }
    It 'recurses a folder and filters by configured extensions' {
        $root = Join-Path $TestDrive 'docs'
        New-Item -ItemType Directory -Path (Join-Path $root 'sub') -Force | Out-Null
        Set-Content (Join-Path $root 'a.pdf') 'x'
        Set-Content (Join-Path $root 'sub\b.docx') 'x'
        Set-Content (Join-Path $root 'sub\c.zip') 'x'
        $files = Get-FilesToConvert -Path $root -Extensions @('.pdf','.docx')
        $files.Count | Should -Be 2
        ($files | ForEach-Object { [IO.Path]::GetExtension($_).ToLower() } | Sort-Object) | Should -Be @('.docx','.pdf')
    }
}

Describe 'Convert-Files' {
    It 'save mode writes a .md next to the source' {
        $f = Join-Path $TestDrive 'doc.pdf'; Set-Content $f 'x'
        Mock -ModuleName Converter Invoke-MarkItDownCli { '# Title' }
        $res = Convert-Files -Files @($f) -Mode 'save'
        $res[0].Success | Should -BeTrue
        (Get-Content -Raw (Join-Path $TestDrive 'doc.md')).Trim() | Should -Be '# Title'
    }
    It 'records a failure when the CLI throws' {
        $f = Join-Path $TestDrive 'bad.pdf'; Set-Content $f 'x'
        Mock -ModuleName Converter Invoke-MarkItDownCli { throw 'boom' }
        $res = Convert-Files -Files @($f) -Mode 'save'
        $res[0].Success | Should -BeFalse
        $res[0].Error   | Should -Match 'boom'
    }
}
