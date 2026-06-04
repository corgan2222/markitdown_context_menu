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
        foreach ($k in $loc.Keys) { $en[$k] = $loc[$k] }
    }
    $en
}

function Get-String {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][hashtable]$Strings)
    if ($Strings.ContainsKey($Key)) { return $Strings[$Key] }
    $Key
}

Export-ModuleMember -Function Resolve-Language, Import-Language, Get-String, ConvertTo-StringTable
