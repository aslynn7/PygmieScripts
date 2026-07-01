function Convert-psImagesToBW {
    <#
    .SYNOPSIS
        Converts color JPG/JPEG images to grayscale (black and white).

    .DESCRIPTION
        Scans the input folder for lossy image files (JPG/JPEG) and converts each
        to a grayscale copy using ImageMagick's Gray colorspace. Original files are
        untouched; output is written to a 'BlackAndWhite' subfolder by default.

    .INPUTS
        [System.String] $InputFolder          = Folder containing color image files. Defaults to current directory.
        [System.String] $OutputFolder         = Destination folder for B&W images. Defaults to InputFolder/BlackAndWhite.
        [Switch]        $OverwriteOutputFolder = When specified, clears the output folder before processing.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails or no images are found.

    .EXAMPLE
        Convert-psImagesToBW

    .EXAMPLE
        Convert-psImagesToBW -InputFolder '/Volumes/Photos/Session1'

    .EXAMPLE
        Convert-psImagesToBW -InputFolder '/Volumes/Photos/Session1' -OutputFolder '/Volumes/Photos/BW' -OverwriteOutputFolder

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Output files share the same filename as the input; only the content is grayscaled.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = '',

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        if ([System.String]::IsNullOrEmpty($OutputFolder)) {
            $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'BlackAndWhite'
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }

            if (-not (Test-Path -LiteralPath $OutputFolder)) {
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }
            elseif ($OverwriteOutputFolder) {
                Remove-Item $OutputFolder -Recurse -Force | Out-Null
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            $Files = @()
            $Files += foreach ($FileType in $Global:LossyFileTypes) {
                Get-ChildItem -Path $InputFolder -Filter $FileType -File -ErrorAction SilentlyContinue
            }

            if ($Files.Count -eq 0) {
                Write-Host 'No image files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host "Converting $($Files.Count) image(s) to Black & White:" -ForegroundColor Cyan

                foreach ($File in $Files) {
                    $Index++
                    try {
                        $OutputFile = Join-Path $OutputFolder $File.Name
                        magick $File.FullName -colorspace Gray $OutputFile
                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $($File.Name)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'B&W Conversion' -Rows @(
                    [pscustomobject]@{ Label = 'Files converted'; Count = $countSucceeded; Color = 'Green' }
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
