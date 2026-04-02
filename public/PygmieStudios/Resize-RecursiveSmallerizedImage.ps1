function Resize-RecursiveSmallerizedImage {
    <#
    .SYNOPSIS
        Shrinks JPG/JPEG image files from an input folder tree into a flat output folder.

    .DESCRIPTION
        Recursively scans the input folder for .jpg and .jpeg files, smallerizes each one
        with ImageMagick, and writes the results to the output folder using sequential
        filenames in the format Smallerized-0001.jpg, Smallerized-0002.jpg, etc.

    .INPUTS
        [System.String] $InputFolder
            Folder where the source .jpg/.jpeg files are located.

        [System.String] $OutputFolder
            Folder where the smallerized output files will be written.

        [System.Int32] $MaxSizeKB
            Target maximum size in KB for each output file.

        [Switch] $OverwriteOutputFolder
            If specified, removes and recreates the output folder before processing.

    .OUTPUTS
        [Bool]
            $True on success, $False if one or more files fail or no files are found.

    .NOTES
        This function is intended for MacOS PowerShell 5.1 usage with ImageMagick installed.
        Ensure `magick` is available in PATH.
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
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [bool] $Result = $true

        $InputFolder = [System.IO.Path]::GetFullPath($InputFolder)
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

        Write-Verbose 'Calling Resize-RecursiveSmallerizedImage() with the following parameters:'
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

        $NormalizedInput = $InputFolder.TrimEnd('\', '/')
        $NormalizedOutput = $OutputFolder.TrimEnd('\', '/')

        if ($NormalizedOutput.StartsWith($NormalizedInput + [System.IO.Path]::DirectorySeparatorChar)) {
            throw 'OutputFolder cannot be inside InputFolder.'
        }

        $MagickCommand = Get-Command magick -ErrorAction SilentlyContinue
        if (-not $MagickCommand) {
            throw "ImageMagick 'magick' command was not found in PATH."
        }

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

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

            $Directories = New-Object System.Collections.Generic.List[System.String]
            $Directories.Add($InputFolder)

            try {
                Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse -ErrorAction Stop |
                Sort-Object FullName |
                ForEach-Object {
                    $Directories.Add($_.FullName)
                }
            }
            catch {
                throw "Failed while enumerating directories. $($_.Exception.Message)"
            }

            $Files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
            $DirIndex = 0
            $DirTotal = $Directories.Count

            foreach ($Directory in $Directories) {
                $DirIndex++

                Write-Host "[Scan folder $DirIndex/$DirTotal] Reading: $Directory" -ForegroundColor DarkCyan

                try {
                    $FoundFiles = Get-ChildItem -LiteralPath $Directory -File -ErrorAction Stop |
                    Where-Object { $_.Extension -match '^\.(jpg|jpeg)$' } |
                    Sort-Object FullName
                }
                catch {
                    $Result = $false
                    Write-Host "[Scan folder $DirIndex/$DirTotal] FAILED: $Directory" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                    continue
                }

                foreach ($FoundFile in $FoundFiles) {
                    $Files.Add($FoundFile)
                    Write-Host "[Discovered $($Files.Count)] $($FoundFile.FullName)" -ForegroundColor Gray
                }
            }

            if ($Files.Count -eq 0) {
                Write-Host 'No JPG/JPEG files found!' -ForegroundColor Yellow
                $Result = $false
            }
            else {
                Write-Host "Found $($Files.Count) JPG/JPEG file(s)." -ForegroundColor Cyan
                Write-Host "Beginning smallerization to: $OutputFolder" -ForegroundColor Cyan

                $WriteIndex = 0

                foreach ($File in $Files) {
                    $WriteIndex++

                    try {
                        $OutputName = 'Smallerized-{0:D4}.jpg' -f $WriteIndex
                        $DestinationFile = Join-Path -Path $OutputFolder -ChildPath $OutputName

                        Write-Host "[Write $WriteIndex/$($Files.Count)] Reading: $($File.FullName)" -ForegroundColor DarkYellow
                        Write-Host "[Write $WriteIndex/$($Files.Count)] Writing: $DestinationFile" -ForegroundColor Green

                        & magick $File.FullName -define jpeg:extent="$($MaxSizeKB)KB" $DestinationFile

                        if ($LASTEXITCODE -ne 0) {
                            throw "ImageMagick returned exit code $LASTEXITCODE"
                        }
                    }
                    catch {
                        $Result = $false
                        Write-Host "[Write $WriteIndex/$($Files.Count)] FAILED: $($File.FullName)" -ForegroundColor Red
                        Write-Host $_.Exception.Message -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
        }

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}


Resize-RecursiveSmallerizedImage `
    -InputFolder '/Volumes/mine/Media Server/Pictures/PygmieStudios/2025' `
    -OutputFolder '/Volumes/Frame/' `
    -MaxSizeKB 2000 