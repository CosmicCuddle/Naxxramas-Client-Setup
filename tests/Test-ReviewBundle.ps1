#requires -Version 5.1
# Windows CI checks a disposable repository mirror; never opens a real client.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Yes,[string]$Text){
    if(-not $Yes){throw ('TEST FAILED: '+$Text)}
    Write-Host ('PASS: '+$Text)
}
function Snapshot-Tree([string]$Directory){
    return (@(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Directory.Length)+':'+
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }) -join '|')
}
function RunBundledWizard([string[]]$Arguments){
    # Start the unzipped copy from outside the repo, to test its real
    # relative dependencies rather than scripts in the git checkout.
    $exe=Join-Path $unpack 'tools/Start-Naxxramas-SetupWizard.ps1'
    $out=Join-Path $root ('runtime-out-'+[guid]::NewGuid().ToString('N')+'.txt')
    $err=Join-Path $root ('runtime-err-'+[guid]::NewGuid().ToString('N')+'.txt')
    $argsList=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$exe+'"'))
    foreach($value in $Arguments){
        if($value.StartsWith('-')){$argsList+= $value}
        else{$argsList+=('"'+$value+'"')}
    }
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList $argsList -WorkingDirectory $root -NoNewWindow -PassThru -Wait -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{
        code=$p.ExitCode
        stdout=[IO.File]::ReadAllText($out)
        stderr=[IO.File]::ReadAllText($err)
    }
}
function CallBuilder([string]$Output){
    $out=Join-Path $root ('builder-out-'+[guid]::NewGuid().ToString('N')+'.txt')
    $err=Join-Path $root ('builder-err-'+[guid]::NewGuid().ToString('N')+'.txt')
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',
        ('"'+$builder+'"'),'-OutputDirectory',('"'+$Output+'"')
    ) -NoNewWindow -PassThru -Wait -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{
        code=$p.ExitCode
        stdout=([IO.File]::ReadAllText($out))
        stderr=([IO.File]::ReadAllText($err))
    }
}
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxReviewBundle-'+[guid]::NewGuid().ToString('N'))
$mirror=Join-Path $root 'fake-repository'
$dst=Join-Path $root 'empty-output'
$unpack=Join-Path $root 'unpacked'
$paths=@(
    'README-REVIEW-ONLY.md',
    'tools/Start-Naxxramas-SetupWizard.bat',
    'tools/Start-Naxxramas-SetupWizard.ps1',
    'tools/Naxxramas-WizardDetails.ps1',
    'tools/Show-Naxxramas-InstallReview.ps1',
    'tools/Plan-Naxxramas-Install.ps1',
    'config/client-patches.json',
    'config/realm.json',
    'config/patch-versions/patchset-0001.json',
    'docs/GUIDED-WINDOWS-SETUP.md',
    'docs/PLAYER-INSTALL-REVIEW.md',
    'docs/WINDOWS-ACCESSIBILITY-ACCEPTANCE.md'
)
try{
    [void][IO.Directory]::CreateDirectory($root)
    foreach($rel in @($paths)+@('tools/Build-Naxxramas-ReviewBundle.ps1')){
        $target=Join-Path $mirror ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar))
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
        [IO.File]::Copy((Join-Path $repo $rel),$target,$false)
    }
    $builder=Join-Path $mirror 'tools/Build-Naxxramas-ReviewBundle.ps1'
    # Deliberately add a "private" fake MPQ and other unapproved files to the
    # fixture source; they MUST never be copied into the allowlisted archive.
    [void][IO.Directory]::CreateDirectory((Join-Path $mirror 'Data'))
    [IO.File]::WriteAllText((Join-Path $mirror 'Data/patch-V.mpq'),'FAKE GAME PATCH - MUST NOT PACKAGE')
    [IO.File]::WriteAllText((Join-Path $mirror 'my-private-notes.txt'),'FAKE PERSONAL DATA - MUST NOT PACKAGE')
    [void][IO.Directory]::CreateDirectory($dst)
    $result=CallBuilder $dst
    Check ($result.code -eq 0) ('Builder succeeds on reviewed fake mirror: '+$result.stderr)
    $info=$result.stdout|ConvertFrom-Json
    Check ($info.kind -ceq 'read_only_scripts_bundle_build' -and $info.file_count -eq $paths.Count -and
        -not $info.release_approved -and -not $info.contains_game_files) 'Builder confirms scripts-only, not a release'
    $zip=Join-Path $dst 'Naxxramas-Review-Only-Scripts.zip'
    Check ((Test-Path -LiteralPath $zip -PathType Leaf) -and
        @(Get-ChildItem -LiteralPath $dst -Force).Count -eq 1) 'Only one ZIP created; temp staging was removed'
    Expand-Archive -LiteralPath $zip -DestinationPath $unpack
    $actual=@(Get-ChildItem -LiteralPath $unpack -File -Recurse -Force | ForEach-Object {
        $_.FullName.Substring($unpack.Length+1).Replace('\','/')
    })
    $expected=@($paths)+@('BUNDLE-MANIFEST.json')
    Check ($actual.Count -eq $expected.Count -and
       @($actual | Where-Object {$expected -cnotcontains $_}).Count -eq 0) 'Archive contains exactly the fixed allowlist and manifest'
    Check (@($actual | Where-Object {$_ -match '(?i)\.(mpq|exe|dll|zip|wtf)$' -or $_ -match '(^|/)(WTF|Data|Cache|Interface|AddOns)/'}).Count -eq 0) 'No WoW client files, game patches, addons or nested archives'
    $manifest=Get-Content -LiteralPath (Join-Path $unpack 'BUNDLE-MANIFEST.json') -Raw|ConvertFrom-Json
    Check ($manifest.kind -ceq 'naxxramas_review_only_scripts_bundle' -and
        @($manifest.files).Count -eq $paths.Count -and
        -not $manifest.release_approved -and -not $manifest.contains_game_files -and
        -not $manifest.installs_or_modifies_client) 'Manifest explicitly denies release, gameplay assets and installation'
    foreach($row in $manifest.files){
        $path=[string]$row.path
        Check ($paths -ccontains $path) ('Manifest uses approved path: '+$path)
        $file=Join-Path $unpack ($path.Replace('/',[IO.Path]::DirectorySeparatorChar))
        Check ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
            [string]$row.sha256 -and (Get-Item -LiteralPath $file).Length -eq [long]$row.size_bytes) ('Manifest matches bytes: '+$path)
        $source=Join-Path $mirror ($path.Replace('/',[IO.Path]::DirectorySeparatorChar))
        Check ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ceq
            (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash) ('Packager preserved original byte content: '+$path)
    }

    # Runtime proof: execute the ZIP's own Windows wizard and planner from an
    # unrelated working directory, against a separate disposable fake client.
    # Neither real WoW archives nor private patch sources exist in this test.
    $client=Join-Path $root 'synthetic-client'
    $locale=Join-Path $client 'Data/enUS'
    [void][IO.Directory]::CreateDirectory($locale)
    $fakeExe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class NaxxStandaloneZipFixture {public static int Main(){return 0;}}
