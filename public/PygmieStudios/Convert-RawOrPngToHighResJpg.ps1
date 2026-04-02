# Converts RAW/PNG/TIFF files to high-resolution JPEGs (same base filename & dimensions).
# Uses dcraw when available to decode RAW to TIFF, then ImageMagick to write a high-quality JPG.
function Convert-RawOrPngToHighResJpg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Quality = 98,

        [Parameter()]
        [switch]$Overwrite
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        $rawExts = @('.cr2', '.nef', '.arw', '.raf', '.dng', '.rw2', '.raw')
        $rasterExts = @('.png', '.tif', '.tiff', '.jpg', '.jpeg')

        Write-Host ''
        Write-Host "Converting RAW files in: $($InputFolder):" -ForegroundColor Cyan

        Push-Location -Path $InputFolder

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        $RawFiles = foreach ($pattern in $Global:RawFileTypes) {
            Get-ChildItem -Path . -Filter $pattern -File -ErrorAction SilentlyContinue
        }

        $Index = 0
        foreach ($RawFile in $RawFiles) {
            $Index++
            $RawExtension = [IO.Path]::GetExtension($RawFile.FullName).ToLowerInvariant()
            $BaseFilename = Join-Path $RawFile.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($RawFile.Name))
            $JpgFilename = "$BaseFilename.jpg"


            # If file exists and user does not want overwrite
            if ((Test-Path $JpgFilename) -and (-not $Overwrite)) {
                Write-Host "Jpg already exists, skipping existing output: $JpgFilename" -ForegroundColor Yellow
                continue
            }

            # --- Convert RAW/PNG/BMP/etc. → JPG ---
            try {
                #Write-Host "Converting $($RawFile.Name) → $(Split-Path $JpgFilename -Leaf)..." -ForegroundColor Cyan

                & magick @(
                    $RawFile.FullName
                    '-quality'
                    $Quality
                    $JpgFilename
                )

                if (Test-Path $JpgFilename) {
                    Write-Host -Message "[$Index/$($RawFiles.Count) $($RawFile.FullName) `n  -> $JpgFilename" -ForegroundColor Green
                }
                else {
                    Write-Host -Message "[$Index/$($RawFiles.Count) $($RawFile.FullName) `n  -> $JpgFilename" -ForegroundColor Red
                    $Result = $false
                }
            }
            catch {
                Write-Host -Message "[$Index/$($RawFiles.Count) $($RawFile.FullName) `n  -> $JpgFilename" -ForegroundColor Red
                Write-Host "    Exception during conversion of $($RawFile.FullName): $_" -ForegroundColor Red
                $Result = $false
            }
        }
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"

        Pop-Location

        return $Result

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'end' block"
    }
}

