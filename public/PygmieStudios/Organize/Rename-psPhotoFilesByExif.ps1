function Rename-psPhotoFilesByExif {
    <#
    .SYNOPSIS
        Renames photo files using their EXIF DateTimeOriginal metadata.

    .DESCRIPTION
        Reads the DateTimeOriginal EXIF field from each image file in the input folder
        and renames the file to a sortable datetime-based format:
        YYYY-MM-DD_HH-MM-SS[_N].ext where [_N] is a collision counter.

        Uses the EXIF capture time rather than filesystem modification time, which is
        more accurate and survives file copies, backups, and cloud syncs that reset mtime.
        Falls back to filesystem mtime if DateTimeOriginal is absent.

    .INPUTS
        [System.String] $InputFolder = Folder containing image files to rename. Defaults to current directory.
        [Switch]        $WhatIf      = When specified, previews renames without applying them.

    .OUTPUTS
        [Bool] = $True on full success, $False if any rename fails.

    .EXAMPLE
        Rename-psPhotoFilesByExif

    .EXAMPLE
        Rename-psPhotoFilesByExif -InputFolder '/Volumes/Camera/DCIM' -WhatIf

    .EXAMPLE
        Rename-psPhotoFilesByExif -InputFolder '/Volumes/Camera/DCIM'

    .NOTES
        Requires ExifTool. Install via: brew install exiftool
        Files with no DateTimeOriginal fallback to LastWriteTime with a '[mtime]' suffix.
        Rename collisions (same second) are resolved with a counter: _2, _3, etc.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Switch] $WhatIf
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose "   InputFolder = $InputFolder"
        Write-Verbose "   WhatIf      = $WhatIf"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFolder)) {
                throw "Input folder does not exist: $InputFolder"
            }
            if (-not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
                throw "ExifTool not found in PATH. Install via: brew install exiftool"
            }

            $Files = @()
            $Files += foreach ($Pattern in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            if ($Files.Count -eq 0) {
                Write-Host 'No image files found!' -ForegroundColor Yellow
                $Result = $False
            }
            else {
                Write-Host "Reading EXIF data for $($Files.Count) file(s)..." -ForegroundColor Cyan
                if ($WhatIf) { Write-Host '  WhatIf mode — no files will be renamed.' -ForegroundColor Yellow }
                Write-Host ''

                $Index          = 0
                $countRenamed   = 0
                $countFallback  = 0
                $countFailed    = 0
                $usedNames      = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

                foreach ($File in $Files) {
                    $Index++
                    try {
                        $exifJson = & exiftool -json -DateTimeOriginal $File.FullName 2>$null | ConvertFrom-Json
                        $dto      = $exifJson[0].DateTimeOriginal
                        $isFallback = $false

                        if ($dto) {
                            $dt = [DateTime]::ParseExact($dto, 'yyyy:MM:dd HH:mm:ss', $null)
                        }
                        else {
                            $dt = $File.LastWriteTime
                            $isFallback = $true
                        }

                        $BaseNew  = $dt.ToString('yyyy-MM-dd_HH-mm-ss')
                        if ($isFallback) { $BaseNew += '_[mtime]' }
                        $Ext      = $File.Extension.ToLower()
                        $NewName  = $BaseNew + $Ext

                        $Counter = 2
                        while ($usedNames.Contains($NewName) -or (Test-Path (Join-Path $InputFolder $NewName))) {
                            $NewName = "${BaseNew}_${Counter}${Ext}"
                            $Counter++
                        }
                        $null = $usedNames.Add($NewName)

                        $color = if ($isFallback) { 'Yellow' } else { 'Green' }
                        $suffix = if ($isFallback) { '  [no EXIF, used mtime]' } else { '' }

                        if ($WhatIf) {
                            Write-Host "[$Index/$($Files.Count)] PREVIEW: $($File.Name) -> $NewName$suffix" -ForegroundColor $color
                        }
                        else {
                            if ($File.Name -ne $NewName) {
                                Rename-Item -Path $File.FullName -NewName $NewName
                                $countRenamed++
                                Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $NewName$suffix" -ForegroundColor $color
                            }
                            else {
                                Write-Host "[$Index/$($Files.Count)] UNCHANGED: $($File.Name)" -ForegroundColor DarkGray
                            }
                            if ($isFallback) { $countFallback++ }
                        }
                    }
                    catch {
                        $Result = $False
                        $countFailed++
                        Write-Host "[$Index/$($Files.Count)] FAILED: $($File.Name) — $_" -ForegroundColor Red
                    }
                }

                if (-not $WhatIf) {
                    Write-SummaryTable -Title 'Rename by EXIF' -Rows @(
                        [pscustomobject]@{ Label = 'Files renamed';        Count = $countRenamed;  Color = 'Green'  }
                        [pscustomobject]@{ Label = 'Used mtime fallback';  Count = $countFallback; Color = if ($countFallback -gt 0) { 'Yellow' } else { 'Cyan' } }
                        [pscustomobject]@{ Label = 'Files failed';         Count = $countFailed;   Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
                    )
                }
            }
        }
        catch {
            $Result = $False
            throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
