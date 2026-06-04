BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Runtime.psm1" -Force
}

Describe 'ConvertTo-PythonVersion' {
    It 'parses a standard python --version string' {
        (ConvertTo-PythonVersion -Text 'Python 3.12.1').ToString() | Should -Be '3.12.1'
    }
    It 'returns $null for unparseable text' {
        ConvertTo-PythonVersion -Text 'not python' | Should -Be $null
    }
}

Describe 'Test-PythonVersion' {
    It 'true when at or above minimum' {
        Test-PythonVersion -Version ([version]'3.10.0') -Minimum ([version]'3.10') | Should -BeTrue
        Test-PythonVersion -Version ([version]'3.12.4') -Minimum ([version]'3.10') | Should -BeTrue
    }
    It 'false when below minimum' {
        Test-PythonVersion -Version ([version]'3.9.13') -Minimum ([version]'3.10') | Should -BeFalse
    }
    It 'false when version is null' {
        Test-PythonVersion -Version $null -Minimum ([version]'3.10') | Should -BeFalse
    }
}

Describe 'Get-ToolVersion' {
    It 'reads and trims a version from a VERSION file' {
        $f = Join-Path $TestDrive 'VERSION'
        Set-Content -LiteralPath $f -Value "  1.2.3 `r`n" -NoNewline
        Get-ToolVersion -Path $f | Should -Be '1.2.3'
    }
    It 'returns $null when the file does not exist' {
        Get-ToolVersion -Path (Join-Path $TestDrive 'nope.txt') | Should -Be $null
    }
    It 'returns $null for an empty file' {
        $f = Join-Path $TestDrive 'EMPTY'
        Set-Content -LiteralPath $f -Value '' -NoNewline
        Get-ToolVersion -Path $f | Should -Be $null
    }
    It 'returns $null when no path is given' {
        Get-ToolVersion -Path '' | Should -Be $null
    }
}

Describe 'Test-UpdateAvailable' {
    It 'true when latest release is numerically higher' {
        Test-UpdateAvailable -Installed '0.1.1' -Latest '0.1.2' | Should -BeTrue
        Test-UpdateAvailable -Installed '0.1.1' -Latest '0.2.0' | Should -BeTrue
        Test-UpdateAvailable -Installed '0.9.0' -Latest '1.0.0' | Should -BeTrue
    }
    It 'false when versions are equal' {
        Test-UpdateAvailable -Installed '0.1.1' -Latest '0.1.1' | Should -BeFalse
    }
    It 'false when installed is newer than latest' {
        Test-UpdateAvailable -Installed '0.2.0' -Latest '0.1.9' | Should -BeFalse
    }
    It 'handles differing segment counts' {
        Test-UpdateAvailable -Installed '0.1' -Latest '0.1.1' | Should -BeTrue
        Test-UpdateAvailable -Installed '0.1.0' -Latest '0.1'   | Should -BeFalse
    }
    It 'treats an installed prerelease as older than the same numeric final release' {
        Test-UpdateAvailable -Installed '0.0.1a2' -Latest '0.0.1' | Should -BeTrue
    }
    It 'false when either version is missing' {
        Test-UpdateAvailable -Installed ''       -Latest '0.1.0' | Should -BeFalse
        Test-UpdateAvailable -Installed '0.1.0'  -Latest ''      | Should -BeFalse
        Test-UpdateAvailable -Installed $null    -Latest $null   | Should -BeFalse
    }
}
