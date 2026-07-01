function Show-PygmieMenu {
    $bar = '═' * 62

    Write-Host ''
    Write-Host "  $bar" -ForegroundColor White
    Write-Host '        P Y G M I E   S T U D I O S   T O O L K I T' -ForegroundColor Cyan
    Write-Host "  $bar" -ForegroundColor White
    Write-Host ''

    $modeColor = if ($Global:ProcessSubfolders) { 'Green' } else { 'Yellow' }
    $modeLabel = if ($Global:ProcessSubfolders) { 'SUBFOLDER — processing all subdirectories' } else { 'CURRENT FOLDER only' }
    Write-Host "  Mode : $modeLabel" -ForegroundColor $modeColor
    Write-Host ''
    Write-Host '  ┌─────────────────────────────────────────────────────────────┐' -ForegroundColor DarkCyan
    Write-Host "  │  PWD: $($PWD.ToString().PadRight(58))│" -ForegroundColor Cyan
    Write-Host '  └─────────────────────────────────────────────────────────────┘' -ForegroundColor DarkCyan

    if ($Global:LastCommandResults) {
        Write-Host ''
        Write-Host "  Last : $Global:LastCommandResults" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host "  $bar" -ForegroundColor White
    Write-Host '  PHOTO TOOLS' -ForegroundColor White
    Write-Host "  $bar" -ForegroundColor DarkGray
    Write-Host '   0  Convert RAW/PNG/TIFF to High-Res JPG' -ForegroundColor White
    Write-Host '   1  Move images to date-stamped folders' -ForegroundColor White
    Write-Host '   2  Rename photo files (sequential)' -ForegroundColor White
    Write-Host '   3  Move RAW files to RAW subfolder' -ForegroundColor White
    Write-Host '   4  Remove orphaned RAW files               [DELETES FILES]' -ForegroundColor Red
    Write-Host '   5  Compress, Watermark & Copyright images' -ForegroundColor White
    Write-Host '   6  Expand canvas (add white space below)   [MODIFIES IN-PLACE]' -ForegroundColor Red
    Write-Host '   7  Convert negatives to positives' -ForegroundColor White
    Write-Host '   8  Combine front & back scan pairs' -ForegroundColor White
    Write-Host ''
    Write-Host '  SPECIALIZED PHOTO TOOLS' -ForegroundColor White
    Write-Host "  $bar" -ForegroundColor DarkGray
    Write-Host '  11  Flip/mirror photos horizontally' -ForegroundColor White
    Write-Host '  12  Convert HEIC files to JPG' -ForegroundColor White
    Write-Host '  13  Convert color images to Black & White' -ForegroundColor White
    Write-Host '  14  Compress image tree (recursive, flat output)' -ForegroundColor White
    Write-Host '  15  Convert NEF files to PNG' -ForegroundColor White
    Write-Host '  16  Export contact sheet (thumbnail grid)' -ForegroundColor White
    Write-Host '  17  Backup EXIF metadata to JSON' -ForegroundColor White
    Write-Host '  18  Rename photos by EXIF date/time' -ForegroundColor White
    Write-Host ''
    Write-Host '  VIDEO TOOLS' -ForegroundColor White
    Write-Host "  $bar" -ForegroundColor DarkGray
    Write-Host '   9  Optimize MP4 for streaming' -ForegroundColor White
    Write-Host '  10  Extract MP3 audio from MP4' -ForegroundColor White
    Write-Host '  19  Convert video to animated GIF' -ForegroundColor White
    Write-Host ''
    Write-Host "  $bar" -ForegroundColor White
    Write-Host '   S  Toggle subfolder mode' -ForegroundColor DarkGray
    Write-Host '   C  Change working directory' -ForegroundColor DarkGray
    Write-Host ' All  Run standard workflow: 2 → 0 → 3 → [4] → 5' -ForegroundColor DarkGray
    Write-Host '   Q  Quit' -ForegroundColor DarkGray
    Write-Host "  $bar" -ForegroundColor White
    Write-Host ''
}

function Start-0 {
    foreach ($Dir in $Global:Directories) {
        $Results = Convert-psRawOrPngToHighResJpg -InputFolder $Dir
    }
    $Global:LastCommandResults = "RAW/PNG to High-Res JPG = $Results"
    return $Results
}

function Start-1 {
    foreach ($Dir in $Global:Directories) {
        $Results = Move-psImagesByDate -InputFolder $Dir
    }
    $Global:LastCommandResults = "Move to date folders = $Results"
    return $Results
}

function Start-2 {
    Write-Host ''
    $UseFolderNamePrefixing = Read-Host '  Use folder names as file prefixes? (Y/N  [Enter]=Y)'

    $FilenamePrefix = ''
    if ($UseFolderNamePrefixing -eq 'n') {
        Write-Host ''
        $FilenamePrefix = Read-Host '  Enter a filename prefix ([Enter] = "Photo-")'
    }

    Write-Host ''

    $Results = $true
    foreach ($Dir in $Global:Directories) {
        if ($UseFolderNamePrefixing -eq 'n') {
            if ([System.String]::IsNullOrEmpty($FilenamePrefix)) {
                $Results = Rename-psPhotoFiles -InputFolder $Dir
            }
            else {
                $Results = Rename-psPhotoFiles -InputFolder $Dir -FilenamePrefix $FilenamePrefix
            }
        }
        else {
            $Results = Rename-psPhotoFiles -InputFolder $Dir -UseFolderNamePrefixing
        }
    }

    $Global:LastCommandResults = "Rename files = $Results"
    return $Results
}

function Start-3 {
    foreach ($Dir in $Global:Directories) {
        $Results = Move-psRawFilesToSubfolders -InputFolder $Dir
    }
    $Global:LastCommandResults = "Move RAW to subfolder = $Results"
    return $Results
}

function Start-4 {
    foreach ($Dir in $Global:Directories) {
        $Results = Remove-psOrphanRawFiles -InputFolder $Dir
    }
    $Global:LastCommandResults = "Remove orphan RAW files = $Results"
    return $Results
}

function Start-5 {
    Write-Host ''
    Write-Host '  Pick your Copyright / Watermark profile:' -ForegroundColor Cyan
    Write-Host ''

    $PossibilityCount = $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name.Count
    $AdHocOption      = $PossibilityCount + 1

    do {
        $Index = 0
        foreach ($Possibility in $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name) {
            $Index++
            Write-Host "  $($Index): $Possibility"
        }
        Write-Host "  $($AdHocOption): [Ad Hoc / Custom Entry]"
        Write-Host ''
        $Option = Read-Host '  Choose your destiny (Q to quit)'
    } while ((-not [int]::TryParse($Option, [ref]$null) -or [int]$Option -lt 1 -or [int]$Option -gt $AdHocOption) -and $Option -ne 'Q')

    if ($Option -ne 'Q') {
        if ([int]$Option -eq $AdHocOption) {
            Write-Host ''
            $Copyright = Read-Host '  Enter Copyright text'
            $Watermark = Read-Host '  Enter Watermark text'
            $Author    = Read-Host '  Enter Author name'
            $Comment   = Read-Host '  Enter Comment (or [Enter] to skip)'
        }
        else {
            $OptionName = $Global:PygmieScriptsConfig.Attribution.psObject.Properties.Name[$Option - 1]
            $Copyright  = ($Global:PygmieScriptsConfig.Attribution.$OptionName.Copyright).Replace('{YEAR}', (Get-Date).Year)
            $Watermark  = ($Global:PygmieScriptsConfig.Attribution.$OptionName.Watermark).Replace('{YEAR}', (Get-Date).Year)
            $Author     = $Global:PygmieScriptsConfig.Attribution.$OptionName.Author
            $Comment    = Read-Host '  Enter Comment (or [Enter] to skip)'
        }

        Write-Host ''
        Write-Host "  Copyright : $Copyright"
        Write-Host "  Watermark : $Watermark"
        Write-Host "  Author    : $Author"
        Write-Host "  Comment   : $Comment"
        Write-Host ''

        $Results = $true
        foreach ($Dir in $Global:Directories) {
            $Results = $Results -band (Compress-psImage -InputFolder $Dir)
            $SmallerizedFolder = Join-Path -Path $Dir -ChildPath 'Smallerized'
            $WatermarkedFolder = Join-Path -Path $Dir -ChildPath 'WatermarkedAndCopyrighted'
            $Results = $Results -band (Add-psCopyrightAndWatermarkToImage -InputFolder $SmallerizedFolder -OutputFolder $WatermarkedFolder -Watermark $Watermark -Copyright $Copyright -Author $Author -Comment $Comment)
        }

        $Global:LastCommandResults = "Compress + Watermark + Copyright = $Results"
        return $Results
    }
    return $false
}

function Start-6 {
    foreach ($Dir in $Global:Directories) {
        $Results = Expand-psImageCanvas -InputFolder $Dir
    }
    $Global:LastCommandResults = "Expand canvas = $Results"
    return $Results
}

function Start-7 {
    Write-Host ''
    $ColorOrBW = Read-Host '  Are the negatives Color or Grayscale? (C/G)'

    if ($ColorOrBW -eq 'G') {
        $ColorSpace = 'Gray'
    }
    elseif ($ColorOrBW -eq 'C') {
        $ColorSpace = 'RGB'
    }
    else {
        Write-Host '  Invalid option. Returning to menu.' -ForegroundColor Red
        return $false
    }

    $Results = $true
    foreach ($Dir in $Global:Directories) {
        $Results = Convert-psNegativeImage -InputFolder $Dir -ColorSpace $ColorSpace
    }

    $Global:LastCommandResults = "Negative to positive = $Results"
    return $Results
}

function Start-8 {
    foreach ($Dir in $Global:Directories) {
        $Results = Merge-psScanPair -InputFolder $Dir
    }
    $Global:LastCommandResults = "Combine scan pairs = $Results"
    return $Results
}

function Start-9 {
    Write-Host ''
    $InputFile  = Read-Host '  Enter the fully qualified path to the input MP4 file'
    $OutputFile = Read-Host '  Enter the output file path ([Enter] for auto-generated name)'

    if ([System.String]::IsNullOrEmpty($OutputFile)) {
        $Results = Convert-psVideoToStreamableVersion -InputFile $InputFile
    }
    else {
        $Results = Convert-psVideoToStreamableVersion -InputFile $InputFile -OutputFile $OutputFile
    }
    $Global:LastCommandResults = "Optimize video = $Results"
    return $Results
}

function Start-10 {
    $Results = Convert-psMp4ToMp3
    $Global:LastCommandResults = "MP4 to MP3 = $Results"
    return $Results
}

function Start-11 {
    foreach ($Dir in $Global:Directories) {
        $Results = Invoke-psImageFlip -InputFolder $Dir
    }
    $Global:LastCommandResults = "Flip/mirror images = $Results"
    return $Results
}

function Start-12 {
    foreach ($Dir in $Global:Directories) {
        $Results = Convert-psHeicToJpg -InputFolder $Dir
    }
    $Global:LastCommandResults = "HEIC to JPG = $Results"
    return $Results
}

function Start-13 {
    foreach ($Dir in $Global:Directories) {
        $Results = Convert-psImagesToBW -InputFolder $Dir
    }
    $Global:LastCommandResults = "Color to B&W = $Results"
    return $Results
}

function Start-14 {
    Write-Host ''
    $InputFolder  = Read-Host '  Enter the source folder to scan recursively'
    $OutputFolder = Read-Host '  Enter the output folder for compressed files'

    $Results = Compress-psImageTree -InputFolder $InputFolder -OutputFolder $OutputFolder
    $Global:LastCommandResults = "Compress image tree = $Results"
    return $Results
}

function Start-15 {
    foreach ($Dir in $Global:Directories) {
        $Results = Convert-psNefToPng -SourceFolder $Dir
    }
    $Global:LastCommandResults = "NEF to PNG = $Results"
    return $Results
}

function Start-16 {
    foreach ($Dir in $Global:Directories) {
        $Results = Export-psContactSheet -InputFolder $Dir
    }
    $Global:LastCommandResults = "Export contact sheet = $Results"
    return $Results
}

function Start-17 {
    foreach ($Dir in $Global:Directories) {
        $Results = Backup-psExifData -InputFolder $Dir
    }
    $Global:LastCommandResults = "Backup EXIF data = $Results"
    return $Results
}

function Start-18 {
    Write-Host ''
    $WhatIf = Read-Host '  Preview renames without applying? (Y/N  [Enter]=N)'

    foreach ($Dir in $Global:Directories) {
        if ($WhatIf -eq 'Y' -or $WhatIf -eq 'y') {
            $Results = Rename-psPhotoFilesByExif -InputFolder $Dir -WhatIf
        }
        else {
            $Results = Rename-psPhotoFilesByExif -InputFolder $Dir
        }
    }
    $Global:LastCommandResults = "Rename by EXIF = $Results"
    return $Results
}

function Start-19 {
    Write-Host ''
    $InputFile  = Read-Host '  Enter the fully qualified path to the input video file'
    $OutputFile = Read-Host '  Enter the output GIF path ([Enter] for auto-generated name)'
    Write-Host ''
    $FpsInput   = Read-Host '  Frame rate fps ([Enter] = 10)'
    $WidthInput = Read-Host '  Output width px ([Enter] = 640)'

    $Fps   = if ([int]::TryParse($FpsInput,   [ref]$null)) { [int]$FpsInput   } else { 10  }
    $Width = if ([int]::TryParse($WidthInput, [ref]$null)) { [int]$WidthInput } else { 640 }

    $Params = @{ InputFile = $InputFile; Fps = $Fps; Width = $Width }
    if (-not [System.String]::IsNullOrEmpty($OutputFile)) { $Params.OutputFile = $OutputFile }

    $Results = Convert-psVideoToGif @Params
    $Global:LastCommandResults = "Video to GIF = $Results"
    return $Results
}

function Show-AllWorkflowSummary {
    param([hashtable] $StepResults)

    $bar = '─' * 40
    Write-Host ''
    Write-Host "  $bar" -ForegroundColor White
    Write-Host '  ALL WORKFLOW SUMMARY' -ForegroundColor White
    Write-Host "  $bar" -ForegroundColor DarkGray

    foreach ($Step in $StepResults.Keys) {
        $val   = $StepResults[$Step]
        $color = if ($val -eq $true) { 'Green' } elseif ($val -eq $false) { 'Red' } else { 'Yellow' }
        $label = if ($val -eq $true) { 'PASS' } elseif ($val -eq $false) { 'FAIL' } else { 'SKIP' }
        Write-Host "  $($Step.PadRight(30)) $label" -ForegroundColor $color
    }

    Write-Host "  $bar" -ForegroundColor White
    Write-Host ''
}

function Go-P {
    do {
        Clear-Host

        Show-PygmieMenu

        $DoSomething = Read-Host '  Select an option (0-19, S, C, All, Q)'

        if ($Global:ProcessSubfolders) {
            $Global:Directories = (Get-ChildItem -Directory -Recurse).FullName
        }
        else {
            $Global:Directories = @($PWD)
        }

        switch ($DoSomething) {
            'All' {
                $InitialFolderMode        = $Global:ProcessSubfolders
                $Global:ProcessSubfolders = $False
                $Global:Directories       = @($PWD)
                Write-Host '  Running standard workflow in Current Folder Mode.' -ForegroundColor Cyan
                Write-Host ''

                $StepResults = [ordered]@{}

                $StepResults['2. Rename files']    = Start-2
                $StepResults['0. RAW to JPG']      = Start-0
                $StepResults['3. Move RAW to sub'] = Start-3

                $GoAhead = Read-Host "`n  Cull any lossy files now. Type 'Yes' to run orphan RAW cleanup, or [Enter] to skip."
                if ($GoAhead -eq 'Yes') {
                    $StepResults['4. Remove orphan RAW'] = Start-4
                }
                else {
                    $StepResults['4. Remove orphan RAW'] = 'skipped'
                }

                $StepResults['5. Compress+Watermark'] = Start-5

                Show-AllWorkflowSummary -StepResults $StepResults
                $Global:ProcessSubfolders = $InitialFolderMode
            }
            '0'  { Start-0;  Read-Host "`n  Press Enter to continue" }
            '1'  { Start-1;  Read-Host "`n  Press Enter to continue" }
            '2'  { Start-2;  Read-Host "`n  Press Enter to continue" }
            '3'  { Start-3;  Read-Host "`n  Press Enter to continue" }
            '4'  { Start-4;  Read-Host "`n  Press Enter to continue" }
            '5'  { Start-5;  Read-Host "`n  Press Enter to continue" }
            '6'  { Start-6;  Read-Host "`n  Press Enter to continue" }
            '7'  { Start-7;  Read-Host "`n  Press Enter to continue" }
            '8'  { Start-8;  Read-Host "`n  Press Enter to continue" }
            '9'  { Start-9;  Read-Host "`n  Press Enter to continue" }
            '10' { Start-10; Read-Host "`n  Press Enter to continue" }
            '11' { Start-11; Read-Host "`n  Press Enter to continue" }
            '12' { Start-12; Read-Host "`n  Press Enter to continue" }
            '13' { Start-13; Read-Host "`n  Press Enter to continue" }
            '14' { Start-14; Read-Host "`n  Press Enter to continue" }
            '15' { Start-15; Read-Host "`n  Press Enter to continue" }
            '16' { Start-16; Read-Host "`n  Press Enter to continue" }
            '17' { Start-17; Read-Host "`n  Press Enter to continue" }
            '18' { Start-18; Read-Host "`n  Press Enter to continue" }
            '19' { Start-19; Read-Host "`n  Press Enter to continue" }
            'S'  {
                if ($Global:ProcessSubfolders) {
                    $Global:ProcessSubfolders = $false
                    Write-Host '  Switched to Current Folder Mode.' -ForegroundColor Yellow
                }
                else {
                    $Global:ProcessSubfolders = $true
                    Write-Host '  Switched to Subfolder Mode.' -ForegroundColor Green
                }
            }
            'C'  {
                Write-Host ''
                Write-Host "  Current directory: $PWD" -ForegroundColor DarkGray
                $NewPath = Read-Host '  Enter new working directory path'
                if (-not [System.String]::IsNullOrEmpty($NewPath)) {
                    if (Test-Path -LiteralPath $NewPath -PathType Container) {
                        Set-Location -LiteralPath $NewPath
                        Write-Host "  Changed to: $PWD" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  Path not found: $NewPath" -ForegroundColor Red
                    }
                }
            }
            'Q'  { Write-Host '  Goodbye!' -ForegroundColor Yellow }
            default { Write-Host '  Goodbye!' -ForegroundColor Yellow }
        }

    } while ($DoSomething -ne 'Q' -and -not [System.String]::IsNullOrEmpty($DoSomething))
}
