<#
.SYNOPSIS
    Read-only inventory of a World of Warcraft 3.3.5a folder.
.DESCRIPTION
    Writes ONLY filenames and approximate sizes. Does not inspect game settings
    or save data and does not modify or upload any game files.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ClientPath
)

$ErrorActionPreference = 'Stop'

try {
    $root = (Resolve-Path -LiteralPath $ClientPath).ProviderPath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'The supplied path is not a folder.'
    }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('Naxxramas Client - Read-Only Inventory')
    $lines.Add('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $lines.Add('Only filenames and approximate file sizes are listed.')
    $lines.Add('No client files are modified or uploaded.')
    $lines.Add('')

    $lines.Add('=== CLIENT ROOT (ONE LEVEL ONLY) ===')
    foreach ($item in (Get-ChildItem -LiteralPath $root -Force | Sort-Object Name)) {
        if ($item.PSIsContainer) {
            $lines.Add('[FOLDER] ' + $item.Name)
        }
        else {
            $lines.Add(('[FILE] {0} ({1:N1} MB)' -f $item.Name, ($item.Length / 1MB)))
        }
    }
    $lines.Add('')

    $dataFolder = Join-Path $root 'Data'
    $lines.Add('=== DATA MPQ ARCHIVES ===')
    if (Test-Path -LiteralPath $dataFolder -PathType Container) {
        $mpqs = @(Get-ChildItem -LiteralPath $dataFolder -Recurse -File |
            Where-Object { $_.Extension -ieq '.mpq' } |
            Sort-Object FullName)
        foreach ($mpq in $mpqs) {
            $relative = $mpq.FullName.Substring($dataFolder.Length) -replace '^[\\/]+', ''
            $lines.Add(('{0} ({1:N1} MB)' -f $relative, ($mpq.Length / 1MB)))
        }
        if ($mpqs.Count -eq 0) {
            $lines.Add('(none found)')
        }
    }
    else {
        $lines.Add('(Data folder not found)')
    }
    $lines.Add('')

    $addonsFolder = Join-Path (Join-Path $root 'Interface') 'AddOns'
    $lines.Add('=== ADDON FOLDER NAMES ONLY ===')
    if (Test-Path -LiteralPath $addonsFolder -PathType Container) {
        $addons = @(Get-ChildItem -LiteralPath $addonsFolder -Directory | Sort-Object Name)
        foreach ($addon in $addons) {
            $lines.Add($addon.Name)
        }
        if ($addons.Count -eq 0) {
            $lines.Add('(none found)')
        }
    }
    else {
        $lines.Add('(Interface\AddOns folder not found)')
    }

    $outputFile = Join-Path $PSScriptRoot 'client-inventory.txt'
    $lines | Set-Content -LiteralPath $outputFile -Encoding UTF8
    Write-Host ''
    Write-Host 'Inventory completed successfully.' -ForegroundColor Green
    Write-Host ('Saved to: ' + $outputFile)
    Write-Host 'Please review it before sharing.'
}
catch {
    Write-Error ('Inventory failed: ' + $_.Exception.Message)
    exit 1
}
