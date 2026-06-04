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
    param(
        [string]$ShellPath, [hashtable]$Labels, [string]$LauncherCommand, [string]$Arg = '%1',
        [hashtable]$Icons = @{}, [string]$SettingsCommand
    )
    New-RegKey "$ShellPath\MarkItDownOptions"
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'MUIVerb' -Value $Labels.options
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'SubCommands' -Value ''
    Set-Icon "$ShellPath\MarkItDownOptions" $Icons.options

    $children = [ordered]@{
        '01_save' = @{ label = $Labels.save; icon = $Icons.save; cmd = ("{0} save `"{1}`"" -f $LauncherCommand, $Arg) }
        '02_clip' = @{ label = $Labels.clip; icon = $Icons.clip; cmd = ("{0} clip `"{1}`"" -f $LauncherCommand, $Arg) }
        '03_open' = @{ label = $Labels.open; icon = $Icons.open; cmd = ("{0} open `"{1}`"" -f $LauncherCommand, $Arg) }
    }
    if ($SettingsCommand) {
        $children['04_settings'] = @{ label = $Labels.settings; icon = $Icons.settings; cmd = $SettingsCommand }
    }
    foreach ($k in $children.Keys) {
        $c = $children[$k]
        New-RegKey "$ShellPath\MarkItDownOptions\shell\$k"
        Set-ItemProperty "$ShellPath\MarkItDownOptions\shell\$k" -Name 'MUIVerb' -Value $c.label
        Set-Icon "$ShellPath\MarkItDownOptions\shell\$k" $c.icon
        New-RegKey "$ShellPath\MarkItDownOptions\shell\$k\command"
        Set-ItemProperty "$ShellPath\MarkItDownOptions\shell\$k\command" -Name '(default)' -Value $c.cmd
    }
}

function Register-MenuForExtension {
    param(
        [Parameter(Mandatory)][string]$Extension,
        [Parameter(Mandatory)][string]$DefaultMode,
        [Parameter(Mandatory)][hashtable]$Labels,
        [Parameter(Mandatory)][string]$LauncherCommand,
        [hashtable]$Icons = @{},
        [string]$SettingsCommand,
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\SystemFileAssociations\$Extension\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand -IconPath $Icons.direct
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand -Icons $Icons -SettingsCommand $SettingsCommand
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
        [hashtable]$Icons = @{},
        [string]$SettingsCommand,
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\Directory\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand -IconPath $Icons.direct
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand -Icons $Icons -SettingsCommand $SettingsCommand
}

function Unregister-MenuForFolder {
    param([string]$ClassesRoot = 'HKCU:\Software\Classes')
    $shell = "$ClassesRoot\Directory\shell"
    foreach ($v in 'MarkItDown','MarkItDownOptions') {
        if (Test-Path "$shell\$v") { Remove-Item "$shell\$v" -Recurse -Force }
    }
}

Export-ModuleMember -Function Register-MenuForExtension, Unregister-MenuForExtension, Get-RegisteredExtensions, Register-MenuForFolder, Unregister-MenuForFolder
