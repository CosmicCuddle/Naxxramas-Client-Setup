#requires -Version 5.1
<#
OFFLINE, READ-ONLY archive inspection for the independently obtained
N Addon Suite v2.0.0 release ZIP. Does NOT extract, install, download,
copy, alter client data, create backups or approve a public release.
Developer-only: deliberately EXCLUDED from the player scripts-only ZIP.

Fixture parameters are exclusively for synthetic tests: they cannot set
reference approval and their result is always tagged synthetic_test_only.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [switch]$Fixture,
    [string]$ExpectedSha256,
    [long]$ExpectedSizeBytes
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$known=@('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
# Required marker names follow the owner's v2.0.0 source TAG and its
# scripts/build_bundle.py packaging recipe, not an assertion that the
# published release ZIP bytes have already been inspected.
$requiredFiles=@(
    'NCore/NCore.toc',
    'NCore/ExpectedVersions.lua',
    'NCore/ClassicBattlegrounds/NClassicBattlegrounds.lua',
    'NCore/LegacyCheck.lua',
    'NCore/Settings.lua',
    'IndividualProgressionAddon/IndividualProgressionAddon.toc',
    'DungeonJournal/DungeonJournal.toc',
    'DungeonJournal/LICENSE-GPL-2.0.txt',
    'DungeonJournal/CREDITS.txt',
    'MultiBot/MultiBot.toc',
    'MultiBot/LICENSE',
    'NaxxLootLottery/NaxxLootLottery.toc'
)
$forbiddenFileExtensions=@('.exe','.com','.dll','.msi','.msp','.bat','.cmd','.ps1','.vbs','.vbe','.wsf','.scr','.lnk')
$expectedName='N-Addon-Collection-v2.0.0.zip'
$officialHash='07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324'
$officialSize=[long]26762217
$referenceKind='github_release_asset_metadata_not_redistribution_approval'
if($Fixture){
    if($ExpectedSha256 -cnotmatch '^[a-f0-9]{64}$' -or $ExpectedSizeBytes -le 0){
        throw 'Fixture requires an exact lowercase SHA-256 and positive size.'
    }
    $referenceKind='synthetic_test_only'
}else{
    if($PSBoundParameters.ContainsKey('ExpectedSha256') -or
       $PSBoundParameters.ContainsKey('ExpectedSizeBytes')){
        throw 'Reference overrides require explicit synthetic -Fixture mode.'
    }
    $catalogPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'config/optional-content.json'
    $catalog=Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    if($catalog.addon_suite.archive_sha256 -cne $officialHash -or
       [long]$catalog.addon_suite.archive_size_bytes -ne $officialSize -or
       $catalog.addon_suite.archive_name -cne $expectedName -or
       [bool]$catalog.addon_suite.archive_verification_approved -or
       [bool]$catalog.addon_suite.automatic_download_approved -or
       [bool]$catalog.addon_suite.install_approved -or
       (@($catalog.addon_suite.required_with_suite) -join '|') -cne 'NCore' -or
       (@($catalog.addon_suite.optional_folders) -join '|') -cne
       'IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery'){
        throw 'Addon catalogue has changed; refuse unreviewed reference.'
    }
    $ExpectedSha256=$officialHash
    $ExpectedSizeBytes=$officialSize
    if(-not ([IO.Path]::GetFileName($ArchivePath).Equals($expectedName,[StringComparison]::Ordinal))){
        throw 'Official release ZIP filename does not match the v2.0.0 reference.'
    }
}

# Reject symbolic links/junctions at EVERY existing path component.
# The archive is only opened for reading; NO extraction path is formed.
$absolute=[IO.Path]::GetFullPath($ArchivePath)
$cursor=$absolute
while($true){
    if(Test-Path -LiteralPath $cursor){
        $node=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if(($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
            throw 'Linked archive paths are unsafe and may not be inspected.'
        }
    }
    $parent=[IO.Directory]::GetParent($cursor)
    if($null -eq $parent){break}
    $cursor=$parent.FullName
}
if(-not (Test-Path -LiteralPath $absolute -PathType Leaf)){
    throw 'Choose an existing local ZIP file; no download is performed.'
}
$size=[long](Get-Item -LiteralPath $absolute -Force).Length
if($size -ne $ExpectedSizeBytes){
    throw 'Archive size does not match the expected reference. No files were changed.'
}
$stream=$null
$archive=$null
try{
    $stream=[IO.FileStream]::new($absolute,[IO.FileMode]::Open,
        [IO.FileAccess]::Read,[IO.FileShare]::Read)
    $digest=(Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant()
    if($digest -cne $ExpectedSha256){
        throw 'Archive SHA-256 differs from the reference. No files were changed.'
    }
    $stream.Position=0
    Add-Type -AssemblyName System.IO.Compression
    $archive=[IO.Compression.ZipArchive]::new($stream,
        [IO.Compression.ZipArchiveMode]::Read,$true)
    $entries=@($archive.Entries)
    if($entries.Count -lt 5 -or $entries.Count -gt 15000){
        throw 'Unexpected archive entry count; inspection refused.'
    }
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $filePaths=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $directoryPaths=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $files=@{}
    $toc=@{}
    foreach($name in $known){$files[$name]=0;$toc[$name]=0}
    $totalBytes=[long]0
    foreach($entry in $entries){
        $path=[string]$entry.FullName
        if([string]::IsNullOrWhiteSpace($path) -or
           $path.StartsWith('/') -or $path.Contains('\') -or
           $path -match '[\x00-\x1f<>:"|?*]' -or
           -not $seen.Add($path)){
            throw 'Archive contains an invalid, duplicate or unsafe path.'
        }
        $dir=$path.EndsWith('/')
        if($dir){$path=$path.Substring(0,$path.Length-1)}
        $parts=@($path.Split([char]'/'))
        if($parts.Count -lt 1 -or $parts.Count -gt 12){
            throw 'Archive directory layout is unrecognised.'
        }
        foreach($part in $parts){
            if([string]::IsNullOrWhiteSpace($part) -or
               $part -in @('.','..') -or
               $part.EndsWith('.') -or $part.EndsWith(' ') -or
               $part -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$'){
                throw 'Archive contains an unsafe Windows filename or traversal.'
            }
        }
        if($known -cnotcontains $parts[0]){
            throw 'Archive contains an unrecognised root folder or an outer wrapper.'
        }
        # Refuse Unix symlinks and Windows reparse entries by ZIP metadata.
        $mode=(([int]$entry.ExternalAttributes -shr 16) -band 0xF000)
        if($mode -eq 0xA000 -or
           (([int]$entry.ExternalAttributes -band 0x400) -ne 0)){
            throw 'Archive contains a linked/reparse entry; inspection refused.'
        }
        if($dir){
            if([long]$entry.Length -ne 0){throw 'Invalid ZIP directory entry.'}
            [void]$directoryPaths.Add($path)
            continue
        }
        [void]$filePaths.Add($path)
        if($parts.Count -lt 2){
            throw 'Archive contains a file at root instead of inside an addon folder.'
        }
        $extension=[IO.Path]::GetExtension($parts[-1])
        if($forbiddenFileExtensions -contains $extension.ToLowerInvariant()){
            throw 'Archive contains a forbidden executable or launcher entry.'
        }
        $length=[long]$entry.Length
        $compressed=[long]$entry.CompressedLength
        if($length -lt 0 -or $length -gt 134217728 -or $compressed -lt 0 -or
           ($length -gt 0 -and $compressed -eq 0) -or
           ($compressed -gt 0 -and $length -gt $compressed * 2000)){
            throw 'Archive entry exceeds safe inspection limits or has extreme compression.'
        }
        $totalBytes += $length
        if($totalBytes -gt 536870912){
            throw 'Archive declares over 512 MiB of uncompressed data.'
        }
        $root=[string]$parts[0]
        $files[$root]=[int]$files[$root]+1
        if($parts.Count -eq 2 -and $parts[-1].EndsWith('.toc',[StringComparison]::OrdinalIgnoreCase)){
            $toc[$root]=[int]$toc[$root]+1
        }
    }
    foreach($name in $known){
        if($files[$name] -lt 1 -or $toc[$name] -lt 1){
            throw ('Archive is missing an addon directory or root-level .toc: '+$name)
        }
    }
    # ZIPs can store a file and a directory with the same Windows path;
    # such an archive is structurally unsuitable even if never extracted.
    foreach($path in $filePaths){
        if($directoryPaths.Contains($path)){
            throw 'Archive contains a file and directory path collision.'
        }
        $parts=@($path.Split([char]'/'))
        for($i=1;$i -lt $parts.Count;$i++){
            $ancestor=($parts[0..($i-1)] -join '/')
            if($filePaths.Contains($ancestor)){
                throw 'Archive contains a file used as a parent directory.'
            }
        }
    }
    foreach($required in $requiredFiles){
        if(-not $filePaths.Contains($required)){
            throw ('Archive is missing a v2.0.0 source-tag packaging marker: '+$required)
        }
    }
    # Get-FileHash was computed from the same exclusively-read stream; it
    # remains open while the central-directory layout is inspected.
    [pscustomobject][ordered]@{
        kind='naxxramas_offline_addon_zip_audit'
        schema_version=1
        reference_kind=$referenceKind
        reference_fingerprint_matches=$true
        zip_metadata_layout_passed=$true
        packaging_recipe_marker_count=$requiredFiles.Count
        packaging_recipe_source='N-Addon-Collection/v2.0.0 scripts/build_bundle.py; metadata only'
        archive_file_count=@($entries | Where-Object {-not $_.FullName.EndsWith('/')}).Count
        declared_uncompressed_bytes=$totalBytes
        folders=@($known | ForEach-Object {
            [pscustomobject][ordered]@{
                name=$_
                file_count=[int]$files[$_]
                root_toc_count=[int]$toc[$_]
            }
        })
        archive_contents_extracted=$false
        archive_payload_crc_or_lua_verified=$false
        addon_licenses_approved=$false
        game_compatibility_verified=$false
        install_or_backup_authorised=$false
        redistribution_authorised=$false
        client_files_changed=$false
    } | ConvertTo-Json -Depth 6
}finally{
    if($null -ne $archive){$archive.Dispose()}
    if($null -ne $stream){$stream.Dispose()}
}
