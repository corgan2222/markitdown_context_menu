Import-Module (Join-Path $PSScriptRoot 'Runtime.psm1')   # Get-PythonCommand

function Get-OutputPath {
    param([Parameter(Mandatory)][string]$InputPath, [switch]$IncludeComments)
    $dir  = [IO.Path]::GetDirectoryName($InputPath)
    $name = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    if ($IncludeComments) { return Join-Path $dir "$name.with-comments.md" }
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
    param([Parameter(Mandatory)][string]$InputPath, [switch]$IncludeComments)
    # Python writes UTF-8 and PowerShell reads UTF-8, whatever the console code page is.
    $env:PYTHONIOENCODING = "utf-8"
    $oldEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    try {
        if ($IncludeComments) {
            $helper = Join-Path (Split-Path -Parent $PSScriptRoot) 'ConvertDocxWithComments.py'
            $out = & (Get-PythonCommand) -X utf8 $helper $InputPath 2>&1
        } else {
            $out = & (Get-PythonCommand) -m markitdown $InputPath 2>&1
        }
        if ($LASTEXITCODE -ne 0) { throw ($out -join [Environment]::NewLine) }
        return ($out -join [Environment]::NewLine)
    }
    finally {
        # Restore the original encoding to avoid affecting other functions
        [Console]::OutputEncoding = $oldEncoding
    }
}

function Convert-Files {
    param(
        [Parameter(Mandatory)][string[]]$Files,
        [Parameter(Mandatory)][ValidateSet('save','clip','open','comments')][string]$Mode
    )
    $results = New-Object System.Collections.Generic.List[object]
    $clipBuffer = New-Object System.Collections.Generic.List[string]
    foreach ($f in $Files) {
        try {
            if ($Mode -eq 'comments') {
                if ([IO.Path]::GetExtension($f) -ine '.docx') { throw 'Including comments requires a .docx file.' }
                $md = Invoke-MarkItDownCli -InputPath $f -IncludeComments
            } else {
                $md = Invoke-MarkItDownCli -InputPath $f
            }
            switch ($Mode) {
                'comments' { Set-Content -LiteralPath (Get-OutputPath $f -IncludeComments) -Value $md -Encoding utf8 }
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
