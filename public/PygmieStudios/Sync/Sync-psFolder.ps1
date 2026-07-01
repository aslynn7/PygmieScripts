function Sync-psFolder {
    <#
    .SYNOPSIS
        Performs a one-way mirror sync from a source folder to a target folder.

    .DESCRIPTION
        Mirrors the entire contents of Source into Target, keeping them identical:
          - New files present in Source but missing from Target are copied.
          - Files that differ (by size, or by SHA256 hash when timestamps vary) are overwritten.
          - Files present in Target but absent from Source are deleted.
          - Empty directories in Target with no Source counterpart are removed.

        Comparison is two-stage for speed: size first, then SHA256 only when sizes
        match but timestamps differ. On a stable mirror this means no file I/O beyond
        the initial directory scans.

    .INPUTS
        [System.String] $Source = Path to the source (authoritative) folder.
        [System.String] $Target = Path to the target (mirror) folder. Created if absent.

    .OUTPUTS
        [Bool] = $True on success, $False if any individual operation fails.

    .EXAMPLE
        Sync-psFolder -Source '/Volumes/Camera/PhaysPhotos' -Target '/Volumes/Backup/PhaysPhotos'

    .EXAMPLE
        Sync-psFolder -Source $env:USERPROFILE\Pictures -Target D:\Mirror\Pictures

    .NOTES
        One-way destructive sync. Files deleted from Source will be deleted from Target.
        Confirm Source is the authoritative copy before running.
        Requires PowerShell 5.1+. Cross-platform compatible.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $true)]
        [System.String] $Source,

        [Parameter(Mandatory = $true)]
        [System.String] $Target
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        function Get-RelativePath {
            param([string]$BasePath, [string]$FullPath)
            return [System.IO.Path]::GetRelativePath(
                [System.IO.Path]::GetFullPath($BasePath),
                [System.IO.Path]::GetFullPath($FullPath)
            )
        }

        function Get-FileHashSafe {
            param([string]$Path)
            return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        }

        function Show-SyncProgress {
            param([string]$Activity, [int]$Current, [int]$Total, [string]$Status)
            $pct = if ($Total -le 0) { 100 } else { [int](($Current / $Total) * 100) }
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $pct
        }

        $Source = [System.IO.Path]::GetFullPath($Source)
        $Target = [System.IO.Path]::GetFullPath($Target)

        if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
            throw "Source folder does not exist: $Source"
        }
        if ($Source -eq $Target) { throw 'Source and target cannot be the same folder.' }
        if ($Target.StartsWith($Source + [System.IO.Path]::DirectorySeparatorChar)) {
            throw 'Target cannot be inside source.'
        }
        if ($Source.StartsWith($Target + [System.IO.Path]::DirectorySeparatorChar)) {
            throw 'Source cannot be inside target.'
        }

        if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
            New-Item -ItemType Directory -Path $Target -Force | Out-Null
            Write-Host "Created target folder: $Target" -ForegroundColor Cyan
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            Write-Host ''
            Write-Host '  Scanning source and target...' -ForegroundColor DarkGray
            Write-Host "  Source : $Source" -ForegroundColor DarkGray
            Write-Host "  Target : $Target" -ForegroundColor DarkGray
            Write-Host ''

            $sourceFiles = @{}
            Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
                $sourceFiles[(Get-RelativePath $Source $_.FullName)] = $_
            }

            $targetFiles = @{}
            Get-ChildItem -LiteralPath $Target -Recurse -File | ForEach-Object {
                $targetFiles[(Get-RelativePath $Target $_.FullName)] = $_
            }

            $sourceDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            $null = $sourceDirs.Add('')
            Get-ChildItem -LiteralPath $Source -Recurse -Directory | ForEach-Object {
                $null = $sourceDirs.Add((Get-RelativePath $Source $_.FullName))
            }

            $workItems = New-Object System.Collections.Generic.List[object]

            foreach ($relativePath in ($sourceFiles.Keys | Sort-Object)) {
                $sourceFile     = $sourceFiles[$relativePath]
                $targetFilePath = Join-Path $Target $relativePath

                if (-not (Test-Path -LiteralPath $targetFilePath -PathType Leaf)) {
                    $workItems.Add([pscustomobject]@{ Type = 'CopyNew'; Relative = $relativePath; Source = $sourceFile.FullName; Target = $targetFilePath })
                    continue
                }

                $srcInfo     = Get-Item -LiteralPath $sourceFile.FullName
                $tgtInfo     = Get-Item -LiteralPath $targetFilePath
                $isDifferent = $false

                if ($srcInfo.Length -ne $tgtInfo.Length) {
                    $isDifferent = $true
                }
                elseif ($srcInfo.LastWriteTimeUtc -ne $tgtInfo.LastWriteTimeUtc) {
                    if ((Get-FileHashSafe $sourceFile.FullName) -ne (Get-FileHashSafe $targetFilePath)) {
                        $isDifferent = $true
                    }
                }

                if ($isDifferent) {
                    $workItems.Add([pscustomobject]@{ Type = 'Update'; Relative = $relativePath; Source = $sourceFile.FullName; Target = $targetFilePath })
                }
            }

            foreach ($relativePath in ($targetFiles.Keys | Sort-Object)) {
                if (-not $sourceFiles.ContainsKey($relativePath)) {
                    $workItems.Add([pscustomobject]@{ Type = 'RemoveFile'; Relative = $relativePath; Source = $null; Target = (Join-Path $Target $relativePath) })
                }
            }

            $targetDirsToRemove = Get-ChildItem -LiteralPath $Target -Recurse -Directory |
                Sort-Object FullName -Descending |
                ForEach-Object {
                    $relDir = Get-RelativePath $Target $_.FullName
                    if (-not $sourceDirs.Contains($relDir)) {
                        [pscustomobject]@{ Type = 'RemoveDir'; Relative = $relDir; Target = $_.FullName }
                    }
                }
            foreach ($dirItem in $targetDirsToRemove) { $workItems.Add($dirItem) }

            $totalItems        = $workItems.Count
            $currentItem       = 0
            $countCopied       = 0
            $countUpdated      = 0
            $countFilesRemoved = 0
            $countDirsRemoved  = 0

            Write-Host "  Planned operations : $totalItems" -ForegroundColor DarkGray
            Write-Host ''

            foreach ($item in $workItems) {
                $currentItem++
                Show-SyncProgress 'Syncing folder' $currentItem $totalItems "$currentItem/$totalItems  $($item.Type)  $($item.Relative)"

                switch ($item.Type) {
                    'CopyNew' {
                        $targetDir = Split-Path -Path $item.Target -Parent
                        if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
                        (Get-Item -LiteralPath $item.Target).LastWriteTimeUtc = (Get-Item -LiteralPath $item.Source).LastWriteTimeUtc
                        $countCopied++
                        Write-Host "[$currentItem/$totalItems] COPIED  : $($item.Relative)" -ForegroundColor Green
                    }
                    'Update' {
                        $targetDir = Split-Path -Path $item.Target -Parent
                        if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
                        (Get-Item -LiteralPath $item.Target).LastWriteTimeUtc = (Get-Item -LiteralPath $item.Source).LastWriteTimeUtc
                        $countUpdated++
                        Write-Host "[$currentItem/$totalItems] UPDATED : $($item.Relative)" -ForegroundColor Yellow
                    }
                    'RemoveFile' {
                        if (Test-Path -LiteralPath $item.Target -PathType Leaf) {
                            Remove-Item -LiteralPath $item.Target -Force
                            $countFilesRemoved++
                            Write-Host "[$currentItem/$totalItems] REMOVED : $($item.Relative)" -ForegroundColor Red
                        }
                    }
                    'RemoveDir' {
                        if ((Test-Path -LiteralPath $item.Target -PathType Container) -and
                            (-not (Get-ChildItem -LiteralPath $item.Target -Force | Select-Object -First 1))) {
                            Remove-Item -LiteralPath $item.Target -Force
                            $countDirsRemoved++
                            Write-Host "[$currentItem/$totalItems] RMDIR   : $($item.Relative)" -ForegroundColor DarkRed
                        }
                    }
                }
            }

            Write-Progress -Activity 'Syncing folder' -Completed

            Write-SummaryTable -Title 'Sync Summary' -Rows @(
                [pscustomobject]@{ Label = 'Already in sync';  Count = ($sourceFiles.Count - $countCopied - $countUpdated); Color = 'Cyan'    }
                [pscustomobject]@{ Label = 'New files copied'; Count = $countCopied;       Color = 'Green'   }
                [pscustomobject]@{ Label = 'Files updated';    Count = $countUpdated;      Color = 'Yellow'  }
                [pscustomobject]@{ Label = 'Files removed';    Count = $countFilesRemoved; Color = 'Red'     }
                [pscustomobject]@{ Label = 'Dirs removed';     Count = $countDirsRemoved;  Color = 'DarkRed' }
            )
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
