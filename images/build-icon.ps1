# images/build-icon.ps1 — regenerate one .ico per .png in this folder.
# Classic Explorer context-menu icons must be .ico; PNG/SVG are ignored.
# Each .ico is multi-resolution (PNG-compressed entries, Vista+).
#Requires -Version 7.0
Add-Type -AssemblyName System.Drawing

$here  = $PSScriptRoot
$sizes = 16, 24, 32, 48, 64, 256

function Convert-PngToIco {
    param([string]$Png, [string]$Ico)
    $src = [System.Drawing.Image]::FromFile($Png)
    try {
        $frames = foreach ($s in $sizes) {
            $bmp = New-Object System.Drawing.Bitmap $s, $s
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.DrawImage($src, 0, 0, $s, $s)
            $g.Dispose()
            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            [pscustomobject]@{ Size = $s; Bytes = $ms.ToArray() }
            $ms.Dispose()
        }
    }
    finally { $src.Dispose() }

    $fs = [System.IO.File]::Create($Ico)
    $bw = New-Object System.IO.BinaryWriter $fs
    try {
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)  # ICONDIR
        $offset = 6 + (16 * $frames.Count)
        foreach ($f in $frames) {
            $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
            $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
            $bw.Write([uint16]1); $bw.Write([uint16]32)
            $bw.Write([uint32]$f.Bytes.Length); $bw.Write([uint32]$offset)
            $offset += $f.Bytes.Length
        }
        foreach ($f in $frames) { $bw.Write($f.Bytes) }
    }
    finally { $bw.Dispose(); $fs.Dispose() }
}

Get-ChildItem -Path $here -Filter '*.png' | ForEach-Object {
    $ico = [System.IO.Path]::ChangeExtension($_.FullName, '.ico')
    Convert-PngToIco -Png $_.FullName -Ico $ico
    Write-Host ("{0} -> {1} ({2} bytes)" -f $_.Name, (Split-Path $ico -Leaf), (Get-Item $ico).Length)
}
