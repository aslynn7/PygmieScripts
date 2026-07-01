function Backup-psExifData {
    <#
    .SYNOPSIS
        Exports EXIF metadata from all images in a folder to a JSON sidecar file.

    .DESCRIPTION
        Uses ExifTool to read all metadata fields from every image file in the input
        folder (optionally recursing into subfolders) and writes the results as a
        structured JSON file. Useful as a safety net before batch operations that
        might modify or strip metadata, and as a searchable record of your photo
        library's technical data.

    .INPUTS
        [System.String] $InputFolder = Folder containing image files. Defaults to current directory.
        [System.String] $OutputFile  = Path for the output JSON file. Defaults to InputFolder/ExifBackup.json.
        [Switch]        $Recurse     = When specified, includes images in all subfolders.

    .OUTPUTS
        [Bool] = $True on success, $False on failure.

    .EXAMPLE
        Backup-psExifData

    .EXAMPLE
        Backup-psExifData -InputFolder '/Volumes/Photos/Session1'

    .EXAMPLE
        Backup-psExifData -InputFolder '/Volumes/Photos/Archive' -OutputFile '/Volumes/Backups/archive_exif.json' -Recurse

    .NOTES
        Requires ExifTool. Install via: brew install exiftool
        The output JSON is an array of objects, one per image, with all available metadata fields.
        File size can be large for big folders — 1000 images ~ 5-15 MB depending on metadata richness.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = '',

        [Switch] $Recurse
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        if ([System.String]::IsNullOrEmpty($OutputFile)) {
            $Timestamp  = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
            $OutputFile = Join-Path $InputFolder "ExifBackup_$Timestamp.json"
        }

        Write-Verbose "   InputFolder = $InputFolder"
        Write-Verbose "   OutputFile  = $OutputFile"
        Write-Verbose "   Recurse     = $Recurse"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }

            if (-not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
                throw "ExifTool not found in PATH. Install via: brew install exiftool"
            }

            Write-Host "Backing up EXIF metadata from: $InputFolder" -ForegroundColor Cyan
            Write-Host "Output: $OutputFile" -ForegroundColor DarkGray
            Write-Host ''

            $exifArgs = @('-json', '-a', '-G1')
            if ($Recurse) { $exifArgs += '-r' }
            $exifArgs += $InputFolder

            $jsonOutput = & exiftool @exifArgs

            if ($LASTEXITCODE -ne 0) {
                throw "ExifTool returned exit code $LASTEXITCODE"
            }

            $jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8

            $SizeKB    = [Math]::Round((Get-Item $OutputFile).Length / 1KB)
            $ImageCount = ($jsonOutput | ConvertFrom-Json).Count

            Write-Host "EXIF backup saved: $OutputFile" -ForegroundColor Green
            Write-SummaryTable -Title 'EXIF Backup' -Rows @(
                [pscustomobject]@{ Label = 'Images backed up'; Count = $ImageCount; Color = 'Green' }
                [pscustomobject]@{ Label = 'Output size KB';   Count = $SizeKB;    Color = 'Cyan'  }
            )
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
