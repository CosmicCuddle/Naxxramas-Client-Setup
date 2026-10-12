#requires -Version 5.1
# Developer-only synthetic ZIP fixtures. Never use real player files or downloads.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
$repo=Split-Path -Parent $PSScriptRoot
$auditor=Join-Path $repo 'tools/Test-Naxxramas-AddonArchive.ps1'
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxAddonZipAudit-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
function Check([bool]$Good,[string]$Description){
    if(-not $Good){throw ('TEST FAILED: '+$Description)}
    Write-Host ('PASS: '+$Description) -ForegroundColor Green
}
function Make-Zip([string]$Name,[string[]]$Paths,[string]$Symlink=''){
    $target=Join-Path $root $Name
    $stream=[IO.FileStream]::new($target,[IO.FileMode]::CreateNew,
        [IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{
        $z=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        try{
            foreach($path in $Paths){
                $entry=$z.CreateEntry($path,[IO.Compression.CompressionLevel]::Optimal)
                if($path -ceq $Symlink){
                    $entry.ExternalAttributes=-1577123840 # Unix symlink file mode 0xA1FF0000
                }
                if(-not $path.EndsWith('/')){
                    $output=$entry.Open()
                    try{
                        $raw=[Text.Encoding]::UTF8.GetBytes('## Interface: 30300'+[Environment]::NewLine+'## Title: Fake Test File')
                        $output.Write($raw,0,$raw.Length)
                    }finally{$output.Dispose()}
                }
            }
        }finally{$z.Dispose()}
    }finally{$stream.Dispose()}
    return $target
}
function Invoke-Audit([string]$Path,[bool]$Synthetic=$true,[string]$OverrideHash=$null,[long]$OverrideSize=0){
    $out=Join-Path $root ('result-'+[guid]::NewGuid().ToString('N')+'.txt')
    $err=Join-Path $root ('error-'+[guid]::NewGuid().ToString('N')+'.txt')
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$auditor+'"'),
        '-ArchivePath',('"'+$Path+'"'))
    if($Synthetic){
        $item=Get-Item -LiteralPath $Path
        $hash=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        $size=[long]$item.Length
        if($null -ne $OverrideHash){$hash=$OverrideHash}
        if($OverrideSize -gt 0){$size=$OverrideSize}
        $arguments+=@('-Fixture','-ExpectedSha256',$hash,'-ExpectedSizeBytes',"$size")
    }
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -NoNewWindow -PassThru -Wait -WorkingDirectory $root -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{
        code=$p.ExitCode
        stdout=[IO.File]::ReadAllText($out)
        stderr=[IO.File]::ReadAllText($err)
    }
}
$five=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
$entries=@($five|ForEach-Object {$_+'/'+$_+'.toc'})
try{
    Check (Test-Path -LiteralPath $auditor -PathType Leaf) 'Offline audit script exists'
    $client=Join-Path $root 'FAKE WoW Client'
    $addons=Join-Path $client 'Interface/AddOns/NCore'
    [void][IO.Directory]::CreateDirectory($addons)
    $sentinel=Join-Path $addons 'NeverTouch-Me.lua'
    [IO.File]::WriteAllText($sentinel,'FAKE_PLAYER_ADDON_SENTINEL')
    $before=(Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
    $good=Make-Zip 'synthetic addon zip with spaces.zip' $entries
    $answer=Invoke-Audit $good
    Check ($answer.code -eq 0) ('Five-addon synthetic structure is accepted: '+$answer.stderr)
    $report=$answer.stdout|ConvertFrom-Json
    Check ($report.kind -ceq 'naxxramas_offline_addon_zip_audit' -and
        $report.reference_kind -ceq 'synthetic_test_only' -and
        $report.reference_fingerprint_matches -and
        $report.zip_metadata_layout_passed -and
        @($report.folders).Count -eq 5 -and
        @($report.folders|Where-Object {$_.root_toc_count -ne 1}).Count -eq 0 -and
        -not $report.archive_contents_extracted -and
        -not $report.archive_payload_crc_or_lua_verified -and
        -not $report.install_or_backup_authorised -and
        -not $report.redistribution_authorised -and
        -not $report.client_files_changed) 'Audit reports structural evidence only, never installation approval'
    $noFixture=Invoke-Audit $good $false
    Check ($noFixture.code -ne 0 -and
        $noFixture.stderr.Contains('Official release ZIP filename')) 'Nonfixture path requires exact published ZIP filename'
    $wrongHash=Invoke-Audit $good $true ('0'*64)
    Check ($wrongHash.code -ne 0 -and
        $wrongHash.stderr.Contains('SHA-256 differs')) 'Wrong hash stops before inspecting ZIP entries'
    $wrongSize=Invoke-Audit $good $true $null 999999
    Check ($wrongSize.code -ne 0 -and
        $wrongSize.stderr.Contains('size does not match')) 'Wrong archive length fails closed'
    $cases=@(
        @{name='traversal.zip';paths=@($entries)+@('NCore/../WTF/Account/secret.txt');text='unsafe Windows filename or traversal'},
        @{name='wrapped.zip';paths=@($entries|ForEach-Object {'N-Addon-Suite/'+$_});text='unrecognised root folder'},
        @{name='unknown.zip';paths=@($entries)+@('ServerDungeonJournal/Old.toc');text='unrecognised root folder'},
        @{name='duplicate-case.zip';paths=@($entries)+@('ncore/NCore.toc');text='duplicate or unsafe path'},
        @{name='no-toc.zip';paths=@('NCore/info.txt')+@($entries|Where-Object {$_ -cne 'NCore/NCore.toc'});text='missing an addon directory or root-level .toc'},
        @{name='absolute.zip';paths=@($entries)+@('/NCore/strange.txt');text='invalid, duplicate or unsafe path'},
        @{name='windows-device.zip';paths=@($entries)+@('NCore/CON.txt');text='unsafe Windows filename'},
        @{name='standalone-file.zip';paths=@($entries)+@('NCoreFile.lua');text='unrecognised root folder'}
    )
    foreach($case in $cases){
        $zip=Make-Zip $case.name $case.paths
        $result=Invoke-Audit $zip
        Check ($result.code -ne 0 -and $result.stderr.Contains($case.text)) ('Fail closed for '+$case.name)
    }
    $linked=Make-Zip 'symlink-entry.zip' (@($entries)+@('NCore/evil-link')) 'NCore/evil-link'
    $unsafe=Invoke-Audit $linked
    Check ($unsafe.code -ne 0 -and $unsafe.stderr.Contains('linked/reparse entry')) 'Never accept symlinks recorded inside addon ZIP'
    Check ((Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -ceq $before -and
        (Get-Content -LiteralPath $sentinel -Raw) -ceq 'FAKE_PLAYER_ADDON_SENTINEL') 'All ZIP inspection leaves fake player addon intact'
    Write-Host 'All developer-only offline addon archive audit tests passed.' -ForegroundColor Green
}finally{
    # Remove only the uniquely-created synthetic CI fixture, never client files.
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
