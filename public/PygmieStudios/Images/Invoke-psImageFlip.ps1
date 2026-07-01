function Invoke-psImageFlip {
    <#
    .SYNOPSIS
        Creates horizontally flipped (mirrored) copies of photo files.

    .DESCRIPTION
        Produces a left-right flipped version of every image file in the input folder,
        writing results to a 'Mirrored' subfolder by default. Both lossy (JPG/JPEG) and
        RAW format files are processed. Uses ImageMagick's -flop operation.

    .INPUTS
        [System.String] $InputFolder          = Folder containing the photos to flip. Defaults to current directory.
        [System.String] $OutputFolder         = Destination folder for flipped files. Defaults to InputFolder/Mirrored.
        [Switch]        $OverwriteOutputFolder = When specified, clears the output folder before processing.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails or no images are found.

    .EXAMPLE
        Invoke-psImageFlip

    .EXAMPLE
        Invoke-psImageFlip -InputFolder '/Volumes/Photos/Session1'

    .EXAMPLE
        Invoke-psImageFlip -InputFolder '/Volumes/Photos/Session1' -OutputFolder '/Volumes/Photos/Flipped' -OverwriteOutputFolder

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        The -flop operation mirrors horizontally (left-right). For vertical flip use -flip.
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
            $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'Mirrored'
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
            $Files += foreach ($Pattern in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            if ($Files.Count -eq 0) {
                Write-Host 'No photo files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host "Flipping $($Files.Count) photo(s):" -ForegroundColor Cyan
                Write-Host "  From : $InputFolder" -ForegroundColor DarkGray
                Write-Host "  To   : $OutputFolder" -ForegroundColor DarkGray
                Write-Host ''

                foreach ($File in $Files) {
                    $Index++
                    try {
                        $OutputFile = Join-Path $OutputFolder $File.Name
                        magick $File.FullName -flop $OutputFile
                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $(Split-Path $OutputFile -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Image Flip' -Rows @(
                    [pscustomobject]@{ Label = 'Photos flipped'; Count = $countSucceeded; Color = 'Green' }
                    [pscustomobject]@{ Label = 'Photos failed';  Count = $countFailed;    Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
