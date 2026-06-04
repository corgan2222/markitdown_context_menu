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
        & python -c "import markitdown" *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Get-MarkItDownVersion {
    try {
        $out = & python -c "import importlib.metadata as m; print(m.version('markitdown'))" 2>$null
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
    & python -m pip install --user --upgrade "markitdown[all]"
    return ($LASTEXITCODE -eq 0)
}

function Install-Python {
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

Export-ModuleMember -Function ConvertTo-PythonVersion, Test-PythonVersion, Get-PythonVersion, Test-MarkItDownInstalled, Get-MarkItDownVersion, Get-LatestMarkItDownVersion, Test-UpdateAvailable, Update-MarkItDown, Install-Python, Install-MarkItDown, Confirm-Runtime
