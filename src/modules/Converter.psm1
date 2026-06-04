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
