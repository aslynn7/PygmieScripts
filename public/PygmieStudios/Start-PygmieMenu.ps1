function Show-PygmieMenu {
    Write-Host ''
    Write-Host '===================================' -ForegroundColor White
    Write-Host '        Pygmie Studios Menu       ' -ForegroundColor White
    if ( $Global:ProcessSubfolders ) {
        Write-Host '          (Subfolder Mode)          ' -ForegroundColor Gredd
    }
    else {
        Write-Host '        (Non Subfolder Mode)          ' -ForegroundColor Red
    }
    Write-Host '===================================' -ForegroundColor White
    Write-Host '1. Move images into date/time stamped folders' -ForegroundColor White
    Write-Host '2. Rename Files' -ForegroundColor White
    Write-Host '3. Move RAW files to Subfolders' -ForegroundColor White
    Write-Host '4. Cleanup Extraneous RAW/NEF Files' -ForegroundColor White
    Write-Host '5. Resize, Copyright, and Watermark Files' -ForegroundColor White
    Write-Host 'S. Switch between Current Folder and Subfolder Mode' -ForegroundColor White
    Write-Host 'Q. Quit' -ForegroundColor White
    Write-Host '-----------------------------------' -ForegroundColor White
}

function Start-PygmieMenu {
    do {
        Clear-Host

        Show-PygmieMenu

        $DoSomething = Read-Host 'Select an option (1, 2, 3, or Q)'

        switch ($DoSomething) {
            '1' {
                # Move images into date/time stamped folders
                Move-ImagesToTimeStampedFolders
            }
            '2' {
                # Rename Files
                $FilenamePrefix = Read-Host 'Enter the filename prefix (e.g., "Photos-")'
                if ( $Global:ProcessSubfolders ) {
                    $SubDirectories = Get-ChildItem -Directory
                    foreach ( $Dir in $SubDirectories.FullName ) {
                        Rename-PhotoFiles -InputFolder $Dir -FilenamePrefix $FilenamePrefix
                    }
                }
                else {
                    Rename-PhotoFiles -InputFolder $PWD -FilenamePrefix $FilenamePrefix
                }
            }
            '3' {
                # Move Raws files to Subfolders
                if ( $Global:ProcessSubfolders ) {
                    $SubDirectories = Get-ChildItem -Directory
                    foreach ( $Dir in $SubDirectories.FullName ) {
                        Move-RawFilesToSubfolders -InputFolder $Dir
                    }
                }
                else {
                    Move-RawFilesToSubfolders -InputFolder $PWD
                }
            }
            '4' {
                # Cleanup Extraneous RAW/NEF Files
                if ( $Global:ProcessSubfolders ) {
                    $SubDirectories = Get-ChildItem -Directory
                    foreach ( $Dir in $SubDirectories.FullName ) {
                        Cleanup-ExtraneousRAWFiles -InputFolder $Dir
                    }
                }
                else {
                    Cleanup-ExtraneousRAWFiles -InputFolder $PWD
                }
            }
            '5' {
                # Resize, Copyright, and Watermark Files
                if ( $Global:ProcessSubfolders ) {
                    $SubDirectories = Get-ChildItem -Directory
                    foreach ( $Dir in $SubDirectories.FullName ) {
                        Resize-SmallerizedImage -InputFolder $Dir -OverwriteOutputFolder

                        $SmallerizedFolder = Join-Path -Path $Dir -ChildPath 'Smallerized'
                        $WaterMarkedAndCopyrightedFolder = Join-Path -Path $Dir -ChildPath 'WatermarkedAndCopyrighted'
                        Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedFolder -OutputFolder $WaterMarkedAndCopyrightedFolder
                    }
                }
                else {
                    Resize-SmallerizedImage -InputFolder $PWD -OverwriteOutputFolder

                    $SmallerizedFolder = Join-Path -Path $PWD -ChildPath 'Smallerized'
                    $WaterMarkedAndCopyrightedFolder = Join-Path -Path $PWD -ChildPath 'WatermarkedAndCopyrighted'
                    Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedFolder -OutputFolder $WaterMarkedAndCopyrightedFolder
                }
            }
            'S' {
                if ( $Global:ProcessSubfolders ) {
                    $Global:ProcessSubfolders = $false
                    Write-Host 'Switched to Current Folder Mode' -ForegroundColor Cyan
                }
                else {
                    $Global:ProcessSubfolders = $true
                    Write-Host 'Switched to Subfolder Mode' -ForegroundColor Cyan
                }
                Start-Sleep -Seconds 2
            }
            'Q' {
                Write-Host 'Exiting the menu. Goodbye!' -ForegroundColor Yellow
            }
            default {
                Write-Host 'Exiting the menu. Goodbye!' -ForegroundColor Yellow
            }
        }

    } while ($DoSomething -ne 'Q')
}