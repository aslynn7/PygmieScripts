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
        [System.String] $OutputFolder = "$PWD/Watermarked",

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
        [System.Int16] $FontSize = 16,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $false

        Write-Host 'Calling Add-CopyrightAndWatermarkToImage() with the following parameters:'

        Write-Host "   InputFolder  = $InputFolder"
        Write-Host "   OutputFolder = $OutputFolder"
        Write-Host "   Watermark    = $($Watermark.Replace("`n", "`n   "))"
        Write-Host "   Copyright    = $Copyright"
        Write-Host "   Title        = $Title"
        Write-Host "   Author       = $Author"
        Write-Host "   Tags         = $Tags"
        Write-Host "   Comment      = $Comment"

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
                Remove-Item $OutputFolder -Recurse -Force
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            Write-Host ''
            Write-Host 'Converting files:'
            Get-ChildItem -Path $inputFolder\* -Include *.jpg, *.jpeg | ForEach-Object {
                $InputFile = $_.FullName
                Write-Host "   - $InputFile"

                $OutputFile = Join-Path $OutputFolder $_.Name

                Write-Verbose "Adding watermark to $InputFile"
                & magick `
                    $InputFile `
                    -font $FontName `
                    -gravity southeast `
                    -pointsize $FontSize `
                    -fill 'rgba(255,255,255,0.3)' `
                    -annotate +10+10 "$Watermark" `
                    $OutputFile

                Write-Verbose "Adding metadata to $OutputFile"
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

            }

            $Result = $true
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

