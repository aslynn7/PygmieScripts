function Cleanup-ExtraneousRAWFiles {
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $false)]
        [string] $InputFolder = $PWD
    )

    begin {
        $Result = $False

        Write-Host ''
        Write-Host "Starting Cleanup-ExtraneousRAWFiles in folder: $InputFolder" -ForegroundColor Cyan

        Write-Verbose "InputFolder = $InputFolder"
    }

    process {
        try {
            $PhotoBaseNames = @()
            foreach ($pattern in $Global:LossyFileTypes) {
                Get-ChildItem -Path $InputFolder -Filter $pattern -File | ForEach-Object {
                    $PhotoBaseNames += $_.BaseName.ToLower()
                }
            }

            $RawFolder = Join-Path -Path $InputFolder -ChildPath 'RAW'

            $RawFiles = @()
            foreach ($pattern in $Global:RawFileTypes) {
                $RawFiles += Get-ChildItem -Path $RawFolder -Filter $pattern -File
            }

            foreach ($file in $RawFiles) {
                $baseName = $file.BaseName.ToLower()

                if (-not ($PhotoBaseNames -contains $baseName)) {
                    Write-Host " - Deleting orphan RAW: $($file.Name)" -ForegroundColor Yellow
                    Remove-Item $file.FullName -Force
                }
                else {
                    Write-Verbose "Keeping RAW: $($file.Name)"
                }
            }

            $Result = $true
        }
        catch {
            Write-Error "An error occurred: $_"
            $Result = $False 
        }
    }

    end {
        return $Result
    }
}