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
        [System.String] $FilenamePrefix = 'Photo-'
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $true

        Write-Verbose 'Calling Rename-PhotoFiles() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verobse "   FilenamePrefix = $FilenamePrefix"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if ( -not (Test-Path $InputFolder) ) { throw "$InputFolder does not exist, bailing!" }

            foreach ( $FileType in $Global:LossyFileTypes ) {
                Write-Verbose "Processing file type: $FileType"

                $Files = Get-ChildItem -Path $InputFolder -Filter $FileType -File | Sort-Object CreationTime

                foreach ( $File in $Files ) {
                    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)

                    $RawFile = $Null
                    $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.RAW" -File
                    if (-not $RawFile) {
                        $RawFile = Get-ChildItem -Path $InputFolder -Filter "$BaseName.NEF" -File
                    }

                    if ( $RawFile ) {
                        $NewRawName = '{0}{1:D4}{2}' -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $RawFile.Extension
                        Write-Verbose "   '$RawFile' -> '$NewRawName'"
                        Rename-Item -Path $RawFile.FullName -NewName $NewRawName
                    }

                    $NewName = '{0}{1:D4}{2}' -f $FilenamePrefix, ($Files.IndexOf($File) + 1), $File.Extension

                    $NewPath = Join-Path -Path $File.DirectoryName -ChildPath $NewName

                    Write-Verbose "Renaming file to: $NewPath"

                    Rename-Item -Path $File.FullName -NewName $NewName

                    Write-Host "   '$($File.Name)' -> '$NewName'"
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