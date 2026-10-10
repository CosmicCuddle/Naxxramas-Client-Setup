#requires -Version 5.1
<#
Synthetic integration tests for Plan-Naxxramas-Install.ps1.
Creates a miniature client and miniature patch manifest in a temporary folder.
Never reads a real game installation or uses proprietary game files.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Bytes([string]$Value) { return [Text.Encoding]::ASCII.GetBytes($Value) }
function Save([string]$Path,[string]$Value) {
    [IO.File]::WriteAllBytes($Path,(Bytes $Value))
}
function Sign([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = [int64]$item.Length
    }
}
function Snapshot([string]$Path) {
    $lines = @(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName |
        ForEach-Object {
            $_.FullName.Substring($Path.Length) + ':' +
              (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        })
    return ($lines -join '|')
}
function Item([object]$Plan,[string]$Path) {
    $found = @($Plan.files | Where-Object { $_.path -eq $Path })
    if ($found.Count -ne 1) { throw "Expected exactly one plan entry for $Path" }
    return $found[0]
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('NaxxPlanFixture-' + [guid]::NewGuid().ToString('N'))
$client = Join-Path $work 'client'
$source = Join-Path $work 'source'
$tools = Join-Path $work 'tools'
$config = Join-Path $work 'config'
$historyDir = Join-Path $config 'patch-versions'
$rootRepo = Split-Path -Parent $PSScriptRoot
try {
    foreach ($folder in @($client,$source,$tools,$historyDir,
        (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'))) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }
    $planner = Join-Path $tools 'Plan-Naxxramas-Install.ps1'
    Copy-Item -LiteralPath (Join-Path $rootRepo 'tools/Plan-Naxxramas-Install.ps1') -Destination $planner
    Save (Join-Path $client 'Wow.exe') 'fake exe for fixture only'
    $patchNames = @('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')
    $patchRows = @()
    $i = 0
    foreach ($name in $patchNames) {
        $sourceFile = Join-Path (Join-Path $source 'Data') $name
        Save $sourceFile ("fixture-current-$name")
        $fingerprint = Sign $sourceFile
        $patchRows += [ordered]@{
            path = "Data/$name"
            required = ($i -lt 2)
            allow_disable = ($i -ge 2)
            sha256 = $fingerprint.sha256
            size_bytes = $fingerprint.size_bytes
            public_distribution_approved = $false
        }
        $i++
    }
    $manifest = [ordered]@{
        schema_version = 1
        target_client = @{ build = 12340; locale = 'enUS' }
        patch_set_revision = 1
        patch_set_version = 'patchset-0001'
        patches = $patchRows
    }
    $manifest | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath (Join-Path $config 'client-patches.json') -Encoding UTF8
    @{
        schema_version = 1
        relative_path = 'Data/enUS/realmlist.wtf'
        host = 'naxx.example.test'
    } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $config 'realm.json') -Encoding UTF8

    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-V.mpq') -Destination (Join-Path $client 'Data/patch-V.mpq')
    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
    Save (Join-Path $client 'Data/enUS/realmlist.wtf') 'set realmlist naxx.example.test'

    function Plan([bool]$UseSource=$false,[bool]$Login=$false,[bool]$Loading=$false) {
        $parameters = @{ ClientPath = $client; Json = $true }
        if ($UseSource) { $parameters.PatchSourcePath = $source }
        if ($Login) { $parameters.VanillaLogin = $true }
        if ($Loading) { $parameters.VanillaLoading = $true }
        $before = Snapshot $client
        $sourceBefore = Snapshot $source
        $json = & $planner @parameters | Out-String
        $after = Snapshot $client
        $sourceAfter = Snapshot $source
        Check ($before -ceq $after) 'Preview does not modify any fixture client file'
        Check ($sourceBefore -ceq $sourceAfter) 'Preview does not modify any fixture source file'
        $parsed = $json | ConvertFrom-Json
        Check (-not $json.Contains($work)) 'Plan JSON excludes absolute test paths'
        return $parsed
    }

    $plan = Plan
    Check ((Item $plan 'Data/patch-V.mpq').action -eq 'no_change') 'Current mandatory V is never replaced'
    Check ((Item $plan 'Data/patch-Z.mpq').action -eq 'no_change') 'Current mandatory Z is never replaced'
    Check ((Item $plan 'Data/Patch-J.mpq').action -eq 'not_selected') 'Unselected J remains optional'
    Check ((Item $plan 'Data/Patch-U.mpq').action -eq 'not_selected') 'Unselected U remains optional'
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'no_change') 'Matching realmlist preserved'
    Check ($plan.status -eq 'blocked') 'Unknown executable version is reported as blocking'
    Check (@($plan.blockers | Where-Object { $_ -like '*12340*' }).Count -eq 1) 'Unsupported executable metadata is not silently accepted'
    Check ($plan.patch_set_version -eq 'patchset-0001') 'Plan records the pinned patchset'
    Check (@($plan.files).Count -eq 5) 'Plan includes only four patches and the realmlist'

    Remove-Item -LiteralPath (Join-Path $client 'Data/patch-Z.mpq')
    $plan = Plan
    Check ((Item $plan 'Data/patch-Z.mpq').action -eq 'blocked') 'Missing mandatory Z with no source is blocked'
    $plan = Plan $true
    Check ((Item $plan 'Data/patch-Z.mpq').action -eq 'install') 'Missing mandatory Z is previewed when verified local source exists'

    Save (Join-Path $client 'Data/patch-V.mpq') 'unknown custom patch'
    $plan = Plan $true
    Check ((Item $plan 'Data/patch-V.mpq').action -eq 'blocked') 'Unknown existing core patch is never overwritten'

    $oldPatch = Join-Path $client 'Data/patch-V.mpq'
    Save $oldPatch 'known-old-V'
    $oldSignature = Sign $oldPatch
    @{
        schema_version = 1
        revision = 0
        version = 'patchset-0000'
        patches = @(@{
            path = 'Data/patch-V.mpq'
            sha256 = $oldSignature.sha256
            size_bytes = $oldSignature.size_bytes
        })
    } | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath (Join-Path $historyDir 'patchset-0000.json') -Encoding UTF8
    $plan = Plan $true
    Check ((Item $plan 'Data/patch-V.mpq').action -eq 'replace_after_backup') 'Known older V requires backup for proposed upgrade'
    Check ((Item $plan 'Data/patch-V.mpq').backup_required) 'Known older V marks backup requirement'

    # Restore required patches, then check independent optional choices.
    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-V.mpq') -Destination $oldPatch -Force
    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
    Save (Join-Path $client 'Data/Patch-U.mpq') 'my existing loading patch'
    $plan = Plan $true $true $false
    Check ((Item $plan 'Data/Patch-J.mpq').action -eq 'install') 'Selected J uses verified local source'
    Check ((Item $plan 'Data/Patch-U.mpq').action -eq 'leave_existing') 'Unselected pre-existing U is not removed'
    $plan = Plan $true $true $true
    Check ((Item $plan 'Data/Patch-U.mpq').action -eq 'blocked') 'Selected unknown U is blocked'
    Check (@($plan.warnings | Where-Object { $_ -like '*overlapping*' }).Count -eq 1) 'Joint J/U warning appears'

    Remove-Item -LiteralPath (Join-Path $client 'Data/Patch-U.mpq')
    $plan = Plan $true $false $true
    Check ((Item $plan 'Data/Patch-U.mpq').action -eq 'install') 'Selected U can be installed independently'

    $realmFile = Join-Path $client 'Data/enUS/realmlist.wtf'
    Save $realmFile 'set realmlist other.example.test'
    $plan = Plan
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'replace_after_backup') 'Different realmlist requires backup'
    Save $realmFile 'custom lines without realm setting'
    $plan = Plan
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'blocked') 'Unrecognised realmlist is blocked'
    Save $realmFile 'set realmlist naxx.example.test'

    Save (Join-Path $source 'Data/Patch-J.mpq') 'source-invalid-hash'
    $plan = Plan $true $true
    Check ((Item $plan 'Data/Patch-J.mpq').action -eq 'blocked') 'Unrecognised source hash is blocked'

    $collisionThrown = $false
    try {
        $null = & $planner -ClientPath $client -PatchSourcePath $client -Json 2>&1 | Out-String
    } catch { $collisionThrown = $true }
    Check $collisionThrown 'Source and destination collision is rejected'

    $nestedThrown = $false
    try {
        $null = & $planner -ClientPath $client -PatchSourcePath (Join-Path $client 'Data') -Json 2>&1 | Out-String
    } catch { $nestedThrown = $true }
    Check $nestedThrown 'Nested source and destination are rejected'

    $missingThrown = $false
    try {
        $null = & $planner -ClientPath (Join-Path $work 'missing-client-folder') -Json 2>&1 | Out-String
    } catch { $missingThrown = $true }
    Check $missingThrown 'Missing client path is rejected'

    $realmFile = Join-Path $client 'Data/enUS/realmlist.wtf'
    Save $realmFile ("set realmlist naxx.example.test" + "`r`n" + '# user comment')
    $plan = Plan
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'leave_existing') 'Additional realmlist content is preserved'
    Save $realmFile 'set realmlist naxx.example.test'

    $changedPlan = (& $planner -ClientPath $client -RealmHost 'alternate.example.test' -Json |
        Out-String) | ConvertFrom-Json
    Check ($changedPlan.realm_host -eq 'alternate.example.test') 'Realm host override is reflected in the preview'
    Check ((Item $changedPlan 'Data/enUS/realmlist.wtf').action -eq 'replace_after_backup') 'Realm override requires backup'

    $invalidHostThrown = $false
    try {
        $null = & $planner -ClientPath $client -RealmHost 'https://bad.example.test:8085' -Json 2>&1 | Out-String
    } catch { $invalidHostThrown = $true }
    Check $invalidHostThrown 'URL and port are rejected as realm host'

    $bigRealmlist = ('x' * 4097)
    Save $realmFile $bigRealmlist
    $plan = Plan
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'blocked') 'Oversized realmlist is blocked'
    Save $realmFile 'set realmlist naxx.example.test'

    $invalidManifest = Join-Path $config 'client-patches.json'
    $originalManifest = [IO.File]::ReadAllBytes($invalidManifest)
    try {
        $invalidPolicy = Get-Content -LiteralPath $invalidManifest -Raw | ConvertFrom-Json
        $invalidPolicy.patches[2].required = $true
        $invalidPolicy | ConvertTo-Json -Depth 9 |
            Set-Content -LiteralPath $invalidManifest -Encoding UTF8
        $invalidManifestThrown = $false
        try {
            $null = & $planner -ClientPath $client -Json 2>&1 | Out-String
        } catch { $invalidManifestThrown = $true }
        Check $invalidManifestThrown 'Invalid manifest cannot make optional J mandatory'
    } finally {
        [IO.File]::WriteAllBytes($invalidManifest,$originalManifest)
    }

    # A junction is created only within this disposable fixture, and may be
    # unavailable without elevated privileges on some local Windows machines.
    $junction = Join-Path $work 'junction-client'
    $createdJunction = $false
    try {
        $null = New-Item -ItemType Junction -Path $junction -Target $client -ErrorAction Stop
        $createdJunction = $true
    } catch {
        Write-Host 'SKIP: Junction creation not available on this Windows configuration.'
    }
    if ($createdJunction) {
        $linkThrown = $false
        try {
            $null = & $planner -ClientPath $junction -Json 2>&1 | Out-String
        } catch { $linkThrown = $true }
        Check $linkThrown 'Junction-backed client path is rejected'
    }

    # A tiny, locally compiled executable with *metadata only* is used to
    # exercise the supported-build/no-blockers path. It is not a WoW binary.
    $fixtureExe = Join-Path $client 'Wow.exe'
    Remove-Item -LiteralPath $fixtureExe -Force
    $syntheticExecutableSource = @'
