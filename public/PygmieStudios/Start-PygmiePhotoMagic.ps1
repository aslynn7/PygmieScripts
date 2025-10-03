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

   .EXAMPLE
      C:\PS> Start-PygmiePhotoMagic -DoSortToFolders -Cleanup -RenameFiles -MoveRawFiles

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
        [System.String] $OutputFolder = "$PWD\Finals",

        [Parameter(Mandatory = $False)]
        [System.String] $FilenamePrefix = 'Photo-',

        [Switch] $OperateOnSubfolders,

        [Switch] $DoSortToFolders,  # For this we want to check if there are any subfolders present already, if so bail with warning

        [Switch] $Cleanup,

        [Switch] $RenameFiles,

        [Switch] $MoveRawFiles
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

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
                    Write-Host "Processing subfolder: $($SubFolder.FullName)"
                    $SubfolderPath = Join-Path -Path $InputFolder -ChildPath $SubFolder.Name

                    Push-Location $SubfolderPath
                    $Result = Start-PygmiePhotoMagic -OperateOnSubfolders:$false -Cleanup:$Cleanup -Verbose:$VerbosePreference -DoSortToFolders:$DoSortToFolders
                    Pop-Location
                }
            }
            else {
                $SmallerizedPath = Join-Path -Path $OutputFolder -ChildPath 'Smallerized'
                $WatermarkedPath = Join-Path -Path $OutputFolder -ChildPath 'Watermarked'

                Write-Host ''

                if ( $DoSortToFolders ) {
                    try {
                        $SortResults = Move-ImagesToTimeStampedFolders -Verbose:$VerbosePreference
                        $Result = $Result -band $SortResults
                    }
                    catch {
                        throw "Error encountered while moving images to time-stamped folders: $($_.Exception.Message)"
                    }

                    if ( $SortResults ) {
                        try {
                            $MagicResult = Start-PygmiePhotoMagic -OperateOnSubfolders:$true -Cleanup:$Cleanup -Verbose:$VerbosePreference
                            $Result = $Result -band $MagicResult
                        }
                        catch {
                            throw "Error encountered while calling Start-PygmiePhotoMagic on the sorted folders: $($_.Exception.Message)"
                        }
                    }
                }
                else {
                    if ( $RenameFiles ) {
                        Write-Host "Renaming files in $InputFolder with prefix $FilenamePrefix"
                        Rename-PhotoFiles -InputFolder $InputFolder -FilenamePrefix $FilenamePrefix -Verbose:$VerbosePreference
                    }
                    else {
                        Write-Host "Not renaming files in $InputFolder"
                    }

                    if ( $MoveRawFiles ) {
                        Write-Host "Moving RAW files in $InputFolder to $InputFolder\RAW"
                        $RawFolder = Join-Path -Path $InputFolder -ChildPath 'RAW'
                        if (-not (Test-Path $RawFolder)) {
                            New-Item -Path $RawFolder -ItemType Directory | Out-Null
                        }
                        Get-ChildItem -Path $InputFolder -Filter *.NEF -File | ForEach-Object {
                            Move-Item -Path $_.FullName -Destination $RawFolder
                        }
                        Get-ChildItem -Path $InputFolder -Filter *.RAW -File | ForEach-Object {
                            Move-Item -Path $_.FullName -Destination $RawFolder
                        }
                    }

                    try {
                        $SmallerizedResults = Resize-SmallerizedImage -OutputFolder $SmallerizedPath -OverwriteOutputFolder -Verbose:$VerbosePreference
                        $Result = $Result -band $SmallerizedResults
                    }
                    catch {
                        throw "Error encountered while resizing images: $($_.Exception.Message)"
                    }

                    if ( $SmallerizedResults ) {
                        try {
                            $WatermarkingResults = Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedPath -OutputFolder $WatermarkedPath -OverwriteOutputFolder -Verbose:$VerbosePreference
                            $Result = $Result -band $WatermarkingResults
                        }
                        catch {
                            throw "Error encountered while watermarking images: $($_.Exception.Message)"
                        }

                        Copy-Item $WatermarkedPath\* $OutputFolder | Out-Null

                        if ( $Cleanup ) {
                            try {
                                if ( Test-Path $SmallerizedPath ) {
                                    Write-Host "Cleaning up $SmallerizedPath"
                                    Remove-Item -Path $SmallerizedPath -Recurse -Force | Out-Null
                                }
                                if ( Test-Path $WatermarkedPath ) {
                                    Write-Host "Cleaning up $WatermarkedPath"
                                    Remove-Item -Path $WatermarkedPath -Recurse -Force | Out-Null
                                }
                            }
                            catch {
                                Write-Host "Error encountered while cleaning up: $($_.Exception.Message)"
                                $Result = $false
                            }
                        }
                    }
                }
            }
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