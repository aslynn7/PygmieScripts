function Resize-SmallerizedImage {
    <#
   .SYNOPSIS
      Shrinks a large image file to a smaller file.

   .DESCRIPTION
      Shrinks (Smallerizes) a large image file to a smaller file.

   .INPUTS
        [System.String] $InputFolder = Folder where the input .jpg/.jpeg files are located.
        [System.String] $OutputFolder = Folder where the output Smallerized photos are to be written.
        [System.Int16] $MaxSizeKB = Size of the Smallerized image file.
        [Switch] $OverwriteOutputFolder = If specified, will overwrite the output folder if it already exists.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      C:\PS> Resize-SmallerizedImage

   .NOTES
      This function only works on MacOS.  Requires installation of ImageMagick and ExifTool.
      Ensure they're installed and in your PATH.
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [System.String] $OutputFolder = "$PWD/Smallerized",

        [Parameter(Mandatory = $False)]
        [System.Int16] $MaxSizeKB = 2000,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $false

        Write-Host 'Calling Resize-SmallerizedImage() with the following parameters:'

        Write-Host "   InputFolder  = $InputFolder"
        Write-Host "   OutputFolder = $OutputFolder"
        Write-Host "   MaxSizeKB    = $MaxSizeKB"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            if (-not (Test-Path $OutputFolder)) {
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }
            elseif ($OverwriteOutputFolder) {
                Write-Verbose "Overwriting existing output folder: $OutputFolder"
                Remove-Item $OutputFolder -Recurse -Force
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            Write-Host ''
            Write-Host 'Smallerizing files:'

            Get-ChildItem -Path $InputFolder\* -Include *.jpg, *.jpeg | ForEach-Object {
                $OutputFile = Join-Path $OutputFolder $_.Name
                magick $_.FullName -define jpeg:extent=${MaxSizeKB}KB $OutputFile
                Write-Host "Processed $($_.Name)"
            }

            $Result = $true
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