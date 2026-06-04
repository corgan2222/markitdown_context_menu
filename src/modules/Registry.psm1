function New-RegKey { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null } }

function Set-Icon {
    param([string]$KeyPath, [string]$IconPath)
    if ($IconPath) { Set-ItemProperty $KeyPath -Name 'Icon' -Value $IconPath }
}

function Set-Verb {
    param([string]$ShellPath, [string]$Label, [string]$Mode, [string]$LauncherCommand, [string]$Arg = '%1', [string]$IconPath)
    New-RegKey "$ShellPath\MarkItDown"
    Set-ItemProperty "$ShellPath\MarkItDown" -Name 'MUIVerb' -Value $Label
    Set-Icon "$ShellPath\MarkItDown" $IconPath
    New-RegKey "$ShellPath\MarkItDown\command"
    Set-ItemProperty "$ShellPath\MarkItDown\command" -Name '(default)' -Value ("{0} {1} `"{2}`"" -f $LauncherCommand, $Mode, $Arg)
}

function Set-OptionsVerb {
    param([string]$ShellPath, [hashtable]$Labels, [string]$LauncherCommand, [string]$Arg = '%1', [string]$IconPath)
    New-RegKey "$ShellPath\MarkItDownOptions"
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'MUIVerb' -Value $Labels.options
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'SubCommands' -Value ''
    Set-Icon "$ShellPath\MarkItDownOptions" $IconPath
    $children = @{ '01_save' = @('save', $Labels.save); '02_clip' = @('clip', $Labels.clip); '03_open' = @('open', $Labels.open) }
    foreach ($k in ($children.Keys | Sort-Object)) {
        $mode, $label = $children[$k]
        New-RegKey "$ShellPath\MarkItDownOptions\shell\$k"
        Set-ItemProperty "$ShellPath\MarkItDownOptions\shell\$k" -Name 'MUIVerb' -Value $label
        Set-Icon "$ShellPath\MarkItDownOptions\shell\$k" $IconPath
        New-RegKey "$ShellPath\MarkItDownOptions\shell\$k\command"
        Set-ItemProperty "$ShellPath\MarkItDownOptions\shell\$k\command" -Name '(default)' -Value ("{0} {1} `"{2}`"" -f $LauncherCommand, $mode, $Arg)
    }
}

function Register-MenuForExtension {
    param(
        [Parameter(Mandatory)][string]$Extension,
        [Parameter(Mandatory)][string]$DefaultMode,
        [Parameter(Mandatory)][hashtable]$Labels,
        [Parameter(Mandatory)][string]$LauncherCommand,
        [string]$IconPath,
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\SystemFileAssociations\$Extension\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand -IconPath $IconPath
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand -IconPath $IconPath
}

function Unregister-MenuForExtension {
    param([Parameter(Mandatory)][string]$Extension, [string]$ClassesRoot = 'HKCU:\Software\Classes')
    $shell = "$ClassesRoot\SystemFileAssociations\$Extension\shell"
    foreach ($v in 'MarkItDown','MarkItDownOptions') {
        if (Test-Path "$shell\$v") { Remove-Item "$shell\$v" -Recurse -Force }
    }
}

function Get-RegisteredExtensions {
    param([string]$ClassesRoot = 'HKCU:\Software\Classes')
    $base = "$ClassesRoot\SystemFileAssociations"
    if (-not (Test-Path $base)) { return @() }
    @(Get-ChildItem $base | Where-Object {
        Test-Path "$($_.PSPath)\shell\MarkItDown"
    } | ForEach-Object { $_.PSChildName })
}

function Register-MenuForFolder {
    param(
        [Parameter(Mandatory)][string]$DefaultMode,
        [Parameter(Mandatory)][hashtable]$Labels,
        [Parameter(Mandatory)][string]$LauncherCommand,
        [string]$IconPath,
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\Directory\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand -IconPath $IconPath
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand -IconPath $IconPath
}

function Unregister-MenuForFolder {
    param([string]$ClassesRoot = 'HKCU:\Software\Classes')
    $shell = "$ClassesRoot\Directory\shell"
    foreach ($v in 'MarkItDown','MarkItDownOptions') {
        if (Test-Path "$shell\$v") { Remove-Item "$shell\$v" -Recurse -Force }
    }
}

Export-ModuleMember -Function Register-MenuForExtension, Unregister-MenuForExtension, Get-RegisteredExtensions, Register-MenuForFolder, Unregister-MenuForFolder
