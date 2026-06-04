BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/I18n.psm1" -Force
    $script:langDir = Join-Path $PSScriptRoot '../lang'
}

Describe 'Resolve-Language' {
    It 'uses explicit setting when available' {
        Resolve-Language -Setting 'de' -SystemCulture 'en-US' -Available @('de','en') | Should -Be 'de'
    }
    It 'falls back to system 2-letter code on auto' {
        Resolve-Language -Setting 'auto' -SystemCulture 'de-DE' -Available @('de','en') | Should -Be 'de'
    }
    It 'falls back to en for unknown system language' {
        Resolve-Language -Setting 'auto' -SystemCulture 'fr-FR' -Available @('de','en') | Should -Be 'en'
    }
}

Describe 'Strings' {
    It 'loads German strings' {
        $s = Import-Language -LangDir $script:langDir -Code 'de'
        Get-String -Key 'menu.save' -Strings $s | Should -Be 'Speichern (.md)'
    }
    It 'falls back to English for a key missing in a partial language' {
        $s = Import-Language -LangDir $script:langDir -Code 'de'
        Get-String -Key 'toast.title' -Strings $s | Should -Be 'MarkItDown'
    }
    It 'returns the key itself when totally unknown' {
        $s = Import-Language -LangDir $script:langDir -Code 'en'
        Get-String -Key 'does.not.exist' -Strings $s | Should -Be 'does.not.exist'
    }
    It 'every key in en.json exists in de.json' {
        $en = Get-Content -Raw (Join-Path $script:langDir 'en.json') | ConvertFrom-Json
        $de = Get-Content -Raw (Join-Path $script:langDir 'de.json') | ConvertFrom-Json
        $missing = $en.PSObject.Properties.Name | Where-Object { -not $de.PSObject.Properties.Name.Contains($_) }
        $missing | Should -BeNullOrEmpty
    }
}
