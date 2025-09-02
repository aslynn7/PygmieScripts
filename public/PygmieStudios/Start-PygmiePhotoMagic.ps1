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

   .EXAMPLE
      C:\PS> Start-PygmiePhotoMagic -Cleanup

   .EXAMPLE
      C:\PS> Start-PygmiePhotoMagic -DoSortToFolders -Cleanup

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
        [System.String] $OutputFolder = "$PWD\YeahBaby",

        [Switch] $OperateOnSubfolders,

        [Switch] $DoSortToFolders,  # NOTE NOT WORKING YET

        [Switch] $Cleanup
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $false

        Write-Verbose 'Calling Start-PygmiePhotoMagic() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder  = $OutputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if ( -not (Test-Path $InputFolder) ) { throw "$InputFolder does not exist, bailing!" }

            if ( $OperateOnSubfolders ) {
                $Subfolders = Get-ChildItem -Path $InputFolder -Directory
                foreach ( $SubFolder in $Subfolders ) {
                    Write-Output "Processing subfolder: $($SubFolder.FullName)"
                    $SubfolderPath = Join-Path -Path $InputFolder -ChildPath $SubFolder.Name
                    Push-Location $SubfolderPath
                    Start-PygmiePhotoMagic -OperateOnSubfolders:$false -Cleanup:$Cleanup -Verbose:$VerbosePreference
                    Pop-Location
                }
            }
            else {
                $SmallerizedPath = Join-Path -Path $OutputFolder -ChildPath 'Smallerized'
                $WatermarkedPath = Join-Path -Path $OutputFolder -ChildPath 'Watermarked'

                Write-Output ''
                try {
                    $SmallerizedResults = Resize-SmallerizedImage -OutputFolder $SmallerizedPath -OverwriteOutputFolder -Verbose:$VerbosePreference
                }
                catch {
                    throw "Error encountered while resizing images: $($_.Exception.Message)"
                }

                if ( $SmallerizedResults ) {
                    try {
                        $WatermarkingResults = Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedPath -OutputFolder $WatermarkedPath -OverwriteOutputFolder -Verbose:$VerbosePreference
                    }
                    catch {
                        throw "Error encountered while watermarking images: $($_.Exception.Message)"
                    }
                
                    $Result = $True 

                    if ( $WatermarkingResults ) {
                        if ( $DoSortToFolders ) {
                            try {
                                $SortResult = Move-ImagesToTimeStampedFolders -InputFolder $WatermarkedPath -Verbose:$VerbosePreference
                                $Result = $Result -band $SortResult

                                $TimeStampedFolders = Get-ChildItem -Path $WatermarkedPath -Directory

                                foreach ( $Folder in $TimeStampedFolders ) {
                                    Move-Item -Path $Folder.FullName -Destination $OutputFolder -Force
                                }

                                if ( $Cleanup ) {
                                    Remove-Item -Path $OutputFolder\*.jpg -Recurse -Force
                                    Remove-Item -Path $OutputFolder\*.jpeg -Recurse -Force
                                }
                            }
                            catch {
                                $Result = $False
                                throw "Error encountered while moving images to time-stamped folders: $($_.Exception.Message)"
                            }
                        }
                        else {
                            $Files = Get-ChildItem -Path $WatermarkedPath\* -Include *.jpg, *.jpeg

                            foreach ( $File in $Files ) {
                                Move-Item -Path $File.FullName -Destination $OutputFolder -Force
                            }
                        }
                    }

                    if ( $Cleanup ) {
                        try {
                            if ( Test-Path $SmallerizedPath ) {
                                Write-Output "Cleaning up $SmallerizedPath"
                                Remove-Item -Path $SmallerizedPath -Recurse -Force
                            }
                            if ( Test-Path $WatermarkedPath ) {
                                Write-Output "Cleaning up $WatermarkedPath"
                                Remove-Item -Path $WatermarkedPath -Recurse -Force
                            }
                        }
                        catch {
                            Write-Output "Error encountered while cleaning up: $($_.Exception.Message)"
                            $Result = $false
                        }
                    }
                }
            }
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