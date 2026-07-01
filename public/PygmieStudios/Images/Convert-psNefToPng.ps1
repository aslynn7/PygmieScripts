function Convert-psNefToPng {
    <#
    .SYNOPSIS
        Converts Nikon RAW (.nef) files to lossless 16-bit PNG images.

    .DESCRIPTION
        Finds all .nef files in the source folder (optionally recursing into subfolders)
        and converts each to a full-resolution 16-bit PNG using ImageMagick. The sRGB
        colorspace and -auto-orient flags are applied to ensure correct color rendering
        and camera orientation. The relative subfolder structure is preserved in the output.

    .INPUTS
        [System.String] $SourceFolder = Folder containing .nef files. Defaults to current directory.
        [System.String] $OutputFolder = Destination folder for PNG files. Defaults to SourceFolder.
        [Switch]        $Recurse      = When specified, scans subfolders recursively.

    .OUTPUTS
        [Bool] = $True on full success, $False if any conversion fails or no NEF files are found.

    .EXAMPLE
        Convert-psNefToPng -SourceFolder '/Volumes/Camera/DCIM'

    .EXAMPLE
        Convert-psNefToPng -SourceFolder '/Volumes/Camera/DCIM' -OutputFolder '/Volumes/Photos/PNG' -Recurse

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Output uses PNG48 (16-bit RGB) for maximum tonal data retention.
        No resize is applied — output is full native resolution.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [string] $SourceFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [string] $OutputFolder = '',

        [switch] $Recurse
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        if ([System.String]::IsNullOrEmpty($OutputFolder)) {
            $OutputFolder = $SourceFolder
        }

        $SourceFolder = (Resolve-Path -LiteralPath $SourceFolder).Path

        if (-not (Test-Path -LiteralPath $SourceFolder)) {
            throw "Source folder does not exist: $SourceFolder"
        }

        if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
            throw "ImageMagick 'magick' command was not found in PATH."
        }

        if (-not (Test-Path -LiteralPath $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }

        $OutputFolder = (Resolve-Path -LiteralPath $OutputFolder).Path

        Write-Verbose "   SourceFolder = $SourceFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"
        Write-Verbose "   Recurse      = $Recurse"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $searchParams = @{
                LiteralPath = $SourceFolder
                Filter      = '*.nef'
                File        = $true
            }
            if ($Recurse) { $searchParams.Recurse = $true }

            $NefFiles = Get-ChildItem @searchParams | Sort-Object FullName

            if (-not $NefFiles) {
                Write-Host "No .nef files found in: $SourceFolder" -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $Total          = $NefFiles.Count
                $Index          = 0
                $countSucceeded = 0
                $countFailed    = 0

                Write-Host "Converting $Total NEF file(s) to PNG:" -ForegroundColor Cyan

                foreach ($Nef in $NefFiles) {
                    $Index++

                    $RelativeParent = [System.IO.Path]::GetRelativePath($SourceFolder, $Nef.DirectoryName)
                    $TargetDir      = if ($RelativeParent -eq '.') { $OutputFolder } else { Join-Path $OutputFolder $RelativeParent }

                    if (-not (Test-Path -LiteralPath $TargetDir)) {
                        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
                    }

                    $PngPath = Join-Path $TargetDir ($Nef.BaseName + '.png')

                    Write-Progress -Activity 'Converting NEF to PNG' -Status "$Index of $Total — $($Nef.Name)" -PercentComplete (($Index / $Total) * 100)

                    try {
                        & magick $Nef.FullName -auto-orient -colorspace sRGB -depth 16 "PNG48:$PngPath"

                        if ($LASTEXITCODE -ne 0) { throw "magick returned exit code $LASTEXITCODE" }
                        $countSucceeded++
                        Write-Host "[$Index/$Total] $($Nef.Name) -> $(Split-Path $PngPath -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$Total] FAILED: $($Nef.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-Progress -Activity 'Converting NEF to PNG' -Completed

                Write-SummaryTable -Title 'NEF to PNG' -Rows @(
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
