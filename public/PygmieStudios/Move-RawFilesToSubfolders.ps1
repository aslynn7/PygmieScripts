function Move-RawFilesToSubfolders {
    <#
   .SYNOPSIS
      Blah

   .DESCRIPTION
      Blah

   .INPUTS
        Blah

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Blah

   .NOTES
      Blah
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
        Write-Host "Moving RAW files in $InputFolder to $InputFolder/RAW" -ForegroundColor Cyan

        Write-Verbose "   InputFolder  = $InputFolder"

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
                    Move-Item -Path $_.FullName -Destination $RawFolder
                    Write-Host "  - Moved file: $($_.Name)" -ForegroundColor Green
                }
            }

            $Result = $True
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