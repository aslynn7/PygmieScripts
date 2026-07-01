function Write-SummaryTable {
    <#
    .SYNOPSIS
        Renders a formatted ASCII summary table to the host.

    .DESCRIPTION
        Private helper used by all PygmieStudios functions to display a consistent
        bordered summary table at the end of an operation. Each row has a label,
        a count, and a color applied to both.

    .INPUTS
        [string]          $Title = Text shown in the header row of the table.
        [pscustomobject[]] $Rows  = Array of objects with Label, Count, and Color properties.

    .EXAMPLE
        Write-SummaryTable -Title 'My Operation' -Rows @(
            [pscustomobject]@{ Label = 'Files succeeded'; Count = 42;  Color = 'Green' }
            [pscustomobject]@{ Label = 'Files failed';    Count = 0;   Color = 'Cyan'  }
        )
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [pscustomobject[]] $Rows
    )

    $LW = 22
    $VW = 8

    $inner     = " $Title "
    $titlePad  = [Math]::Floor(($LW - $inner.Length) / 2)
    $titleRow  = (' ' * $titlePad) + $inner + (' ' * ($LW - $inner.Length - $titlePad))

    Write-Host ''
    Write-Host "  ┌$('─' * $LW)┬$('─' * $VW)┐"
    Write-Host "  │$titleRow│$(' ' * $VW)│"
    Write-Host "  ├$('─' * $LW)┼$('─' * $VW)┤"

    foreach ($row in $Rows) {
        $label = ("  $($row.Label)").PadRight($LW)
        $value = (' ' + $row.Count.ToString('N0').PadLeft($VW - 2) + ' ')
        Write-Host '  │' -NoNewline
        Write-Host $label -ForegroundColor $row.Color -NoNewline
        Write-Host '│' -NoNewline
        Write-Host $value -ForegroundColor $row.Color -NoNewline
        Write-Host '│'
    }

    Write-Host "  └$('─' * $LW)┴$('─' * $VW)┘"
    Write-Host ''
}
