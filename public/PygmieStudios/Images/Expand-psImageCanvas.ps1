function Expand-psImageCanvas {
    <#
    .SYNOPSIS
        Doubles the height of images by adding white space to the bottom.

    .DESCRIPTION
        Extends the canvas of every image file in the input folder to twice its original
        height, placing the original photo in the top half and leaving the bottom half
        white. Useful when scanning both front and back of photos: scan the front, run
        this to make room, then paste the back image into the bottom half before combining.
        Files are modified in-place.

    .INPUTS
        [System.String] $InputFolder = Folder containing image files. Defaults to current directory.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails.

    .EXAMPLE
        Expand-psImageCanvas

    .EXAMPLE
        Expand-psImageCanvas -InputFolder '/Volumes/Scans/BatchA'

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Files are edited in-place — the original is overwritten. Make a backup first if needed.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose "   InputFolder = $InputFolder"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $Files = @()
            $Files += foreach ($FileType in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                Get-ChildItem -Path $InputFolder -Filter $FileType -File -ErrorAction SilentlyContinue
            }

            $Index          = 0
            $countSucceeded = 0
            $countFailed    = 0

            if ($Files.Count -eq 0) {
                Write-Warning "No photos found in $InputFolder"
                $Result = $False
            }
            else {
                Write-Host ''
                Write-Host "Expanding canvas (2x height) for $($Files.Count) image(s):" -ForegroundColor Cyan

                foreach ($File in $Files) {
                    $Index++
                    try {
                        & magick $File.FullName -gravity north -background white -extent '%wx%[fx:2*h]' $File.FullName
                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Expand Canvas' -Rows @(
                    [pscustomobject]@{ Label = 'Images expanded'; Count = $countSucceeded; Color = 'Green' }
                    [pscustomobject]@{ Label = 'Images failed';   Count = $countFailed;    Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
