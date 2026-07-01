function Convert-psRawOrPngToHighResJpg {
    <#
    .SYNOPSIS
        Converts RAW, PNG, and TIFF files to high-resolution JPEG files in-place.

    .DESCRIPTION
        Scans the input folder for RAW and raster image files and converts each one
        to a high-quality JPEG at the same location using the same base filename.
        If a JPEG of the same name already exists, the file is skipped unless
        the -Overwrite switch is specified.

    .INPUTS
        [System.String] $InputFolder = Folder containing the source image files. Defaults to current directory.
        [System.Int32]  $Quality     = JPEG quality (1-100). Default is 98.
        [Switch]        $Overwrite   = When specified, overwrites existing JPEG output files.

    .OUTPUTS
        [Bool] = $True on full success, $False if any conversion fails.

    .EXAMPLE
        Convert-psRawOrPngToHighResJpg

    .EXAMPLE
        Convert-psRawOrPngToHighResJpg -InputFolder '/Volumes/Camera/DCIM' -Quality 95

    .EXAMPLE
        Convert-psRawOrPngToHighResJpg -InputFolder '/Volumes/Camera/DCIM' -Overwrite

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Output JPEGs are placed alongside the source files (same folder, .jpg extension).
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $Quality = 98,

        [Parameter()]
        [switch] $Overwrite
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        $InputFolder = [System.IO.Path]::GetFullPath($InputFolder)

        Write-Host ''
        Write-Host "Converting RAW/PNG/TIFF files in: $InputFolder" -ForegroundColor Cyan

        Write-Verbose "   InputFolder = $InputFolder"
        Write-Verbose "   Quality     = $Quality"
        Write-Verbose "   Overwrite   = $Overwrite"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }

            $RawFiles = @()
            $RawFiles += foreach ($Pattern in $Global:RawFileTypes) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            if ($RawFiles.Count -eq 0) {
                Write-Host 'No RAW/PNG/TIFF files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $Index          = 0
                $countSucceeded = 0
                $countSkipped   = 0
                $countFailed    = 0

                foreach ($RawFile in $RawFiles) {
                    $Index++
                    $JpgFilename = Join-Path $RawFile.DirectoryName ([System.IO.Path]::GetFileNameWithoutExtension($RawFile.Name) + '.jpg')

                    if ((Test-Path $JpgFilename) -and (-not $Overwrite)) {
                        $countSkipped++
                        Write-Host "[$Index/$($RawFiles.Count)] SKIPPED (exists): $(Split-Path $JpgFilename -Leaf)" -ForegroundColor Yellow
                        continue
                    }

                    try {
                        & magick $RawFile.FullName -quality $Quality $JpgFilename

                        if (Test-Path $JpgFilename) {
                            $countSucceeded++
                            Write-Host "[$Index/$($RawFiles.Count)] $($RawFile.Name) -> $(Split-Path $JpgFilename -Leaf)" -ForegroundColor Green
                        }
                        else {
                            $Result = $false
                            $countFailed++
                            Write-Host "[$Index/$($RawFiles.Count)] FAILED (no output): $($RawFile.Name)" -ForegroundColor Red
                        }
                    }
                    catch {
                        $Result = $false
                        $countFailed++
                        Write-Host "[$Index/$($RawFiles.Count)] FAILED: $($RawFile.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'RAW to JPG' -Rows @(
                    [pscustomobject]@{ Label = 'Files converted'; Count = $countSucceeded; Color = 'Green'  }
                    [pscustomobject]@{ Label = 'Files skipped';   Count = $countSkipped;   Color = 'Yellow' }
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
