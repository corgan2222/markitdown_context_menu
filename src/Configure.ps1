# src/Configure.ps1
#Requires -Version 7.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Split-Path -Parent $here
foreach ($m in 'Paths','Config','I18n','Registry','Runtime','Toast') {
    Import-Module (Join-Path $here "modules/$m.psm1") -Force
}

$settings = Get-Settings -Path (Get-SettingsPath)
$code     = Resolve-Language -Setting $settings.Language -Available @('de','en')
$S        = Import-Language -LangDir (Join-Path $appRoot 'lang') -Code $code
function T($k) { Get-String -Key $k -Strings $S }

$catalog  = Get-FileTypeCatalog -CatalogPath (Join-Path $appRoot 'config/filetypes.default.json')
$current  = @(Get-RegisteredExtensions)

# launcher command embedded into every registry verb
$launcherCmd = 'wscript "' + (Join-Path $appRoot 'src\HiddenLaunch.vbs') + '"'

$form = New-Object System.Windows.Forms.Form
$form.Text = T 'gui.title'
$form.Size = New-Object System.Drawing.Size(460, 560)
$form.StartPosition = 'CenterScreen'

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = T 'gui.filetypes'; $lbl.Location = '12,10'; $lbl.AutoSize = $true
$form.Controls.Add($lbl)

$list = New-Object System.Windows.Forms.CheckedListBox
$list.Location = '12,32'; $list.Size = '420,260'; $list.CheckOnClick = $true
foreach ($item in $catalog) {
    $idx = $list.Items.Add($("{0}  ({1})" -f $item.Name, $item.Extension))
    if ($item.Extension -in $current) { $list.SetItemChecked($idx, $true) }
}
$form.Controls.Add($list)

# custom extension add
$txt = New-Object System.Windows.Forms.TextBox; $txt.Location = '12,300'; $txt.Size = '120,24'
$btnAdd = New-Object System.Windows.Forms.Button; $btnAdd.Text = T 'gui.add'; $btnAdd.Location = '140,299'
$btnAdd.Add_Click({
    if ($txt.Text) {
        $e = ConvertTo-NormalizedExt $txt.Text
        $i = $list.Items.Add($("{0}  ({1})" -f $e, $e)); $list.SetItemChecked($i, $true); $txt.Clear()
    }
})
$form.Controls.AddRange(@($txt, $btnAdd))

# default action
$lblAct = New-Object System.Windows.Forms.Label; $lblAct.Text = T 'gui.defaultAction'; $lblAct.Location = '12,338'; $lblAct.AutoSize = $true
$cmbAct = New-Object System.Windows.Forms.ComboBox; $cmbAct.Location = '180,335'; $cmbAct.Size = '240,24'; $cmbAct.DropDownStyle = 'DropDownList'
$actMap = [ordered]@{ (T 'menu.save')='save'; (T 'menu.clip')='clip'; (T 'menu.open')='open' }
$cmbAct.Items.AddRange(@($actMap.Keys)); $cmbAct.SelectedIndex = @($actMap.Values).IndexOf($settings.DefaultAction)
$form.Controls.AddRange(@($lblAct, $cmbAct))

# language
$lblLang = New-Object System.Windows.Forms.Label; $lblLang.Text = T 'gui.language'; $lblLang.Location = '12,372'; $lblLang.AutoSize = $true
$cmbLang = New-Object System.Windows.Forms.ComboBox; $cmbLang.Location = '180,369'; $cmbLang.Size = '240,24'; $cmbLang.DropDownStyle = 'DropDownList'
$langMap = [ordered]@{ (T 'gui.langAuto')='auto'; 'Deutsch'='de'; 'English'='en' }
$cmbLang.Items.AddRange(@($langMap.Keys)); $cmbLang.SelectedIndex = @($langMap.Values).IndexOf($settings.Language)
$form.Controls.AddRange(@($lblLang, $cmbLang))

# buttons
$btnRuntime = New-Object System.Windows.Forms.Button; $btnRuntime.Text = T 'gui.checkRuntime'; $btnRuntime.Location = '12,410'; $btnRuntime.Size = '420,30'
$btnRuntime.Add_Click({ if (Confirm-Runtime -Strings $S) { [System.Windows.Forms.MessageBox]::Show((T 'gui.runtimeOk')) | Out-Null } })
$form.Controls.Add($btnRuntime)

$btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text = T 'gui.save'; $btnSave.Location = '12,450'; $btnSave.Size = '200,34'
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text = T 'gui.uninstall'; $btnUninstall.Location = '232,450'; $btnUninstall.Size = '200,34'

$btnSave.Add_Click({
    $desired = @()
    for ($i=0; $i -lt $list.Items.Count; $i++) {
        if ($list.GetItemChecked($i)) {
            if ($list.Items[$i] -match '\((\.[^)]+)\)') { $desired += $Matches[1] }
        }
    }
    $mode = $actMap[$cmbAct.SelectedItem]
    $lang = $langMap[$cmbLang.SelectedItem]

    # persist settings, re-resolve labels in chosen language
    Set-Settings -Path (Get-SettingsPath) -Settings ([pscustomobject]@{ Language=$lang; DefaultAction=$mode })
    $codeNew = Resolve-Language -Setting $lang -Available @('de','en')
    $Snew = Import-Language -LangDir (Join-Path $appRoot 'lang') -Code $codeNew
    $labels = @{ direct=$Snew['menu.direct']; options=$Snew['menu.options']; save=$Snew['menu.save']; clip=$Snew['menu.clip']; open=$Snew['menu.open'] }

    $diff = Get-SelectionDiff -Desired $desired -Current @(Get-RegisteredExtensions)
    foreach ($e in $diff.ToRemove) { Unregister-MenuForExtension -Extension $e }
    foreach ($e in $desired)       { Register-MenuForExtension -Extension $e -DefaultMode $mode -Labels $labels -LauncherCommand $launcherCmd }
    Register-MenuForFolder -DefaultMode $mode -Labels $labels -LauncherCommand $launcherCmd
    [System.Windows.Forms.MessageBox]::Show((T 'gui.saved')) | Out-Null
})

$btnUninstall.Add_Click({
    foreach ($e in @(Get-RegisteredExtensions)) { Unregister-MenuForExtension -Extension $e }
    Unregister-MenuForFolder
    [System.Windows.Forms.MessageBox]::Show((T 'gui.saved')) | Out-Null
    $form.Close()
})
$form.Controls.AddRange(@($btnSave, $btnUninstall))

[void]$form.ShowDialog()
