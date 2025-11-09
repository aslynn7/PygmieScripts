function Show-PygmieMenu {
    Write-Host ''
    Write-Host '===================================' -ForegroundColor White
    Write-Host '        Pygmie Studios Menu       ' -ForegroundColor White
    Write-Host ''
    if ( $Global:ProcessSubfolders ) {
        Write-Host '          (Subfolder Mode)          ' -ForegroundColor Green
    }
    else {
        Write-Host '        (Non Subfolder Mode)          ' -ForegroundColor Red
    }
    Write-Host ''
    Write-Host " PWD = $PWD" -ForegroundColor Cyan
    if ( $Global:LastCommandResults ) {
        Write-Host ''
        Write-Host " Last Command Results: $Global:LastCommandResults" -ForegroundColor Green
        Write-Host ''
    }
    Write-Host '===================================' -ForegroundColor White
    Write-Host '  1. Move images to date/time stamped folders' -ForegroundColor White
    Write-Host '  2. Rename Files' -ForegroundColor White
    Write-Host '  3. Move RAW files to Subfolders' -ForegroundColor White
    Write-Host '  4. Cleanup Extraneous RAW/NEF Files' -ForegroundColor White
    Write-Host '  5. Resize, Copyright, and Watermark Files' -ForegroundColor White
    Write-Host '  6. Add White Space to Bottoms of Images' -ForegroundColor White
    Write-Host '  7. Start Negative to Positive Conversion' -ForegroundColor White
    Write-Host '  8. Combine Front and Back Scans' -ForegroundColor White
    Write-Host ''
    Write-Host '  9. Smallerize .mp4 file' -ForegroundColor White
    Write-Host ' 10. Convert MP4 file to MP3 file' -ForegroundColor White
    Write-Host ''
    Write-Host '  S. Switch between Current Folder and Subfolder Mode' -ForegroundColor White
    Write-Host ''
    Write-Host 'All = Run All Steps I normally Run (1 - 5)' -ForegroundColor White
    Write-Host ''
    Write-Host ' Q/[Enter] = Quit' -ForegroundColor White
    Write-Host '===================================' -ForegroundColor White
}

function Start-1 {
    # Move images to date/time stamped folders
    foreach ( $Dir in $Global:Directories ) {
        $Results = Move-ImagesToTimeStampedFolders -InputFolder $Dir
    }

    $Global:LastCommandResults = "Moved images to date/time stamped folders = $Results"
}

