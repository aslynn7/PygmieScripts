function Move-psImagesByDate {
    <#
    .SYNOPSIS
        Sorts image files into subfolders named by their last-modified date.

    .DESCRIPTION
        Scans the input folder for all image files (lossy and RAW) and moves each
        one into a subfolder named by its LastWriteTime date in MM-dd-yyyy format.
        Existing subfolders are used if already present; new ones are created as needed.

    .INPUTS
        [System.String] $InputFolder = Folder containing image files to organize. Defaults to current directory.

    .OUTPUTS
        [Bool] = $True on full success, $False if any move fails.

    .EXAMPLE
        Move-psImagesByDate

    .EXAMPLE
        Move-psImagesByDate -InputFolder '/Volumes/Camera/DCIM'

    .NOTES
        Files are sorted by LastWriteTime, newest first before moving.
        Destination subfolder format: MM-dd-yyyy (e.g. 06-14-2025)
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

            $Files = $Files | Sort-Object -Property LastWriteTime -Descending

            $Index          = 0
            $countMoved     = 0
            $countFailed    = 0

            if ($Files.Count -eq 0) {
                Write-Warning "No image files found in input folder: $InputFolder"
            }
            else {
                Write-Host ''
                Write-Host "Organizing $($Files.Count) images by date from: $InputFolder" -ForegroundColor Cyan

                $TargetFoldersSeen = @()

                foreach ($File in $Files) {
                    $Index++
                    try {
                        [string]$DateTaken    = ([DateTime]$File.LastWriteTime).ToString('MM-dd-yyyy')
                        $WriteToFolder        = Join-Path $InputFolder $DateTaken

                        if ($TargetFoldersSeen -notcontains $WriteToFolder) {
                            Write-Host "  -> $WriteToFolder" -ForegroundColor Cyan
                            $TargetFoldersSeen += $WriteToFolder
                        }

                        if (-not (Test-Path $WriteToFolder)) {
                            New-Item -Path $WriteToFolder -ItemType Directory -Force | Out-Null
                        }

                        Move-Item -Path $File.FullName -Destination $WriteToFolder -Force
                        $countMoved++
                        Write-Host "  [$Index/$($Files.Count)] $($File.Name)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "  [$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Move by Date' -Rows @(
                    [pscustomobject]@{ Label = 'Files moved';   Count = $countMoved;   Color = 'Green' }
                    [pscustomobject]@{ Label = 'Files failed';  Count = $countFailed;  Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
