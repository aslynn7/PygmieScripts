function Rename-PhotoFiles {
    <#
   .SYNOPSIS
      Blah

   .DESCRIPTION
      Blah

   .INPUTS
        Blah

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Blah

   .NOTES
      Blah
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $FilenamePrefix = $Null,

        [Switch] $SkipFolderNamePrefixing
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Verbose 'Calling Rename-PhotoFiles() with the following parameters:'

        if ( $SkipFolderNamePrefixing ) {
            if ( [System.String]::IsNullOrEmpty( $FilenamePrefix ) ) {
                $FilenamePrefix = 'Photo-'
            }
        }
        else {
            $FolderName = ( Split-Path -Path $InputFolder -Leaf )
            if ( [System.String]::IsNullOrEmpty( $FilenamePrefix ) ) {
                $FilenamePrefix = "$FolderName-Photo-"
            }
            else {
                $FilenamePrefix = "$FolderName-$FilenamePrefix"
            }
        }

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   FilenamePrefix = $FilenamePrefix"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if ( -not (Test-Path $InputFolder) ) { throw "$InputFolder does not exist, bailing!" }

            $FileTypeIndex = 0
            foreach ( $FileType in $Global:LossyFileTypes ) {
                $FileTypeIndex++

                Write-Verbose "Processing file type: $FileType"

                $Files = Get-ChildItem -Path $InputFolder -Filter $FileType -File | Sort-Object LastWriteTime

                $FileIndex = 0
                foreach ( $File in $Files ) {
                    $FileIndex++
                    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
                    $NewName = '{0}{1:D4}{2}' -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $File.Extension

                    Rename-Item -Path $File.FullName -NewName $NewName
                    Write-Host "[$FileTypeIndex][$FileIndex] Renaming $($File.Name) -> $NewName" -ForegroundColor Green

                    $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.RAW" -File
                    if ( -not $RawFile ) {
                        $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.NEF" -File
                    }
                    if ( -not $RawFile ) {
                        $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.PNG" -File
                    }

                    if ( $RawFile ) {
                        $NewRawName = '{0}{1:D4}{2}' -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $RawFile.Extension

                        Rename-Item -Path $RawFile.FullName -NewName $NewRawName
                        Write-Host "[$FileTypeIndex][$FileIndex] $RawFile -> $NewRawName" -ForegroundColor Green
                    }
                }
            }

            $Result = $True
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