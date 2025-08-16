function Start-PygmiePhotoMagic {
    <#
   .SYNOPSIS
      A wrapper.

   .DESCRIPTION
      A wrapper that shrinks, watermarks, copyrights, and sorts images.

   .INPUTS
        [System.String] $InputFolder = Folder where the input .jpg/.jpeg files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      C:\PS> Start-PygmiePhotoMagic

   .NOTES
      This function calls functions that only work on MacOS.  Requires installation of ImageMagick and ExifTool.
      Ensure that the they're both in your PATH.
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

        [Bool] $Result = $false

        Write-Host 'Calling Start-PygmiePhotoMagic() with the following parameters:'

        Write-Host "   InputFolder  = $InputFolder"
        Write-Host "   OutputFolder  = $OutputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $SmallerizedPath = Path-Join -Path $InputFolder -ChildPath 'Smallerized'
            $WatermarkedPath = Path-Join -Path $InputFolder -ChildPath 'Watermarked'

            Resize-SmallerizedImage -OutputFolder $SmallerizedPath -OverwriteOutputFolder
            Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedPath -OutputFolder $WatermarkedPath -OverwriteOutputFolder
            Move-ImagesToTimeStampedFolders -InputFolder $WatermarkedPath

            $TimeStampedFolders = Get-ChildItem -Path $WatermarkedPath -Directory

            foreach ( $Folder in $TimeStampedFolders ) {
                Move-Item -Path $Folder.FullName -Destination $OutputFolder
            }

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