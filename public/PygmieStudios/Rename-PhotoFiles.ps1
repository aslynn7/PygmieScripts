function Rename-PhotoFiles {
    <#
   .SYNOPSIS
      Renames photo files in a folder to a standardized format.

   .DESCRIPTION
      Renames photo files in a folder to a standardized format.

   .INPUTS
      InputFolder = The folder containing the photo files to rename.  The default is the current working directory.
      FilenamePrefix = The prefix to use for the renamed files.  The default is 'Photo-'.
      UseFolderNamePrefixing = If set, uses the folder name as the prefix, not the passed in Filename Prefix.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Rename-PhotoFiles

   .EXAMPLE
      Rename-PhotoFiles -FilenamePrefix 'Vacation-'

   .EXAMPLE
      Rename-PhotoFiles -UseFolderNamePrefixing
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
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Verbose 'Calling Rename-PhotoFiles() with the following parameters:'

        if ( $UseFolderNamePrefixing ) {
            $FilenamePrefix = Split-Path -Path $InputFolder -Leaf
            $FilenamePrefix += '-'
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   FilenamePrefix = $FilenamePrefix"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if ( -not (Test-Path $InputFolder) ) { throw "$InputFolder does not exist, bailing!" }

            $AllFileTypes = $Global:LossyFileTypes + $Global:RawFileTypes

            $FileTypeIndex = 0
            foreach ( $FileType in $AllFileTypes ) {
                $FileTypeIndex++

                Write-Verbose "Processing file type: $FileType"

                $Files = Get-ChildItem -Path $InputFolder -Filter $FileType -File | Sort-Object LastWriteTime

                $FileIndex = 0
                foreach ( $File in $Files ) {
                    try {
                        $null = Get-Item -Path $File.FullName -ErrorAction Stop

                        $FileIndex++
                        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
                        $Digits = [Math]::Max( [Math]::Ceiling( [Math]::Log10( [Math]::Max($Files.Count, 1) + 1 ) ), 1 )
                        $NewName = ("{0}{1:D$Digits}{2}" -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $File.Extension)

                        Rename-Item -Path $File.FullName -NewName $NewName
                        Write-Host "[$FileTypeIndex][$FileIndex/$($Files.Count)] Renaming $($File.Name) -> $NewName" -ForegroundColor Green

                        $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.RAW" -File
                        if ( -not $RawFile ) {
                            $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.NEF" -File
                        }
                        if ( -not $RawFile ) {
                            $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.PNG" -File
                        }

                        if ( $RawFile ) {
                            $NewRawName = ("{0}{1:D$Digits}{2}" -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $RawFile.Extension)

                            Rename-Item -Path $RawFile.FullName -NewName $NewRawName

                            Write-Host "[$FileTypeIndex][$FileIndex] $RawFile -> $NewRawName" -ForegroundColor Green
                        }

                        $Result = $Result -band $true
                    }
                    catch {
                        Write-Warning "Failed renaming $($File.FullName), continuing..."

                        $Result = $false
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