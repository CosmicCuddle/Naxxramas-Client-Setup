#requires -Version 5.1
# Windows-only, disposable fixtures. No real game files used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$policyPath = Join-Path $repo 'config/client-patches.json'
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$realmPolicy = Get-Content -LiteralPath (Join-Path $repo 'config/realm.json') -Raw | ConvertFrom-Json
$realmTemplate = Join-Path $repo 'templates/realmlist.wtf'
if ($realmPolicy.schema_version -ne 1 -or
    $realmPolicy.host -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' -or
    $realmPolicy.relative_path -ne 'Data/enUS/realmlist.wtf') {
  throw 'Unexpected initial default realm configuration.'
}
if (-not (Test-Path -LiteralPath $realmTemplate -PathType Leaf)) { throw 'Missing realmlist template.' }
$rawTemplate = Get-Content -LiteralPath $realmTemplate -Raw -Encoding ASCII
if ($rawTemplate -ne ('set realmlist ' + $realmPolicy.host) -or
    $realmPolicy.line -ne $rawTemplate) {
  throw 'Realmlist template does not match config/realm.json.'
}


foreach ($name in @('Test-Naxxramas-Client.ps1','Get-Core-Patch-Hashes.ps1','Prepare-Patch-Update.ps1')) {
  $path = Join-Path (Join-Path $repo 'tools') $name
  $tokens = $null
  $parseErrors = $null
  [Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors) | Out-Null
  if (@($parseErrors).Count -ne 0) { throw ("Syntax error in {0}: {1}" -f $name, ($parseErrors -join '; ')) }
}
if ($policy.schema_version -ne 1 -or [int]$policy.patch_set_revision -lt 1 -or $policy.patch_set_version -ne ('patchset-{0:D4}' -f [int]$policy.patch_set_revision)) {
  throw 'Unexpected baseline patch version.'
}
if (@($policy.patches).Count -ne 4) { throw 'Four patch entries expected.' }
$versionPath = Join-Path $repo ('config/patch-versions/' + $policy.patch_set_version + '.json')
$history = Get-Content -LiteralPath $versionPath -Raw | ConvertFrom-Json
if ($history.revision -ne $policy.patch_set_revision -or $history.version -ne $policy.patch_set_version) { throw 'Invalid current version history.' }
foreach ($entry in @($policy.patches)) {
  $ref = @($history.patches | Where-Object { $_.path -eq $entry.path })
  if ($ref.Count -ne 1 -or $entry.sha256 -notmatch '^[0-9a-f]{64}$' -or
      [long]$entry.size_bytes -le 0 -or
      $ref[0].sha256 -ne $entry.sha256 -or
      [long]$ref[0].size_bytes -ne [long]$entry.size_bytes) {
    throw "Patch reference or history mismatch: $($entry.path)"
  }
  if ($entry.path -match '^Data/patch-[VZ]\.mpq$') {
    if (-not $entry.required -or $entry.allow_disable) { throw "Core requirement violated: $($entry.path)" }
  } else {
    if ($entry.required -or -not $entry.allow_disable) { throw "Optional requirement violated: $($entry.path)" }
  }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('naxx-version-tests-' + [guid]::NewGuid().ToString('N'))
try {
  $testRepo = Join-Path $fixture 'repo'
  $client = Join-Path $fixture 'game'
  foreach ($folder in @('repo/tools','repo/config','game/Data/enUS')) {
    New-Item -ItemType Directory -Path (Join-Path $fixture $folder) -Force | Out-Null
  }
  Copy-Item -LiteralPath (Join-Path $repo 'tools/Test-Naxxramas-Client.ps1') -Destination (Join-Path $testRepo 'tools/Test-Naxxramas-Client.ps1')
  Copy-Item -LiteralPath (Join-Path $repo 'tools/Prepare-Patch-Update.ps1') -Destination (Join-Path $testRepo 'tools/Prepare-Patch-Update.ps1')
  Copy-Item -LiteralPath (Join-Path $repo 'config/realm.json') -Destination (Join-Path $testRepo 'config/realm.json')
  Set-Content -LiteralPath (Join-Path $client 'Data/enUS/realmlist.wtf') -Value ('set realmlist ' + $realmPolicy.host) -Encoding ASCII
  [IO.File]::WriteAllBytes((Join-Path $client 'Wow.exe'),[byte[]]@())
  $v = Join-Path $client 'Data/patch-V.mpq'
  $z = Join-Path $client 'Data/patch-Z.mpq'
  Set-Content -LiteralPath $v -Value 'fake V1 data' -Encoding ASCII
  Set-Content -LiteralPath $z -Value 'fake Z1 data' -Encoding ASCII
  $fakePolicy = $policy | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  foreach ($p in @($fakePolicy.patches)) {
    if ($p.path -eq 'Data/patch-V.mpq' -or $p.path -eq 'Data/patch-Z.mpq') {
      $f = if ($p.path -eq 'Data/patch-V.mpq') { $v } else { $z }
      $p.sha256 = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLowerInvariant()
      $p.size_bytes = (Get-Item -LiteralPath $f).Length
    }
  }
  $localManifest = Join-Path $testRepo 'config/client-patches.json'
  $fakePolicy | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $localManifest -Encoding UTF8
  $policyHash = (Get-FileHash -LiteralPath $localManifest -Algorithm SHA256).Hash
  $preflight = Join-Path $testRepo 'tools/Test-Naxxramas-Client.ps1'
  $updater = Join-Path $testRepo 'tools/Prepare-Patch-Update.ps1'

  function Invoke-Fixture([string]$file,[string[]]$options) {
    $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$file,'-ClientPath',$client) + @($options)
    $out = (& powershell.exe @argsList 2>&1 | Out-String)
    return [pscustomobject]@{ Code=$LASTEXITCODE; Output=$out }
  }
  $r = Invoke-Fixture $preflight @()
  if ($r.Code -ne 0) { throw "Matching fake core patches should pass preflight: $($r.Output)" }
  if (-not $r.Output.Contains('REALMLIST MATCH')) { throw 'Existing correct realm was not recognised.' }
  $r = Invoke-Fixture $preflight @('-RealmHost','example.org')
  if ($r.Code -ne 0 -or -not $r.Output.Contains('REALMLIST DIFFERENT')) { throw 'Realm override mismatch was not reported safely.' }
  $r = Invoke-Fixture $preflight @('-VanillaLogin')
  if ($r.Code -eq 0 -or -not $r.Output.Contains('Missing selected optional patch')) {
    throw 'Missing selected optional patch was not rejected.'
  }
  $r = Invoke-Fixture $preflight @('-RealmHost','https://invalid/address')
  if ($r.Code -eq 0) { throw 'Invalid realmlist format was accepted.' }

  Set-Content -LiteralPath $v -Value 'fake V2 data' -Encoding ASCII
  $r = Invoke-Fixture $preflight @()
  if ($r.Code -eq 0 -or -not $r.Output.Contains('MISMATCH')) {
    throw 'Changed core patch was not rejected by preflight.'
  }

  $r = Invoke-Fixture $updater @()
  if ($r.Code -ne 0) { throw "Could not prepare patch proposal: $($r.Output)" }
  $proposalFile = Join-Path $testRepo 'tools/patch-update-proposal.json'
  if (-not (Test-Path -LiteralPath $proposalFile)) { throw 'Proposal was not saved.' }
  $proposal = Get-Content -LiteralPath $proposalFile -Raw | ConvertFrom-Json
  if ($proposal.base_patch_set_revision -ne $policy.patch_set_revision -or $proposal.proposed_patch_set_revision -ne ([int]$policy.patch_set_revision + 1) -or
      @($proposal.changes).Count -ne 1 -or $proposal.changes[0].path -ne 'Data/patch-V.mpq' -or
      $proposal.changes[0].new_sha256 -ne (Get-FileHash -LiteralPath $v -Algorithm SHA256).Hash.ToLowerInvariant()) {
    throw 'Proposal did not accurately describe the one changed core patch.'
  }
  $proposalText = Get-Content -LiteralPath $proposalFile -Raw
  if ($proposalText.Contains($fixture)) { throw 'Proposal leaked an absolute local filesystem path.' }
  if ((Get-FileHash -LiteralPath $localManifest -Algorithm SHA256).Hash -ne $policyHash) {
    throw 'Preparing a proposal changed the local reference manifest.'
  }
  $r = Invoke-Fixture $updater @()
  if ($r.Code -eq 0) { throw 'Second run overwrote a pending proposal.' }
  Write-Host 'All version, preflight and patch-proposal fixture tests passed.' -ForegroundColor Green
}
finally {
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

# Clear the last expected failure code from child PowerShell smoke tests.
exit 0
