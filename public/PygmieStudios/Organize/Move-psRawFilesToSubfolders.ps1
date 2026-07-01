function Move-psRawFilesToSubfolders {
    <#
    .SYNOPSIS
        Moves RAW/lossless image files to a 'RAW' subfolder.

    .DESCRIPTION
        Scans the input folder for all RAW and lossless image file types and moves
        them into a 'RAW' subfolder within the same folder. The subfolder is created
        if it does not already exist. Useful for organizing a folder after import,
        keeping RAW files separate from lossy exports.

    .INPUTS
        [System.String] $InputFolder = Folder containing RAW files to move. Defaults to current directory.

    .OUTPUTS
        [Bool] = $True on full success, $False if any move fails.

    .EXAMPLE
        Move-psRawFilesToSubfolders

    .EXAMPLE
        Move-psRawFilesToSubfolders -InputFolder '/Volumes/Camera/DCIM'

    .NOTES
        RAW file types are defined in $Global:RawFileTypes (png, raw, nef, bmp, cr2, tif, tiff).
        Files are not renamed; they are moved as-is into the RAW subfolder.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Host ''
        Write-Host "Moving RAW files in: $InputFolder" -ForegroundColor Cyan
        Write-Host "To: $InputFolder/RAW" -ForegroundColor Cyan

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $RawFolder = Join-Path -Path $InputFolder -ChildPath 'RAW'

            if (-not (Test-Path $RawFolder)) {
                New-Item -Path $RawFolder -ItemType Directory | Out-Null
            }

            $countMoved  = 0
            $countFailed = 0

            foreach ($FileType in $Global:RawFileTypes) {
                $RawFiles = Get-ChildItem -Path $InputFolder -Filter $FileType -File
                foreach ($File in $RawFiles) {
                    try {
                        Move-Item -Path $File.FullName -Destination $RawFolder
                        $countMoved++
                        Write-Host "  Moved: $($File.Name)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $false
                        $countFailed++
                        Write-Host "  FAILED: $($File.Name) — $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            Write-SummaryTable -Title 'RAW to Subfolder' -Rows @(
                [pscustomobject]@{ Label = 'Files moved';  Count = $countMoved;  Color = 'Green' }
                [pscustomobject]@{ Label = 'Files failed'; Count = $countFailed; Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
