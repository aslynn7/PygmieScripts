# GROK THIS NEEDS WORK AND ADDED TO PP


function Convert-ImagesToBW {
    param (
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    $source = Get-ChildItem -Path $InputFolder -Filter *.jpg -File

    Get-ChildItem -Filter *.jpg | ForEach-Object {
        $out = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + '_bw.jpg'
        magick $_.FullName -colorspace Gray $out
    }
}   

