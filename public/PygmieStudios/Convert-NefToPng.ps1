function Convert-NefToPng {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder = $PWD,

        [string]$OutputFolder = $SourceFolder,

        [switch]$Recurse
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        throw "Source folder does not exist: $SourceFolder"
    }

    $magickCommand = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $magickCommand) {
        throw "ImageMagick's 'magick' command was not found in PATH."
    }

    $sourceRoot = (Resolve-Path -LiteralPath $SourceFolder).Path

    if (-not (Test-Path -LiteralPath $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $outputRoot = (Resolve-Path -LiteralPath $OutputFolder).Path

    $searchParams = @{
        LiteralPath = $sourceRoot
        Filter      = '*.nef'
        File        = $true
    }

    if ($Recurse) {
        $searchParams.Recurse = $true
    }

    $nefFiles = Get-ChildItem @searchParams | Sort-Object FullName

    if (-not $nefFiles) {
        Write-Host "No .nef files found in: $sourceRoot"
        return
    }

    $total = $nefFiles.Count
    $index = 0

    foreach ($nef in $nefFiles) {
        $index++

        $relativeParent = [System.IO.Path]::GetRelativePath(
            $sourceRoot,
            $nef.DirectoryName
        )

        if ($relativeParent -eq '.') {
            $targetDir = $outputRoot
        }
        else {
            $targetDir = Join-Path -Path $outputRoot -ChildPath $relativeParent
        }

        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        $pngPath = Join-Path -Path $targetDir -ChildPath ($nef.BaseName + '.png')

        Write-Progress -Activity 'Converting NEF to PNG' `
            -Status "$index of $total - $($nef.FullName)" `
            -PercentComplete (($index / $total) * 100)

        Write-Host "[$index/$total] Converting:"
        Write-Host "  Source: $($nef.FullName)"
        Write-Host "  Target: $pngPath"

        # Notes:
        # - No resize operation is used, so output stays at full resolution.
        # - PNG is lossless.
        # - PNG48 requests 16-bit RGB output for maximum retained tonal data.
        # - -auto-orient applies camera orientation metadata.
        & $magickCommand.Source `
            $nef.FullName `
            -auto-orient `
            -colorspace sRGB `
            -depth 16 `
            "PNG48:$pngPath"

        if ($LASTEXITCODE -ne 0) {
            throw "ImageMagick failed while converting: $($nef.FullName)"
        }
    }

    Write-Progress -Activity 'Converting NEF to PNG' -Completed
    Write-Host "Done. Converted $total file(s)."
}