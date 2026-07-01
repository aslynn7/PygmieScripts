function Convert-psHeicToJpg {
    <#
    .SYNOPSIS
        Converts HEIC image files to JPEG format.

    .DESCRIPTION
        Scans the input folder for HEIC files (typically from iPhone/iPad cameras)
        and converts each one to a high-quality JPEG, preserving EXIF orientation
        metadata. Output is written to a 'JPG' subfolder by default.

    .INPUTS
        [System.String] $InputFolder          = Folder containing .heic files. Defaults to current directory.
        [System.String] $OutputFolder         = Destination folder for converted JPGs. Defaults to InputFolder/JPG.
        [Switch]        $OverwriteOutputFolder = When specified, clears the output folder before processing.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails or no HEIC files are found.

    .EXAMPLE
        Convert-psHeicToJpg

    .EXAMPLE
        Convert-psHeicToJpg -InputFolder '/Volumes/iPhone/DCIM/100APPLE'

    .EXAMPLE
        Convert-psHeicToJpg -InputFolder '/Volumes/iPhone/DCIM' -OutputFolder '/Volumes/Photos/Converted' -OverwriteOutputFolder

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        EXIF metadata (date taken, GPS) is preserved. Orientation is corrected via -auto-orient.
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
            $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'JPG'
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

            $Files = Get-ChildItem -Path $InputFolder -Filter '*.heic' -File -ErrorAction SilentlyContinue

            if ($Files.Count -eq 0) {
                Write-Host 'No HEIC files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host "Converting $($Files.Count) HEIC file(s) to JPG:" -ForegroundColor Cyan

                foreach ($File in $Files) {
                    $Index++
                    try {
                        $OutputFile = Join-Path $OutputFolder ([System.IO.Path]::ChangeExtension($File.Name, '.jpg'))
                        magick $File.FullName -quality 92 -auto-orient $OutputFile
                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $(Split-Path $OutputFile -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'HEIC Conversion' -Rows @(
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