function Start-2 {
    # Rename Files
    Write-Host ''
    $UseFolderNamePrefixing = Read-Host 'User folder names as file prefixes? (Y/N [Enter]=Y)'

    if ( $UseFolderNamePrefixing -eq 'n' ) {
        Write-Host ''
        $FilenamePrefix = Read-Host 'Enter a filename prefix to use ([Enter] = "Photo-")'
    }

    Write-Host ''

    foreach ( $Dir in $Global:Directories ) {
        if ( $UseFolderNamePrefixing -eq 'n' ) {
            if ( [System.String]::IsNullOrEmpty( $FilenamePrefix ) ) {
                $Results = Rename-PhotoFiles -InputFolder $Dir
            }
            else {
                $Results = Rename-PhotoFiles -InputFolder $Dir -FilenamePrefix $FilenamePrefix
            }
        }
        else {
            $Results = Rename-PhotoFiles -InputFolder $Dir -UseFolderNamePrefixing
        }
    }

    $Global:LastCommandResults = "Renamed Files = $Results"
}
function Start-3 {
    # Move Raws files to Subfolders
    foreach ( $Dir in $Global:Directories ) {
        $Results = Move-RawFilesToSubfolders -InputFolder $Dir
    }

    $Global:LastCommandResults = "Moved RAW files to subfolders = $Results"
}
function Start-4 {
    # Cleanup Extraneous RAW/NEF Files
    # GROK NEED TO TEST THE FUNCTIONALITY OF THIS CALL - PROBABLY NEED TO UPDATE TO MATCH ANY LOSSY FILE OF ANY TYPE JUST TO BE F'N SAFE
    foreach ( $Dir in $Global:Directories ) {
        $Results = Cleanup-ExtraneousRAWFiles -InputFolder $Dir
    }

    $Global:LastCommandResults = "Cleaned Extranous RAW files = $Results"
}
function Start-5 {
    # Resize, Copyright, and Watermark Files
    # GROK - EVERYTHING WORK BUT RETURN CODE ISN"T A BOOLEAN

    Write-Host ''
    Write-Host 'Pick your Copyright and Watermark option'
    Write-Host ''

    $PossibilityCount = $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name.Count
    do {
        $Index = 0
        foreach ($Possibility in $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name) {
            $Index++
            Write-Host "$($Index): $Possibility"
        }
        Write-Host ''
        $Option = Read-Host 'Choose your destiny (Q to quit)'
    } while ( (-not [int]::TryParse($Option, [ref]$null) -or [int]$Option -lt 1 -or [int]$Option -gt $PossibilityCount) -and $Option -ne 'Q')

    if ( $Option -ne 'Q') {
        $Option = $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name[$Option - 1]
        $Copyright = ($Global:PygmieScriptsConfig.Attribution.$Option.Copyright).Replace( '{YEAR}', (Get-Date).Year )
        $Trademark = ($Global:PygmieScriptsConfig.Attribution.$Option.Trademark).Replace( '{YEAR}', (Get-Date).Year )
        $Watermark = ($Global:PygmieScriptsConfig.Attribution.$Option.Watermark).Replace( '{YEAR}', (Get-Date).Year )
        $Author = $Global:PygmieScriptsConfig.Attribution.$Option.Author

        Write-Host ''
        Write-Host "Setting Copyright to: $Copyright"
        Write-Host "Setting Trademark to: $Trademark"
        Write-Host "Setting Watermark to: $Watermark"
        Write-Host "   Setting Author to: $Author"

        Write-Host ''

        $Results = $true
        foreach ( $Dir in $Global:Directories ) {
            $Results = $Results -band (Resize-SmallerizedImage -InputFolder $Dir)

            $SmallerizedFolder = Join-Path -Path $Dir -ChildPath 'Smallerized'
            $WaterMarkedAndCopyrightedFolder = Join-Path -Path $Dir -ChildPath 'WatermarkedAndCopyrighted'
            $Results = $Result -band (Add-CopyrightAndWatermarkToImage -InputFolder $SmallerizedFolder -OutputFolder $WaterMarkedAndCopyrightedFolder -Watermark $Watermark -Copyright $Copyright -Author $Author)
        }

        $Global:LastCommandResults = "Resized, copyrighted, and watermarked files = $Results"
    }
}
function Start-6 {
    # Add White Space to Bottoms of Images
    foreach ( $Dir in $Global:Directories ) {
        $Results = Add-WhiteSpaceToImageBottoms -InputFolder $Dir
    }

    $Global:LastCommandResults = "Added white space to bottoms of images = $Results"
}
function Start-7 {
    # Start Negative to Positive Conversion

    Write-Host ''
    $ColorOrBW = Read-Host 'Are the negatives Color or Grayscale? (C/G)'

    if ( $ColorOrBW -eq 'G' ) {
        $ColorSpace = 'Gray'
    }
    elseif ( $ColorOrBW -eq 'C' ) {
        $ColorSpace = 'RGB'
    }
    else {
        Write-Host ''
        Write-Host 'Invalid option selected. Exiting to menu.' -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    if ( $ColorSpace -eq 'Gray' -or $ColorSpace -eq 'RGB' ) {
        foreach ( $Dir in $Global:Directories ) {
            $Results = Start-NegativeToPositiveConversion -InputFolder $Dir -ColorSpace $ColorSpace
        }

        $Global:LastCommandResults = "Negative to Positive conversions = $Results"
    }
}

function Start-8 {
    # Combine Front and Back Scans
    # THIS CODE TOTALLY NEEDS TO TLC FACE LIFT AND CURRENTLY DOESNT RETURN A VALID RETURN CODE
    foreach ( $Dir in $Global:Directories ) {
        $Results = Combine-FrontAndBackScans -InputFolder $Dir
    }

    $Global:LastCommandResults = "Cleaned Extranous RAW files = $Results"
}

function Start-10 {
    # Convert MP4 file to MP3 file
    $Result = Convert-Mp4ToMp3
}

function Go-P {
    do {
        Clear-Host

        Show-PygmieMenu

        $DoSomething = Read-Host 'Select an option (1, 2, 3, 4, 5, 6, 7, 8, All, S or Q)'

        if ( $Global:ProcessSubfolders ) {
            $Global:Directories = ( Get-ChildItem -Directory ).FullName
        }
        else {
            $Global:Directories = @( $PWD )
        }

        switch ( $DoSomething ) {
            'All' {
                # GROK - DO WE ALWAYS WANT TO SORT FILES TO DATE?  CASES WHERE WE DON'T?  AND HOW TO HANDLE THAT?  ALL VS. SOMETHING ELSE?
                # MAYBE WE ASK A FEW QUESTIONS
                # - DO YOU WANT TO SORT FILES INTO DATE FOLDERS? (Y/N)
                # - DO YOU WANT TO WORK ON SUBFOLDERS? (Y/N)
                # - THEN DO THE THING

                $InitialFolderMode = $Global:ProcessSubfolders

                $Global:ProcessSubfolders = $False
                Write-Host 'Switched to Current Folder Mode' -ForegroundColor Cyan
                $Global:Directories = @( $PWD )

                Start-1

                $Global:ProcessSubfolders = $True
                Write-Host 'Switched to Subfolder Mode' -ForegroundColor Cyan
                $Global:Directories = ( Get-ChildItem -Directory ).FullName

                Start-2
                Start-3

                $GoAhead = Read-Host "`nClean up any lossy files now. Type 'Yes' continue to the RAW file cleanup or [Enter] to skip this step."

                if ( $GoAhead -eq 'Yes' ) {
                    Start-4
                }

                Start-5

                $Global:ProcessSubfolders = $InitialFolderMode
            }
            '1' {
                Start-1
                Read-Host "`nPress Enter to continue"
            }
            '2' {
                Start-2
                Read-Host "`nPress Enter to continue"
            }
            '3' {
                Start-3
                Read-Host "`nPress Enter to continue"
            }
            '4' {
                Start-4
                Read-Host "`nPress Enter to continue"
            }
            '5' {
                Start-5
                Read-Host "`nPress Enter to continue"
            }
            '6' {
                Start-6
                Read-Host "`nPress Enter to continue"
            }
            '7' {
                Start-7
                Read-Host "`nPress Enter to continue"
            }
            '8' {
                Start-8
                Read-Host "`nPress Enter to continue"
            }
            '9' {
                $InputFile = Read-Host 'Enter the Fully Qualified Path of the input file'
                $OutputFile = Read-Host 'Enter the Fully Qualified Path of the Output File ([Enter] for defaults)'
                
                Convert-VideoToStreamableVersion -InputFile $InputFile -OutputFile $OutputFile 
            }
            '10' {
                Start-10
                Read-Host "`nPress Enter to continue"
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
            }
            'Q' {
                Write-Host 'Exiting the menu. Goodbye!' -ForegroundColor Yellow
            }
            default {
                Write-Host 'Exiting the menu. Goodbye!' -ForegroundColor Yellow
            }
        }

        # if ( $DoSomething -ne 'Q' -and $DoSomething -ne 'S' -and -not [System.String]::IsNullOrEmpty( $DoSomething ) ) {
        #     Start-Sleep -Seconds 7
        # }

    } while ($DoSomething -ne 'Q' -and -not [System.String]::IsNullOrEmpty( $DoSomething ))
}