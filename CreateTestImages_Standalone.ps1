# CreateTestImages_Standalone.ps1
# Standalone test image generator (all-in-one)

# ===== CLASSES =====
class PixelRGB888 {
    [byte]$R
    [byte]$G
    [byte]$B
    
    PixelRGB888([byte]$r, [byte]$g, [byte]$b) {
        $this.R = $r
        $this.G = $g
        $this.B = $b
    }
}

class ImageContainer {
    [string]$Signature = "IMG1"
    [int]$Width
    [int]$Height
    [int]$PixelType = 1
    [PixelRGB888[]]$Pixels
    
    ImageContainer([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.Pixels = New-Object PixelRGB888[] ($width * $height)
        
        for ($i = 0; $i -lt $this.Pixels.Length; $i++) {
            $this.Pixels[$i] = [PixelRGB888]::new(0, 0, 0)
        }
    }
    
    [PixelRGB888]GetPixel([int]$x, [int]$y) {
        $index = $y * $this.Width + $x
        return $this.Pixels[$index]
    }
    
    [void]SetPixel([int]$x, [int]$y, [PixelRGB888]$pixel) {
        $index = $y * $this.Width + $x
        $this.Pixels[$index] = $pixel
    }
    
    [void]SaveToFile([string]$path) {
        $stream = [System.IO.File]::Create($path)
        $writer = New-Object System.IO.BinaryWriter($stream)
        
        try {
            $sigBytes = [System.Text.Encoding]::ASCII.GetBytes($this.Signature)
            $writer.Write($sigBytes, 0, 4)
            $writer.Write([int]$this.Width)
            $writer.Write([int]$this.Height)
            $writer.Write([int]$this.PixelType)
            
            foreach ($pixel in $this.Pixels) {
                $writer.Write([byte]$pixel.R)
                $writer.Write([byte]$pixel.G)
                $writer.Write([byte]$pixel.B)
            }
        }
        finally {
            $writer.Close()
            $stream.Close()
        }
    }
    
    static [ImageContainer]LoadFromFile([string]$filePath) {
        $fileStream = [System.IO.File]::OpenRead($filePath)
        $fileReader = New-Object System.IO.BinaryReader($fileStream)
        
        try {
            $headerBytes = $fileReader.ReadBytes(4)
            $fileSignature = [System.Text.Encoding]::ASCII.GetString($headerBytes)
            
            if ($fileSignature -ne "IMG1") {
                throw "Invalid format"
            }
            
            $imageWidth = $fileReader.ReadInt32()
            $imageHeight = $fileReader.ReadInt32()
            $imagePixelType = $fileReader.ReadInt32()
            
            $imageContainer = [ImageContainer]::new($imageWidth, $imageHeight)
            
            for ($idx = 0; $idx -lt ($imageWidth * $imageHeight); $idx++) {
                $redValue = $fileReader.ReadByte()
                $greenValue = $fileReader.ReadByte()
                $blueValue = $fileReader.ReadByte()
                $imageContainer.Pixels[$idx] = [PixelRGB888]::new($redValue, $greenValue, $blueValue)
            }
            
            return $imageContainer
        }
        finally {
            $fileReader.Close()
            $fileStream.Close()
        }
    }
}

# ===== GENERATOR FUNCTIONS =====

Write-Host ""
Write-Host "=== Test Image Generator ===" -ForegroundColor Yellow
Write-Host ""

# 1. Gradient
Write-Host "Creating gradient..." -ForegroundColor Cyan
$img = [ImageContainer]::new(256, 256)
for ($y = 0; $y -lt 256; $y++) {
    for ($x = 0; $x -lt 256; $x++) {
        $r = [byte]$x
        $g = [byte]$y
        $b = [byte]((255 - $x) / 2)
        $img.SetPixel($x, $y, [PixelRGB888]::new($r, $g, $b))
    }
}
$img.SaveToFile("test_gradient.img")
Write-Host "  Saved: test_gradient.img" -ForegroundColor Green

# 2. Checkerboard
Write-Host "Creating checkerboard..." -ForegroundColor Cyan
$img = [ImageContainer]::new(64, 64)
$cellSize = 8
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 64; $x++) {
        $isWhite = (([Math]::Floor($x / $cellSize) + [Math]::Floor($y / $cellSize)) % 2) -eq 0
        if ($isWhite) {
            $img.SetPixel($x, $y, [PixelRGB888]::new(255, 255, 255))
        } else {
            $img.SetPixel($x, $y, [PixelRGB888]::new(0, 0, 0))
        }
    }
}
$img.SaveToFile("test_checkerboard.img")
Write-Host "  Saved: test_checkerboard.img" -ForegroundColor Green

# 3. Color bars
Write-Host "Creating color bars..." -ForegroundColor Cyan
$img = [ImageContainer]::new(280, 100)
$colors = @(
    @(255, 0, 0),
    @(255, 165, 0),
    @(255, 255, 0),
    @(0, 255, 0),
    @(0, 127, 255),
    @(0, 0, 255),
    @(139, 0, 255)
)
$barWidth = [Math]::Floor($img.Width / $colors.Count)
for ($y = 0; $y -lt $img.Height; $y++) {
    for ($x = 0; $x -lt $img.Width; $x++) {
        $colorIndex = [Math]::Min([Math]::Floor($x / $barWidth), $colors.Count - 1)
        $color = $colors[$colorIndex]
        $img.SetPixel($x, $y, [PixelRGB888]::new($color[0], $color[1], $color[2]))
    }
}
$img.SaveToFile("test_colorbars.img")
Write-Host "  Saved: test_colorbars.img" -ForegroundColor Green

# 4. Circles
Write-Host "Creating circles..." -ForegroundColor Cyan
$img = [ImageContainer]::new(200, 200)
$centerX = 100
$centerY = 100
$maxRadius = [Math]::Sqrt($centerX * $centerX + $centerY * $centerY)
for ($y = 0; $y -lt 200; $y++) {
    for ($x = 0; $x -lt 200; $x++) {
        $dx = $x - $centerX
        $dy = $y - $centerY
        $distance = [Math]::Sqrt($dx * $dx + $dy * $dy)
        $normalized = $distance / $maxRadius
        $intensity = [byte]([Math]::Sin($normalized * [Math]::PI * 10) * 127 + 128)
        $img.SetPixel($x, $y, [PixelRGB888]::new($intensity, $intensity, 255))
    }
}
$img.SaveToFile("test_circles.img")
Write-Host "  Saved: test_circles.img" -ForegroundColor Green

# 5. Noise
Write-Host "Creating noise..." -ForegroundColor Cyan
$img = [ImageContainer]::new(128, 128)
$random = New-Object System.Random
for ($y = 0; $y -lt 128; $y++) {
    for ($x = 0; $x -lt 128; $x++) {
        $r = [byte]$random.Next(256)
        $g = [byte]$random.Next(256)
        $b = [byte]$random.Next(256)
        $img.SetPixel($x, $y, [PixelRGB888]::new($r, $g, $b))
    }
}
$img.SaveToFile("test_noise.img")
Write-Host "  Saved: test_noise.img" -ForegroundColor Green

Write-Host ""
Write-Host "All images created! Run ImageViewer_Standalone.ps1" -ForegroundColor Green