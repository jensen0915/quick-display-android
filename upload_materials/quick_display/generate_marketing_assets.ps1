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
    $bars = @(2, 1, 3, 1, 1, 2, 4, 1, 2, 3, 1, 1, 4, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 4, 1, 3, 1)
    $total = ($bars | Measure-Object -Sum).Sum
    $scale = $w / $total
    $cursor = $x

    foreach ($bar in $bars) {
        $barWidth = [Math]::Max(2, [int]($bar * $scale))
        $brush = New-Object System.Drawing.SolidBrush($color)
        $graphics.FillRectangle($brush, $cursor, $y, $barWidth, $h)
        $brush.Dispose()
        $cursor += $barWidth + $scale
    }
}

function Draw-SlotIcon($graphics, [float]$x, [float]$y, [float]$size, [string]$type, [bool]$active) {
    $backgroundColor = if ($active) {
        [System.Drawing.Color]::FromArgb(255, 32, 42, 68)
    } else {
        [System.Drawing.Color]::FromArgb(255, 237, 240, 247)
    }
    $foregroundColor = if ($active) {
        [System.Drawing.Color]::White
    } else {
        [System.Drawing.Color]::FromArgb(255, 90, 100, 118)
    }

    $backgroundBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
    Fill-RoundedRect $graphics $backgroundBrush $x $y $size $size 18
    $backgroundBrush.Dispose()

    $penBrush = New-Object System.Drawing.SolidBrush($foregroundColor)
    $pen = New-Object System.Drawing.Pen($penBrush, 4)

    switch ($type) {
        "barcode" {
            for ($i = 0; $i -lt 8; $i++) {
                $barX = $x + 14 + ($i * 6)
                $barW = if ($i % 3 -eq 0) { 4 } else { 2 }
                $barBrush = New-Object System.Drawing.SolidBrush($foregroundColor)
                $graphics.FillRectangle($barBrush, $barX, $y + 16, $barW, $size - 32)
                $barBrush.Dispose()
            }
        }
        "qr" {
            $qrBrush = New-Object System.Drawing.SolidBrush($foregroundColor)
            $graphics.FillRectangle($qrBrush, $x + 14, $y + 14, 14, 14)
            $graphics.FillRectangle($qrBrush, ($x + $size - 28), $y + 14, 14, 14)
            $graphics.FillRectangle($qrBrush, $x + 14, ($y + $size - 28), 14, 14)
            $graphics.FillRectangle($qrBrush, $x + 34, $y + 34, 8, 8)
            $graphics.FillRectangle($qrBrush, $x + 50, $y + 34, 8, 8)
            $graphics.FillRectangle($qrBrush, $x + 42, $y + 50, 8, 8)
            $qrBrush.Dispose()
        }
        "photo" {
            $graphics.DrawRectangle($pen, $x + 14, $y + 18, $size - 28, $size - 36)
            $graphics.DrawEllipse($pen, $x + 24, $y + 26, 10, 10)
            $points = [System.Drawing.PointF[]]@(
                ([System.Drawing.PointF]::new(($x + 20), ($y + $size - 24))),
                ([System.Drawing.PointF]::new(($x + 34), ($y + 44))),
                ([System.Drawing.PointF]::new(($x + 46), ($y + 56))),
                ([System.Drawing.PointF]::new(($x + $size - 18), ($y + $size - 24)))
            )
            $graphics.DrawLines($pen, $points)
        }
    }

    $pen.Dispose()
    $penBrush.Dispose()
}

function Save-AppIcon {
    $bitmap = New-Object System.Drawing.Bitmap 512, 512
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = "AntiAlias"
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 245, 247, 251))

    $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle 64, 64, 384, 384),
        ([System.Drawing.Color]::FromArgb(255, 26, 39, 68)),
        ([System.Drawing.Color]::FromArgb(255, 31, 118, 110)),
        45
    )
    Fill-RoundedRect $graphics $gradient 64 64 384 384 86
    $gradient.Dispose()

    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 0, 0, 0))
    Fill-RoundedRect $graphics $shadowBrush 92 110 328 292 44
    $shadowBrush.Dispose()

    $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 250, 255))
    Fill-RoundedRect $graphics $panelBrush 86 98 340 304 42
    $panelBrush.Dispose()

    Draw-SlotIcon $graphics 112 124 84 "barcode" $true
    Draw-SlotIcon $graphics 214 124 84 "qr" $false
    Draw-SlotIcon $graphics 316 124 84 "photo" $false

    $screenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    Fill-RoundedRect $graphics $screenBrush 120 230 272 118 24
    $screenBrush.Dispose()

    Draw-Barcode $graphics 150 252 210 56 ([System.Drawing.Color]::FromArgb(255, 32, 42, 68))

    $font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 32, 42, 68))
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = "Center"
    $graphics.DrawString("QD", $font, $textBrush, (New-Object System.Drawing.RectangleF(0, 390, 512, 40)), $format)

    $graphics.Dispose()
    $font.Dispose()
    $textBrush.Dispose()
    $format.Dispose()

    $iconPath = Join-Path $outDir "quick_display_app_icon_512.png"
    $bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    return $iconPath
}

