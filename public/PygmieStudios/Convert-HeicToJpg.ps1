# THIS NEEDS WORK AND ADDED TO PP

function Convert-HeicToJpg {
    param (
        [Parameter(Mandatory = $False)]
        [System.String] $InputFolder = $PWD
    )

    # convert heic (mac stupid pictures) to .jpg

    $source = Get-ChildItem -Path $InputFolder -Filter *.heic -File

    foreach ($file in $source) {
        $output = [System.IO.Path]::ChangeExtension($file.FullName, '.jpg')

        magick "$($file.FullName)" `
            -quality 92 `
            -strip `
            "$output"
    }
}   

