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
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $false

        Write-Host 'Calling ConvertTo-WatermarkedImage() with the following parameters:'

        Write-Host "   InputFolder  = $InputFolder"
        Write-Host "   OutputFolder = $OutputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            Push-Location

            $Pictures = Get-Item *.jpg
            $Pictures += Get-Item *.raw
            $Pictures += Get-Item *.nef
            $Pictures += Get-Item *.raf

            foreach ( $Picture in $Pictures ) {
                [System.String] $DateTaken = ([DateTime]$Picture.LastWriteTime ).ToString('MM-dd-yyyy')

                if ( -not ( Test-Path $DateTaken ) ) {
                    Write-Output "Creating folder $DateTaken"
                    New-Item -Path $DateTaken -ItemType Directory | Out-Null
                }

                Write-Output "Moving $($Picture.FullName) to $DateTaken"
                Move-Item -Path $Picture.FullName -Destination $DateTaken
            }

            Pop-Location

            $Result = $true
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