function Save-FeatureGraphic {
    $bitmap = New-Object System.Drawing.Bitmap 1024, 500
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = "AntiAlias"
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 247, 248, 251))

    $backgroundGradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle 0, 0, 1024, 500),
        ([System.Drawing.Color]::FromArgb(255, 248, 250, 255)),
        ([System.Drawing.Color]::FromArgb(255, 226, 238, 240)),
        0
    )
    $graphics.FillRectangle($backgroundGradient, 0, 0, 1024, 500)
    $backgroundGradient.Dispose()

    $accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(35, 15, 118, 110))
    $graphics.FillEllipse($accentBrush, 760, -40, 220, 220)
    $graphics.FillEllipse($accentBrush, 620, 320, 280, 180)
    $accentBrush.Dispose()

    $titleFont = New-Object System.Drawing.Font("Segoe UI", 30, [System.Drawing.FontStyle]::Bold)
    $bodyFont = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Regular)
    $smallFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)

    $darkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 24, 34, 56))
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 82, 95, 118))
    $tealBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 118, 110))
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

    $graphics.DrawString("Quick Display", $titleFont, $darkBrush, 86, 96)
    $graphics.DrawString(
        "Switch between barcodes, QR codes, and saved images instantly.",
        $bodyFont,
        $mutedBrush,
        (New-Object System.Drawing.RectangleF(88, 150, 420, 80))
    )

    Fill-RoundedRect $graphics $tealBrush 88 246 190 42 18
    $graphics.DrawString("Fast access slots", $smallFont, $whiteBrush, 118, 255)

    $phoneShadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 0, 0, 0))
    Fill-RoundedRect $graphics $phoneShadow 592 64 272 372 38
    $phoneShadow.Dispose()

    $phoneBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 21, 28, 45))
    Fill-RoundedRect $graphics $phoneBrush 572 48 272 372 38
    $phoneBrush.Dispose()

    $notchBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 12, 16, 26))
    Fill-RoundedRect $graphics $notchBrush 654 64 108 18 9
    $notchBrush.Dispose()

    $screenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 242, 245, 249))
    Fill-RoundedRect $graphics $screenBrush 590 88 236 314 26
    $screenBrush.Dispose()

    Draw-SlotIcon $graphics 608 106 58 "barcode" $true
    Draw-SlotIcon $graphics 676 106 58 "qr" $false
    Draw-SlotIcon $graphics 744 106 58 "photo" $false

    $previewBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    Fill-RoundedRect $graphics $previewBrush 614 184 188 118 18
    $previewBrush.Dispose()

    Draw-Barcode $graphics 640 216 138 48 ([System.Drawing.Color]::FromArgb(255, 32, 42, 68))

    $miniBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 118, 110))
    Fill-RoundedRect $graphics $miniBrush 616 328 54 34 14
    Fill-RoundedRect $graphics $miniBrush 678 328 54 34 14
    $miniBrush.Dispose()

    $dangerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 180, 35, 24))
    Fill-RoundedRect $graphics $dangerBrush 740 328 54 34 14
    $dangerBrush.Dispose()

    $graphics.Dispose()
    $titleFont.Dispose()
    $bodyFont.Dispose()
    $smallFont.Dispose()
    $darkBrush.Dispose()
    $mutedBrush.Dispose()
    $tealBrush.Dispose()
    $whiteBrush.Dispose()

    $featurePath = Join-Path $outDir "quick_display_feature_graphic_1024x500.png"
    $bitmap.Save($featurePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    return $featurePath
}

$iconPath = Save-AppIcon
$featurePath = Save-FeatureGraphic

Write-Output $iconPath
Write-Output $featurePath
