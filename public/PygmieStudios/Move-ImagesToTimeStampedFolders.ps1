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
      C:\PS> Move-ImagesToTimeStampedFolders
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = $PWD
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling ConvertTo-WatermarkedImage() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            Push-Location $InputFolder

            $Pictures = Get-Item ./*.jpg, *.jpeg, *.raw, *.nef

            $Index = 0

            Write-Host "Sorting $($Pictures.Count) images into date based subfolders:" -ForegroundColor White
            foreach ( $Picture in $Pictures ) {
                $Index++

                try {
                    Write-Host "$($Picture.LastWriteTime)"
                    [System.String] $DateTaken = ([DateTime]$Picture.LastWriteTime ).ToString('MM-dd-yyyy')

                    $WriteToFolder = Join-Path $OutputFolder -ChildPath $DateTaken 

                    if ( -not ( Test-Path $WriteToFolder ) ) {
                        New-Item -Path $WriteToFolder -ItemType Directory -Force | Out-Null
                    }

                    Move-Item -Path $Picture.FullName -Destination $WriteToFolder -Force
                    Write-Host "[$Index/$($Pictures.Count)] $($Picture.FullName) -> $($OutputFolder)/$DateTaken" -ForegroundColor Green
                }
                catch {
                    $Result = $False
                    Write-Host "[$Index/$($Pictures.Count)] $($Picture.FullName) -> $($OutputFolder)/$DateTaken" -ForegroundColor Red
                }
            }

            Pop-Location

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