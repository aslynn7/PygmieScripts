function Merge-psScanPairForImage {
    <#
    .SYNOPSIS
        Combines a front scan and a back scan image into a single stacked composite.

    .DESCRIPTION
        Takes two image paths — a top (front) and a bottom (back) scan — and produces
        a single output image with the front on the top half and back on the bottom half.
        The output is written alongside the top image with a '_Combined' filename suffix.
        Both images are auto-oriented and white-matted before compositing. The bottom
        image is cropped to match the dimensions of the top image exactly.

    .INPUTS
        [System.String] $TopImagePath    = Full path to the front/top scan image.
        [System.String] $BottomImagePath = Full path to the back/bottom scan image.

    .OUTPUTS
        None. Writes the combined file to disk alongside $TopImagePath.

    .EXAMPLE
        Merge-psScanPairForImage -TopImagePath '/Volumes/Scans/front.jpg' -BottomImagePath '/Volumes/Scans/back.jpg'

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        The output is placed in the same directory as the top image, with '_Combined' suffix.
        Temp files are written to a 'tmp_combine' subfolder and cleaned up automatically.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string] $TopImagePath,

        [Parameter(Mandatory = $true)]
        [string] $BottomImagePath
    )

    $Dir        = Split-Path $TopImagePath -Parent
    $Name       = [System.IO.Path]::GetFileNameWithoutExtension($TopImagePath)
    $Ext        = [System.IO.Path]::GetExtension($TopImagePath)
    $OutputPath = Join-Path $Dir "${Name}_Combined${Ext}"

    $tmpDir    = Join-Path $Dir 'tmp_combine'
    if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }
    $tmpTop    = Join-Path $tmpDir ('top_{0}.png'    -f ([guid]::NewGuid()))
    $tmpBottom = Join-Path $tmpDir ('bottom_{0}.png' -f ([guid]::NewGuid()))

    try {
        Write-Host "  Processing: $([System.IO.Path]::GetFileName($TopImagePath)) + $([System.IO.Path]::GetFileName($BottomImagePath))"

        & magick "$TopImagePath" -auto-orient -background white -alpha remove "$tmpTop"

        $Width  = [int](& magick identify -format '%w' "$tmpTop")
        $Height = [int](& magick identify -format '%h' "$tmpTop")
        $FinalH = $Height * 2

        Write-Verbose "Top image dimensions: ${Width}x${Height}"

        & magick "$BottomImagePath" `
            -auto-orient `
            -crop "${Width}x${Height}+0+0" `
            +repage `
            -background white -alpha remove `
            "$tmpBottom"

        & magick -size "${Width}x${FinalH}" canvas:white `
            "$tmpTop"    -geometry +0+0         -compose over -composite `
            "$tmpBottom" -geometry "+0+${Height}" -compose over -composite `
            "$OutputPath"

        Write-Host "  Output: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to combine images: $_"
    }
    finally {
        Remove-Item $tmpTop    -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpBottom -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpDir    -Recurse -Force -ErrorAction SilentlyContinue
    }
}
