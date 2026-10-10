#requires -Version 5.1
<#
  Naxxramas client preflight (READ ONLY).
  Checks required core patches, optional visual patches, WoW build metadata,
  local N Addon Suite layout and realm hostname/current realmlist comparison.
  Does not install, copy, delete, download or edit game files.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ClientPath,
  [string]$PatchSourcePath,
  [switch]$VanillaLogin,
  [switch]$TbcLogin,
  [switch]$VanillaLoading,
  [string]$AddonSuitePath,
  [ValidateSet('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')]
  [string[]]$Addons = @(),
  [string]$RealmHost
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Require-Folder([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    throw "Folder does not exist: $path"
  }
  return (Resolve-Path -LiteralPath $path).ProviderPath
}
function Find-Patch([string]$root,[string]$path) {
  if (-not $root) { return $null }
  $suffix = ($path -replace '/', [IO.Path]::DirectorySeparatorChar)
  $candidates = @((Join-Path $root $suffix))
  if ($path.StartsWith('Data/')) {
    $candidates += (Join-Path $root ($path.Substring(5) -replace '/', [IO.Path]::DirectorySeparatorChar))
  }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      if ((Get-Item -LiteralPath $candidate).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Linked files are not supported: $candidate"
      }
      return $candidate
    }
  }
  return $null
}
function Hash-File([string]$path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}
try {
  $root = Require-Folder $ClientPath
  $configPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config/client-patches.json'
  $policy = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  if ($policy.schema_version -ne 1) { throw 'Unsupported patch policy manifest.' }
  $realmConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config/realm.json'
  if (-not (Test-Path -LiteralPath $realmConfigPath -PathType Leaf)) {
    throw 'Missing config/realm.json. Download the latest repository ZIP.'
  }
  $realmPolicy = Get-Content -LiteralPath $realmConfigPath -Raw | ConvertFrom-Json
  if ([int]$realmPolicy.schema_version -ne 1 -or [string]$realmPolicy.locale -ne 'enUS' -or
      [string]$realmPolicy.relative_path -ne 'Data/enUS/realmlist.wtf') {
    throw 'Unsupported realm configuration schema, locale or target path.'
  }
  $patchSource = if ($PatchSourcePath) { Require-Folder $PatchSourcePath } else { $root }
  $issues = New-Object 'System.Collections.Generic.List[string]'
  $warnings = New-Object 'System.Collections.Generic.List[string]'

  Write-Host ''
  Write-Host 'Naxxramas Client - Read-Only Preflight' -ForegroundColor Cyan
  Write-Host '-------------------------------------'
  $revisionLabel = if ($policy.patch_set_version) { [string]$policy.patch_set_version } else { 'unversioned (older repository copy)' }
  Write-Host "Patch reference: $revisionLabel"
  if (-not $policy.patch_set_version) {
    $warnings.Add('The repository copy is outdated and has no versioned patch reference. Download the latest repository ZIP.')
  }

  $wow = Join-Path $root 'Wow.exe'
  if (-not (Test-Path -LiteralPath $wow -PathType Leaf)) {
    $issues.Add('Wow.exe is missing from the selected client folder.')
  } else {
    $version = $null
    try { $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($wow).FileVersion }
    catch { $warnings.Add('Could not read Wow.exe version metadata. Verify that Wow.exe is a genuine client executable.') }
    Write-Host "WoW version metadata: $(if ($version) { $version } else { '(not available)' })"
    if (-not ($version -and $version -match '(^|[.,\s])12340($|[.,\s])')) {
      $warnings.Add('Build 12340 is not confirmed by Wow.exe version metadata. Verify the game build before installation.')
    } else {
      Write-Host 'WoW build: 12340 confirmed from executable version metadata' -ForegroundColor Green
    }
  }

  if (-not (Test-Path -LiteralPath (Join-Path $root 'Data/enUS') -PathType Container)) {
    $issues.Add('Data/enUS is missing. This first version supports enUS clients only.')
  }
  $historyDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'config/patch-versions'
  $knownOlder = @()
  if (Test-Path -LiteralPath $historyDir -PathType Container) {
    foreach ($historyFile in @(Get-ChildItem -LiteralPath $historyDir -Filter 'patchset-*.json' -File)) {
      $historical = Get-Content -LiteralPath $historyFile.FullName -Raw | ConvertFrom-Json
      if ([int]$historical.revision -lt [int]$policy.patch_set_revision) {
        $knownOlder += $historical
      }
    }
  }

  $expectedHost = if ($RealmHost) { $RealmHost } else { [string]$realmPolicy.host }
  if (-not $expectedHost -or $expectedHost.Length -gt 253 -or
      $expectedHost -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' -or
      $expectedHost.Contains('..')) {
    $issues.Add('Realm host must be a hostname or IPv4 address without a URL scheme, spaces, port or commands.')
  } else {
    Write-Host "Configured realm host: $expectedHost"
    $realmFile = Join-Path $root 'Data/enUS/realmlist.wtf'
    if (-not (Test-Path -LiteralPath $realmFile -PathType Leaf)) {
      Write-Host 'REALMLIST NOT PRESENT: the future installer will offer to configure Data/enUS/realmlist.wtf.'
    } else {
      $foundHost = $null
      foreach ($line in @(Get-Content -LiteralPath $realmFile -TotalCount 50)) {
        if ($line -match '^\s*set\s+realmlist\s+(\S+)\s*(?:#.*)?$') {
          $foundHost = [string]$Matches[1]
          break
        }
      }
      if (-not $foundHost) {
        $warnings.Add('Existing Data/enUS/realmlist.wtf has no recognised set realmlist entry. No changes were made.')
        Write-Host 'REALMLIST UNRECOGNISED' -ForegroundColor Yellow
      } elseif ($foundHost -ne $expectedHost) {
        $warnings.Add("Existing realmlist points to $foundHost rather than $expectedHost. Back up the file before any later modification.")
        Write-Host 'REALMLIST DIFFERENT: the future installer can offer to update it after backup.' -ForegroundColor Yellow
      } else {
        Write-Host 'REALMLIST MATCH: existing client uses the configured Naxxramas address.' -ForegroundColor Green
      }
    }
  }

  if ($VanillaLogin -and $TbcLogin) {
    $issues.Add('Choose only one login screen: Vanilla Patch J or Burning Crusade Patch C.')
  }
  $existingJ = Find-Patch $root 'Data/Patch-J.mpq'
  $existingC = Find-Patch $root 'Data/Patch-C.mpq'
  if ($existingJ -and $existingC) {
    $issues.Add('Conflicting login patches J and C are both installed. Back up and resolve manually.')
  }
  if ($TbcLogin -and $existingJ) {
    $issues.Add('Cannot select TBC Patch C while Vanilla Patch J exists. Back up and remove J manually.')
  }
  if ($VanillaLogin -and $existingC) {
    $issues.Add('Cannot select Vanilla Patch J while TBC Patch C exists. Back up and remove C manually.')
  }

  foreach ($patch in @($policy.patches)) {
    $required = [bool]$patch.required
    $chosen = $required -or ($patch.path -eq 'Data/Patch-J.mpq' -and [bool]$VanillaLogin) -or
      ($patch.path -eq 'Data/Patch-C.mpq' -and [bool]$TbcLogin) -or
      ($patch.path -eq 'Data/Patch-U.mpq' -and [bool]$VanillaLoading)
    $installed = Find-Patch $root $patch.path
    if (-not $chosen) {
      if (-not $installed) {
        Write-Host "OPTIONAL NOT INSTALLED: $($patch.path)"
      } else {
        $installedHash = Hash-File $installed
        if ($patch.sha256 -and $installedHash -ne $patch.sha256.ToLowerInvariant()) {
          $warnings.Add("Installed optional patch is a different version: $($patch.path). The preflight did not change it.")
          Write-Host "OPTIONAL PRESENT (different version): $($patch.path)" -ForegroundColor Yellow
        } else {
          Write-Host "OPTIONAL PRESENT (not requested for installation): $($patch.path)" -ForegroundColor Green
        }
      }
      continue
    }
    $source = Find-Patch $patchSource $patch.path
    $candidate = if ($source) { $source } else { $installed }
    if (-not $candidate) {
      $issues.Add("Missing $(if ($required) {'mandatory'} else {'selected optional'}) patch: $($patch.path)")
      Write-Host "MISSING: $($patch.path)" -ForegroundColor Red
      continue
    }
    $sha = Hash-File $candidate
    if ($patch.sha256 -and $sha -ne $patch.sha256.ToLowerInvariant()) {
      $olderVersion = $null
      foreach ($history in @($knownOlder)) {
        foreach ($entry in @($history.patches)) {
          if ($entry.path -eq $patch.path -and $entry.sha256 -eq $sha) {
            $olderVersion = [string]$history.version
          }
        }
      }
      if ($olderVersion) {
        $issues.Add("Older known patch $($patch.path) ($olderVersion) is installed; the current reference is $($policy.patch_set_version). An update is needed.")
        Write-Host "OUTDATED: $($patch.path) ($olderVersion)" -ForegroundColor Yellow
      } else {
        $issues.Add("Checksum mismatch for $($patch.path). It does not match the current pinned version.")
        Write-Host "MISMATCH: $($patch.path)" -ForegroundColor Red
      }
    } else {
      $size = (Get-Item -LiteralPath $candidate).Length
      Write-Host ("VERIFIED: {0} ({1:N1} MB)" -f $patch.path,($size / 1MB))
    }
    if ($required -and -not $patch.sha256) {
      $warnings.Add("Mandatory patch $($patch.path) is present but has no pinned reference SHA-256. Authenticity is NOT verified. Actual SHA-256: $sha")
    }
    if ($installed -and $source -and
        -not $installed.Equals($source,[StringComparison]::OrdinalIgnoreCase) -and
        (Hash-File $installed) -ne $sha) {
      $warnings.Add("The existing and proposed versions differ for $($patch.path). Backups will be necessary before any replacement.")
    }
  }

  if ($VanillaLogin -and $VanillaLoading) {
    $warnings.Add('Optional J and U both contain two loading-screen textures; their combined in-game precedence is not yet tested.')
  }

  if ($Addons.Count -gt 0 -and -not $AddonSuitePath) {
    $issues.Add('Selected addons require a local extracted N Addon Suite folder.')
  }
  if ($AddonSuitePath) {
    $suite = Require-Folder $AddonSuitePath
    $suiteRoot = if (Test-Path -LiteralPath (Join-Path $suite 'NCore/NCore.toc') -PathType Leaf) {
      $suite
    } else {
      Join-Path (Join-Path $suite 'Interface') 'AddOns'
    }
    $selected = @('NCore') + @($Addons | Select-Object -Unique)
    foreach ($name in $selected) {
      $toc = Join-Path $suiteRoot ($name + '/' + $name + '.toc')
      if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) {
        $issues.Add("Addon source does not contain expected TOC: $name")
        continue
      }
      if (Test-Path -LiteralPath (Join-Path $root ('Interface/AddOns/' + $name))) {
        $warnings.Add("Addon $name already exists in the client. An installer must back it up or avoid overwriting it.")
      }
      Write-Host "ADDON source found: $name"
    }
    $warnings.Add('Addon Suite folder structure was checked; release signature, license and source revision were not authenticated.')
  }

  Write-Host ''
  foreach ($warning in $warnings) { Write-Warning $warning }
  if ($issues.Count -gt 0) {
    foreach ($issue in $issues) { Write-Host "ERROR: $issue" -ForegroundColor Red }
    Write-Host 'Preflight: FAILED. No files changed.' -ForegroundColor Red
    exit 1
  }
  Write-Host 'Preflight: required patch checks PASSED against the selected local manifest. Review any warnings.' -ForegroundColor Green
  Write-Host 'This tool is READ ONLY: no game files were changed or uploaded.'
  exit 0
}
catch {
  Write-Host ("ERROR: Preflight could not finish: " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}
