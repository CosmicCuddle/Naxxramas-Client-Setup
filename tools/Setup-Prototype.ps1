#requires -Version 5.1
<#
Naxxramas Setup alpha. PLAN is read-only.
Install/Rollback are locked to disposable test fixtures; NOT for a live WoW client.
No downloads, game files, or patch binaries are distributed by this tool.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ClientPath,
 [ValidateSet('Plan','Install','Rollback')][string]$Action='Plan',
 [string]$PatchSourcePath,
 [switch]$VanillaLogin,
 [switch]$VanillaLoading,
 [switch]$Apply,
 [switch]$ConfirmDisposableFixture,
 [ValidateRange(0,5)][int]$SimulateFailureAfter=0
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Require([bool]$ok,[string]$reason) { if (-not $ok) { throw $reason } }
function Folder([string]$p) {
 Require (-not [string]::IsNullOrWhiteSpace($p)) 'Folder path is empty.'
 $x=Get-Item -LiteralPath $p -ErrorAction Stop
 Require ($x.PSIsContainer) "Not a folder: $p"
 return [IO.Path]::GetFullPath($x.FullName).TrimEnd([char[]]@('\','/'))
}
function IsInside([string]$p,[string]$parent) {
 return $p.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
    $p.StartsWith(($parent+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}
function Rel([string]$p) {
 Require (@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf') -ccontains $p) "Unsafe path: $p"
 return $p.Replace('/',[IO.Path]::DirectorySeparatorChar)
}
function NoLinks([string]$base,[string]$sub) {
 $cur=$base
 Require (-not ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) "Linked root: $cur"
 foreach ($part in ($sub -split '[\/\\]')) {
  Require ($part -and $part -ne '.' -and $part -ne '..') 'Unsafe path part.'
  $cur=Join-Path $cur $part
  if (Test-Path -LiteralPath $cur) {
   Require (-not ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) "Linked path: $cur"
  }
 }
}
function Destination([string]$p) {
 $sub=Rel $p
 NoLinks $client $sub
 return Join-Path $client $sub
}
function SHA([string]$p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function Check([string]$p,[string]$hash,[long]$size) {
 Require (Test-Path -LiteralPath $p -PathType Leaf) "Missing file: $p"
 Require ((Get-Item -LiteralPath $p).Length -eq $size) "Wrong file size: $p"
 Require ((SHA $p) -ceq $hash.ToLowerInvariant()) "Checksum mismatch: $p"
}
function ReadJSON([string]$p) {
 Require (Test-Path -LiteralPath $p -PathType Leaf) "Missing manifest: $p"
 return Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
}
function SaveJSON([string]$p,[object]$data) {
 $tmp=$p+'.writing'
 Require (-not (Test-Path -LiteralPath $tmp)) 'Interrupted state write requires inspection.'
 [IO.File]::WriteAllText($tmp,($data | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 Move-Item -LiteralPath $tmp -Destination $p -Force
}
function SafeCopy([string]$from,[string]$to,[string]$hash) {
 $dir=Split-Path -Parent $to
 if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
 Copy-Item -LiteralPath $from -Destination $to -ErrorAction Stop
 Require ((SHA $to) -ceq $hash) "Copied data could not be verified: $to"
}
function FixtureGuard {
 Require ([bool]$Apply -and [bool]$ConfirmDisposableFixture) 'Test installation requires both -Apply and -ConfirmDisposableFixture.'
 $m=Join-Path $client '.naxx-test-fixture'
 Require (Test-Path -LiteralPath $m -PathType Leaf) 'PROTECTED: only disposable test clients are supported by this alpha.'
 Require (([IO.File]::ReadAllText($m).Trim()) -ceq 'NAXXRAMAS_DISPOSABLE_FIXTURE_V1') 'Invalid test fixture marker.'
 Require (@(Get-Process -Name Wow -ErrorAction SilentlyContinue).Count -eq 0) 'Close World of Warcraft first.'
}
function PatchSource([string]$p) {
 if (-not $sourceRoot) { return $null }
 $sub=Rel $p
 NoLinks $sourceRoot $sub
 $s=Join-Path $sourceRoot $sub
 if (Test-Path -LiteralPath $s -PathType Leaf) { return $s }
 return $null
}
function ProposedChanges {
 $changes=New-Object 'System.Collections.Generic.List[object]'
 foreach ($p in @($policy.patches)) {
  $path=[string]$p.path
  $null=Rel $path
  $needed=[bool]$p.required -or ($path -ceq 'Data/Patch-J.mpq' -and $VanillaLogin) -or ($path -ceq 'Data/Patch-U.mpq' -and $VanillaLoading)
  if (-not $needed) { continue }
  $hash=[string]$p.sha256
  $size=[long]$p.size_bytes
  Require ($hash -match '^[0-9a-f]{64}$' -and $size -gt 0) "Unpinned patch: $path"
  $target=Destination $path
  $before=$null
  if (Test-Path -LiteralPath $target -PathType Leaf) { $before=SHA $target }
  if ($before -ceq $hash -and (Get-Item -LiteralPath $target).Length -eq $size) { Write-Host "CURRENT: $path"; continue }
  $source=PatchSource $path
  Require ([bool]$source) "Required or selected patch cannot be verified locally; supply a separate authorised source with Data folder: $path"
  Check $source $hash $size
  $changes.Add([pscustomobject]@{path=$path;source=$source;old_sha256=$before;new_sha256=$hash;kind='patch'})
 }
 $p='Data/enUS/realmlist.wtf'
 $target=Destination $p
 $before=$null
 if (Test-Path -LiteralPath $target -PathType Leaf) { $before=SHA $target }
 $bytes=[Text.Encoding]::ASCII.GetBytes([string]$realm.line)
 $sha256=[Security.Cryptography.SHA256]::Create()
 try { $hash=[BitConverter]::ToString($sha256.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
 finally { $sha256.Dispose() }
 if ($hash -cne $before) {
  $changes.Add([pscustomobject]@{path=$p;source=$null;old_sha256=$before;new_sha256=$hash;kind='realm'})
 } else { Write-Host "CURRENT: $p" }
 if ($VanillaLogin -and $VanillaLoading) { Write-Warning 'J and U overlap on loading-screen assets; test both together in-game.' }
 return @($changes.ToArray())
}
function UndoSession {
 $activePath=Join-Path $state 'active.json'
 $active=ReadJSON $activePath
 Require ($active.schema -eq 1 -and $active.client -ceq $client -and $active.session -match '^[0-9a-f]{32}$') 'Invalid active state.'
 $session=Join-Path (Join-Path $state 'sessions') ([string]$active.session)
 NoLinks $client ('.naxxramas-setup/sessions/'+[string]$active.session)
 $file=Join-Path $session 'manifest.json'
 $j=ReadJSON $file
 Require ($j.schema -eq 1 -and $j.client -ceq $client -and $j.session -ceq $active.session) 'Invalid rollback manifest.'
 Require (@($j.operations).Count -le 5) 'Unexpected rollback operations.'
 # Verify ALL backups and targets before modifying any client file.
 foreach ($op in @($j.operations)) {
  $to=Destination ([string]$op.path)
  Require ($op.new_sha256 -match '^[0-9a-f]{64}$') 'Invalid new-file checksum in rollback state.'
  if (Test-Path -LiteralPath $to -PathType Leaf) {
   $now=SHA $to
   Require ($now -ceq $op.new_sha256 -or ($op.old_sha256 -and $now -ceq $op.old_sha256)) "Client file changed after setup; refusing rollback: $($op.path)"
  } elseif ($op.old_sha256 -and $j.status -ceq 'installed') {
   throw "Previously existing file disappeared; manual review needed: $($op.path)"
  }
  if ($op.old_sha256) {
   Require ($op.old_sha256 -match '^[0-9a-f]{64}$') 'Invalid original checksum.'
   NoLinks $session ('backups/'+[string]$op.path)
   $backup=Join-Path (Join-Path $session 'backups') (Rel ([string]$op.path))
   Require (Test-Path -LiteralPath $backup -PathType Leaf) "Missing backup: $($op.path)"
   Require ((SHA $backup) -ceq $op.old_sha256) "Damaged backup: $($op.path)"
  }
 }
 $j.status='restoring'
 SaveJSON $file $j
 foreach ($op in @($j.operations)) {
  $to=Destination ([string]$op.path)
  if ($op.old_sha256) {
   if (-not (Test-Path -LiteralPath $to -PathType Leaf) -or (SHA $to) -cne $op.old_sha256) {
    $backup=Join-Path (Join-Path $session 'backups') (Rel ([string]$op.path))
    $temp=$to+'.naxxrestore'
    Require (-not (Test-Path -LiteralPath $temp)) 'Restore temporary file already exists.'
    SafeCopy $backup $temp ([string]$op.old_sha256)
    Move-Item -LiteralPath $temp -Destination $to -Force
    Require ((SHA $to) -ceq $op.old_sha256) 'Restoration checksum mismatch.'
   }
  } elseif (Test-Path -LiteralPath $to -PathType Leaf) {
   Require ((SHA $to) -ceq $op.new_sha256) 'Installer-created file changed after validation.'
   Remove-Item -LiteralPath $to -Force
  }
  Write-Host "RESTORED: $($op.path)"
 }
 $j.status='rolled_back'
 SaveJSON $file $j
 Remove-Item -LiteralPath $activePath -Force
 Write-Host 'ROLLBACK COMPLETE (disposable fixture). Backups and journal preserved.' -ForegroundColor Green
}
try {
 $client=Folder $ClientPath
 Require (Test-Path -LiteralPath (Join-Path $client 'Wow.exe') -PathType Leaf) 'Wow.exe missing.'
 Require (Test-Path -LiteralPath (Join-Path $client 'Data/enUS') -PathType Container) 'Data/enUS missing.'
 $state=Join-Path $client '.naxxramas-setup'
 if ($Action -eq 'Rollback') { FixtureGuard; UndoSession; exit 0 }
 $repo=Split-Path -Parent $PSScriptRoot
 $policy=ReadJSON (Join-Path $repo 'config/client-patches.json')
 $realm=ReadJSON (Join-Path $repo 'config/realm.json')
 Require ($policy.schema_version -eq 1 -and [bool]$policy.patch_set_version) 'Unknown patchset manifest.'
 Require ($realm.schema_version -eq 1 -and $realm.relative_path -ceq 'Data/enUS/realmlist.wtf') 'Wrong realm configuration target.'
 Require ($realm.host -match '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' -and $realm.line -ceq ('set realmlist '+$realm.host)) 'Unsafe realm configuration.'
 Require (@($policy.patches).Count -eq 4) 'Unexpected patch manifest count.'
 $needed=@($policy.patches | Where-Object { $_.required })
 Require ($needed.Count -eq 2 -and @($needed | Where-Object { $_.path -ceq 'Data/patch-V.mpq' }).Count -eq 1 -and
  @($needed | Where-Object { $_.path -ceq 'Data/patch-Z.mpq' }).Count -eq 1) 'Both mandatory core patches must be present in manifest.'
 $sourceRoot=$null
 if ($PatchSourcePath) {
  $sourceRoot=Folder $PatchSourcePath
  Require (-not (IsInside $client $sourceRoot) -and -not (IsInside $sourceRoot $client)) 'Patch source and target must be separate, non-nested folders.'
 }
 $ops=@(ProposedChanges)
 Write-Host "PATCHSET: $($policy.patch_set_version)"
 Write-Host "PLAN: $($ops.Count) file change(s)"
 foreach ($op in $ops) { Write-Host ("{0}: {1}" -f $(if ($op.old_sha256) { 'BACKUP + REPLACE' } else { 'CREATE' }),$op.path) }
 if ($Action -eq 'Plan') { Write-Host 'READ-ONLY PLAN COMPLETE. No files changed.' -ForegroundColor Green; exit 0 }
 FixtureGuard
 Require ($ops.Count -gt 0) 'Nothing to install.'
 Require (-not (Test-Path -LiteralPath (Join-Path $state 'active.json'))) 'An active installation exists; roll it back first.'
 if (Test-Path -LiteralPath $state) { NoLinks $client '.naxxramas-setup' }
 $sid=[guid]::NewGuid().ToString('N')
 $session=Join-Path (Join-Path $state 'sessions') $sid
 $stage=Join-Path $session 'staging'
 $backups=Join-Path $session 'backups'
 New-Item -ItemType Directory -Path $stage -Force | Out-Null
 New-Item -ItemType Directory -Path $backups -Force | Out-Null
 $entries=New-Object 'System.Collections.Generic.List[object]'
 foreach($op in $ops) {
  $rel=Rel ([string]$op.path)
  $to=Destination ([string]$op.path)
  $temp=Join-Path $stage $rel
  New-Item -Path (Split-Path -Parent $temp) -ItemType Directory -Force | Out-Null
  if ($op.kind -ceq 'realm') {
   [IO.File]::WriteAllBytes($temp,[Text.Encoding]::ASCII.GetBytes([string]$realm.line))
   Require ((SHA $temp) -ceq $op.new_sha256) 'Generated realmlist mismatch.'
  } else { SafeCopy $op.source $temp $op.new_sha256 }
  if ($op.old_sha256) {
   Require ((SHA $to) -ceq $op.old_sha256) "Destination changed since preview: $($op.path)"
   $backup=Join-Path $backups $rel
   SafeCopy $to $backup $op.old_sha256
  } else { Require (-not (Test-Path -LiteralPath $to)) "New destination appeared since preview: $($op.path)" }
  $entries.Add([pscustomobject]@{path=$op.path;old_sha256=$op.old_sha256;new_sha256=$op.new_sha256})
 }
 $j=[pscustomobject]@{schema=1;client=$client;session=$sid;patchset=$policy.patch_set_version;status='prepared';operations=@($entries.ToArray())}
 $jpath=Join-Path $session 'manifest.json'
 SaveJSON $jpath $j
 SaveJSON (Join-Path $state 'active.json') ([pscustomobject]@{schema=1;client=$client;session=$sid})
 $j.status='applying'
 SaveJSON $jpath $j
 try {
  $done=0
  foreach($op in $ops) {
   $to=Destination ([string]$op.path)
   $tmp=Join-Path $stage (Rel ([string]$op.path))
   Move-Item -LiteralPath $tmp -Destination $to -Force
   Require ((SHA $to) -ceq $op.new_sha256) "Installed data mismatch: $($op.path)"
   $done++
   if ($SimulateFailureAfter -gt 0 -and $done -eq $SimulateFailureAfter) { throw "Simulated failure after $done files." }
  }
  $j.status='installed'
  SaveJSON $jpath $j
  Write-Host 'TEST INSTALL COMPLETE. Use -Action Rollback with both confirmation switches to undo.' -ForegroundColor Green
 } catch {
  $reason=$_.Exception.Message
  Write-Warning "Installation interrupted: $reason"
  try { UndoSession } catch { Write-Warning "Automatic rollback blocked: $($_.Exception.Message)" }
  throw $reason
 }
} catch {
 Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
 exit 1
}
