function Export-psContactSheet {
    <#
    .SYNOPSIS
        Generates a contact sheet (thumbnail grid) from images in a folder.

    .DESCRIPTION
        Creates a single image containing thumbnail previews of all photos in the
        input folder, arranged in a grid. Each thumbnail is labeled with its filename.
        Useful for quickly reviewing a folder of photos without opening each file.
        Output is written to the input folder as 'ContactSheet.jpg' by default.

    .INPUTS
        [System.String] $InputFolder    = Folder containing source images. Defaults to current directory.
        [System.String] $OutputFile     = Output file path. Defaults to InputFolder/ContactSheet.jpg.
        [System.Int32]  $ThumbWidth     = Width of each thumbnail in pixels. Default is 200.
        [System.Int32]  $ThumbHeight    = Height of each thumbnail in pixels. Default is 200.
        [System.Int32]  $Columns        = Number of columns in the grid. Default is 5.
        [System.String] $BackgroundColor = Background color of the sheet. Default is '#1a1a1a'.

    .OUTPUTS
        [Bool] = $True on success, $False on failure or no images found.

    .EXAMPLE
        Export-psContactSheet

    .EXAMPLE
        Export-psContactSheet -InputFolder '/Volumes/Photos/Session1' -Columns 6 -ThumbWidth 240

    .EXAMPLE
        Export-psContactSheet -InputFolder '/Volumes/Photos/Session1' -OutputFile '/Desktop/preview.jpg'

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Large folders (500+ files) may take a minute to render. Thumbnail labels show filenames.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = '',

        [Parameter(Mandatory = $False)]
        [System.Int32] $ThumbWidth = 200,

        [Parameter(Mandatory = $False)]
        [System.Int32] $ThumbHeight = 200,

        [Parameter(Mandatory = $False)]
        [System.Int32] $Columns = 5,

        [Parameter(Mandatory = $False)]
        [System.String] $BackgroundColor = '#1a1a1a'
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        if ([System.String]::IsNullOrEmpty($OutputFile)) {
            $OutputFile = Join-Path $InputFolder 'ContactSheet.jpg'
        }

        Write-Verbose "   InputFolder     = $InputFolder"
        Write-Verbose "   OutputFile      = $OutputFile"
        Write-Verbose "   ThumbWidth      = $ThumbWidth"
        Write-Verbose "   ThumbHeight     = $ThumbHeight"
        Write-Verbose "   Columns         = $Columns"
        Write-Verbose "   BackgroundColor = $BackgroundColor"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }

            $Files = @()
            $Files += foreach ($Pattern in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            if ($Files.Count -eq 0) {
                Write-Host 'No image files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                Write-Host "Building contact sheet from $($Files.Count) image(s)..." -ForegroundColor Cyan
                Write-Host "  Grid     : ${Columns} columns  x  ${ThumbWidth}x${ThumbHeight}px thumbs" -ForegroundColor DarkGray
                Write-Host "  Output   : $OutputFile" -ForegroundColor DarkGray
                Write-Host ''

                $InputPaths = $Files | ForEach-Object { $_.FullName }

                & magick montage @InputPaths `
                    -geometry "${ThumbWidth}x${ThumbHeight}+4+4" `
                    -tile "${Columns}x" `
                    -background $BackgroundColor `
                    -fill white `
                    -font Courier `
                    -pointsize 11 `
                    -label '%f' `
                    $OutputFile

                if ($LASTEXITCODE -eq 0) {
                    $SizeKB = [Math]::Round((Get-Item $OutputFile).Length / 1KB)
                    Write-Host "Contact sheet saved: $OutputFile (${SizeKB} KB)" -ForegroundColor Green
                    Write-SummaryTable -Title 'Contact Sheet' -Rows @(
                        [pscustomobject]@{ Label = 'Images included'; Count = $Files.Count; Color = 'Green' }
                        [pscustomobject]@{ Label = 'Output size KB';  Count = $SizeKB;      Color = 'Cyan'  }
                    )
                }
                else {
                    throw "ImageMagick montage returned exit code $LASTEXITCODE"
                }
            }
        }
        catch {
            $Result = $False
            throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
