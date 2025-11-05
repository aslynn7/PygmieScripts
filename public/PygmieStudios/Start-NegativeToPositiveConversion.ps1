function Start-NegativeToPositiveConversion {
    <#
   .SYNOPSIS
      Converts negative images to positive images.

   .DESCRIPTION
      Converts negative images to positive images.

   .INPUTS
     [System.String] $InputFolder = Folder where the input .jpg/.jpeg, .raw, .nef, .png and .raf files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Start-NegativeToPositiveConversion
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Gray', 'RGB')]
        [System.String] $ColorSpace
    )

    begin {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'begin' block"

        [Bool] $Result = $True

        Write-Verbose 'Calling Start-NegativeToPositiveConversion() with the following parameters:'

        Write-Verbose "   InputFolder  = $InputFolder"

        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Exiting 'begin' block"
    }

    process {
        Write-Verbose -Message "[$($MyInvocation.MyCommand.Name)] - Entering 'process' block"

        try {
            $Patterns = $Global:LossyFileTypes + $Global:RawFileTypes

            $Pictures = foreach ( $Pattern in $Patterns ) {
                Get-ChildItem -Path $InputFolder -Filter $Pattern -File -ErrorAction SilentlyContinue
            }

            $Index = 0

            if ( -not $Pictures ) {
                Write-Warning "No pictures found in $InputFolder"
            }
            else {
                Write-Host ''
                Write-Host "Negitivating $($Pictures.Count) images:" -ForegroundColor Cyan

                foreach ( $Picture in $Pictures ) {
                    $Index++

                    try {
                        $InputFile = $Picture.FullName
                        $Extension = [System.IO.Path]::GetExtension($InputFile)
                        if ( $Extension -eq '.cr2' ) {
                            $Extension = '.png'
                        }

                        $OutputFile = "$($InputFile.Substring(0, $InputFile.Length - 4)) ($($ColorSpace)-Negatized)$($Extension)"

                        & magick $InputFile -colorspace $ColorSpace -negate -quality 100 -auto-orient $OutputFile

                        Write-Host "[$Index/$($Pictures.Count)] Converted $($Picture.FullName)" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        Write-Host "[$Index/$($Pictures.Count)] Failed converting $($Picture.FullName)" -ForegroundColor Red
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