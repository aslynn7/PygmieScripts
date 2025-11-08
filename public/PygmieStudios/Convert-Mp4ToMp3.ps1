
$File = '2025-11-07 23-21-18'




function Convert-Mp4ToMp3 {
    <#
   .SYNOPSIS
      Converts an MP4 to and MP3 file.

   .DESCRIPTION
      Converts an MP4 to and MP3 file.

   .INPUTS
     [System.String] $InputFile = (Optional) Input .mp4 file.
     [System.String] $OutputFile = (Optional) Output .mp3 file.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Convert-Mp4ToMp3 -InputFile $InputMp4

      .EXAMPLE
      Convert-Mp4ToMp3 -InputFile $InputMp4 -OutputFile $OutputMp3
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFile = $Null,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = $Null 
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $False

        Write-Verbose 'Calling Convert-VideoToStreamableVersion() with the following parameters:'

        if ( -not $InputFile ) {
            $InputFile = Read-Host 'Enter the input file name'
        }
        if ( -not $OutputFile ) {
            $OutputFile = $InputFile.Replace('.mp4', '.mp3')
        }

        Write-Verbose "   InputFolder  = $InputFile"
        Write-Verbose "   InputFolder  = $OutputFile"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        if ( -not ( Test-Path "$InputFile" ) ) {
            Write-Warning "The input file does not exist:  $InputFile "
            $Result = $false
        }
        else {
            try {
                ffmpeg -i "$InputFile" -vn -acodec libmp3lame -b:a 192k "$OutputFile"
                $Result = $true 
            }
            catch {
                throw $("Error encountered in [$($MyInvocation.MyCommand.Name)] - " + $_.Exception)
            }
        }

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"

        return $Result

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'end' block"
    }
}