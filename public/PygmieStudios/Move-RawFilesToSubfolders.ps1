function Move-RawFilesToSubfolders {
    <#
   .SYNOPSIS
      Moves any RAW/Lossless files to a 'RAW' subfolder within the specified folder.

   .DESCRIPTION
      Moves any RAW/Lossless files to a 'RAW' subfolder within the specified folder.

   .INPUTS
      [System.String] Path to the folder containing files to be moved. Defaults to the current working directory.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Move-RawFilesToSubfolders
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Host ''
        Write-Host "Moving RAW files in: $($InputFolder):" -ForegroundColor Cyan
        Write-Host "To: $InputFolder/RAW" -ForegroundColor Cyan

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $RawFolder = Join-Path -Path $InputFolder -ChildPath 'RAW'

            if (-not (Test-Path $RawFolder)) {
                New-Item -Path $RawFolder -ItemType Directory | Out-Null
            }

            foreach ( $FileType in $Global:RawFileTypes ) {
                Write-Verbose "Processing file type: $FileType"
                Get-ChildItem -Path $InputFolder -Filter $FileType -File | ForEach-Object {
                    try {
                        Move-Item -Path $_.FullName -Destination $RawFolder
                        Write-Host "  - Moved: $($_.Name)" -ForegroundColor Green
                        $Result = $Result -band $True
                    }
                    catch {
                        Write-Host "  - Move Failed: $($_.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        $Result = $false
                    }
                }
            }

            $Result = $Result -band $True
        }
        catch {
            $Result = $False
            throw $("Error encountered in [$($MyInvocation.MyCommand.Name)] - " + $_.Exception)
        }

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"

        return $Result

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'end' block"
    }
}