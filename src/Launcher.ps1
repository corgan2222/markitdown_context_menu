param(
    [switch]$AsModule,
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
    foreach ($m in 'Paths','Config','I18n','Converter','Runtime','Registry','Toast','Batch') {
        Import-Module (Join-Path $modules "$m.psm1") -Force
    }
    $appRoot = Split-Path -Parent $here

    $settings = Get-Settings -Path (Get-SettingsPath)
    $langDir  = Join-Path $appRoot 'lang'
    $code     = Resolve-Language -Setting $settings.Language -Available @('de','en')
    $strings  = Import-Language -LangDir $langDir -Code $code

    $queue = Get-QueuePath
    $mutex = 'MarkItDownMenuQueue'
    $isOwner = Add-ToQueue -QueuePath $queue -Path $Path -MutexName $mutex
    if (-not $isOwner) { return }
    Start-Sleep -Milliseconds 800
    $paths = Read-AndClearQueue -QueuePath $queue -MutexName $mutex

    if (-not (Confirm-Runtime -Strings $strings)) { return }

    $exts  = Get-RegisteredExtensions
    $files = foreach ($p in $paths) { Get-FilesToConvert -Path $p -Extensions $exts }

    $results = Convert-Files -Files @($files) -Mode $Mode
    $ok   = @($results | Where-Object Success).Count
    $fail = @($results | Where-Object { -not $_.Success }).Count

    $log = Get-LogPath
    foreach ($r in @($results | Where-Object { -not $_.Success })) {
        Add-Content -Path $log -Value ("{0}`t{1}`t{2}" -f (Get-Date -Format s), $r.Path, $r.Error) -Encoding utf8
    }
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
