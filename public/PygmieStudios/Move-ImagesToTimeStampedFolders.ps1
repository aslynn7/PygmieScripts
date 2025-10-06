function Move-ImagesToTimeStampedFolders {
    <#
   .SYNOPSIS
      Sorts iages into named folders by creation date.

   .DESCRIPTION
      Sorts iages into named folders by creation date.

   .INPUTS
        [System.String] $InputFolder = Folder where the input .jpg/.jpeg, .raw, .nef, and .raf files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Move-ImagesToTimeStampedFolders
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling Move-ImagesToTimeStampedFolders() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $Patterns = $Global:LossyFileTypes + $Global:RawFileTypes

            $Pictures = foreach ( $Pattern in $Patterns ) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            $Index = 0

            if ( -not $Pictures ) {
                Write-Warning "No pictures found in $InputFolder"
            }
            else {
                Write-Host ''
                Write-Host "Sorting $($Pictures.Count) images into date based subfolders:" -ForegroundColor Cyan

                foreach ( $Picture in $Pictures ) {
                    $Index++

                    try {
                        [System.String] $DateTaken = ([DateTime]$Picture.LastWriteTime ).ToString('MM-dd-yyyy')

                        $WriteToFolder = Join-Path $InputFolder -ChildPath $DateTaken

                        if ( -not ( Test-Path $WriteToFolder ) ) {
                            New-Item -Path $WriteToFolder -ItemType Directory -Force | Out-Null
                        }

                        Move-Item -Path $Picture.FullName -Destination $WriteToFolder -Force
                        Write-Host "[$Index/$($Pictures.Count)] Moving $($Picture.FullName) -> $($InputFolder)/$DateTaken" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        Write-Host "[$Index/$($Pictures.Count)] Failed Move $($Picture.FullName) -> $($InputFolder)/$DateTaken" -ForegroundColor Red
                    }
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