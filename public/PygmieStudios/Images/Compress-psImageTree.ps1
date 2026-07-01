function Compress-psImageTree {
    <#
    .SYNOPSIS
        Recursively compresses JPG/JPEG images from a folder tree into a flat output folder.

    .DESCRIPTION
        Recursively scans the input folder for .jpg and .jpeg files, compresses each one
        with ImageMagick to fit within the specified KB limit, and writes the results to
        the output folder using sequential filenames in the format Smallerized-0001.jpg,
        Smallerized-0002.jpg, etc. The output is flat (no subdirectory structure preserved).

    .INPUTS
        [System.String] $InputFolder          = Root folder to scan recursively for JPG/JPEG files.
        [System.String] $OutputFolder         = Destination folder for compressed output files.
        [System.Int32]  $MaxSizeKB            = Target maximum size in KB for each output file. Default is 2000.
        [Switch]        $OverwriteOutputFolder = When specified, removes and recreates the output folder before processing.

    .OUTPUTS
        [Bool] = $True on success, $False if any files fail or no files are found.

    .EXAMPLE
        Compress-psImageTree -InputFolder '/Volumes/Photos/Archive' -OutputFolder '/Volumes/Photos/WebExport'

    .EXAMPLE
        Compress-psImageTree -InputFolder '/Volumes/Photos/Archive' -OutputFolder '/Volumes/Photos/WebExport' -MaxSizeKB 1000 -OverwriteOutputFolder

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Output filenames are sequential (Smallerized-0001.jpg etc.) — original names are not preserved.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $true)]
        [System.String] $InputFolder,

        [Parameter(Mandatory = $true)]
        [System.String] $OutputFolder,

        [Parameter(Mandatory = $false)]
        [System.Int32] $MaxSizeKB = 2000,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [bool] $Result = $true

        $InputFolder  = [System.IO.Path]::GetFullPath($InputFolder)
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

        Write-Verbose "   InputFolder           = $InputFolder"
        Write-Verbose "   OutputFolder          = $OutputFolder"
        Write-Verbose "   MaxSizeKB             = $MaxSizeKB"
        Write-Verbose "   OverwriteOutputFolder = $OverwriteOutputFolder"

        if (-not (Test-Path -LiteralPath $InputFolder)) {
            throw "Input folder does not exist: $InputFolder"
        }
        if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) {
            throw "Input path is not a folder: $InputFolder"
        }
        if ($InputFolder -eq $OutputFolder) {
            throw 'InputFolder and OutputFolder cannot be the same.'
        }

        $NormalizedInput  = $InputFolder.TrimEnd('\', '/')
        $NormalizedOutput = $OutputFolder.TrimEnd('\', '/')
        if ($NormalizedOutput.StartsWith($NormalizedInput + [System.IO.Path]::DirectorySeparatorChar)) {
            throw 'OutputFolder cannot be inside InputFolder.'
        }

        if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
            throw "ImageMagick 'magick' command was not found in PATH."
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (Test-Path -LiteralPath $OutputFolder) {
                if ($OverwriteOutputFolder) {
                    Write-Host "Overwriting output folder: $OutputFolder" -ForegroundColor Yellow
                    Remove-Item -LiteralPath $OutputFolder -Recurse -Force
                    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
                }
                else {
                    Write-Host "Using existing output folder: $OutputFolder" -ForegroundColor Cyan
                }
            }
            else {
                Write-Host "Creating output folder: $OutputFolder" -ForegroundColor Cyan
                New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
            }

            Write-Host "Scanning for JPG/JPEG files under: $InputFolder" -ForegroundColor Cyan

            $Files = Get-ChildItem -LiteralPath $InputFolder -File -Recurse -ErrorAction Stop |
                Where-Object { $_.Extension -imatch '^\.(jpg|jpeg)$' } |
                Sort-Object FullName

            if ($Files.Count -eq 0) {
                Write-Host 'No JPG/JPEG files found!' -ForegroundColor Yellow
                $Result = $false
            }
            else {
                Write-Host "Found $($Files.Count) JPG/JPEG file(s). Compressing to max ${MaxSizeKB} KB each." -ForegroundColor Cyan

                $WriteIndex     = 0
                $countSucceeded = 0
                $countFailed    = 0

                foreach ($File in $Files) {
                    $WriteIndex++
                    try {
                        $OutputName      = 'Smallerized-{0:D4}.jpg' -f $WriteIndex
                        $DestinationFile = Join-Path -Path $OutputFolder -ChildPath $OutputName

                        Write-Host "[$WriteIndex/$($Files.Count)] $($File.FullName)" -ForegroundColor DarkYellow
                        Write-Host "  -> $DestinationFile" -ForegroundColor Green

                        & magick $File.FullName -define jpeg:extent="${MaxSizeKB}KB" $DestinationFile

                        if ($LASTEXITCODE -ne 0) {
                            throw "ImageMagick returned exit code $LASTEXITCODE"
                        }
                        $countSucceeded++
                    }
                    catch {
                        $Result = $false
                        $countFailed++
                        Write-Host "[$WriteIndex/$($Files.Count)] FAILED: $($File.FullName)" -ForegroundColor Red
                        Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }

                Write-SummaryTable -Title 'Compress Tree' -Rows @(
                    [pscustomobject]@{ Label = 'Files compressed'; Count = $countSucceeded; Color = 'Green' }
                    [pscustomobject]@{ Label = 'Files failed';     Count = $countFailed;    Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
