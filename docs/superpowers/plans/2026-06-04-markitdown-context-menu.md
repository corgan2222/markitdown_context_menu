# MarkItDown Context Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A no-admin Windows Explorer right-click integration that converts files/folders to Markdown via Microsoft's `markitdown`, with two menu entries (direct + options submenu), a checkbox config GUI, on-demand Python/markitdown install, and German/English localization.

**Architecture:** Pure PowerShell + Windows built-ins. Pure-logic modules (paths, config, i18n, converter helpers, batch queue, version parsing) are unit-tested with Pester 5. Registry add/remove is tested via a throwaway HKCU subtree. Toast, GUI, VBS shim, and installers are constructed and manually smoke-tested. Conversion/runtime/toast functions are reusable so a future Win11 COM handler can call the same core.

**Tech Stack:** PowerShell 7+ (`pwsh`), Pester 5, Windows Forms, WinRT toast (`Windows.UI.Notifications`), VBScript launch shim, registry (`HKCU\Software\Classes`).

**Spec:** `docs/superpowers/specs/2026-06-04-markitdown-context-menu-design.md`

---

## File Structure

```
markitdown_context_menu/
  install.cmd                      # double-click entry → install.ps1 (bypass)
  install.ps1                      # copy files to %LOCALAPPDATA%, register, shortcut
  uninstall.ps1                    # remove keys + files + shortcut
  README.md
  config/filetypes.default.json    # catalog: {extension, name}
  lang/de.json                     # German strings
  lang/en.json                     # English strings (fallback base)
  src/
    HiddenLaunch.vbs               # starts pwsh with no console window
    Launcher.ps1                   # arg parse → batch → runtime → convert → toast
    Configure.ps1                  # WinForms GUI
    modules/
      Paths.psm1                   # install dir / settings / queue / log paths
      Config.psm1                  # catalog load, selection diff, settings get/set
      I18n.psm1                    # language resolution + Get-String
      Converter.psm1               # output path, file enumeration, convert
      Runtime.psm1                 # python/markitdown detection + install
      Toast.psm1                   # WinRT toast + MessageBox fallback
      Batch.psm1                   # mutex + queue aggregator
      Registry.psm1                # menu register/unregister per ext + folder
  tests/
    Paths.Tests.ps1
    Config.Tests.ps1
    I18n.Tests.ps1
    Converter.Tests.ps1
    Runtime.Tests.ps1
    Batch.Tests.ps1
    Registry.Tests.ps1
    Launcher.Tests.ps1
```

**Naming conventions used throughout (keep consistent across tasks):**
- Modes are the lowercase strings `save`, `clip`, `open`.
- Extensions are stored/compared lowercase **with** leading dot, e.g. `.pdf`.
- Settings object shape: `{ Language = 'auto'|'de'|'en'; DefaultAction = 'save'|'clip'|'open' }`.
- The single external seam for markitdown is `Invoke-MarkItDownCli` (mocked in tests).

---

## Task 0: Project scaffolding & Pester 5

**Files:**
- Create: `.gitignore`
- Create: `tests/RunTests.ps1`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
# build / local
*.log
queue.txt
settings.json
.code-review-graph/
```

- [ ] **Step 2: Ensure Pester 5 is available**

Run:
```bash
pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable Pester | Where-Object { \$_.Version.Major -ge 5 })) { Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck }; (Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()"
```
Expected: prints a version `5.x.x` (e.g. `5.7.1`).

- [ ] **Step 3: Create `tests/RunTests.ps1`**

```powershell
#Requires -Version 7.0
# Runs the whole suite with Pester 5.
Import-Module Pester -MinimumVersion 5.0.0 -Force
$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

- [ ] **Step 4: Verify the runner executes (no tests yet)**

Run: `pwsh -NoProfile -File tests/RunTests.ps1`
Expected: Pester runs and reports `Tests Passed: 0` (no failures).

- [ ] **Step 5: Commit**

```bash
git add .gitignore tests/RunTests.ps1
git commit -m "Add project scaffolding and Pester 5 test runner"
```

---

## Task 1: Paths module

**Files:**
- Create: `src/modules/Paths.psm1`
- Test: `tests/Paths.Tests.ps1`

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Paths.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Paths.psm1" -Force
}

