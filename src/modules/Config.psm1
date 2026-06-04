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
