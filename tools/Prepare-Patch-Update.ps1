#requires -Version 5.1
<#
  Naxxramas patch update proposal (READ ONLY to the game installation and repository manifest).
  Drag the WoW folder onto Prepare-Patch-Update.bat.
  Outputs tools/patch-update-proposal.json with NO local paths, MPQ bytes, or personal data.
  Give the proposal to the repository maintainer for review before changing the published manifest.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ClientPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
  if (-not (Test-Path -LiteralPath $ClientPath -PathType Container)) {
    throw 'Please select the folder that contains Wow.exe.'
  }
  $client = (Resolve-Path -LiteralPath $ClientPath).ProviderPath
  if (-not (Test-Path -LiteralPath (Join-Path $client 'Wow.exe') -PathType Leaf)) {
    throw 'Wow.exe was not found in that folder.'
  }
  $policyPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config/client-patches.json'
  $manifest = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
  if ($manifest.schema_version -ne 1 -or $manifest.patch_set_revision -lt 1) {
    throw 'This repository copy does not contain a supported versioned patch policy. Download an updated repository ZIP.'
  }
  $oldRevision = [int]$manifest.patch_set_revision
  $findings = New-Object 'System.Collections.Generic.List[object]'
  $changes = New-Object 'System.Collections.Generic.List[object]'

  Write-Host ''
  Write-Host 'Naxxramas - Patch Update Preparation (READ ONLY)' -ForegroundColor Cyan
  Write-Host ("Current approved reference: {0}" -f $manifest.patch_set_version)
  Write-Host 'Calculating SHA-256 of local patch files...'
  foreach ($patch in @($manifest.patches)) {
    $name = [IO.Path]::GetFileName([string]$patch.path)
    if ($name -notmatch '^(?i:patch-[VZJU]\.mpq)$') {
      throw "Unexpected patch entry in manifest: $($patch.path)"
    }
    $file = Join-Path (Join-Path $client 'Data') $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
      if ([bool]$patch.required) {
        throw "Required patch is missing: $name. No proposal generated."
      }
      Write-Host "Optional patch not present: $name (no update proposed)"
      continue
    }
    $item = Get-Item -LiteralPath $file -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      throw "Refusing symlink or junction: $name"
    }
    $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
    $currentSize = [int64]$item.Length
    $oldSha = [string]$patch.sha256
    $oldSize = [int64]$patch.size_bytes
    $changed = (-not $oldSha.Equals($sha,[StringComparison]::OrdinalIgnoreCase)) -or ($oldSize -ne $currentSize)
    $findings.Add([pscustomobject][ordered]@{
      path = [string]$patch.path
      required = [bool]$patch.required
      sha256 = $sha
      size_bytes = $currentSize
      changed = $changed
    })
    if ($changed) {
      $changes.Add([pscustomobject][ordered]@{
        path = [string]$patch.path
        previous_sha256 = $oldSha
        new_sha256 = $sha
        previous_size_bytes = $oldSize
        new_size_bytes = $currentSize
      })
      Write-Host "CHANGED: $name" -ForegroundColor Yellow
    } else {
      Write-Host "Unchanged: $name" -ForegroundColor Green
    }
  }

  $output = Join-Path $PSScriptRoot 'patch-update-proposal.json'
  if ($changes.Count -eq 0) {
    Write-Host ''
    Write-Host 'No differences found. Your local patches match the current patch-set reference.' -ForegroundColor Green
    Write-Host 'No proposal file was generated.'
    exit 0
  }

  # Fail rather than overwriting a different, not-yet-reviewed proposal.
  if (Test-Path -LiteralPath $output) {
    throw 'A previous tools/patch-update-proposal.json already exists. Keep or rename it before creating another proposal.'
  }
  $nextRevision = $oldRevision + 1
  $proposal = [ordered]@{
    proposal_schema_version = 1
    kind = 'review_only_not_published'
    base_patch_set_revision = $oldRevision
    proposed_patch_set_revision = $nextRevision
    proposed_patch_set_version = ('patchset-{0:D4}' -f $nextRevision)
    created_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    note = 'Metadata only. No MPQ files are included. Requires compatibility testing, owner approval and a separate GitHub commit.'
    files_checked = @($findings.ToArray())
    changes = @($changes.ToArray())
  }
  $proposal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding UTF8
  Write-Host ''
  Write-Host ("Detected {0} changed patch file(s)." -f $changes.Count) -ForegroundColor Yellow
  Write-Host "Update proposal saved at: $output"
  Write-Host 'Share that JSON file privately for review; do not publish patches or game files.'
  Write-Host 'Your WoW client and repository patch manifest have not been changed.'
}
catch {
  Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}
