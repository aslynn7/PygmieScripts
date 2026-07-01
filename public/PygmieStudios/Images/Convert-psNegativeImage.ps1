function Convert-psNegativeImage {
    <#
    .SYNOPSIS
        Converts scanned film negatives to positive images.

    .DESCRIPTION
        Inverts the colors of all image files in the input folder using ImageMagick's
        -negate operation, producing positive prints from film negative scans. Supports
        both grayscale (black-and-white film) and RGB (color film) output colorspaces.
        Output files are written alongside the originals with a colorspace suffix.

    .INPUTS
        [System.String] $InputFolder = Folder where the negative image files are located. Defaults to current directory.
        [System.String] $ColorSpace  = Color mode: 'Gray' for B&W film, 'RGB' for color film.

    .OUTPUTS
        [Bool] = $True on full success, $False if any conversion fails.

    .EXAMPLE
        Convert-psNegativeImage -ColorSpace Gray

    .EXAMPLE
        Convert-psNegativeImage -InputFolder '/Volumes/Scans/FilmRoll1' -ColorSpace RGB

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        CR2 files are converted to PNG output (lossless, preserves dynamic range).
        Output filenames include the colorspace suffix, e.g. 'IMG_001 (RGB-Negatized).jpg'.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Gray', 'RGB')]
        [System.String] $ColorSpace
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose "   InputFolder = $InputFolder"
        Write-Verbose "   ColorSpace  = $ColorSpace"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $Patterns = $Global:LossyFileTypes + $Global:RawFileTypes

            $Pictures = @()
            $Pictures += foreach ($Pattern in $Patterns) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            $Index          = 0
            $countSucceeded = 0
            $countFailed    = 0

            if ($Pictures.Count -eq 0) {
                Write-Warning "No pictures found in $InputFolder"
                $Result = $False
            }
            else {
                Write-Host ''
                Write-Host "Converting $($Pictures.Count) negative(s) to positive ($ColorSpace):" -ForegroundColor Cyan

                foreach ($Picture in $Pictures) {
                    $Index++
                    try {
                        $InputFile  = $Picture.FullName
                        $Extension  = [System.IO.Path]::GetExtension($InputFile)
                        if ($Extension -ieq '.cr2') { $Extension = '.png' }

                        $BaseName   = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
                        $OutputFile = Join-Path ([System.IO.Path]::GetDirectoryName($InputFile)) "$BaseName ($ColorSpace-Negatized)$Extension"

                        & magick $InputFile -colorspace $ColorSpace -negate -quality 100 -auto-orient $OutputFile
                        $countSucceeded++
                        Write-Host "[$Index/$($Pictures.Count)] $($Picture.Name) -> $(Split-Path $OutputFile -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Pictures.Count)] FAILED: $($Picture.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Negative Conversion' -Rows @(
                    [pscustomobject]@{ Label = 'Images converted'; Count = $countSucceeded; Color = 'Green' }
                    [pscustomobject]@{ Label = 'Images failed';    Count = $countFailed;    Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
