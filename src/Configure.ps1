# src/Configure.ps1
#Requires -Version 7.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Split-Path -Parent $here
foreach ($m in 'Paths','Config','I18n','Registry','Runtime','Toast','Icons') {
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
$settingsCmd = 'wscript "' + (Join-Path $appRoot 'src\HiddenConfigure.vbs') + '"'
$icons       = Get-IconSet -ImagesDir (Join-Path $appRoot 'images') -Dark:(Test-DarkMode)

$form = New-Object System.Windows.Forms.Form
$form.Text = T 'gui.title'
$form.Size = New-Object System.Drawing.Size(460, 660)
$form.StartPosition = 'CenterScreen'
$form.ShowInTaskbar = $true
# Launched from a hidden background process (wscript -> pwsh), the window would
# otherwise open behind Explorer without focus. Force it to the foreground.
$form.Add_Shown({
    $form.WindowState = 'Normal'
    $form.TopMost = $true
    $form.Activate()
    $form.BringToFront()
    $form.TopMost = $false
})

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

# runtime versions + update check
$lblVerHdr = New-Object System.Windows.Forms.Label; $lblVerHdr.Text = T 'gui.versionsHeader'; $lblVerHdr.Location = '12,404'; $lblVerHdr.AutoSize = $true
$lblPy = New-Object System.Windows.Forms.Label; $lblPy.Location = '24,424'; $lblPy.AutoSize = $true
$lblMd = New-Object System.Windows.Forms.Label; $lblMd.Location = '24,442'; $lblMd.AutoSize = $true

$pyVer = Get-PythonVersion
$mdVer = Get-MarkItDownVersion
$lblPy.Text = ((T 'gui.pythonVersion')    -f $(if ($pyVer) { $pyVer.ToString() } else { T 'gui.notInstalled' }))
$lblMd.Text = ((T 'gui.markitdownVersion') -f $(if ($mdVer) { $mdVer }            else { T 'gui.notInstalled' }))

$btnCheckUpdate = New-Object System.Windows.Forms.Button; $btnCheckUpdate.Text = T 'gui.checkUpdates'; $btnCheckUpdate.Location = '12,466'; $btnCheckUpdate.Size = '200,28'
$btnUpdateMd = New-Object System.Windows.Forms.Button; $btnUpdateMd.Text = T 'gui.updateMarkitdown'; $btnUpdateMd.Location = '232,466'; $btnUpdateMd.Size = '200,28'; $btnUpdateMd.Enabled = $false
$lblUpd = New-Object System.Windows.Forms.Label; $lblUpd.Location = '12,498'; $lblUpd.AutoSize = $true; $lblUpd.MaximumSize = '420,0'

$btnCheckUpdate.Add_Click({
    $lblUpd.Text = T 'gui.checking'; $form.Refresh()
    $installed = Get-MarkItDownVersion
    if (-not $installed) { $lblUpd.Text = T 'gui.notInstalled'; $btnUpdateMd.Enabled = $false; return }
    $latest = Get-LatestMarkItDownVersion
    if (-not $latest) { $lblUpd.Text = T 'gui.updateCheckFailed'; return }
    if (Test-UpdateAvailable -Installed $installed -Latest $latest) {
        $lblUpd.Text = ((T 'gui.updateAvailable') -f $installed, $latest); $btnUpdateMd.Enabled = $true
    } else {
        $lblUpd.Text = ((T 'gui.upToDate') -f $installed); $btnUpdateMd.Enabled = $false
    }
})
$btnUpdateMd.Add_Click({
    $lblUpd.Text = T 'gui.updating'; $btnUpdateMd.Enabled = $false; $form.Refresh()
    if (Update-MarkItDown) {
        $new = Get-MarkItDownVersion
        $lblMd.Text = ((T 'gui.markitdownVersion') -f $new)
        $lblUpd.Text = ((T 'gui.updated') -f $new)
    } else {
        $lblUpd.Text = T 'gui.updateFailed'; $btnUpdateMd.Enabled = $true
    }
})
$form.Controls.AddRange(@($lblVerHdr, $lblPy, $lblMd, $btnCheckUpdate, $btnUpdateMd, $lblUpd))

# buttons
$btnRuntime = New-Object System.Windows.Forms.Button; $btnRuntime.Text = T 'gui.checkRuntime'; $btnRuntime.Location = '12,528'; $btnRuntime.Size = '420,30'
$btnRuntime.Add_Click({ if (Confirm-Runtime -Strings $S) { [System.Windows.Forms.MessageBox]::Show((T 'gui.runtimeOk')) | Out-Null } })
$form.Controls.Add($btnRuntime)

$btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text = T 'gui.save'; $btnSave.Location = '12,566'; $btnSave.Size = '200,34'
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text = T 'gui.uninstall'; $btnUninstall.Location = '232,566'; $btnUninstall.Size = '200,34'

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
    $labels = @{ direct=$Snew['menu.direct']; options=$Snew['menu.options']; save=$Snew['menu.save']; clip=$Snew['menu.clip']; open=$Snew['menu.open']; settings=$Snew['menu.settings'] }

    $diff = Get-SelectionDiff -Desired $desired -Current @(Get-RegisteredExtensions)
    foreach ($e in $diff.ToRemove) { Unregister-MenuForExtension -Extension $e }
    foreach ($e in $desired)       { Register-MenuForExtension -Extension $e -DefaultMode $mode -Labels $labels -LauncherCommand $launcherCmd -Icons $icons -SettingsCommand $settingsCmd }
    Register-MenuForFolder -DefaultMode $mode -Labels $labels -LauncherCommand $launcherCmd -Icons $icons -SettingsCommand $settingsCmd
    [System.Windows.Forms.MessageBox]::Show((T 'gui.saved')) | Out-Null
})

$btnUninstall.Add_Click({
    foreach ($e in @(Get-RegisteredExtensions)) { Unregister-MenuForExtension -Extension $e }
    Unregister-MenuForFolder
    [System.Windows.Forms.MessageBox]::Show((T 'gui.uninstalled')) | Out-Null
    $form.Close()
})
$form.Controls.AddRange(@($btnSave, $btnUninstall))

[void]$form.ShowDialog()
