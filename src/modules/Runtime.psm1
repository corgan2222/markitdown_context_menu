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

# markitdown 0.1.8+ declares Requires-Python <3.15 (PyPI, 2026-11-10); on 3.15 pip falls back to 0.0.2.
# Fixed ceiling: raise it once markitdown supports the next Python.
$script:PythonBelow = [version]'3.15'

# Pure: interpreter paths from `py -0p` output that markitdown supports, newest first.
function Select-PythonFromPyList {
    param([string[]]$Lines, [version]$Below = $script:PythonBelow, [version]$Minimum = ([version]'3.10'))
    $found = foreach ($l in $Lines) {
        if ($l -notmatch '^\s*-V:(\S+)\s+(?:\*\s+)?(.+?\.exe)\s*$') { continue }
        $tag = $Matches[1]; $path = $Matches[2]
        if ($tag -match 't$') { continue }   # free-threaded build
        if ($tag -notmatch '(\d+)\.(\d+)') { continue }
        $v = [version]("{0}.{1}" -f $Matches[1], $Matches[2])
        if ($v -lt $Minimum -or $v -ge $Below) { continue }
        [pscustomobject]@{ Version = $v; Path = $path }
    }
    @($found | Sort-Object Version -Descending | ForEach-Object Path)
}

# --- side-effecting helpers (smoke-tested manually) ---

# The interpreter every call uses: the newest one markitdown supports, else plain `python`.
function Get-PythonCommand {
    if ($script:PythonCommand) { return $script:PythonCommand }
    $script:PythonCommand = 'python'
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $list = @(& py -0p 2>$null)
        foreach ($p in Select-PythonFromPyList -Lines $list) {
            # pip --user refuses an externally managed interpreter (for example one installed by uv)
            if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $p) 'Lib\EXTERNALLY-MANAGED')) { continue }
            $script:PythonCommand = $p
            break
        }
    }
    $script:PythonCommand
}

function Get-PythonVersion {
    try {
        $out = & (Get-PythonCommand) --version 2>&1
        return ConvertTo-PythonVersion -Text ($out -join ' ')
    } catch { return $null }
}

function Test-MarkItDownInstalled {
    try {
        & (Get-PythonCommand) -c "import markitdown" *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Get-MarkItDownVersion {
    try {
        $out = & (Get-PythonCommand) -c "import importlib.metadata as m; print(m.version('markitdown'))" 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return (@($out)[0]).Trim() }
        return $null
    } catch { return $null }
}

function Get-LatestMarkItDownVersion {
    param([int]$TimeoutSec = 8)
    try {
        $r = Invoke-RestMethod -Uri 'https://pypi.org/pypi/markitdown/json' -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $r.info.version
    } catch { return $null }
}

# This tool's own version. Bundled at install time as a plain-text VERSION file
# in the application root; kept in sync with the latest GitHub release tag.
function Get-ToolVersion {
    param([string]$Path)
    try {
        if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
        $v = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
        if ([string]::IsNullOrWhiteSpace($v)) { return $null }
        return $v
    } catch { return $null }
}

# Latest published release tag from GitHub (e.g. 'v0.2.0' -> '0.2.0').
function Get-LatestToolVersion {
    param(
        [string]$Repo = 'corgan2222/markitdown_context_menu',
        [int]$TimeoutSec = 8
    )
    try {
        $uri = "https://api.github.com/repos/$Repo/releases/latest"
        $headers = @{ 'User-Agent' = 'markitdown-context-menu'; 'Accept' = 'application/vnd.github+json' }
        $r = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec $TimeoutSec -ErrorAction Stop
        $tag = $r.tag_name
        if ([string]::IsNullOrWhiteSpace($tag)) { return $null }
        return ($tag -replace '^v', '')
    } catch { return $null }
}

# Pure comparison: is $Latest a newer release than $Installed?
function Test-UpdateAvailable {
    param([string]$Installed, [string]$Latest)
    if ([string]::IsNullOrWhiteSpace($Installed) -or [string]::IsNullOrWhiteSpace($Latest)) { return $false }
    if ($Installed -eq $Latest) { return $false }

    $toNums = {
        param([string]$v)
        $m = [regex]::Match($v, '^\d+(\.\d+)*')
        if (-not $m.Success) { return @() }
        return @($m.Value.Split('.') | ForEach-Object { [int]$_ })
    }
    $a = & $toNums $Installed
    $b = & $toNums $Latest
    $len = [Math]::Max($a.Count, $b.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $x = if ($i -lt $a.Count) { $a[$i] } else { 0 }
        $y = if ($i -lt $b.Count) { $b[$i] } else { 0 }
        if ($y -gt $x) { return $true }
        if ($y -lt $x) { return $false }
    }
    # Numeric release equal: an installed prerelease (e.g. 0.0.1a2) is older than the final (0.0.1)
    $instPre = $Installed -match '[A-Za-z]'
    $latePre = $Latest    -match '[A-Za-z]'
    if ($instPre -and -not $latePre) { return $true }
    return $false
}

function Update-MarkItDown {
    & (Get-PythonCommand) -m pip install --user --upgrade "markitdown[all]"
    return ($LASTEXITCODE -eq 0)
}

function Install-Python {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements
        $script:PythonCommand = $null   # pick again, the new interpreter may be the right one
        return ($LASTEXITCODE -eq 0)
    }
    Start-Process 'https://www.python.org/downloads/windows/'
    return $false
}

function Install-MarkItDown {
    & (Get-PythonCommand) -m pip install --user "markitdown[all]"
    return ($LASTEXITCODE -eq 0)
}

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

Export-ModuleMember -Function ConvertTo-PythonVersion, Test-PythonVersion, Select-PythonFromPyList, Get-PythonCommand, Get-PythonVersion, Test-MarkItDownInstalled, Get-MarkItDownVersion, Get-LatestMarkItDownVersion, Get-ToolVersion, Get-LatestToolVersion, Test-UpdateAvailable, Update-MarkItDown, Install-Python, Install-MarkItDown, Confirm-Runtime
