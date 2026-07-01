function Compress-psImage {
    <#
    .SYNOPSIS
        Compresses image files to fit within a maximum file size in KB.

    .DESCRIPTION
        Processes all lossy (JPG/JPEG) and RAW image files in the input folder,
        using ImageMagick to compress each one to under the specified size limit.
        RAW files are converted to JPG during compression. Output is written to
        a 'Smallerized' subfolder by default, preserving original files untouched.

    .INPUTS
        [System.String] $InputFolder          = Source folder containing image files. Defaults to current directory.
        [System.String] $OutputFolder         = Destination folder for compressed files. Defaults to InputFolder/Smallerized.
        [System.Int16]  $MaxSizeKB            = Maximum output file size in kilobytes. Default is 2000 KB.
        [Switch]        $OverwriteOutputFolder = When specified, clears the output folder before processing.

    .OUTPUTS
        [Bool] = $True on full success, $False if any file fails or no files are found.

    .EXAMPLE
        Compress-psImage

    .EXAMPLE
        Compress-psImage -InputFolder '/Volumes/Photos/Session1' -MaxSizeKB 1500

    .EXAMPLE
        Compress-psImage -InputFolder '/Volumes/Photos/Session1' -OutputFolder '/Volumes/Web/Export' -MaxSizeKB 800 -OverwriteOutputFolder

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Uses the 'jpeg:extent' define to target a specific file size ceiling.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = '',

        [Parameter(Mandatory = $False)]
        [System.Int16] $MaxSizeKB = 2000,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        if ([System.String]::IsNullOrEmpty($OutputFolder)) {
            $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'Smallerized'
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"
        Write-Verbose "   MaxSizeKB    = $MaxSizeKB"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }

            if (-not (Test-Path $OutputFolder)) {
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }
            elseif ($OverwriteOutputFolder) {
                Write-Verbose "Overwriting existing output folder: $OutputFolder"
                Remove-Item $OutputFolder -Recurse -Force | Out-Null
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
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
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host "Compressing $($Files.Count) image(s) to max ${MaxSizeKB} KB:" -ForegroundColor Cyan

                foreach ($File in $Files) {
                    $Index++
                    try {
                        $OutputName = [System.IO.Path]::ChangeExtension($File.Name, '.jpg')
                        $OutputFile = Join-Path $OutputFolder $OutputName
                        magick $File.FullName -define jpeg:extent=${MaxSizeKB}KB $OutputFile
                        $countSucceeded++
                        Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $OutputName" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Compress Images' -Rows @(
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
