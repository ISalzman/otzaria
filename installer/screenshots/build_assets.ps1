# מייצר את כל קבצי ה-BMP הדרושים למתקין מתוך הצילומים בתיקייה זו.
# מקור: 1.png = מסך ראשי (לתמונת WizardImageFile האנכית)
#       2.png-5.png = תכונות (לדף תכונות מותאם)
# פלט:  ../wizard_large.bmp + @2x + @3x       (164x314 / 246x471 / 328x628)
#       ../wizard_small.bmp + @2x + @3x       (55x58  / 83x87  / 110x116)  מה-icon
#       ../feature1..4.bmp                    (400x210 כל אחד, לדף התכונות)

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$srcDir = $PSScriptRoot
$outDir = Split-Path $srcDir -Parent

function Save-Bmp24 {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    # ממיר ל-24bpp BMP (פורמט נתמך ע"י Inno Setup TBitmapImage).
    $converted = New-Object System.Drawing.Bitmap($Bitmap.Width, $Bitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($converted)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($Bitmap, 0, 0, $Bitmap.Width, $Bitmap.Height)
    $g.Dispose()
    $converted.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $converted.Dispose()
    Write-Output ("  -> {0} ({1}x{2})" -f (Split-Path $Path -Leaf), $Bitmap.Width, $Bitmap.Height)
}

function Resize-Image {
    param([System.Drawing.Image]$Source, [int]$Width, [int]$Height)
    $resized = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($resized)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($Source, 0, 0, $Width, $Height)
    $g.Dispose()
    return $resized
}

function Crop-ToOpaqueBounds {
    param([System.Drawing.Image]$Source, [int]$AlphaThreshold = 250)
    # מסיר שוליים שקופים (צל/הילה) ב-PNG. מחזיר Bitmap חדש 32bpp עם אזור התוכן בלבד.
    # אם אין מידע אלפא משמעותי - מחזיר העתק של המקור.
    $w = $Source.Width
    $h = $Source.Height
    $bmp32 = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g32 = [System.Drawing.Graphics]::FromImage($bmp32)
    $g32.DrawImage($Source, 0, 0, $w, $h)
    $g32.Dispose()

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp32.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $buf.Length)
    $bmp32.UnlockBits($data)

    $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            if ($buf[$row + $x*4 + 3] -ge $AlphaThreshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt 0 -or ($maxX - $minX + 1 -eq $w -and $maxY - $minY + 1 -eq $h)) {
        # אין שוליים שקופים - לא צריך לחתוך
        return $bmp32
    }

    $cropW = $maxX - $minX + 1
    $cropH = $maxY - $minY + 1
    $cropped = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($cropped)
    $g.DrawImage($bmp32, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), $minX, $minY, $cropW, $cropH, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp32.Dispose()
    return $cropped
}

function Crop-CenterVertical {
    param([System.Drawing.Image]$Source, [double]$TargetAspect)
    # מחזיר חיתוך מרכזי לפי יחס יעד (W/H). אם המקור רחב מדי - חותך לרוחב מרכזי.
    $srcAspect = [double]$Source.Width / [double]$Source.Height
    if ($srcAspect -gt $TargetAspect) {
        $newW = [int]([Math]::Round($Source.Height * $TargetAspect))
        $newH = $Source.Height
        $x = [int](($Source.Width - $newW) / 2)
        $y = 0
    } else {
        $newW = $Source.Width
        $newH = [int]([Math]::Round($Source.Width / $TargetAspect))
        $x = 0
        $y = [int](($Source.Height - $newH) / 2)
    }
    $cropped = New-Object System.Drawing.Bitmap($newW, $newH, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($cropped)
    $g.DrawImage($Source, (New-Object System.Drawing.Rectangle(0, 0, $newW, $newH)), $x, $y, $newW, $newH, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $cropped
}

Write-Output ""
Write-Output "=== WizardImageFile (תמונה אנכית גדולה) מתוך 1.png ==="
$src1Raw = [System.Drawing.Image]::FromFile((Join-Path $srcDir '1.png'))
$src1 = Crop-ToOpaqueBounds -Source $src1Raw
$src1Raw.Dispose()
$targetAspect = 164.0 / 314.0
$cropped = Crop-CenterVertical -Source $src1 -TargetAspect $targetAspect
foreach ($pair in @(@{n='wizard_large.bmp';     w=164; h=314},
                    @{n='wizard_large@2x.bmp';  w=246; h=471},
                    @{n='wizard_large@3x.bmp';  w=328; h=628})) {
    $r = Resize-Image -Source $cropped -Width $pair.w -Height $pair.h
    Save-Bmp24 -Bitmap $r -Path (Join-Path $outDir $pair.n)
    $r.Dispose()
}
$cropped.Dispose()
$src1.Dispose()

Write-Output ""
Write-Output "=== WizardSmallImageFile (אייקון קטן) מתוך white_sketch128x128.ico ==="
$iconPath = Join-Path $outDir 'white_sketch128x128.ico'
$iconImg = [System.Drawing.Image]::FromFile($iconPath)
foreach ($pair in @(@{n='wizard_small.bmp';     w=55;  h=58},
                    @{n='wizard_small@2x.bmp';  w=83;  h=87},
                    @{n='wizard_small@3x.bmp';  w=110; h=116})) {
    # האייקון ריבועי 128x128, גם היעד כמעט ריבועי - resize ישיר עובד יפה.
    $r = Resize-Image -Source $iconImg -Width $pair.w -Height $pair.h
    Save-Bmp24 -Bitmap $r -Path (Join-Path $outDir $pair.n)
    $r.Dispose()
}
$iconImg.Dispose()

Write-Output ""
Write-Output "=== Feature thumbnails (לדף תכונות מותאם) ==="
# יחס יעד: 400x210 (~1.9:1, תואם את ה-1770x935 של המקור)
$featureMap = @(
    @{src='2.png'; out='feature1.bmp'},
    @{src='3.png'; out='feature2.bmp'},
    @{src='4.png'; out='feature3.bmp'},
    @{src='5.png'; out='feature4.bmp'}
)
foreach ($m in $featureMap) {
    $imgRaw = [System.Drawing.Image]::FromFile((Join-Path $srcDir $m.src))
    $img = Crop-ToOpaqueBounds -Source $imgRaw
    $imgRaw.Dispose()
    # חיתוך ליחס 400:210 = 1.905 לפני שינוי גודל
    $thumbAspect = 400.0 / 210.0
    $cropped = Crop-CenterVertical -Source $img -TargetAspect $thumbAspect
    $r = Resize-Image -Source $cropped -Width 400 -Height 210
    Save-Bmp24 -Bitmap $r -Path (Join-Path $outDir $m.out)
    $r.Dispose()
    $cropped.Dispose()
    $img.Dispose()
}

Write-Output ""
Write-Output "סיום. הקבצים נשמרו ב-$outDir"
