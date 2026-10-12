#requires -Version 5.1
<#
Build an allowlisted READ-ONLY Windows review ZIP for CI inspection.
This is packaging tooling, NOT a client installer or an approved release.
No game archives, executables, accounts, player data or addons are copied.
The supplied output folder must be an EMPTY directory outside this repo.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$repo=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\','/')
function Assert-NoLink([string]$Path){
    $at=[IO.Path]::GetFullPath($Path)
    while($true){
        if(Test-Path -LiteralPath $at){
            $item=Get-Item -LiteralPath $at -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'Linked paths are forbidden in review-bundle packaging.'
            }
        }
        $parent=[IO.Directory]::GetParent($at)
        if($null -eq $parent){break}
        $at=$parent.FullName
    }
}
Assert-NoLink $repo
if(-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)){
    throw 'Choose an existing EMPTY output directory separate from the repository.'
}
Assert-NoLink $OutputDirectory
$output=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $OutputDirectory).ProviderPath).TrimEnd('\','/')
if($output.Equals($repo,[StringComparison]::OrdinalIgnoreCase) -or
   $output.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
   $repo.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Bundle output must be independent from the source repository.'
}
if(@(Get-ChildItem -LiteralPath $output -Force).Count -ne 0){
    throw 'Output directory must be EMPTY; existing data is never overwritten.'
}

# Explicit positive allowlist: do NOT enumerate whole tools/ or Data/.
$paths=@(
    'README-REVIEW-ONLY.md',
    'tools/Start-Naxxramas-SetupWizard.bat',
    'tools/Start-Naxxramas-SetupWizard.ps1',
    'tools/Naxxramas-WizardDetails.ps1',
    'tools/Naxxramas-OptionalContent.ps1',
    'tools/Show-Naxxramas-InstallReview.ps1',
    'tools/Plan-Naxxramas-Install.ps1',
    'config/client-patches.json',
    'config/optional-content.json',
    'config/realm.json',
    'config/patch-versions/patchset-0001.json',
    'config/patch-versions/patchset-0002.json',
    'docs/GUIDED-WINDOWS-SETUP.md',
    'docs/PLAYER-INSTALL-REVIEW.md',
    'docs/WINDOWS-ACCESSIBILITY-ACCEPTANCE.md'
)
if(@($paths | Select-Object -Unique).Count -ne $paths.Count){
    throw 'Duplicate path in review bundle allowlist.'
}
# Do not package if the version policy and required/optional roles have drifted.
$policy=Get-Content -LiteralPath (Join-Path $repo 'config/client-patches.json') -Raw | ConvertFrom-Json
$history=Get-Content -LiteralPath (Join-Path $repo 'config/patch-versions/patchset-0002.json') -Raw | ConvertFrom-Json
$prior=Get-Content -LiteralPath (Join-Path $repo 'config/patch-versions/patchset-0001.json') -Raw | ConvertFrom-Json
$expected=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq','Data/Patch-C.mpq','Data/Patch-U.mpq')
if($policy.schema_version -ne 1 -or $policy.patch_set_version -cne 'patchset-0002' -or
   $prior.version -cne 'patchset-0001' -or [int]$prior.revision -ne 1 -or
   @($prior.patches).Count -ne 4 -or
   $history.version -cne $policy.patch_set_version -or
   [int]$history.revision -ne [int]$policy.patch_set_revision -or
   @($policy.patches).Count -ne 5 -or @($history.patches).Count -ne 5 -or
   [int]$policy.target_client.build -ne 12340 -or $policy.target_client.locale -cne 'enUS'){
    throw 'Unreviewed patch reference; update the bundle allowlist only after reviewing the new policy.'
}
for($i=0;$i -lt 5;$i++){
    $entry=$policy.patches[$i]
    $old=$history.patches[$i]
    if($entry.path -cne $expected[$i] -or $old.path -cne $entry.path -or
       [bool]$entry.required -ne ($i -lt 2) -or
       [bool]$entry.allow_disable -ne ($i -ge 2) -or
       $entry.sha256 -cne $old.sha256 -or [long]$entry.size_bytes -ne [long]$old.size_bytes -or
       $entry.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [long]$entry.size_bytes -le 0){
        throw 'Invalid or unreviewed core/optional patch rules.'
    }
}
$stage=Join-Path $output ('bundle-stage-'+[guid]::NewGuid().ToString('N'))
$zip=Join-Path $output 'Naxxramas-Review-Only-Scripts.zip'
$success=$false
try{
    [void][IO.Directory]::CreateDirectory($stage)
    $entries=New-Object 'System.Collections.Generic.List[object]'
    foreach($rel in $paths){
        if($rel -cnotmatch '^(README-REVIEW-ONLY\.md|(?:tools/[A-Za-z0-9-]+\.(?:ps1|bat))|(?:config/(?:client-patches|optional-content|realm)\.json)|(?:config/patch-versions/patchset-000[12]\.json)|(?:docs/(?:GUIDED-WINDOWS-SETUP|PLAYER-INSTALL-REVIEW|WINDOWS-ACCESSIBILITY-ACCEPTANCE)\.md))$'){
            throw 'Unexpected bundle path in fixed allowlist.'
        }
        $source=Join-Path $repo ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar))
        Assert-NoLink $source
        if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw ('Required bundle file missing: '+$rel)}
        $item=Get-Item -LiteralPath $source -Force
        if([long]$item.Length -gt 524288){throw ('Unexpectedly large bundle file: '+$rel)}
        $destination=Join-Path $stage ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar))
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($source,$destination,$false)
        $entries.Add([pscustomobject][ordered]@{
            path=$rel
            size_bytes=[long]$item.Length
            sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }
    $manifest=[pscustomobject][ordered]@{
        kind='naxxramas_review_only_scripts_bundle'
        schema_version=1
        patch_set_version='patchset-0002'
        release_approved=$false
        contains_game_files=$false
        installs_or_modifies_client=$false
        files=@($entries.ToArray())
    }
    [IO.File]::WriteAllText((Join-Path $stage 'BUNDLE-MANIFEST.json'),
        ($manifest | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stage,$zip,
        [IO.Compression.CompressionLevel]::Optimal,$false)
    $success=$true
    Write-Output ([pscustomobject][ordered]@{
        kind='read_only_scripts_bundle_build'
        zip_file_name=[IO.Path]::GetFileName($zip)
        file_count=$entries.Count
        patch_set_version='patchset-0002'
        release_approved=$false
        contains_game_files=$false
    } | ConvertTo-Json -Depth 3)
}finally{
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
    if(-not $success -and (Test-Path -LiteralPath $zip)){Remove-Item -LiteralPath $zip -Force}
}
