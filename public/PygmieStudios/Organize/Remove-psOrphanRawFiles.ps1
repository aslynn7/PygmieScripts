function Remove-psOrphanRawFiles {
    <#
    .SYNOPSIS
        Deletes RAW files from the RAW subfolder that have no matching lossy counterpart.

    .DESCRIPTION
        Scans the input folder for lossy (JPG/JPEG) files, then checks the 'RAW'
        subfolder for any RAW/lossless files whose base name does not match any
        lossy file. Orphaned RAW files are deleted. This is useful after culling
        photos: delete the bad JPEGs, then run this to clean up their RAW pairs.

    .INPUTS
        [System.String] $InputFolder = Folder containing the lossy files and the 'RAW' subfolder. Defaults to current directory.

    .OUTPUTS
        [Bool] = $True on full success, $False on error.

    .EXAMPLE
        Remove-psOrphanRawFiles

    .EXAMPLE
        Remove-psOrphanRawFiles -InputFolder '/Volumes/Photos/Session1'

    .NOTES
        Expects RAW files to live in a 'RAW' subfolder within $InputFolder.
        Comparison is case-insensitive on the base filename.
        Will warn and skip gracefully if the RAW subfolder does not exist.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $false)]
        [string] $InputFolder = $PWD
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Host ''
        Write-Host "Scanning for orphan RAW files in: $InputFolder" -ForegroundColor Cyan

        Write-Verbose "   InputFolder = $InputFolder"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $PhotoBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($Pattern in $Global:LossyFileTypes) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $null = $PhotoBaseNames.Add($_.BaseName)
                }
            }

            Write-Verbose "Found $($PhotoBaseNames.Count) lossy file base name(s) in $InputFolder"

            $RawFolder = Join-Path -Path $InputFolder -ChildPath 'RAW'

            if (-not (Test-Path -LiteralPath $RawFolder)) {
                Write-Warning "RAW subfolder not found: $RawFolder — nothing to clean."
            }
            else {
                $RawFiles = @()
                foreach ($Pattern in $Global:RawFileTypes) {
                    $RawFiles += Get-ChildItem -Path $RawFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
                }

                Write-Verbose "Found $($RawFiles.Count) RAW file(s) to evaluate"

                $countDeleted = 0
                $countKept    = 0

                foreach ($File in $RawFiles) {
                    if (-not $PhotoBaseNames.Contains($File.BaseName)) {
                        Write-Host "  Deleting orphan: $($File.Name)" -ForegroundColor Yellow
                        Remove-Item $File.FullName -Force
                        $countDeleted++
                    }
                    else {
                        Write-Verbose "  Keeping: $($File.Name)"
                        $countKept++
                    }
                }

                Write-SummaryTable -Title 'Orphan RAW Cleanup' -Rows @(
                    [pscustomobject]@{ Label = 'RAW files kept';    Count = $countKept;    Color = 'Cyan'   }
                    [pscustomobject]@{ Label = 'Orphans deleted';   Count = $countDeleted; Color = if ($countDeleted -gt 0) { 'Yellow' } else { 'Cyan' } }
                )
            }
        }
        catch {
            $Result = $False
            Write-Error "An error occurred: $_"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
