#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$scriptPath = Join-Path $repo 'tools/Test-Naxxramas-Client.ps1'
$hashPath = Join-Path $repo 'tools/Get-Core-Patch-Hashes.ps1'
$policyPath = Join-Path $repo 'config/client-patches.json'

foreach ($path in @($scriptPath,$hashPath)) {
  $tokens = $null
  $parseErrors = $null
  [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if (@($parseErrors).Count -gt 0) {
    throw ("PowerShell syntax errors in {0}: {1}" -f $path, ($parseErrors -join '; '))
  }
}
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
if (@($policy.patches).Count -ne 4) { throw 'Expected exactly four patch policy entries.' }
foreach ($name in @('Data/patch-V.mpq','Data/patch-Z.mpq')) {
  $patch = @($policy.patches | Where-Object { $_.path -eq $name })
  if ($patch.Count -ne 1 -or -not $patch[0].required -or $patch[0].allow_disable) {
    throw "Core patch policy violated for $name"
  }
}
foreach ($name in @('Data/Patch-J.mpq','Data/Patch-U.mpq')) {
  $patch = @($policy.patches | Where-Object { $_.path -eq $name })
  if ($patch.Count -ne 1 -or $patch[0].required -or -not $patch[0].allow_disable -or
      $patch[0].sha256 -notmatch '^[a-f0-9]{64}$') {
    throw "Optional patch policy violated for $name"
  }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('naxx-preflight-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -Path (Join-Path $fixture 'Data/enUS') -ItemType Directory -Force | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $fixture 'Wow.exe'), [byte[]]@())
  function Run-Check([string[]]$extra) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath,'-ClientPath',$fixture) + $extra
    & powershell.exe @arguments | Out-Null
    return $LASTEXITCODE
  }
  if ((Run-Check @()) -eq 0) { throw 'Check should fail when mandatory MPQs are missing.' }

  Set-Content -LiteralPath (Join-Path $fixture 'Data/patch-V.mpq') -Value 'dummy V' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture 'Data/patch-Z.mpq') -Value 'dummy Z' -Encoding ASCII
  $vBefore = (Get-FileHash -LiteralPath (Join-Path $fixture 'Data/patch-V.mpq')).Hash
  $zBefore = (Get-FileHash -LiteralPath (Join-Path $fixture 'Data/patch-Z.mpq')).Hash
  if ((Run-Check @()) -ne 0) { throw 'Check should succeed with both required files present (unverified fingerprints generate warnings).' }
  if ((Run-Check @('-VanillaLogin')) -eq 0) { throw 'Check should fail when a selected optional patch is missing.' }
  if ((Run-Check @('-RealmHost','https://bad/path')) -eq 0) { throw 'Check should reject an invalid realm hostname.' }

  if ((Get-FileHash -LiteralPath (Join-Path $fixture 'Data/patch-V.mpq')).Hash -ne $vBefore) {
    throw 'Preflight modified patch V.'
  }
  if ((Get-FileHash -LiteralPath (Join-Path $fixture 'Data/patch-Z.mpq')).Hash -ne $zBefore) {
    throw 'Preflight modified patch Z.'
  }
  Write-Host 'All read-only preflight smoke tests passed.' -ForegroundColor Green
}
finally {
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
