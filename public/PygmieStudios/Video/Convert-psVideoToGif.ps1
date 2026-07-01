function Convert-psVideoToGif {
    <#
    .SYNOPSIS
        Converts a video file to an animated GIF.

    .DESCRIPTION
        Uses ffmpeg with a two-pass palette method to produce a high-quality animated
        GIF from an input video. The output is scaled to the specified width while
        preserving the aspect ratio. Frame rate and loop behavior are configurable.

    .INPUTS
        [System.String] $InputFile  = Path to the source video file.
        [System.String] $OutputFile = Path for the output GIF. Defaults to InputFile with .gif extension.
        [System.Int32]  $Fps        = Frame rate of the output GIF. Default is 10.
        [System.Int32]  $Width      = Output width in pixels. Height auto-scales. Default is 640.
        [System.Int32]  $Loop       = Loop count: 0 = infinite, 1 = play once, etc. Default is 0.

    .OUTPUTS
        [Bool] = $True on success, $False on failure.

    .EXAMPLE
        Convert-psVideoToGif -InputFile '/Volumes/Videos/timelapse.mp4'

    .EXAMPLE
        Convert-psVideoToGif -InputFile '/Volumes/Videos/timelapse.mp4' -Width 480 -Fps 15

    .EXAMPLE
        Convert-psVideoToGif -InputFile '/Volumes/Videos/clip.mp4' -OutputFile '/Desktop/clip.gif' -Loop 1

    .NOTES
        Requires ffmpeg. Install via: brew install ffmpeg
        Two-pass palette method gives significantly better color quality than single-pass.
        GIF files can be large — use lower Fps and Width to control size.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $True)]
        [System.String] $InputFile,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFile = '',

        [Parameter(Mandatory = $False)]
        [System.Int32] $Fps = 10,

        [Parameter(Mandatory = $False)]
        [System.Int32] $Width = 640,

        [Parameter(Mandatory = $False)]
        [System.Int32] $Loop = 0
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $False

        if ([System.String]::IsNullOrEmpty($OutputFile)) {
            $OutputFile = [System.IO.Path]::ChangeExtension($InputFile, '.gif')
        }

        $PaletteFile = [System.IO.Path]::ChangeExtension($OutputFile, '.palette.png')

        Write-Verbose "   InputFile   = $InputFile"
        Write-Verbose "   OutputFile  = $OutputFile"
        Write-Verbose "   Fps         = $Fps"
        Write-Verbose "   Width       = $Width"
        Write-Verbose "   Loop        = $Loop"

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path -LiteralPath $InputFile)) {
                throw "Input file does not exist: $InputFile"
            }

            Write-Host "Converting to GIF: $InputFile" -ForegroundColor Cyan
            Write-Host "  Output : $OutputFile" -ForegroundColor DarkGray
            Write-Host "  Size   : ${Width}px wide @ ${Fps}fps" -ForegroundColor DarkGray
            Write-Host ''

            Write-Host '  Pass 1: Generating palette...' -ForegroundColor DarkGray
            & ffmpeg -y -i $InputFile `
                -vf "fps=${Fps},scale=${Width}:-1:flags=lanczos,palettegen" `
                $PaletteFile

            if ($LASTEXITCODE -ne 0) { throw "ffmpeg palette pass returned exit code $LASTEXITCODE" }

            Write-Host '  Pass 2: Rendering GIF...' -ForegroundColor DarkGray
            & ffmpeg -y -i $InputFile -i $PaletteFile `
                -filter_complex "fps=${Fps},scale=${Width}:-1:flags=lanczos[x];[x][1:v]paletteuse" `
                -loop $Loop `
                $OutputFile

            if ($LASTEXITCODE -ne 0) { throw "ffmpeg render pass returned exit code $LASTEXITCODE" }

            $SizeKB = [Math]::Round((Get-Item $OutputFile).Length / 1KB)
            $Result = $True

            Write-Host ''
            Write-SummaryTable -Title 'Video to GIF' -Rows @(
                [pscustomobject]@{ Label = 'Output size KB'; Count = $SizeKB; Color = 'Green' }
                [pscustomobject]@{ Label = 'Frame rate fps'; Count = $Fps;    Color = 'Cyan'  }
                [pscustomobject]@{ Label = 'Width pixels';   Count = $Width;  Color = 'Cyan'  }
            )
        }
        catch {
            throw "Error encountered in [$($MyInvocation.MyCommand.Name)] - $($_.Exception.Message)"
        }
        finally {
            Remove-Item $PaletteFile -Force -ErrorAction SilentlyContinue
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Exiting 'process' block"
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] - Entering 'end' block"
        return $Result
    }
}
