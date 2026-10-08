Add-Type -AssemblyName System.Drawing
$root = (Get-Location).Path
$outDir = Join-Path $root 'assets/tilesets'
New-Item -ItemType Directory -Force $outDir | Out-Null
$soil = [System.Drawing.Bitmap]::FromFile((Join-Path $root 'output/imagegen/tilesets/battlefield-soil-source.png'))
$swamp = [System.Drawing.Bitmap]::FromFile((Join-Path $root 'output/imagegen/tilesets/battlefield-swamp-source.png'))
$atlas = New-Object System.Drawing.Bitmap 1280,320
$g = [System.Drawing.Graphics]::FromImage($atlas)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(35,27,31))
function Draw-Cropped($source, $flipX, $flipY) {
  $side = [Math]::Min($source.Width, $source.Height)
  $cropSide = [int]($side * 0.64)
  $cropX = [int](($source.Width - $cropSide) / 2)
  $cropY = [int](($source.Height - $cropSide) / 2)
  $rect = New-Object System.Drawing.Rectangle $cropX,$cropY,$cropSide,$cropSide
  $tile = New-Object System.Drawing.Bitmap 160,160
  $tg = [System.Drawing.Graphics]::FromImage($tile)
  $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $tg.DrawImage($source, (New-Object System.Drawing.Rectangle 0,0,160,160), $rect, [System.Drawing.GraphicsUnit]::Pixel)
  $tg.Dispose()
  if ($flipX) { $tile.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
  if ($flipY) { $tile.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY) }
  return $tile
}
for ($i=0; $i -lt 5; $i++) {
  $tile = Draw-Cropped $soil ($i % 2 -eq 1) ($i -eq 3)
  $g.DrawImage($tile, $i * 160, 0, 160, 160); $tile.Dispose()
}
for ($i=0; $i -lt 3; $i++) {
  $tile = Draw-Cropped $swamp ($i -eq 1) ($i -eq 2)
  $g.DrawImage($tile, $i * 160, 160, 160, 160); $tile.Dispose()
}
$g.Dispose(); $soil.Dispose(); $swamp.Dispose()
$atlas.Save((Join-Path $outDir 'battlefield_ground_tileset.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
