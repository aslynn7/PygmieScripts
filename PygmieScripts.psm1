[CmdletBinding()]

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]

param()

Set-StrictMode -Version Latest

$Public  = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Public\*.ps1  -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$Local   = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Local\*.ps1   -ErrorAction SilentlyContinue)

foreach ($import in @($Private + $Public + $Local)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

#Import the Configuration File
try {
    $Global:PygmieScriptsConfig = Get-Content $PSScriptRoot\config\config.json | ConvertFrom-Json
}
catch {
    Write-Error -Message "There was an error importing the configuration file config\config.json: $_"
}

$Global:LossyFileTypes = @('*.jpg', '*.jpeg')
$Global:RawFileTypes   = @('*.png', '*.raw', '*.nef', '*.bmp', '*.cr2', '*.tif', '*.tiff')

$Global:ProcessSubfolders = $False
$Global:LastCommandResults = $Null