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
        [System.Int16] $MaxSizeKB = 2000,

        [Switch] $OverwriteOutputFolder
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling Resize-SmallerizedImage() with the following parameters:'

        $OutputFolder = Join-Path -Path $InputFolder -ChildPath 'Smallerized'

        Write-Verbose "   InputFolder  = $InputFolder"
        Write-Verbose "   OutputFolder = $OutputFolder"
        Write-Verbose "   MaxSizeKB    = $MaxSizeKB"

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
                Remove-Item $OutputFolder -Recurse -Force | Out-Null
                New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
            }

            $Files = Get-ChildItem -Path $InputFolder/* -Include *.jpg, *.jpeg

            $Index = 0
            
            Write-Host "Smallerizing $($Files.Count) files:" -ForegroundColor Cyan

            foreach ( $File in $Files ) {
                $Index++
                try {
                    $OutputFile = Join-Path $OutputFolder $File.Name
                    magick $File.FullName -define jpeg:extent=${MaxSizeKB}KB $OutputFile
                    Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $OutputFile" -ForegroundColor Green
                }
                catch {
                    $Result = $False
                    Write-Host "[$Index/$($Files.Count)] $($File.Name) -> $OutputFile" -ForegroundColor Green
                }
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