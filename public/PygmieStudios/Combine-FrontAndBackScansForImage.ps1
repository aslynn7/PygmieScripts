function Combine-FrontAndBackScansForImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TopImagePath,   # front / photo side

        [Parameter(Mandatory = $true)]
        [string]$BottomImagePath # back / print/text side
    )

    # Output path: same filename + "_Combined"
    $dir = Split-Path $TopImagePath -Parent
    $name = [IO.Path]::GetFileNameWithoutExtension($TopImagePath)
    $ext = [IO.Path]::GetExtension($TopImagePath)
    $OutputPath = Join-Path $dir "$name`_Combined$ext"

    # Temp folder
    $tmpDir = Join-Path $dir 'tmp_combine'
    if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }
    $tmpTop = Join-Path $tmpDir ('top_{0}.png' -f ([guid]::NewGuid()))
    $tmpBottom = Join-Path $tmpDir ('bottom_{0}.png' -f ([guid]::NewGuid()))

    try {
        Write-Host 'Processing images...'

        # --- Step 1: Process Top (auto-orient, no trim, no crop) ---
        & magick "$TopImagePath" -auto-orient -background white -alpha remove "$tmpTop"

        # Read reference dimensions
        $width = [int](& magick identify -format '%w' "$tmpTop")
        $height = [int](& magick identify -format '%h' "$tmpTop")
        $finalH = $height * 2

        Write-Host "Top image dimensions = ${width}x${height}"

        # --- Step 2: Process Bottom (auto-orient only, then crop exact WxH from top-left) ---
        & magick "$BottomImagePath" `
            -auto-orient `
            -crop "${width}x${height}+0+0" `
            +repage `
            -background white -alpha remove `
            "$tmpBottom"

        # --- Step 3: Composite onto final canvas manually (top + bottom) ---
        & magick -size "${width}x${finalH}" canvas:white `
            "$tmpTop"    -geometry +0+0         -compose over -composite `
            "$tmpBottom" -geometry "+0+$height" -compose over -composite `
            "$OutputPath"

        Write-Host "✅ Done! Output saved to $OutputPath"
    }
    catch {
        Write-Error "❌ Failed to combine images: $_"
    }
    finally {
        # Cleanup temp files
        try { Remove-Item $tmpTop -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Item $tmpBottom -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}