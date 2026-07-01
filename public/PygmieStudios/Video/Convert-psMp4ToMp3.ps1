function Convert-psMp4ToMp3 {
    <#
    .SYNOPSIS
        Extracts and converts the audio track from an MP4 file to MP3.

    .DESCRIPTION
        Uses ffmpeg to strip the video track and re-encode the audio as a 192kbps MP3.
        If no input file is provided, prompts for one interactively. Output defaults
        to the same path and base name as the input file with a .mp3 extension.

    .INPUTS
        [System.String] $InputFile  = Path to the source MP4 file. If omitted, prompts for input.
        [System.String] $OutputFile = Path for the output MP3 file. Defaults to InputFile with .mp3 extension.

    .OUTPUTS
        [Bool] = $True on success, $False on failure or if input file not found.

    .EXAMPLE
        Convert-psMp4ToMp3 -InputFile '/Volumes/Videos/recording.mp4'

    .EXAMPLE
        Convert-psMp4ToMp3 -InputFile '/Volumes/Videos/recording.mp4' -OutputFile '/Volumes/Music/recording.mp3'

    .NOTES
        Requires ffmpeg. Install via: brew install ffmpeg
        Audio bitrate is fixed at 192kbps. Video track is discarded (-vn flag).
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFile = '',

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = ''
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $False

        if ([System.String]::IsNullOrEmpty($InputFile)) {
            $InputFile = Read-Host 'Enter the input file name'
        }
        if ([System.String]::IsNullOrEmpty($OutputFile)) {
            $OutputFile = [System.IO.Path]::ChangeExtension($InputFile, '.mp3')
        }

        Write-Verbose "   InputFile  = $InputFile"
        Write-Verbose "   OutputFile = $OutputFile"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        if (-not (Test-Path -LiteralPath $InputFile)) {
            Write-Warning "Input file does not exist: $InputFile"
            $Result = $false
        }
        else {
            try {
                Write-Host "Converting: $InputFile" -ForegroundColor Cyan
                Write-Host "       To : $OutputFile" -ForegroundColor Cyan
                Write-Host ''

                ffmpeg -i "$InputFile" -vn -acodec libmp3lame -b:a 192k "$OutputFile"

                if ($LASTEXITCODE -eq 0) {
                    $Result = $true
                    Write-SummaryTable -Title 'MP4 to MP3' -Rows @(
                        [pscustomobject]@{ Label = 'Status'; Count = 1; Color = 'Green' }
                    )
                }
                else {
                    throw "ffmpeg returned exit code $LASTEXITCODE"
                }
            }
            catch {
                throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
            }
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
