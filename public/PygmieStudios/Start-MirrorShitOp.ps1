# GROK - Needs massaging, will get to it!
function Start-MirrorShitOp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Get-RelativePath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$BasePath,

            [Parameter(Mandatory = $true)]
            [string]$FullPath
        )

        $baseFull = [System.IO.Path]::GetFullPath($BasePath)
        $itemFull = [System.IO.Path]::GetFullPath($FullPath)

        return [System.IO.Path]::GetRelativePath($baseFull, $itemFull)
    }

    function Get-FileHashSafe {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }

    function Show-ProgressBar {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Activity,

            [Parameter(Mandatory = $true)]
            [int]$Current,

            [Parameter(Mandatory = $true)]
            [int]$Total,

            [Parameter(Mandatory = $true)]
            [string]$Status
        )

        $percent = if ($Total -le 0) { 100 } else { [int](($Current / $Total) * 100) }
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
    }

    $Source = [System.IO.Path]::GetFullPath($Source)
    $Target = [System.IO.Path]::GetFullPath($Target)

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source folder does not exist: $Source"
    }

    if ($Source -eq $Target) {
        throw 'Source and target cannot be the same folder.'
    }

    if ($Target.StartsWith($Source + [System.IO.Path]::DirectorySeparatorChar)) {
        throw 'Target cannot be inside source.'
    }

    if ($Source.StartsWith($Target + [System.IO.Path]::DirectorySeparatorChar)) {
        throw 'Source cannot be inside target.'
    }

    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
        Write-Host "Created target folder: $Target"
    }

    Write-Host 'Scanning source and target...'
    Write-Host "Source: $Source"
    Write-Host "Target: $Target"
    Write-Host ''

    $sourceFiles = @{}
    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $relative = Get-RelativePath -BasePath $Source -FullPath $_.FullName
        $sourceFiles[$relative] = $_
    }

    $targetFiles = @{}
    Get-ChildItem -LiteralPath $Target -Recurse -File | ForEach-Object {
        $relative = Get-RelativePath -BasePath $Target -FullPath $_.FullName
        $targetFiles[$relative] = $_
    }

    $sourceDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $null = $sourceDirs.Add('')

    Get-ChildItem -LiteralPath $Source -Recurse -Directory | ForEach-Object {
        $relativeDir = Get-RelativePath -BasePath $Source -FullPath $_.FullName
        $null = $sourceDirs.Add($relativeDir)
    }

    $workItems = New-Object System.Collections.Generic.List[object]

    foreach ($relativePath in ($sourceFiles.Keys | Sort-Object)) {
        $sourceFile = $sourceFiles[$relativePath]
        $targetFilePath = Join-Path $Target $relativePath

        if (-not (Test-Path -LiteralPath $targetFilePath -PathType Leaf)) {
            $workItems.Add([pscustomobject]@{
                    Type     = 'CopyNew'
                    Relative = $relativePath
                    Source   = $sourceFile.FullName
                    Target   = $targetFilePath
                })
            continue
        }

        $sourceInfo = Get-Item -LiteralPath $sourceFile.FullName
        $targetInfo = Get-Item -LiteralPath $targetFilePath

        $isDifferent = $false

        if ($sourceInfo.Length -ne $targetInfo.Length) {
            $isDifferent = $true
        }
        elseif ($sourceInfo.LastWriteTimeUtc -ne $targetInfo.LastWriteTimeUtc) {
            $sourceHash = Get-FileHashSafe -Path $sourceFile.FullName
            $targetHash = Get-FileHashSafe -Path $targetFilePath

            if ($sourceHash -ne $targetHash) {
                $isDifferent = $true
            }
        }

        if ($isDifferent) {
            $workItems.Add([pscustomobject]@{
                    Type     = 'Update'
                    Relative = $relativePath
                    Source   = $sourceFile.FullName
                    Target   = $targetFilePath
                })
        }
    }

    foreach ($relativePath in ($targetFiles.Keys | Sort-Object)) {
        if (-not $sourceFiles.ContainsKey($relativePath)) {
            $workItems.Add([pscustomobject]@{
                    Type     = 'RemoveFile'
                    Relative = $relativePath
                    Source   = $null
                    Target   = (Join-Path $Target $relativePath)
                })
        }
    }

    $targetDirsToRemove = Get-ChildItem -LiteralPath $Target -Recurse -Directory |
    Sort-Object FullName -Descending |
    ForEach-Object {
        $relativeDir = Get-RelativePath -BasePath $Target -FullPath $_.FullName
        if (-not $sourceDirs.Contains($relativeDir)) {
            [pscustomobject]@{
                Type     = 'RemoveDir'
                Relative = $relativeDir
                Target   = $_.FullName
            }
        }
    }

    foreach ($dirItem in $targetDirsToRemove) {
        $workItems.Add($dirItem)
    }

    $totalItems = $workItems.Count
    $currentItem = 0

    Write-Host "Planned operations: $totalItems"
    Write-Host ''

    foreach ($item in $workItems) {
        $currentItem++
        $status = "$currentItem of $totalItems - $($item.Type) - $($item.Target)"
        Show-ProgressBar -Activity 'Mirroring files' -Current $currentItem -Total $totalItems -Status $status

        switch ($item.Type) {
            'CopyNew' {
                $targetDir = Split-Path -Path $item.Target -Parent
                if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }

                Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
                $sourceInfo = Get-Item -LiteralPath $item.Source
                (Get-Item -LiteralPath $item.Target).LastWriteTimeUtc = $sourceInfo.LastWriteTimeUtc

                Write-Host "[$currentItem/$totalItems] NEW FILE COPIED: $($item.Target)"
            }

            'Update' {
                $targetDir = Split-Path -Path $item.Target -Parent
                if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }

                Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
                $sourceInfo = Get-Item -LiteralPath $item.Source
                (Get-Item -LiteralPath $item.Target).LastWriteTimeUtc = $sourceInfo.LastWriteTimeUtc

                Write-Host "[$currentItem/$totalItems] FILE UPDATED: $($item.Target)"
            }

            'RemoveFile' {
                if (Test-Path -LiteralPath $item.Target -PathType Leaf) {
                    Remove-Item -LiteralPath $item.Target -Force
                    Write-Host "[$currentItem/$totalItems] FILE REMOVED: $($item.Target)"
                }
            }

            'RemoveDir' {
                if (Test-Path -LiteralPath $item.Target -PathType Container) {
                    $hasChildren = Get-ChildItem -LiteralPath $item.Target -Force | Select-Object -First 1
                    if (-not $hasChildren) {
                        Remove-Item -LiteralPath $item.Target -Force
                        Write-Host "[$currentItem/$totalItems] DIRECTORY REMOVED: $($item.Target)"
                    }
                }
            }
        }
    }

    Write-Progress -Activity 'Mirroring files' -Completed
    Write-Host ''
    Write-Host "Mirror complete. Processed $currentItem item(s)."
}

function Back-ItUpBaby {
    $Source = '/Volumes/GuardianG/PhaysPhotos'
    $Target1 = '/Volumes/Sandbox/Mirror/PhaysPhotos'
    $Target2 = '/Volumes/mine/Media Server/Pictures/PhaysPhotos'

    Start-MirrorShitOp -Source $Source -Target $Target1
    Start-MirrorShitOp -Source $Source -Target $Target2
}