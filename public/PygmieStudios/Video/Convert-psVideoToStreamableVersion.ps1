function Convert-psVideoToStreamableVersion {
    <#
    .SYNOPSIS
        Converts a large MP4 to a smaller, web-optimized streaming version.

    .DESCRIPTION
        Re-encodes an input MP4 file using H.264 video (libx264, CRF 26, slow preset)
        and AAC audio (128k), scaled to 1280px wide at the original aspect ratio.
        The -movflags +faststart flag is applied so playback can begin before the file
        is fully downloaded. Output is written alongside the input file with a
        '_smallerized' suffix unless an explicit output path is provided.

    .INPUTS
        [System.String] $InputFile  = Path to the source MP4 file.
        [System.String] $OutputFile = (Optional) Path for the output file. Defaults to InputFile_smallerized.mp4.

    .OUTPUTS
        [Bool] = $True on success, $False on failure.

    .EXAMPLE
        Convert-psVideoToStreamableVersion -InputFile '/Volumes/Videos/event.mp4'

    .EXAMPLE
        Convert-psVideoToStreamableVersion -InputFile '/Volumes/Videos/event.mp4' -OutputFile '/Volumes/Web/event_web.mp4'

    .NOTES
        Requires ffmpeg. Install via: brew install ffmpeg
        CRF 26 is a good balance of quality/size. Lower = higher quality, larger file.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $True)]
        [System.String] $InputFile,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = ''
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $False

        if ([System.String]::IsNullOrEmpty($OutputFile)) {
            $Base       = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
            $Ext        = [System.IO.Path]::GetExtension($InputFile)
            $OutputFile = Join-Path (Split-Path $InputFile -Parent) "${Base}_smallerized${Ext}"
        }

        Write-Verbose "   InputFile  = $InputFile"
        Write-Verbose "   OutputFile = $OutputFile"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFile)) {
                throw "Input file does not exist: $InputFile"
            }

            Write-Host "Converting: $InputFile" -ForegroundColor Cyan
            Write-Host "       To : $OutputFile" -ForegroundColor Cyan
            Write-Host ''

            ffmpeg -i $InputFile -c:v libx264 -crf 26 -preset slow -vf scale=1280:-2 -c:a aac -b:a 128k -movflags +faststart $OutputFile

            if ($LASTEXITCODE -eq 0) {
                $Result = $True
                Write-Host ''
                Write-SummaryTable -Title 'Video Convert' -Rows @(
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

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
