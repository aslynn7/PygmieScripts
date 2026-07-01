function Add-psCopyrightAndWatermarkToImage {
    <#
    .SYNOPSIS
        Adds a visual watermark and copyright metadata to image files.

    .DESCRIPTION
        Processes all image files in the input folder, applying a translucent text watermark
        to the lower-right corner of each image. EXIF/IPTC/XMP metadata fields (Copyright,
        Artist, Creator, Title, Keywords, Comment) are also written using ExifTool. Output
        is written to a 'Watermarked' subfolder by default, originals are not modified.

    .INPUTS
        [System.String] $InputFolder          = Folder containing source image files. Defaults to current directory.
        [System.String] $OutputFolder         = Destination folder. Defaults to InputFolder/Watermarked.
        [System.String] $Watermark            = Text rendered as visible watermark on the image.
        [System.String] $Copyright            = Copyright text written to image metadata.
        [System.String] $Title                = Title written to image metadata.
        [System.String] $Author               = Author/artist name written to image metadata.
        [System.String] $Tags                 = Comma-separated keywords written to IPTC metadata.
        [System.String] $Comment              = Comment written to image metadata.
        [System.String] $FontName             = ImageMagick font name for the watermark text. Default: Courier.
        [decimal]       $FontSizePercentage   = Fraction of image width the watermark text should span (0.0–1.0). Default: 0.5.
        [Switch]        $OverwriteOutputFolder = When specified, clears the output folder before processing.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails.

    .EXAMPLE
        Add-psCopyrightAndWatermarkToImage

    .EXAMPLE
        Add-psCopyrightAndWatermarkToImage -OverwriteOutputFolder

    .EXAMPLE
        Add-psCopyrightAndWatermarkToImage -InputFolder '/Volumes/Photos/Session1' -Author 'Jane Doe' -Copyright 'Copyright 2025 Jane Doe'

    .NOTES
        Requires ImageMagick and ExifTool.
        Install via: brew install imagemagick exiftool
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = '',

        [Parameter(Mandatory = $False)]
        [System.String] $Watermark = 'Copyright 2025 (c)\nAll Rights Reserved',

        [Parameter(Mandatory = $False)]
        [System.String] $Copyright = 'Copyright 2025 (c) All Rights Reserved',

        [Parameter(Mandatory = $False)]
        [System.String] $Title = '',

        [Parameter(Mandatory = $False)]
        [System.String] $Author = 'John Smith',

        [Parameter(Mandatory = $False)]
        [System.String] $Tags = '',

        [Parameter(Mandatory = $False)]
        [System.String] $Comment = '',

        [Parameter(Mandatory = $False)]
        [System.String] $FontName = 'Courier',

        [Parameter(Mandatory = $False)]
        [ValidateRange(0, 1)]
        [decimal] $FontSizePercentage = .5,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        if ([System.String]::IsNullOrEmpty($OutputFolder)) {
            $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'Watermarked'
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"
        Write-Verbose "   Watermark    = $Watermark"
        Write-Verbose "   Copyright    = $Copyright"
        Write-Verbose "   Author       = $Author"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path $OutputFolder)) {
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }
            elseif ($OverwriteOutputFolder) {
                Remove-Item $OutputFolder -Recurse -Force | Out-Null
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            $Files = @()
            $Files += foreach ($FileType in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                Get-ChildItem -Path $InputFolder -Filter $FileType -File -ErrorAction SilentlyContinue
            }

            if ($Files.Count -eq 0) {
                Write-Warning "No image files found in input folder: $InputFolder"
            }
            else {
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host ''
                Write-Host "Adding watermark and copyright to $($Files.Count) files:" -ForegroundColor Cyan

                foreach ($File in $Files) {
                    $Index++
                    $InputFile  = $File.FullName
                    $OutputFile = Join-Path $OutputFolder $File.Name

                    try {
                        $OrientedFile = Join-Path $InputFolder 'oriented_temp.jpg'
                        & magick $InputFile -auto-orient $OrientedFile

                        $imgWidth   = [int](& magick identify -format '%w' $OrientedFile)
                        $baseSize   = 20
                        $textWidth  = [int](& magick -debug none -font $FontName -pointsize $baseSize label:"$Watermark" -format '%w' info:)
                        $targetWidth = $imgWidth * $FontSizePercentage
                        $FontSize   = [math]::Floor($baseSize * ($targetWidth / $textWidth))

                        & magick $OrientedFile `
                            -font $FontName `
                            -gravity southeast `
                            -pointsize $FontSize `
                            -fill 'rgba(255, 255, 255, 0.29)' `
                            -stroke 'rgba(0,0,0,0.5)' `
                            -strokewidth 2 `
                            -annotate +10+10 "$($Watermark)" `
                            $OutputFile

                        Remove-Item $OrientedFile -Force -ErrorAction SilentlyContinue

                        & exiftool `
                            -overwrite_original `
                            "-Copyright=$Copyright" `
                            "-IPTC:CopyrightNotice=$Copyright" `
                            "-XMP-dc:Rights=$Copyright" `
                            "-Title=$Title" `
                            "-Artist=$Author" `
                            "-Creator=$Author" `
                            "-XMP-dc:Creator=$Author" `
                            "-IPTC:Keywords=$Tags" `
                            "-XMP-dc:Description=$Comment" `
                            "-EXIF:UserComment=$Comment" `
                            "-Comments=$Comment" `
                            $OutputFile | Out-Null

                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $(Split-Path $OutputFile -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Watermark + Copyright' -Rows @(
                    [pscustomobject]@{ Label = 'Files succeeded'; Count = $countSucceeded; Color = 'Green' }
                    [pscustomobject]@{ Label = 'Files failed';    Count = $countFailed;    Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
                )
            }
        }
        catch {
            throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
