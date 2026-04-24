Add-Type -AssemblyName System.Drawing

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Fill-RoundedRect($graphics, $brush, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-RoundedRectPath $x $y $w $h $r
    $graphics.FillPath($brush, $path)
    $path.Dispose()
}

function Draw-Barcode($graphics, [float]$x, [float]$y, [float]$w, [float]$h, [System.Drawing.Color]$color) {
    $bars = @(3,1,2,1,4,1,2,1,3,1,2,2,4,1,1,3,2,1,4,1,2,1,3,1,2,2,4,1,2,1)
    $total = ($bars | Measure-Object -Sum).Sum
    $scale = $w / $total
    $cursor = $x

    foreach ($bar in $bars) {
        $barWidth = [Math]::Max(2, [int]($bar * $scale))
        $brush = New-Object System.Drawing.SolidBrush($color)
        $graphics.FillRectangle($brush, $cursor, $y, $barWidth, $h)
        $brush.Dispose()
        $cursor += $barWidth + 1
    }
}

function Draw-TabIcon($graphics, [float]$x, [float]$y, [float]$size, [string]$type, [bool]$active) {
    $backgroundColor = if ($active) {
        [System.Drawing.Color]::FromArgb(255, 21, 30, 54)
    } else {
        [System.Drawing.Color]::FromArgb(255, 230, 235, 242)
    }
    $foregroundColor = if ($active) {
        [System.Drawing.Color]::White
    } else {
        [System.Drawing.Color]::FromArgb(255, 102, 112, 130)
    }

    $backgroundBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
    Fill-RoundedRect $graphics $backgroundBrush $x $y $size $size 16
    $backgroundBrush.Dispose()

    switch ($type) {
        "barcode" {
            for ($i = 0; $i -lt 8; $i++) {
                $barX = $x + 11 + ($i * 4)
                $barWidth = if ($i % 3 -eq 0) { 3 } else { 2 }
                $brush = New-Object System.Drawing.SolidBrush($foregroundColor)
                $graphics.FillRectangle($brush, $barX, $y + 12, $barWidth, $size - 24)
                $brush.Dispose()
            }
        }
        "qr" {
            $brush = New-Object System.Drawing.SolidBrush($foregroundColor)
            $graphics.FillRectangle($brush, $x + 11, $y + 11, 9, 9)
            $graphics.FillRectangle($brush, $x + 24, $y + 11, 9, 9)
            $graphics.FillRectangle($brush, $x + 17, $y + 24, 9, 9)
            $graphics.FillRectangle($brush, $x + 30, $y + 24, 5, 5)
            $brush.Dispose()
        }
        "photo" {
            $pen = New-Object System.Drawing.Pen($foregroundColor, 3)
            $graphics.DrawRectangle($pen, $x + 10, $y + 12, $size - 20, $size - 24)
            $graphics.DrawEllipse($pen, $x + 16, $y + 18, 6, 6)
            $points = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(($x + 14), ($y + $size - 16)),
                [System.Drawing.PointF]::new(($x + 22), ($y + 24)),
                [System.Drawing.PointF]::new(($x + 29), ($y + 30)),
                [System.Drawing.PointF]::new(($x + $size - 12), ($y + $size - 16))
            )
            $graphics.DrawLines($pen, $points)
            $pen.Dispose()
        }
    }
}

$bitmap = New-Object System.Drawing.Bitmap 512, 512
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = "AntiAlias"
$graphics.Clear([System.Drawing.Color]::FromArgb(255, 246, 248, 252))

$outerGradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 52, 52, 408, 408),
    ([System.Drawing.Color]::FromArgb(255, 26, 38, 66)),
    ([System.Drawing.Color]::FromArgb(255, 24, 111, 108)),
    45
)
Fill-RoundedRect $graphics $outerGradient 52 52 408 408 96
$outerGradient.Dispose()

$innerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 250, 254))
Fill-RoundedRect $graphics $innerBrush 82 82 348 348 64
$innerBrush.Dispose()

$shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 0, 0, 0))
Fill-RoundedRect $graphics $shadowBrush 120 160 272 136 28
$shadowBrush.Dispose()

Draw-TabIcon $graphics 118 110 58 "barcode" $true
Draw-TabIcon $graphics 188 110 58 "qr" $false
Draw-TabIcon $graphics 258 110 58 "photo" $false

$cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
Fill-RoundedRect $graphics $cardBrush 114 154 284 128 28
$cardBrush.Dispose()

Draw-Barcode $graphics 146 188 240 60 ([System.Drawing.Color]::FromArgb(255, 27, 36, 64))

$accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 118, 110))
Fill-RoundedRect $graphics $accentBrush 146 320 64 20 10
Fill-RoundedRect $graphics $accentBrush 224 320 64 20 10
$accentBrush.Dispose()

$dangerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 180, 35, 24))
Fill-RoundedRect $graphics $dangerBrush 302 320 64 20 10
$dangerBrush.Dispose()

$outputPath = Join-Path $outDir "quick_display_app_icon_512_alt.png"
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()

Write-Output $outputPath
