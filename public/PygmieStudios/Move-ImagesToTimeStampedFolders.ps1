function Move-ImagesToTimeStampedFolders {
    <#
   .SYNOPSIS
      Sorts images into named folders by creation date.

   .DESCRIPTION
      Sorts images into named folders by creation date.

   .INPUTS
      [System.String] $InputFolder = Folder where the images are located. Default is the current working directory.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Move-ImagesToTimeStampedFolders
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

        Write-Verbose 'Calling Move-ImagesToTimeStampedFolders() with the following parameters:'

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

            $Files = $Files | Sort-Object -Property LastWriteTime -Descending

            $Index = 0

            if ( $Files.Count -eq 0 ) {
                Write-Warning "No image files found in input folder: $InputFolder"
                $Result = $True
            }
            else {
                Write-Host ''
                Write-Host "Moving $($Files.Count) images from: $($InputFolder)" -ForegroundColor Cyan

                $TargetFolders = @()

                foreach ( $File in $Files ) {
                    $Index++

                    try {
                        [System.String] $DateTaken = ([DateTime]$File.LastWriteTime ).ToString('MM-dd-yyyy')

                        $WriteToFolder = Join-Path $InputFolder -ChildPath $DateTaken

                        if ( $TargetFolders -notcontains $WriteToFolder ) {
                            Write-Host "To: $WriteToFolder" -ForegroundColor Cyan
                        }

                        $TargetFolders += $WriteToFolder

                        if ( -not ( Test-Path $WriteToFolder ) ) {
                            New-Item -Path $WriteToFolder -ItemType Directory -Force | Out-Null
                        }

                        Move-Item -Path $File.FullName -Destination $WriteToFolder -Force
                        Write-Host "   [$Index/$($Files.Count)] $($File.FullName) -> $($InputFolder)/$DateTaken" -ForegroundColor Green
                    }
                    catch {
                        $Result = $False
                        Write-Host "   [$Index/$($Files.Count)] $($File.FullName) -> $($InputFolder)/$DateTaken" -ForegroundColor Red
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