function Add-WhiteSpaceToImageBottoms {
    <#
   .SYNOPSIS
      Doubles the height of all images in a folder.  Keeps picture at the top half.

   .DESCRIPTION
      Doubles the height of all images in a folder.  Keeps picture at the top half.
      This is being used for images where the backs of the photos has also been scanned in.

   .INPUTS
     [System.String] $InputFolder = Folder where the input .jpg/.jpeg, .raw, .nef, .png and .raf files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Add-WhiteSpaceToImageBottoms
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling Add-WhiteSpaceToImageBottoms() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $AllFileTypes = $Global:LossyFileTypes + $Global:RawFileTypes

            $Files = @()
            $Files += foreach ( $FileType in $AllFileTypes ) {
                Get-ChildItem -Path $InputFolder -Filter $FileType -File -ErrorAction SilentlyContinue
            }

            $Index = 0

            if ( $Files.Count -eq 0 ) {
                Write-Warning "No photos found in $InputFolder"
            }
            else {
                Write-Host ''
                Write-Host "Resizing $($Files.Count) images:" -ForegroundColor Cyan

                foreach ( $File in $Files ) {
                    $Index++

                    try {
                        & magick $($File.FullName) -gravity north -background white -extent %wx%[fx:2*h] $($File.FullName)

                        Write-Host "[$Index/$($Files.Count)] Resized $($File.FullName)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        Write-Host "[$Index/$($Files.Count)] Failed resizing $($File.FullName)" -ForegroundColor Red
                    }
                }
            }

            $Result = $Result -band $true
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