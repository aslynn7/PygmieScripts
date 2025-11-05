function Convert-VideoToStreamableVersion {
    <#
   .SYNOPSIS
      Converts a large .mp4 to a smaller, betterer, version for streaming.

   .DESCRIPTION
      Converts a large .mp4 to a smaller, betterer, version for streaming.

   .INPUTS
     [System.String] $InputFile = Input .mp4 file
     [System.String] $OutputFile = (Optional) Output .mp4 file.  If not passed, is name of the input file with "_smallerized" prefix.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Convert-VideoToStreamableVersion -InputFile $InputFile

      .EXAMPLE
      Convert-VideoToStreamableVersion -InputFile $InputFile -OutputFile $OutputFile
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $True)]
        [System.String] $InputFile,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $False

        Write-Verbose 'Calling Convert-VideoToStreamableVersion() with the following parameters:'

        if ( [System.String]::IsNullOrEmpty($OutputFile) ) {
            $Base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
            $Ext = [System.IO.Path]::GetExtension($InputFile)
            $OutputFile = "${Base}_smallerized$Ext"
        }

        Write-Verbose "   InputFolder  = $InputFile"
        Write-Verbose "   InputFolder  = $OutputFile"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            ffmpeg -i $InputFile -c:v libx264 -crf 26 -preset slow -vf scale=1280:-2 -c:a aac -b:a 128k -movflags +faststart $OutputFile
        }
        catch {
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