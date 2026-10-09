#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ClientPath)
$ErrorActionPreference='Stop'
try {
  $root=(Resolve-Path -LiteralPath $ClientPath).ProviderPath
  foreach ($name in @('patch-V.mpq','patch-Z.mpq')) {
    $path=Join-Path (Join-Path $root 'Data') $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Missing $name in the Data folder."
    }
    $item=Get-Item -LiteralPath $path
    $sha=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    Write-Host ('{0} | {1} bytes | SHA-256: {2}' -f $name,$item.Length,$sha)
  }
  Write-Host 'No files have been modified or uploaded.'
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
