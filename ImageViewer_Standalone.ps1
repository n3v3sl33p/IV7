# ImageViewer_Standalone.ps1
# Standalone image viewer (all-in-one)

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

# ===== VIEWER =====
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:currentImage = $null
$global:scale = 1.0
$global:offsetX = 0
$global:offsetY = 0
$global:showGrid = $false
$global:isDragging = $false
$global:lastMouseX = 0
$global:lastMouseY = 0

function Draw-Image {
    param($graphics, $image, $clientWidth, $clientHeight)
    
    if ($null -eq $image) { return }
    
    $graphics.Clear([System.Drawing.Color]::Black)
    
    $scaledWidth = [int]($image.Width * $global:scale)
    $scaledHeight = [int]($image.Height * $global:scale)
    
    $startX = [int](($clientWidth - $scaledWidth) / 2) + $global:offsetX
    $startY = [int](($clientHeight - $scaledHeight) / 2) + $global:offsetY
    
    for ($y = 0; $y -lt $image.Height; $y++) {
        for ($x = 0; $x -lt $image.Width; $x++) {
            $pixel = $image.GetPixel($x, $y)
            $color = [System.Drawing.Color]::FromArgb($pixel.R, $pixel.G, $pixel.B)
            
            $pixelX = $startX + [int]($x * $global:scale)
            $pixelY = $startY + [int]($y * $global:scale)
            $pixelSize = [Math]::Max(1, [int]$global:scale)
            
            $brush = New-Object System.Drawing.SolidBrush($color)
            $graphics.FillRectangle($brush, $pixelX, $pixelY, $pixelSize, $pixelSize)
            $brush.Dispose()
        }
    }
    
    if ($global:showGrid -and $global:scale -ge 4) {
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Gray, 1)
        
        for ($y = 0; $y -le $image.Height; $y++) {
            $lineY = $startY + [int]($y * $global:scale)
            $graphics.DrawLine($pen, $startX, $lineY, $startX + $scaledWidth, $lineY)
        }
        
        for ($x = 0; $x -le $image.Width; $x++) {
            $lineX = $startX + [int]($x * $global:scale)
            $graphics.DrawLine($pen, $lineX, $startY, $lineX, $startY + $scaledHeight)
        }
        
        $pen.Dispose()
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Image Viewer - IV7"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = "Fill"
$pictureBox.BackColor = [System.Drawing.Color]::Black
$form.Controls.Add($pictureBox)

$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Press O to open | +/- zoom | G grid | ESC exit"
$statusBar.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusBar)

$pictureBox.Add_Paint({
    param($sender, $e)
    Draw-Image $e.Graphics $global:currentImage $sender.ClientSize.Width $sender.ClientSize.Height
})

$form.Add_KeyDown({
    param($sender, $e)
    
    switch ($e.KeyCode) {
        "O" {
            $openDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openDialog.Filter = "Image (*.img)|*.img|All (*.*)|*.*"
            
            if ($openDialog.ShowDialog() -eq "OK") {
                try {
                    $global:currentImage = [ImageContainer]::LoadFromFile($openDialog.FileName)
                    $global:scale = 1.0
                    $global:offsetX = 0
                    $global:offsetY = 0
                    $statusLabel.Text = "Loaded: $($global:currentImage.Width)x$($global:currentImage.Height)"
                    $pictureBox.Invalidate()
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error")
                }
            }
        }
        { $_ -in "Add", "Oemplus" } {
            $global:scale = [Math]::Min($global:scale * 1.2, 50)
            $statusLabel.Text = "Zoom: $([Math]::Round($global:scale * 100))%"
            $pictureBox.Invalidate()
        }
        { $_ -in "Subtract", "OemMinus" } {
            $global:scale = [Math]::Max($global:scale / 1.2, 0.1)
            $statusLabel.Text = "Zoom: $([Math]::Round($global:scale * 100))%"
            $pictureBox.Invalidate()
        }
        "D0" {
            $global:scale = 1.0
            $global:offsetX = 0
            $global:offsetY = 0
            $statusLabel.Text = "Reset"
            $pictureBox.Invalidate()
        }
        "G" {
            $global:showGrid = -not $global:showGrid
            $statusLabel.Text = "Grid: $(if ($global:showGrid) { 'ON' } else { 'OFF' })"
            $pictureBox.Invalidate()
        }
        "Escape" {
            $form.Close()
        }
    }
})

$pictureBox.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq "Left") {
        $global:isDragging = $true
        $global:lastMouseX = $e.X
        $global:lastMouseY = $e.Y
    }
})

$pictureBox.Add_MouseMove({
    param($sender, $e)
    if ($global:isDragging) {
        $global:offsetX += $e.X - $global:lastMouseX
        $global:offsetY += $e.Y - $global:lastMouseY
        $global:lastMouseX = $e.X
        $global:lastMouseY = $e.Y
        $pictureBox.Invalidate()
    }
})

$pictureBox.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq "Left") {
        $global:isDragging = $false
    }
})

$pictureBox.Add_MouseWheel({
    param($sender, $e)
    if ($e.Delta -gt 0) {
        $global:scale = [Math]::Min($global:scale * 1.1, 50)
    } else {
        $global:scale = [Math]::Max($global:scale / 1.1, 0.1)
    }
    $statusLabel.Text = "Zoom: $([Math]::Round($global:scale * 100))%"
    $pictureBox.Invalidate()
})

Write-Host "Image Viewer IV7 - Hotkeys: O G +/- 0 ESC" -ForegroundColor Cyan
[void]$form.ShowDialog()