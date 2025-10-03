function Cleanup-ExtraneousRAWFiles {
    <#
   .SYNOPSIS
      xxx

   .DESCRIPTION
      xxx

   .INPUTS
        [System.String] $InputFolder = Folder where the compressed picture files are located.
        [System.String] $RawFolder = Folder where the RAW files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Cleanup-ExtraneousRAWFiles

   .EXAMPLE
      Cleanup-ExtraneousRAWFiles -OutputFolder "C:\SomeFolder\RAW"
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = $Null
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling Cleanup-ExtraneousRAWFiles() with the following parameters:'

        if ( -not $OutputFolder ) {
            $OutputFolder = Join-Path -Path $PWD -ChildPath 'RAW'
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {

            Write-Verbose "Collecting photo base names from: $InputFolder" -ForegroundColor Cyan

            $PhotoBaseNames = @()
            foreach ($pattern in $Global:LossyFileTypes) {
                Get-ChildItem -Path $InputFolder -Filter $pattern -File | ForEach-Object {
                    $PhotoBaseNames += $_.BaseName.ToLower()
                }
            }

            Write-Verbose "Found $($PhotoBaseNames.Count) processed photos." -ForegroundColor Cyan

            Write-Verbose "Scanning raw files in: $RawFolder" -ForegroundColor Cyan
            $RawFiles = @()
            foreach ($pattern in $Global:RawFileTypes) {
                $RawFiles += Get-ChildItem -Path $OutputFolder -Filter $pattern -File
            }

            $DeletedCount = 0
            $KeptCount = 0

            foreach ($file in $RawFiles) {
                $baseName = $file.BaseName.ToLower()

                if (-not ($PhotoBaseNames -contains $baseName)) {
                    Write-Verbose "No match for '$($file.Name)'. Deleting..." -ForegroundColor Yellow

                    if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove orphan raw file')) {
                        Remove-Item $file.FullName -Force
                        $DeletedCount++
                    }
                }
                else {
                    Write-Verbose "Keeping '$($file.Name)' (match found)." -ForegroundColor Green
                    $KeptCount++
                }
            }

            $Result = $Result -band $true
        }
        catch {
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