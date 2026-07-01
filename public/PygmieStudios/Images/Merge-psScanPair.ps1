function Merge-psScanPair {
    <#
    .SYNOPSIS
        Combines front/back scan image pairs into single stacked composites.

    .DESCRIPTION
        Processes images in the input folder in pairs (alphabetical/Finder sort order),
        treating each consecutive pair as a front scan and a back scan. Calls
        Merge-psScanPairForImage for each pair to produce a single composite image
        with the front on top and back on bottom. Unpaired last files are skipped.

    .INPUTS
        [System.String] $InputFolder = Folder containing alternating front/back scan images. Defaults to current directory.

    .OUTPUTS
        [Bool] = $True on full success, $False if any pair fails.

    .EXAMPLE
        Merge-psScanPair

    .EXAMPLE
        Merge-psScanPair -InputFolder '/Volumes/Scans/BatchA'

    .NOTES
        Requires ImageMagick. Install via: brew install imagemagick
        Supported formats: jpg, jpeg, png, tif, tiff
        Files are sorted using natural (numeric-aware) order matching macOS Finder sort.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $false)]
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
            $validExtensions = @('.jpg', '.jpeg', '.png', '.tif', '.tiff')

            $Files = Get-ChildItem -Path $InputFolder -File |
                Where-Object { $validExtensions -contains $_.Extension.ToLower() } |
                Sort-Object {
                    [regex]::Replace($_.Name, '\d+', { param($m) $m.Value.PadLeft(10, '0') }).ToLower()
                }

            if ($Files.Count -lt 2) {
                Write-Host 'Not enough image files in this folder to combine. Need at least 2.' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                $countPairs  = 0
                $countFailed = 0

                Write-Host "Found $($Files.Count) image files. Processing in pairs..." -ForegroundColor Cyan
                Write-Host ''

                for ($i = 0; $i -lt $Files.Count; $i += 2) {
                    if ($i -eq $Files.Count - 1) {
                        Write-Host "Skipping last file '$($Files[$i].Name)' (no pair available)" -ForegroundColor Yellow
                        break
                    }

                    $topImage    = $Files[$i].FullName
                    $bottomImage = $Files[$i + 1].FullName

                    Write-Host "[$i & $($i + 1)/$($Files.Count)] Combining:"
                    Write-Host "   Top    : $($Files[$i].Name)"
                    Write-Host "   Bottom : $($Files[$i + 1].Name)"

                    try {
                        Merge-psScanPairForImage -TopImagePath $topImage -BottomImagePath $bottomImage
                        $countPairs++
                        Write-Host "   Done" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "   FAILED: $($Files[$i].Name) + $($Files[$i + 1].Name) — $_" -ForegroundColor Red
                    }
                }

                Write-SummaryTable -Title 'Scan Pair Merge' -Rows @(
                    [pscustomobject]@{ Label = 'Pairs merged'; Count = $countPairs;  Color = 'Green' }
                    [pscustomobject]@{ Label = 'Pairs failed'; Count = $countFailed; Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
