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
    'docs/PLAYER-INSTALL-REVIEW.md'
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
