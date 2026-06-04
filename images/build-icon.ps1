# images/build-icon.ps1 — regenerate markdown-icon.ico from markdown-icon.png.
# Classic Explorer context-menu icons must be .ico; PNG/SVG are ignored.
# Produces a multi-resolution icon (PNG-compressed entries, Vista+).
#Requires -Version 7.0
Add-Type -AssemblyName System.Drawing

$here = $PSScriptRoot
$png  = Join-Path $here 'markdown-icon.png'
$ico  = Join-Path $here 'markdown-icon.ico'
$sizes = 16, 24, 32, 48, 64, 256

$src = [System.Drawing.Image]::FromFile($png)
try {
    # Render each size to a PNG byte blob.
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

$fs = [System.IO.File]::Create($ico)
$bw = New-Object System.IO.BinaryWriter $fs
try {
    # ICONDIR
    $bw.Write([uint16]0)               # reserved
    $bw.Write([uint16]1)               # type: icon
    $bw.Write([uint16]$frames.Count)   # image count

    # ICONDIRENTRY table; image data starts after dir + entries.
    $offset = 6 + (16 * $frames.Count)
    foreach ($f in $frames) {
        $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
        $bw.Write([byte]$dim)          # width  (0 == 256)
        $bw.Write([byte]$dim)          # height (0 == 256)
        $bw.Write([byte]0)             # palette count
        $bw.Write([byte]0)             # reserved
        $bw.Write([uint16]1)           # color planes
        $bw.Write([uint16]32)          # bits per pixel
        $bw.Write([uint32]$f.Bytes.Length)
        $bw.Write([uint32]$offset)
        $offset += $f.Bytes.Length
    }
    foreach ($f in $frames) { $bw.Write($f.Bytes) }
}
finally { $bw.Dispose(); $fs.Dispose() }

Write-Host "Wrote $ico ($((Get-Item $ico).Length) bytes, $($frames.Count) sizes)"
