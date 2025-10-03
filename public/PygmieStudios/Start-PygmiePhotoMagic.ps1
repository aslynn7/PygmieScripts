function Start-PygmiePhotoMagic {
    <#
   .SYNOPSIS
      A wrapper.

   .DESCRIPTION
      A wrapper that shrinks, watermarks, copyrights, and sorts images.

   .INPUTS
        [System.String] $InputFolder = Folder where the input .jpg/.jpeg files are located.
        [System.String] $OutputFolder = Folder where the final output .jpg/.jpeg files are to be placed.
        [System.String] $FilenamePrefix = Prefix to use when renaming files.
        [System.String] $RawFolder = Folder where the RAW files are to be placed.
        [Switch] $OperateOnSubfolders = If set, will operate on subfolders of the InputFolder.
        [Switch] $DoSortToFolders = If set, will sort images into time-stamped folders.
        [Switch] $Cleanup = If set, will clean up intermediate folders.
        [Switch] $RenameFiles = If set, will rename files with the specified prefix.
        [Switch] $MoveRawFiles = If set, will move RAW files to the specified RawFolder.
        [Switch] $SmallerizeAndWatermark = If set, will smallerize and watermark images.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Start-PygmiePhotoMagic

   .EXAMPLE
      Start-PygmiePhotoMagic -Cleanup

   .EXAMPLE
      Start-PygmiePhotoMagic -DoSortToFolders -Cleanup

   .EXAMPLE
      Start-PygmiePhotoMagic -DoSortToFolders -Cleanup -RenameFiles -MoveRawFiles

   .EXAMPLE
      Start-PygmiePhotoMagic -DoSortToFolders -Cleanup -RenameFiles -MoveRawFiles -SmallerizeAndWatermark

   .EXAMPLE
      Start-PygmiePhotoMagic -InputFolder 'C:\Photos\ToProcess' -OutputFolder 'C:\Photos\Finals' -RawFolder 'C:\Photos\RAW' -DoSortToFolders -Cleanup -RenameFiles -MoveRawFiles -SmallerizeAndWatermark

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
        [System.String] $OutputFolder = $Null,

        [Parameter(Mandatory = $False)]
        [System.String] $FilenamePrefix = 'Photo-',

        [Parameter(Mandatory = $False)]
        [System.String] $RawFolder = $Null,

        [Switch] $OperateOnSubfolders,

        [Switch] $DoSortToFolders,

        [Switch] $Cleanup,

        [Switch] $RenameFiles,

        [Switch] $MoveRawFiles,

        [Switch] $SmallerizeAndWatermark
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Verbose 'Calling Start-PygmiePhotoMagic() with the following parameters:'

        if ( -not $OutputFolder ) {
            $OutputFolder = Join-Path -Path $PWD -ChildPath 'Finals'
        }

        if ( -not $RawFolder ) {
            $RawFolder = Join-Path -Path $PWD -ChildPath 'RAW'
        }

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
                    $Result = Start-PygmiePhotoMagic -OperateOnSubfolders:$false -Cleanup:$Cleanup -Verbose:$VerbosePreference -DoSortToFolders:$DoSortToFolders -RenameFiles:$RenameFiles -MoveRawFiles:$MoveRawFiles
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

                    if ( $MoveRawFiles ) {
                        Write-Host "Moving RAW files in $InputFolder to $InputFolder/RAW"
                        if (-not (Test-Path $RawFolder)) {
                            New-Item -Path $RawFolder -ItemType Directory | Out-Null
                        }

                        foreach ( $FileType in $Global:RawFileTypes ) {
                            Write-Verbose "Processing file type: $FileType"
                            Get-ChildItem -Path $InputFolder -Filter $FileType -File | ForEach-Object {
                                Move-Item -Path $_.FullName -Destination $RawFolder
                            }
                        }
                    }

                    if ( $CleanupExtraneousRAWFiles ) {
                        Write-Host "Cleaning up extraneous RAW files in $InputFolder"
                        Cleanup-ExtraneousRAWFiles -InputFolder $InputFolder $RawFolder -Verbose:$VerbosePreference
                    }

                    if ( $SmallerizeAndWatermark ) {
                        Read-Host 'Most of the magic has occurred and your RAW files have been sorted and cleaned up.  Press Enter to continue with smallerizing and watermarking images, or Ctrl-C to bail.'

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