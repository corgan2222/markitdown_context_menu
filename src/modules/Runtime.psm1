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
