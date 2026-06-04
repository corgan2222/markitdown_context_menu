#Requires -Version 7.0
# Runs the whole suite with Pester 5.
Import-Module Pester -MinimumVersion 5.0.0 -Force
$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
