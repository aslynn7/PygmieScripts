function Combine-FrontAndBackScans {
    <#
   .SYNOPSIS
      xxx

   .DESCRIPTION
      xxx

   .INPUTS
     [System.String] $InputFolder = Folder where the input .jpg/.jpeg, .raw, .nef, .png and .raf files are located.

   .OUTPUTS
      [Bool] = $True on success (or lack of exceptions), $False on failure.

   .EXAMPLE
      Combine-FrontAndBackScans
#>
    [CmdletBinding()]
    [OutputType([Bool])]

    param(
        [Parameter(Mandatory = $false)]
        [System.String] $InputFolder = $PWD
    )

    # Define valid image extensions
    $validExtensions = @('.jpg', '.jpeg', '.png', '.tif', '.tiff')

    # Get all matching image files in the input folder, sorted alphabetically (using same sort order by name as MacOS Finder)
    $files = Get-ChildItem -Path $InputFolder -File |
    Where-Object { $validExtensions -contains $_.Extension.ToLower() } |
    Sort-Object {
        # take the filename
        $name = $_.Name
        # replace every run of digits with a zero-padded version
        # 10 digits is plenty for "…- 38- 34.png" type names
        [regex]::Replace($name, '\d+', { param($m) $m.Value.PadLeft(10, '0') }).ToLower()
    }

    if ($files.Count -lt 2) {
        Write-Host '❌ Not enough image files in this folder to combine. Need at least 2.' -ForegroundColor Yellow
        return
    }

    Write-Host "🔄 Found $($files.Count) image files. Processing in pairs..."

    # Iterate through the files two at a time
    for ($i = 0; $i -lt $files.Count; $i += 2) {
        if ($i -eq $files.Count - 1) {
            Write-Host "⚠ Skipping last file '$($files[$i].Name)' (no pair available)" -ForegroundColor Yellow
            break
        }

        $topImage = $files[$i].FullName
        $bottomImage = $files[$i + 1].FullName

        Write-Host ''
        Write-Host "[$i & $($i + 1)/$($files.Count)] ✅ Combining:"

        Write-Host "   Top   → $($files[$i].Name)"
        Write-Host "   Bottom→ $($files[$i + 1].Name)"

        try {
            Combine-FrontAndBackScansForImage -TopImagePath $topImage -BottomImagePath $bottomImage
        }
        catch {
            Write-Host "❌ Error combining $($files[$i].Name) and $($files[$i + 1].Name): $_" -ForegroundColor Red
        }
    }

    Write-Host '🎉 Finished processing all image pairs.'
}