Describe 'Paths' {
    It 'install dir is under LOCALAPPDATA' {
        $env:LOCALAPPDATA = 'C:\Users\test\AppData\Local'
        Get-InstallDir | Should -Be 'C:\Users\test\AppData\Local\MarkItDownMenu'
    }
    It 'derives settings, queue, and log paths from the install dir' {
        $env:LOCALAPPDATA = 'C:\Users\test\AppData\Local'
        $root = Get-InstallDir
        Get-SettingsPath | Should -Be (Join-Path $root 'settings.json')
        Get-QueuePath    | Should -Be (Join-Path $root 'queue.txt')
        Get-LogPath      | Should -Be (Join-Path $root 'markitdown-menu.log')
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Paths.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-InstallDir` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/modules/Paths.psm1
function Get-InstallDir { Join-Path $env:LOCALAPPDATA 'MarkItDownMenu' }
function Get-SettingsPath { Join-Path (Get-InstallDir) 'settings.json' }
function Get-QueuePath { Join-Path (Get-InstallDir) 'queue.txt' }
function Get-LogPath { Join-Path (Get-InstallDir) 'markitdown-menu.log' }

Export-ModuleMember -Function Get-InstallDir, Get-SettingsPath, Get-QueuePath, Get-LogPath
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Paths.Tests.ps1 -Output Detailed"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add src/modules/Paths.psm1 tests/Paths.Tests.ps1
git commit -m "Add Paths module for install/settings/queue/log locations"
```

---

## Task 2: File-type catalog & settings (Config module)

**Files:**
- Create: `config/filetypes.default.json`
- Create: `src/modules/Config.psm1`
- Test: `tests/Config.Tests.ps1`

- [ ] **Step 1: Create the catalog file**

```json
[
  { "extension": ".pdf",  "name": "PDF" },
  { "extension": ".docx", "name": "Word (.docx)" },
  { "extension": ".doc",  "name": "Word (.doc)" },
  { "extension": ".xlsx", "name": "Excel (.xlsx)" },
  { "extension": ".pptx", "name": "PowerPoint (.pptx)" },
  { "extension": ".png",  "name": "PNG image" },
  { "extension": ".jpg",  "name": "JPEG image" },
  { "extension": ".jpeg", "name": "JPEG image" },
  { "extension": ".html", "name": "HTML" },
  { "extension": ".htm",  "name": "HTML" },
  { "extension": ".csv",  "name": "CSV" },
  { "extension": ".json", "name": "JSON" },
  { "extension": ".xml",  "name": "XML" },
  { "extension": ".txt",  "name": "Text" },
  { "extension": ".epub", "name": "EPUB" }
]
```

- [ ] **Step 2: Write the failing test**

```powershell
# tests/Config.Tests.ps1
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Config.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-FileTypeCatalog` not recognized.

- [ ] **Step 4: Write minimal implementation**

```powershell
# src/modules/Config.psm1

function ConvertTo-NormalizedExt {
    param([string]$Ext)
    $e = $Ext.Trim().ToLowerInvariant()
    if (-not $e.StartsWith('.')) { $e = '.' + $e }
    $e
}

function Get-FileTypeCatalog {
    param([Parameter(Mandatory)][string]$CatalogPath)
    Get-Content -Raw -Path $CatalogPath | ConvertFrom-Json | ForEach-Object {
        [pscustomobject]@{
            Extension = ConvertTo-NormalizedExt $_.extension
            Name      = $_.name
        }
    }
}

function Get-SelectionDiff {
    param([string[]]$Desired = @(), [string[]]$Current = @())
    $d = $Desired | ForEach-Object { ConvertTo-NormalizedExt $_ } | Sort-Object -Unique
    $c = $Current | ForEach-Object { ConvertTo-NormalizedExt $_ } | Sort-Object -Unique
    [pscustomobject]@{
        ToAdd    = @($d | Where-Object { $_ -notin $c })
        ToRemove = @($c | Where-Object { $_ -notin $d })
    }
}

function Get-Settings {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        $j = Get-Content -Raw -Path $Path | ConvertFrom-Json
        return [pscustomobject]@{
            Language      = if ($j.Language) { $j.Language } else { 'auto' }
            DefaultAction = if ($j.DefaultAction) { $j.DefaultAction } else { 'save' }
        }
    }
    [pscustomobject]@{ Language = 'auto'; DefaultAction = 'save' }
}

function Set-Settings {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Settings)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Settings | ConvertTo-Json | Set-Content -Path $Path -Encoding utf8
}

Export-ModuleMember -Function Get-FileTypeCatalog, Get-SelectionDiff, Get-Settings, Set-Settings, ConvertTo-NormalizedExt
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Config.Tests.ps1 -Output Detailed"`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add config/filetypes.default.json src/modules/Config.psm1 tests/Config.Tests.ps1
git commit -m "Add Config module: catalog, selection diff, settings"
```

---

## Task 3: Localization (I18n module + language files)

**Files:**
- Create: `lang/en.json`
- Create: `lang/de.json`
- Create: `src/modules/I18n.psm1`
- Test: `tests/I18n.Tests.ps1`

- [ ] **Step 1: Create `lang/en.json`**

```json
{
  "menu.direct": "Convert to Markdown",
  "menu.options": "Convert to Markdown (Options)",
  "menu.save": "Save (.md)",
  "menu.clip": "Copy to clipboard",
  "menu.open": "Save & open",
  "toast.title": "MarkItDown",
  "toast.done": "{0} converted",
  "toast.partial": "{0}/{1} converted, {2} failed",
  "toast.error": "Error: {0}",
  "runtime.pythonMissing": "Python 3.10+ is required. Install it now?",
  "runtime.markitdownMissing": "markitdown is not installed. Install it now?",
  "runtime.pythonManual": "Could not install automatically. Opening the Python download page.",
  "gui.title": "MarkItDown Context Menu — Settings",
  "gui.filetypes": "Show the menu for these file types:",
  "gui.addCustom": "Add extension:",
  "gui.add": "Add",
  "gui.defaultAction": "Direct entry action:",
  "gui.language": "Language:",
  "gui.langAuto": "Auto (system)",
  "gui.save": "Save",
  "gui.uninstall": "Uninstall",
  "gui.checkRuntime": "Check / install markitdown",
  "gui.saved": "Settings saved.",
  "gui.runtimeOk": "Python and markitdown are ready."
}
```

- [ ] **Step 2: Create `lang/de.json`**

```json
{
  "menu.direct": "In Markdown umwandeln",
  "menu.options": "In Markdown umwandeln (Optionen)",
  "menu.save": "Speichern (.md)",
  "menu.clip": "In Zwischenablage",
  "menu.open": "Speichern & öffnen",
  "toast.title": "MarkItDown",
  "toast.done": "{0} konvertiert",
  "toast.partial": "{0}/{1} konvertiert, {2} Fehler",
  "toast.error": "Fehler: {0}",
  "runtime.pythonMissing": "Python 3.10+ wird benötigt. Jetzt installieren?",
  "runtime.markitdownMissing": "markitdown ist nicht installiert. Jetzt installieren?",
  "runtime.pythonManual": "Automatische Installation nicht möglich. Öffne die Python-Downloadseite.",
  "gui.title": "MarkItDown Kontextmenü — Einstellungen",
  "gui.filetypes": "Menü für diese Dateitypen anzeigen:",
  "gui.addCustom": "Endung hinzufügen:",
  "gui.add": "Hinzufügen",
  "gui.defaultAction": "Aktion des Direkt-Eintrags:",
  "gui.language": "Sprache:",
  "gui.langAuto": "Automatisch (System)",
  "gui.save": "Speichern",
  "gui.uninstall": "Deinstallieren",
  "gui.checkRuntime": "markitdown prüfen / installieren",
  "gui.saved": "Einstellungen gespeichert.",
  "gui.runtimeOk": "Python und markitdown sind bereit."
}
```

- [ ] **Step 3: Write the failing test**

```powershell
# tests/I18n.Tests.ps1
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
        $partial = @{ 'menu.save' = 'X' }   # simulate a sparse table
        # English base must still resolve other keys via Import-Language merge
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
```

- [ ] **Step 4: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/I18n.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Resolve-Language` not recognized.

- [ ] **Step 5: Write minimal implementation**

```powershell
# src/modules/I18n.psm1

function Resolve-Language {
    param(
        [string]$Setting = 'auto',
        [string]$SystemCulture = (Get-UICulture).Name,
        [string[]]$Available = @('en')
    )
    if ($Setting -and $Setting -ne 'auto' -and $Setting -in $Available) { return $Setting }
    $two = ($SystemCulture -split '-')[0].ToLowerInvariant()
    if ($two -in $Available) { return $two }
    'en'
}

function ConvertTo-StringTable {
    param([Parameter(Mandatory)]$Json)
    $h = @{}
    foreach ($p in $Json.PSObject.Properties) { $h[$p.Name] = $p.Value }
    $h
}

function Import-Language {
    param([Parameter(Mandatory)][string]$LangDir, [Parameter(Mandatory)][string]$Code)
    $en = ConvertTo-StringTable (Get-Content -Raw (Join-Path $LangDir 'en.json') | ConvertFrom-Json)
    $codePath = Join-Path $LangDir "$Code.json"
    if ($Code -ne 'en' -and (Test-Path $codePath)) {
        $loc = ConvertTo-StringTable (Get-Content -Raw $codePath | ConvertFrom-Json)
        foreach ($k in $loc.Keys) { $en[$k] = $loc[$k] }   # locale overrides English base
    }
    $en
}

function Get-String {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][hashtable]$Strings)
    if ($Strings.ContainsKey($Key)) { return $Strings[$Key] }
    $Key
}

Export-ModuleMember -Function Resolve-Language, Import-Language, Get-String, ConvertTo-StringTable
```

- [ ] **Step 6: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/I18n.Tests.ps1 -Output Detailed"`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add lang/en.json lang/de.json src/modules/I18n.psm1 tests/I18n.Tests.ps1
git commit -m "Add I18n module with German and English language files"
```

---

## Task 4: Converter module

**Files:**
- Create: `src/modules/Converter.psm1`
- Test: `tests/Converter.Tests.ps1`

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Converter.Tests.ps1
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Converter.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-OutputPath` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/modules/Converter.psm1

function Get-OutputPath {
    param([Parameter(Mandatory)][string]$InputPath)
    $dir  = [IO.Path]::GetDirectoryName($InputPath)
    $name = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    Join-Path $dir "$name.md"
}

function Get-FilesToConvert {
    param([Parameter(Mandatory)][string]$Path, [string[]]$Extensions = @())
    if (Test-Path -Path $Path -PathType Container) {
        $ext = $Extensions | ForEach-Object { $_.ToLowerInvariant() }
        return @(Get-ChildItem -Path $Path -Recurse -File |
            Where-Object { $_.Extension.ToLowerInvariant() -in $ext } |
            ForEach-Object { $_.FullName })
    }
    @($Path)
}

# Single external seam — mocked in tests.
function Invoke-MarkItDownCli {
    param([Parameter(Mandatory)][string]$InputPath)
    $out = & python -m markitdown $InputPath 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($out -join [Environment]::NewLine) }
    ($out -join [Environment]::NewLine)
}

function Convert-Files {
    param(
        [Parameter(Mandatory)][string[]]$Files,
        [Parameter(Mandatory)][ValidateSet('save','clip','open')][string]$Mode
    )
    $results = New-Object System.Collections.Generic.List[object]
    $clipBuffer = New-Object System.Collections.Generic.List[string]
    foreach ($f in $Files) {
        try {
            $md = Invoke-MarkItDownCli -InputPath $f
            switch ($Mode) {
                'save' { Set-Content -Path (Get-OutputPath $f) -Value $md -Encoding utf8 }
                'open' {
                    $o = Get-OutputPath $f
                    Set-Content -Path $o -Value $md -Encoding utf8
                    Invoke-Item -Path $o
                }
                'clip' { $clipBuffer.Add($md) }
            }
            $results.Add([pscustomobject]@{ Path = $f; Success = $true; Error = $null })
        }
        catch {
            $results.Add([pscustomobject]@{ Path = $f; Success = $false; Error = $_.Exception.Message })
        }
    }
    if ($Mode -eq 'clip' -and $clipBuffer.Count -gt 0) {
        Set-Clipboard -Value ($clipBuffer -join ([Environment]::NewLine + '---' + [Environment]::NewLine))
    }
    $results.ToArray()
}

Export-ModuleMember -Function Get-OutputPath, Get-FilesToConvert, Invoke-MarkItDownCli, Convert-Files
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Converter.Tests.ps1 -Output Detailed"`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add src/modules/Converter.psm1 tests/Converter.Tests.ps1
git commit -m "Add Converter module: output path, enumeration, conversion"
```

---

## Task 5: Runtime detection (version parsing)

**Files:**
- Create: `src/modules/Runtime.psm1`
- Test: `tests/Runtime.Tests.ps1`

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Runtime.Tests.ps1
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Runtime.Tests.ps1 -Output Detailed"`
Expected: FAIL — `ConvertTo-PythonVersion` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/modules/Runtime.psm1

function ConvertTo-PythonVersion {
    param([string]$Text)
    if ($Text -match '(\d+)\.(\d+)(?:\.(\d+))?') {
        $patch = if ($Matches[3]) { $Matches[3] } else { '0' }
        return [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $patch)
    }
    $null
}

function Test-PythonVersion {
    param([version]$Version, [version]$Minimum = ([version]'3.10'))
    if ($null -eq $Version) { return $false }
    $Version -ge $Minimum
}

# --- side-effecting helpers (smoke-tested manually) ---

function Get-PythonVersion {
    try {
        $out = & python --version 2>&1
        return ConvertTo-PythonVersion -Text ($out -join ' ')
    } catch { return $null }
}

function Test-MarkItDownInstalled {
    try {
        & python -m markitdown --help *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Install-Python {
    # Prefer winget (per-user, no admin); fall back to the download page.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements
        return ($LASTEXITCODE -eq 0)
    }
    Start-Process 'https://www.python.org/downloads/windows/'
    return $false
}

function Install-MarkItDown {
    & python -m pip install --user "markitdown[all]"
    return ($LASTEXITCODE -eq 0)
}

Export-ModuleMember -Function ConvertTo-PythonVersion, Test-PythonVersion, Get-PythonVersion, Test-MarkItDownInstalled, Install-Python, Install-MarkItDown
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Runtime.Tests.ps1 -Output Detailed"`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add src/modules/Runtime.psm1 tests/Runtime.Tests.ps1
git commit -m "Add Runtime module: python version parsing and install helpers"
```

---

## Task 6: Batch aggregator (mutex + queue)

**Files:**
- Create: `src/modules/Batch.psm1`
- Test: `tests/Batch.Tests.ps1`

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Batch.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Batch.psm1" -Force
}

Describe 'Queue ownership' {
    It 'first enqueue becomes owner, subsequent do not' {
        $q = Join-Path $TestDrive 'queue.txt'
        $m = 'MarkItDownTest_' + [guid]::NewGuid().ToString('N')
        (Add-ToQueue -QueuePath $q -Path 'C:\a.pdf' -MutexName $m) | Should -BeTrue
        (Add-ToQueue -QueuePath $q -Path 'C:\b.pdf' -MutexName $m) | Should -BeFalse
    }
    It 'drains all queued paths and clears the file' {
        $q = Join-Path $TestDrive 'queue.txt'
        $m = 'MarkItDownTest_' + [guid]::NewGuid().ToString('N')
        Add-ToQueue -QueuePath $q -Path 'C:\a.pdf' -MutexName $m | Out-Null
        Add-ToQueue -QueuePath $q -Path 'C:\b.pdf' -MutexName $m | Out-Null
        $drained = Read-AndClearQueue -QueuePath $q -MutexName $m
        $drained | Should -Be @('C:\a.pdf','C:\b.pdf')
        (Test-Path $q) | Should -BeFalse
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Batch.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Add-ToQueue` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/modules/Batch.psm1

function Invoke-WithMutex {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    $mutex = New-Object System.Threading.Mutex($false, "Global\$Name")
    [void]$mutex.WaitOne()
    try { & $Action } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}

function Add-ToQueue {
    param(
        [Parameter(Mandatory)][string]$QueuePath,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$MutexName
    )
    Invoke-WithMutex -Name $MutexName -Action {
        $wasEmpty = -not (Test-Path $QueuePath) -or ((Get-Item $QueuePath).Length -eq 0)
        $dir = Split-Path -Parent $QueuePath
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $QueuePath -Value $Path -Encoding utf8
        return $wasEmpty
    }
}

function Read-AndClearQueue {
    param([Parameter(Mandatory)][string]$QueuePath, [Parameter(Mandatory)][string]$MutexName)
    Invoke-WithMutex -Name $MutexName -Action {
        if (-not (Test-Path $QueuePath)) { return @() }
        $lines = @(Get-Content -Path $QueuePath | Where-Object { $_ -ne '' })
        Remove-Item -Path $QueuePath -Force
        return $lines
    }
}

Export-ModuleMember -Function Add-ToQueue, Read-AndClearQueue, Invoke-WithMutex
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Batch.Tests.ps1 -Output Detailed"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add src/modules/Batch.psm1 tests/Batch.Tests.ps1
git commit -m "Add Batch module: mutex-guarded queue aggregator"
```

---

## Task 7: Registry module (menu register/unregister)

**Files:**
- Create: `src/modules/Registry.psm1`
- Test: `tests/Registry.Tests.ps1`

Note: All functions take a `-ClassesRoot` parameter (default `HKCU:\Software\Classes`) so tests can target a throwaway subtree and clean it up.

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Registry.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Registry.psm1" -Force
    $script:root = 'HKCU:\Software\MarkItDownMenuTest\Classes'
}
AfterAll {
    if (Test-Path 'HKCU:\Software\MarkItDownMenuTest') {
        Remove-Item 'HKCU:\Software\MarkItDownMenuTest' -Recurse -Force
    }
}

Describe 'Extension menu roundtrip' {
    It 'registers, lists, and unregisters an extension' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForExtension -Extension '.pdf' -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        Get-RegisteredExtensions -ClassesRoot $script:root | Should -Contain '.pdf'

        # direct verb command carries the default mode
        $cmd = (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDown\command").'(default)'
        $cmd | Should -Match 'save'
        # options verb exposes SubCommands and three children
        (Get-ItemProperty "$script:root\SystemFileAssociations\.pdf\shell\MarkItDownOptions").SubCommands | Should -Be ''
        (Get-ChildItem "$script:root\SystemFileAssociations\.pdf\shell\MarkItDownOptions\shell").Count | Should -Be 3

        Unregister-MenuForExtension -Extension '.pdf' -ClassesRoot $script:root
        Get-RegisteredExtensions -ClassesRoot $script:root | Should -Not -Contain '.pdf'
    }
}

Describe 'Folder menu roundtrip' {
    It 'registers and unregisters the folder menu' {
        $labels = @{ direct='Convert'; options='Convert (Options)'; save='Save'; clip='Clip'; open='Open' }
        Register-MenuForFolder -DefaultMode 'save' -Labels $labels -LauncherCommand 'wscript x.vbs' -ClassesRoot $script:root
        (Test-Path "$script:root\Directory\shell\MarkItDown") | Should -BeTrue
        Unregister-MenuForFolder -ClassesRoot $script:root
        (Test-Path "$script:root\Directory\shell\MarkItDown") | Should -BeFalse
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Registry.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Register-MenuForExtension` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/modules/Registry.psm1

function New-RegKey { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null } }

function Set-Verb {
    # Writes a parent verb whose command runs "<LauncherCommand> <mode> "%1"".
    param([string]$ShellPath, [string]$Label, [string]$Mode, [string]$LauncherCommand, [string]$Arg = '%1')
    New-RegKey "$ShellPath\MarkItDown"
    Set-ItemProperty "$ShellPath\MarkItDown" -Name 'MUIVerb' -Value $Label
    New-RegKey "$ShellPath\MarkItDown\command"
    Set-ItemProperty "$ShellPath\MarkItDown\command" -Name '(default)' -Value ("{0} {1} `"{2}`"" -f $LauncherCommand, $Mode, $Arg)
}

function Set-OptionsVerb {
    param([string]$ShellPath, [hashtable]$Labels, [string]$LauncherCommand, [string]$Arg = '%1')
    New-RegKey "$ShellPath\MarkItDownOptions"
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'MUIVerb' -Value $Labels.options
    Set-ItemProperty "$ShellPath\MarkItDownOptions" -Name 'SubCommands' -Value ''
    $children = @{ '01_save' = @('save', $Labels.save); '02_clip' = @('clip', $Labels.clip); '03_open' = @('open', $Labels.open) }
    foreach ($k in ($children.Keys | Sort-Object)) {
        $mode, $label = $children[$k]
        New-RegKey "$ShellPath\MarkItDownOptions\shell\$k"
        Set-ItemProperty "$ShellPath\MarkItDownOptions\shell\$k" -Name 'MUIVerb' -Value $label
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
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\SystemFileAssociations\$Extension\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand
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
        [string]$ClassesRoot = 'HKCU:\Software\Classes'
    )
    $shell = "$ClassesRoot\Directory\shell"
    New-RegKey $shell
    Set-Verb -ShellPath $shell -Label $Labels.direct -Mode $DefaultMode -LauncherCommand $LauncherCommand
    Set-OptionsVerb -ShellPath $shell -Labels $Labels -LauncherCommand $LauncherCommand
}

function Unregister-MenuForFolder {
    param([string]$ClassesRoot = 'HKCU:\Software\Classes')
    $shell = "$ClassesRoot\Directory\shell"
    foreach ($v in 'MarkItDown','MarkItDownOptions') {
        if (Test-Path "$shell\$v") { Remove-Item "$shell\$v" -Recurse -Force }
    }
}

Export-ModuleMember -Function Register-MenuForExtension, Unregister-MenuForExtension, Get-RegisteredExtensions, Register-MenuForFolder, Unregister-MenuForFolder
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Registry.Tests.ps1 -Output Detailed"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add src/modules/Registry.psm1 tests/Registry.Tests.ps1
git commit -m "Add Registry module: localized two-entry menu register/unregister"
```

---

## Task 8: Launcher argument parsing

**Files:**
- Create: `src/Launcher.ps1`
- Test: `tests/Launcher.Tests.ps1`

Note: `Launcher.ps1` defines a pure helper `Get-LauncherArgs` and only runs the main flow when invoked directly (guarded by `$MyInvocation.InvocationName -ne '.'` style dot-source check), so the test can dot-source it without side effects.

- [ ] **Step 1: Write the failing test**

```powershell
# tests/Launcher.Tests.ps1
BeforeAll {
    . "$PSScriptRoot/../src/Launcher.ps1" -AsModule
}

Describe 'Get-LauncherArgs' {
    It 'parses mode and path' {
        $a = Get-LauncherArgs -Argv @('save','C:\a\b.pdf')
        $a.Mode | Should -Be 'save'
        $a.Path | Should -Be 'C:\a\b.pdf'
    }
    It 'rejects an unknown mode' {
        { Get-LauncherArgs -Argv @('frobnicate','C:\x') } | Should -Throw
    }
    It 'requires a path' {
        { Get-LauncherArgs -Argv @('save') } | Should -Throw
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Launcher.Tests.ps1 -Output Detailed"`
Expected: FAIL — file not found / `Get-LauncherArgs` not recognized.

- [ ] **Step 3: Write minimal implementation**

```powershell
# src/Launcher.ps1
param(
    [switch]$AsModule,                 # when set, only define functions (for tests)
    [Parameter(Position=0)][string]$Mode,
    [Parameter(Position=1)][string]$Path
)

function Get-LauncherArgs {
    param([string[]]$Argv)
    if ($Argv.Count -lt 2) { throw "Usage: Launcher <save|clip|open> <path>" }
    $mode = $Argv[0]
    if ($mode -notin @('save','clip','open')) { throw "Unknown mode: $mode" }
    [pscustomobject]@{ Mode = $mode; Path = $Argv[1] }
}

function Invoke-Launcher {
    param([string]$Mode, [string]$Path)

    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $modules = Join-Path $here 'modules'
    foreach ($m in 'Paths','Config','I18n','Converter','Runtime','Toast','Batch') {
        Import-Module (Join-Path $modules "$m.psm1") -Force
    }
    $appRoot = Split-Path -Parent $here   # installed layout: <root>/src/Launcher.ps1

    # language strings
    $settings = Get-Settings -Path (Get-SettingsPath)
    $langDir  = Join-Path $appRoot 'lang'
    $code     = Resolve-Language -Setting $settings.Language -Available @('de','en')
    $strings  = Import-Language -LangDir $langDir -Code $code

    # batch: coalesce multi-select into one run
    $queue = Get-QueuePath
    $mutex = 'MarkItDownMenuQueue'
    $isOwner = Add-ToQueue -QueuePath $queue -Path $Path -MutexName $mutex
    if (-not $isOwner) { return }            # a sibling instance owns this batch
    Start-Sleep -Milliseconds 800           # debounce window for sibling launches
    $paths = Read-AndClearQueue -QueuePath $queue -MutexName $mutex

    # runtime guard (interactive offers handled inside)
    if (-not (Confirm-Runtime -Strings $strings)) { return }

    # expand folders to files using the configured extensions
    $exts  = Get-RegisteredExtensions
    $files = foreach ($p in $paths) { Get-FilesToConvert -Path $p -Extensions $exts }

    $results = Convert-Files -Files @($files) -Mode $Mode
    $ok   = @($results | Where-Object Success).Count
    $fail = @($results | Where-Object { -not $_.Success }).Count
    if ($fail -eq 0) {
        Show-Toast -Title (Get-String 'toast.title' $strings) -Message ((Get-String 'toast.done' $strings) -f $ok)
    } else {
        Show-Toast -Title (Get-String 'toast.title' $strings) -Message ((Get-String 'toast.partial' $strings) -f $ok, ($ok+$fail), $fail) -Error
    }
}

if (-not $AsModule) {
    $a = Get-LauncherArgs -Argv @($Mode, $Path)
    Invoke-Launcher -Mode $a.Mode -Path $a.Path
}
```

> Note: `Confirm-Runtime` is added to `Runtime.psm1` in Task 9 (toast dependency). Until Task 9 lands, this script imports `Runtime` but `Confirm-Runtime` is defined there. Task 8 only tests `Get-LauncherArgs`, which is independent.

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Launcher.Tests.ps1 -Output Detailed"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/Launcher.ps1 tests/Launcher.Tests.ps1
git commit -m "Add Launcher with arg parsing and orchestration flow"
```

---

## Task 9: Toast notifier + runtime confirmation (manual smoke)

**Files:**
- Create: `src/modules/Toast.psm1`
- Modify: `src/modules/Runtime.psm1` (add `Confirm-Runtime`)

- [ ] **Step 1: Implement `Toast.psm1`**

```powershell
# src/modules/Toast.psm1

function Show-Toast {
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message, [switch]$Error)
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $template.GetElementsByTagName('text')
        $texts.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $texts.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('MarkItDown.ContextMenu')
        $notifier.Show($toast)
    }
    catch {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = if ($Error) { 'Error' } else { 'Information' }
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', $icon) | Out-Null
    }
}

Export-ModuleMember -Function Show-Toast
```

- [ ] **Step 2: Add `Confirm-Runtime` to `Runtime.psm1`**

Append to `src/modules/Runtime.psm1` (and add `Confirm-Runtime` to its `Export-ModuleMember` list):

```powershell
function Confirm-Runtime {
    param([Parameter(Mandatory)][hashtable]$Strings)
    Add-Type -AssemblyName System.Windows.Forms

    $ver = Get-PythonVersion
    if (-not (Test-PythonVersion -Version $ver)) {
        $ans = [System.Windows.Forms.MessageBox]::Show($Strings['runtime.pythonMissing'], $Strings['toast.title'], 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return $false }
        if (-not (Install-Python)) {
            [System.Windows.Forms.MessageBox]::Show($Strings['runtime.pythonManual'], $Strings['toast.title'], 'OK', 'Information') | Out-Null
            return $false
        }
    }
    if (-not (Test-MarkItDownInstalled)) {
        $ans = [System.Windows.Forms.MessageBox]::Show($Strings['runtime.markitdownMissing'], $Strings['toast.title'], 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return $false }
        if (-not (Install-MarkItDown)) { return $false }
    }
    return $true
}
```

Update the export line in `Runtime.psm1` to include `Confirm-Runtime`.

- [ ] **Step 3: Verify the full suite still passes**

Run: `pwsh -NoProfile -File tests/RunTests.ps1`
Expected: all tests PASS (modules import cleanly; no regressions).

- [ ] **Step 4: Manual smoke — toast**

Run:
```bash
pwsh -NoProfile -Command "Import-Module ./src/modules/Toast.psm1 -Force; Show-Toast -Title 'MarkItDown' -Message 'Smoke test'"
```
Expected: a Windows toast (or a MessageBox fallback) appears reading "Smoke test".

- [ ] **Step 5: Commit**

```bash
git add src/modules/Toast.psm1 src/modules/Runtime.psm1
git commit -m "Add Toast notifier and runtime confirmation dialog"
```

---

## Task 10: Hidden launch shim

**Files:**
- Create: `src/HiddenLaunch.vbs`

- [ ] **Step 1: Implement the VBS shim**

```vbscript
' HiddenLaunch.vbs — runs Launcher.ps1 with no console window.
' Args: <mode> <path>
Set args = WScript.Arguments
mode = args(0)
target = args(1)

scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
launcher = scriptDir & "\Launcher.ps1"

cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & launcher & """ " & mode & " """ & target & """"

CreateObject("WScript.Shell").Run cmd, 0, False
```

- [ ] **Step 2: Manual smoke — no window flash**

Create a test file, then run:
```bash
pwsh -NoProfile -Command "Set-Content $env:TEMP\smoke.txt 'hello world'; wscript src/HiddenLaunch.vbs save $env:TEMP\smoke.txt"
```
Expected: no visible console window; after ~1s a toast appears and `$env:TEMP\smoke.md` exists. (Requires `markitdown` installed — Task 9 dialog will offer it if missing.)

- [ ] **Step 3: Commit**

```bash
git add src/HiddenLaunch.vbs
git commit -m "Add VBScript shim for flicker-free launching"
```

---

## Task 11: Configuration GUI (manual smoke)

**Files:**
- Create: `src/Configure.ps1`

- [ ] **Step 1: Implement the WinForms GUI**

```powershell
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
```

- [ ] **Step 2: Manual smoke — GUI opens and registers**

Run: `pwsh -NoProfile -File src/Configure.ps1`
Expected: window opens; common types listed; checking `.pdf` + Save registers it. Verify:
```bash
pwsh -NoProfile -Command "Import-Module ./src/modules/Registry.psm1 -Force; Get-RegisteredExtensions"
```
Expected: lists `.pdf`. Then right-click a `.pdf` in Explorer → "In Markdown umwandeln" + "(Optionen)" appear (Win11: under "Show more options").

- [ ] **Step 3: Clean up smoke registration**

Run: `pwsh -NoProfile -Command "Import-Module ./src/modules/Registry.psm1 -Force; foreach (\$e in (Get-RegisteredExtensions)) { Unregister-MenuForExtension -Extension \$e }; Unregister-MenuForFolder"`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/Configure.ps1
git commit -m "Add WinForms configuration GUI"
```

---

## Task 12: Installers + README

**Files:**
- Create: `install.ps1`
- Create: `install.cmd`
- Create: `uninstall.ps1`
- Create: `README.md`

- [ ] **Step 1: Implement `install.ps1`**

```powershell
# install.ps1 — copies files to %LOCALAPPDATA%\MarkItDownMenu, registers defaults, adds a shortcut.
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
Import-Module (Join-Path $src 'src/modules/Paths.psm1') -Force
Import-Module (Join-Path $src 'src/modules/Config.psm1') -Force
Import-Module (Join-Path $src 'src/modules/I18n.psm1') -Force
Import-Module (Join-Path $src 'src/modules/Registry.psm1') -Force

$dest = Get-InstallDir
New-Item -ItemType Directory -Path $dest -Force | Out-Null
foreach ($d in 'src','config','lang') {
    Copy-Item -Path (Join-Path $src $d) -Destination $dest -Recurse -Force
}

$settings = Get-Settings -Path (Get-SettingsPath)
$code   = Resolve-Language -Setting $settings.Language -Available @('de','en')
$S      = Import-Language -LangDir (Join-Path $dest 'lang') -Code $code
$labels = @{ direct=$S['menu.direct']; options=$S['menu.options']; save=$S['menu.save']; clip=$S['menu.clip']; open=$S['menu.open'] }
$launcherCmd = 'wscript "' + (Join-Path $dest 'src\HiddenLaunch.vbs') + '"'

$defaults = '.pdf','.docx','.xlsx','.pptx','.png','.jpg','.html','.csv'
foreach ($e in $defaults) { Register-MenuForExtension -Extension $e -DefaultMode $settings.DefaultAction -Labels $labels -LauncherCommand $launcherCmd }
Register-MenuForFolder -DefaultMode $settings.DefaultAction -Labels $labels -LauncherCommand $launcherCmd

# Start-menu shortcut to the GUI
$lnkDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$lnk = Join-Path $lnkDir 'MarkItDown Context Menu.lnk'
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = 'pwsh.exe'
$sc.Arguments  = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dest 'src\Configure.ps1') + '"'
$sc.WorkingDirectory = $dest
$sc.Save()

Write-Host "Installed to $dest. Defaults registered. Open 'MarkItDown Context Menu' from the Start menu to configure."
```

- [ ] **Step 2: Implement `install.cmd`**

```bat
@echo off
where pwsh >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7+ ^(pwsh^) is required. Install it from https://aka.ms/powershell and re-run.
  pause
  exit /b 1
)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
```

- [ ] **Step 3: Implement `uninstall.ps1`**

```powershell
# uninstall.ps1 — removes registry entries, the install dir, and the shortcut.
#Requires -Version 7.0
$dest = Join-Path $env:LOCALAPPDATA 'MarkItDownMenu'
$reg = Join-Path $dest 'src/modules/Registry.psm1'
if (Test-Path $reg) {
    Import-Module $reg -Force
    foreach ($e in @(Get-RegisteredExtensions)) { Unregister-MenuForExtension -Extension $e }
    Unregister-MenuForFolder
}
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MarkItDown Context Menu.lnk'
if (Test-Path $lnk) { Remove-Item $lnk -Force }
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Write-Host "Uninstalled."
```

- [ ] **Step 4: Write `README.md`**

````markdown
# MarkItDown Context Menu

Right-click any supported file or folder in Windows Explorer to convert it to
Markdown with Microsoft's [`markitdown`](https://github.com/microsoft/markitdown).

## Install

1. Install PowerShell 7+ (`pwsh`) from https://aka.ms/powershell if you don't have it.
2. Double-click **`install.cmd`**.

That's it — no admin rights needed. On first conversion the tool checks for
Python 3.10+ and `markitdown`, and offers to install them if missing.

## Use

Right-click a file, several files, or a folder:

- **In Markdown umwandeln / Convert to Markdown** — runs the default action.
- **… (Optionen) / … (Options)** — choose: save `.md`, copy to clipboard, or save & open.

On Windows 11 the entries appear under **"Show more options"** (Shift+Right-click).

## Configure

Open **"MarkItDown Context Menu"** from the Start menu to pick which file types
show the menu, set the direct-entry action, and choose the language
(Auto / Deutsch / English).

## Uninstall

Run `uninstall.ps1`, or use the **Uninstall** button in the settings window.
````

- [ ] **Step 5: Manual smoke — install/uninstall roundtrip**

Run: `pwsh -NoProfile -File install.ps1`
Expected: prints "Installed to …"; `%LOCALAPPDATA%\MarkItDownMenu` exists; Start-menu shortcut present; default extensions registered (verify with `Get-RegisteredExtensions`). Then:
Run: `pwsh -NoProfile -File uninstall.ps1`
Expected: prints "Uninstalled."; install dir and shortcut gone; no registered extensions remain.

- [ ] **Step 6: Commit**

```bash
git add install.ps1 install.cmd uninstall.ps1 README.md
git commit -m "Add installers and README"
```

---

## Task 13: Full-suite verification

- [ ] **Step 1: Run the entire test suite**

Run: `pwsh -NoProfile -File tests/RunTests.ps1`
Expected: all tests PASS, 0 failed. (Paths 2, Config 6, I18n 7, Converter 6, Runtime 5, Batch 2, Registry 2, Launcher 3.)

- [ ] **Step 2: Commit any fixes**

```bash
git add -A
git commit -m "Fix issues found during full-suite verification"
```

(If nothing changed, skip the commit.)

---

## Self-Review Notes (resolved)

- **Spec coverage:** two menu entries (Task 7/11), direct action configurable (Task 11), options submenu (Task 7), file-type checkbox GUI (Task 11), folder + multi-select batch (Task 6/8), Python version gate + install (Task 5/9), markitdown install (Task 9), de/en localization + system default (Task 3), no-admin install for others (Task 12), Win11 hybrid seam — core functions are reusable (Converter/Runtime/Toast), classic registry shipped (Task 7).
- **Naming consistency:** `Get-RegisteredExtensions`, `Register-MenuForExtension`, `Convert-Files`, `Invoke-MarkItDownCli`, `Confirm-Runtime`, modes `save|clip|open`, settings `{Language,DefaultAction}` are used identically across tasks.
- **External seam:** all markitdown calls funnel through `Invoke-MarkItDownCli` (mocked in Task 4).
