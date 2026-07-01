function Rename-psPhotoFiles {
    <#
    .SYNOPSIS
        Renames all photo files in a folder to a standardized sequential format.

    .DESCRIPTION
        Renames lossy and RAW image files in the input folder using a sequential
        numbering scheme: <prefix>0001.jpg, <prefix>0002.jpg, etc. Files are sorted
        using natural (numeric-aware, case-insensitive) order matching macOS Finder.
        If a matching RAW file (same base name, .raw/.nef/.png extension) exists
        alongside a JPG, it is renamed with the same sequence number.

    .INPUTS
        [System.String] $InputFolder          = Folder containing photo files. Defaults to current directory.
        [System.String] $FilenamePrefix       = Prefix for renamed files. Default is 'Photo-'.
        [Switch]        $UseFolderNamePrefixing = When specified, uses the folder's name as the prefix.

    .OUTPUTS
        [Bool] = $True on full success, $False if any rename fails.

    .EXAMPLE
        Rename-psPhotoFiles

    .EXAMPLE
        Rename-psPhotoFiles -FilenamePrefix 'Vacation-'

    .EXAMPLE
        Rename-psPhotoFiles -UseFolderNamePrefixing

    .NOTES
        Files are renamed in-place; no output folder is created.
        RAW companions are co-renamed alongside their JPG counterparts.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $FilenamePrefix = 'Photo-',

        [Switch] $UseFolderNamePrefixing
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        if ($UseFolderNamePrefixing) {
            $FilenamePrefix = (Split-Path -Path $InputFolder -Leaf) + '-'
        }

        Write-Verbose "   InputFolder    = $InputFolder"
        Write-Verbose "   FilenamePrefix = $FilenamePrefix"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path $InputFolder)) { throw "$InputFolder does not exist." }

            $countRenamed = 0
            $countFailed  = 0

            foreach ($FileType in ($Global:LossyFileTypes + $Global:RawFileTypes)) {
                $Files = Get-ChildItem -Path $InputFolder -Filter $FileType -File |
                    Sort-Object {
                        [regex]::Replace($_.Name, '\d+', { param($m) $m.Value.PadLeft(10, '0') }).ToLower()
                    }

                if ($Files.Count -eq 0) { continue }

                $Digits    = [Math]::Max([Math]::Ceiling([Math]::Log10([Math]::Max($Files.Count, 1) + 1)), 1)
                $FileIndex = 0

                foreach ($File in $Files) {
                    $FileIndex++
                    try {
                        $null = Get-Item -Path $File.FullName -ErrorAction Stop

                        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
                        $NewName  = '{0}{1:D' + $Digits + '}{2}' -f $FilenamePrefix, $FileIndex, $File.Extension

                        Rename-Item -Path $File.FullName -NewName $NewName
                        $countRenamed++
                        Write-Host "[$FileIndex/$($Files.Count)] $($File.Name) -> $NewName" -ForegroundColor Green

                        $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.RAW" -File -ErrorAction SilentlyContinue
                        if (-not $RawFile) { $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.NEF" -File -ErrorAction SilentlyContinue }
                        if (-not $RawFile) { $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.PNG" -File -ErrorAction SilentlyContinue }

                        if ($RawFile) {
                            $NewRawName = '{0}{1:D' + $Digits + '}{2}' -f $FilenamePrefix, $FileIndex, $RawFile.Extension
                            Rename-Item -Path $RawFile.FullName -NewName $NewRawName
                            $countRenamed++
                            Write-Host "   + companion: $($RawFile.Name) -> $NewRawName" -ForegroundColor DarkGreen
                        }
                    }
                    catch {
                        $Result = $false
                        $countFailed++
                        Write-Warning "Failed renaming $($File.FullName) — $_"
                    }
                }
            }

            Write-SummaryTable -Title 'Rename Photos' -Rows @(
                [pscustomobject]@{ Label = 'Files renamed'; Count = $countRenamed; Color = 'Green' }
                [pscustomobject]@{ Label = 'Files failed';  Count = $countFailed;  Color = if ($countFailed -gt 0) { 'Red' } else { 'Cyan' } }
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