'@
    Add-Type -TypeDefinition $fakeExe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $locale 'realmlist.wtf'), 'set realmlist prior.example.test')
    [IO.File]::WriteAllText((Join-Path $client 'Data/Patch-J.mpq'), 'FAKE_UNRECOGNISED_PERSONAL_J_MUST_BE_PRESERVED')
    $beforeClient=Snapshot-Tree $client
    $beforeUnpacked=Snapshot-Tree $unpack

    $runtime=RunBundledWizard @('-Diagnostics')
    Check ($runtime.code -eq 0) ('Unpacked wizard constructs from another working directory: '+$runtime.stderr)
    $layout=$runtime.stdout|ConvertFrom-Json
    Check ($layout.kind -ceq 'read_only_windows_setup_wizard_layout' -and
        $layout.form_built -and -not $layout.form_displayed -and
        -not $layout.actual_installer_action_present) 'Unpacked WinForms entrypoint builds headlessly without an install action'

    $runtime=RunBundledWizard @('-PreviewJson','-ClientPath',$client,'-VanillaLoading')
    Check ($runtime.code -eq 0) ('Unpacked planner executes using ZIP-local policy: '+$runtime.stderr)
    $preview=$runtime.stdout|ConvertFrom-Json
    $expectedFiles=@('Data/patch-V.mpq','Data/patch-Z.mpq',
        'Data/Patch-J.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
    Check ($preview.kind -ceq 'read_only_player_facing_installation_review' -and
        $preview.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW' -and
        $preview.file_count -eq 5 -and $preview.patch_set_version -ceq 'patchset-0001') 'Missing real V/Z sources are blocked rather than silently accepted'
    Check ((@($preview.file_reviews | ForEach-Object {$_.relative_path}) -join '|') -ceq
        ($expectedFiles -join '|')) 'Unpacked planner uses exact expected five-file order'
    Check ($preview.file_reviews[0].mandatory -and $preview.file_reviews[0].selected -and
        $preview.file_reviews[1].mandatory -and $preview.file_reviews[1].selected -and
        -not $preview.file_reviews[2].mandatory -and -not $preview.file_reviews[2].selected -and
        -not $preview.file_reviews[3].mandatory -and $preview.file_reviews[3].selected) 'Core V/Z stay mandatory while U-only does not select J'
    Check ($preview.file_reviews[2].proposed_action -ceq 'leave_existing' -and
        $preview.review_required -and $preview.read_only -and
        -not $preview.client_files_modified -and -not $preview.file_writes_authorised -and
        -not $preview.genuine_user_consent_collected -and -not $preview.original_backups_created -and
        -not $preview.public_patch_distribution_authorised) 'Personal J is preserved and no consent, writes, backups or distribution are authorised'

    $runtime=RunBundledWizard @('-DetailDiagnostics','-ClientPath',$client,'-VanillaLoading')
    Check ($runtime.code -eq 0) ('Unpacked five-file details window builds: '+$runtime.stderr)
    $details=$runtime.stdout|ConvertFrom-Json
    Check ($details.file_count -eq 5 -and $details.grid_read_only -and
        $details.warnings_read_only -and $details.compact_details_scrollable -and
        $details.no_approval_or_installation -and -not $details.detail_window_displayed) 'Bundled File Details stays read-only and headlessly scrollable'

    $runtime=RunBundledWizard @('-PreviewJson','-ClientPath',$client,'-VanillaLogin','-VanillaLoading')
    Check ($runtime.code -eq 0) ('Unpacked planner accepts independent J/U choices: '+$runtime.stderr)
    $both=$runtime.stdout|ConvertFrom-Json
    Check ($both.vanilla_login_selected -and $both.vanilla_loading_selected -and
        $both.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW' -and
        @($both.notes|Where-Object {$_ -match 'overlap'}).Count -gt 0) 'Both optional patches retain the overlap warning while required sources remain blocked'

    Check ((Snapshot-Tree $client) -ceq $beforeClient -and
        (Snapshot-Tree $unpack) -ceq $beforeUnpacked) 'Packaged standalone runtime does not mutate synthetic client or its own extracted scripts'
    Check (-not $runtime.stdout.Contains($client)) 'Packaged JSON review never reveals the private client directory'
    Check ([IO.File]::ReadAllText((Join-Path $mirror 'Data/patch-V.mpq')) -ceq
        'FAKE GAME PATCH - MUST NOT PACKAGE') 'Unapproved source fake patch stays unchanged'
    $again=CallBuilder $dst
    Check ($again.code -ne 0 -and (Test-Path -LiteralPath $zip)) 'Non-empty destination rejected rather than overwriting ZIP'
    $nested=Join-Path $mirror 'illegal-output'
    [void][IO.Directory]::CreateDirectory($nested)
    $bad=CallBuilder $nested
    Check ($bad.code -ne 0 -and @(Get-ChildItem -LiteralPath $nested -Force).Count -eq 0) 'Output nested within source repo refused'
    $policyFile=Join-Path $mirror 'config/client-patches.json'
    $policy=Get-Content -LiteralPath $policyFile -Raw|ConvertFrom-Json
    $policy.patches[0].required=$false
    $policy|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $policyFile
    $other=Join-Path $root 'invalid-policy-output'
    [void][IO.Directory]::CreateDirectory($other)
    $bad=CallBuilder $other
    Check ($bad.code -ne 0 -and @(Get-ChildItem -LiteralPath $other -Force).Count -eq 0) 'Invalid mandatory V policy aborts before any packaging'
    Write-Host 'All disposable scripts-only review bundle checks passed.'
}finally{
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
