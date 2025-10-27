function Add-CopyrightAndWatermarkToImage {
    <#
   .SYNOPSIS
      Adds watermark and metadata to images in a specified folder.

   .DESCRIPTION
      Adds watermark and metadata to images in a specified folder.

   .INPUTS
        [System.String] $InputFolder = Folder where the input .jpg/.jpeg files are located.
        [System.String] $OutputFolder = Folder where the output watermarked images will be saved.
        [System.String] $Watermark = Copyright notice to be added as a watermark.
        [System.String] $Copyright = Copyright notice to be added to the image metadata.
        [System.String] $Title = Title to be added to the image metadata.
        [System.String] $Author = Author name to be added to the image metadata.
        [System.String] $Tags = Tags to be added to the image metadata; these are comma-separated.
        [System.String] $Comment = Comment to be added to the image metadata.
        [System.String] $FontName = Name of the font to be used for the watermark.
        [System.Int16] $FontSize = Size of the font to be used for the watermark.
        [Switch] $OverwriteOutputFolder = If specified, will overwrite the output folder if it already exists.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      C:\PS> Add-CopyrightAndWatermarkToImage

   .EXAMPLE
      C:\PS> Add-CopyrightAndWatermarkToImage -OverwriteOutputFolder

   .NOTES
      This function only works on MacOS.  Requires installation of ImageMagick and ExifTool.
      Ensure that the ImageMagick and ExifTool commands are available in your PATH.
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = $Null,

        [Parameter(Mandatory = $False)]
        [System.String] $Watermark = "Copyright 2025 (c) Pygmie Studios`nAll Rights Reserved",

        [Parameter(Mandatory = $False)]
        [System.String] $Copyright = 'Copyright 2025 (c) Pygmie Studios All Rights Reserved',

        [Parameter(Mandatory = $False)]
        [System.String] $Title = '',

        [Parameter(Mandatory = $False)]
        [System.String] $Author = 'Aslynn Meyers',

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
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Host ''
        Write-Host 'Calling Add-CopyrightAndWatermarkToImage() with the following parameters:' -ForegroundColor Cyan

        if ( -not $OutputFolder ) {
            $OutputFolder = Join-Path -Path $PWD -ChildPath 'Watermarked'
        }
          
        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"
        Write-Verbose "   Watermark    = $($Watermark.Replace("`n", "`n   "))"
        Write-Verbose "   Copyright    = $Copyright"
        Write-Verbose "   Title        = $Title"
        Write-Verbose "   Author       = $Author"
        Write-Verbose "   Tags         = $Tags"
        Write-Verbose "   Comment      = $Comment"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path $OutputFolder)) {
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }
            elseif ($OverwriteOutputFolder) {
                Write-Verbose "Overwriting existing output folder: $OutputFolder"
                Remove-Item $OutputFolder -Recurse -Force | Out-Null
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            $Files = Get-ChildItem -Path $inputFolder\* -File -Include *.jpg, *.jpeg

            $Index = 0

            Write-Host "Adding Watermark and Metadata to $($Files.Count) files:" -ForegroundColor White
            foreach ( $File in $Files ) {
                $Index++

                $InputFile = $File.FullName
                $OutputFile = Join-Path $OutputFolder $File.Name

                try {
                    Write-Verbose "Adding watermark to $InputFile"
                    Write-Verbose '---------------------------------------------------'

                    Write-Verbose 'Auto-orient the image so portrait/landscape rotation is correct'
                    $OrientedFile = "$InputFolder/oriented_temp.jpg"
                    & magick $InputFile -auto-orient $OrientedFile

                    Write-Verbose 'Get oriented image width'
                    $imgWidth = [int](& magick identify -format '%w' $OrientedFile)

                    Write-Verbose 'Base font size for measurement'
                    $baseSize = 20

                    Write-Verbose 'Measure text width at base size'
                    $textWidth = [int](& magick -debug none -font $FontName -pointsize $baseSize label:"$Watermark" -format '%w' info:)

                    Write-Verbose 'Compute font size to make watermark ~30% of oriented image width'
                    $targetWidth = $imgWidth * $FontSizePercentage
                    $FontSize = [math]::Floor($baseSize * ($targetWidth / $textWidth))

                    Write-Verbose 'Apply watermark to auto-oriented image'
                    & magick $OrientedFile `
                        -font $FontName `
                        -gravity southeast `
                        -pointsize $FontSize `
                        -fill 'rgba(255, 255, 255, 0.29)' `
                        -stroke 'rgba(0,0,0,0.5)' `
                        -strokewidth 2 `
                        -annotate +10+10 "$Watermark" `
                        $OutputFile

                    Write-Verbose 'Clean up temp file'
                    Remove-Item $OrientedFile -Force

                    Write-Verbose "Adding metadata to $OutputFile"
                    Write-Verbose '---------------------------------------------------'
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
                        $OutputFile | Out-Null

                    Write-Host "[$Index/$($Files.Count)] $InputFile => $OutputFile " -ForegroundColor Green
                }
                catch {
                    $Result = $False
                    Write-Host "[$Index/$($Files.Count)] $InputFile => $OutputFile - Error = $_" -ForegroundColor Red
                }

                $Result = $Result -band $True
            }
        }
        catch {
            throw $("Error encountered in [$($MyInvocation.MyCommand.Name)] - " + $_.Exception)
        }

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"

        return $Result

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'end' block"
    }
}