using System.Reflection;
[assembly: AssemblyVersion("3.3.5.12340")]
[assembly: AssemblyFileVersion("3.3.5.12340")]
public static class FixtureClient {
    public static int Main() { return 0; }
}
'@
    Add-Type -TypeDefinition $syntheticExecutableSource -OutputAssembly $fixtureExe -OutputType ConsoleApplication -ErrorAction Stop
    $plan = Plan
    Check ($plan.status -eq 'review_only_no_blockers') 'Build 12340 metadata plus current patches produces a non-blocking preview'
    Check ((Item $plan 'Data/patch-V.mpq').action -eq 'no_change') 'Verified V remains unchanged for non-blocking plan'
    Check ((Item $plan 'Data/patch-Z.mpq').action -eq 'no_change') 'Verified Z remains unchanged for non-blocking plan'
    Check ((Item $plan 'Data/enUS/realmlist.wtf').action -eq 'no_change') 'Verified realmlist remains unchanged for non-blocking plan'

    Write-Host ''
    Write-Host 'All synthetic read-only planner assertions passed.' -ForegroundColor Green
}
finally {
    # Never recursively traverse a test junction. Remove the link itself first.
    $testJunction = Join-Path $work 'junction-client'
    $cleanJunction = $true
    if (Test-Path -LiteralPath $testJunction) {
        try {
            $link = Get-Item -LiteralPath $testJunction -Force
            if (($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                throw 'Expected junction is not a reparse point; refusing unsafe cleanup.'
            }
            [IO.Directory]::Delete($testJunction,$false)
        } catch {
            $cleanJunction = $false
            Write-Warning 'Could not safely remove temporary test junction; leaving the fixture for manual inspection.'
        }
    }
    if ($cleanJunction -and (Test-Path -LiteralPath $work)) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
