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
