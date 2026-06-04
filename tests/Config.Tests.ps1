BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Config.psm1" -Force
    $script:catalog = Join-Path $PSScriptRoot '../config/filetypes.default.json'
}

Describe 'Config catalog' {
    It 'loads catalog entries with extension and name' {
        $items = Get-FileTypeCatalog -CatalogPath $script:catalog
        ($items | Where-Object Extension -eq '.pdf').Name | Should -Be 'PDF'
        $items.Count | Should -BeGreaterThan 5
    }
    It 'normalizes extensions to lowercase with leading dot' {
        $items = Get-FileTypeCatalog -CatalogPath $script:catalog
        ($items.Extension | Where-Object { $_ -notmatch '^\.[a-z0-9]+$' }) | Should -BeNullOrEmpty
    }
}

Describe 'Selection diff' {
    It 'computes additions and removals' {
        $d = Get-SelectionDiff -Desired @('.pdf','.docx') -Current @('.docx','.csv')
        $d.ToAdd    | Should -Be @('.pdf')
        $d.ToRemove | Should -Be @('.csv')
    }
    It 'is case-insensitive and dot-normalized' {
        $d = Get-SelectionDiff -Desired @('PDF') -Current @('.pdf')
        $d.ToAdd    | Should -BeNullOrEmpty
        $d.ToRemove | Should -BeNullOrEmpty
    }
}

Describe 'Settings' {
    It 'returns defaults when file is missing' {
        $s = Get-Settings -Path (Join-Path $TestDrive 'nope.json')
        $s.Language      | Should -Be 'auto'
        $s.DefaultAction | Should -Be 'save'
    }
    It 'round-trips saved settings' {
        $p = Join-Path $TestDrive 'settings.json'
        Set-Settings -Path $p -Settings ([pscustomobject]@{ Language='de'; DefaultAction='open' })
        $s = Get-Settings -Path $p
        $s.Language      | Should -Be 'de'
        $s.DefaultAction | Should -Be 'open'
    }
}
