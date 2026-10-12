#requires -Version 5.1
<#
READ-ONLY optional-content catalogue and preview layer.
Pins C release metadata but does not download or distribute Patch-C/addon ZIP or authorize
file writes. Patch-C is now part of patchset-0002's strictly read-only six-file review.
#>
Set-StrictMode -Version Latest
function Read-NaxxOptionalCatalog {
    $config=Join-Path (Split-Path -Parent $PSScriptRoot) 'config/optional-content.json'
    if(-not (Test-Path -LiteralPath $config -PathType Leaf)){
        throw 'Optional content catalogue is missing. No review may continue.'
    }
    $item=Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
    if($null -eq $item -or [int]$item.schema_version -ne 1 -or
       $item.kind -cne 'read_only_optional_content_catalog' -or
       $item.status -cne 'planning_only_no_asset_approval' -or
       $item.patch_c.relative_path_candidate -cne 'Data/Patch-C.mpq' -or
       $item.patch_c.mutually_exclusive_with -cne 'Data/Patch-J.mpq' -or
       [bool]$item.patch_c.required -or -not [bool]$item.patch_c.allow_disable -or
       -not [bool]$item.patch_c.reference_approved -or
       -not [bool]$item.patch_c.name_and_file_case_verified -or
       [bool]$item.patch_c.redistribution_approved -or
       $item.patch_c.sha256 -cne '16b339522ca9394c11a5afe505e25cf9f326325eb2518dfde328ff08a99920c8' -or
       [long]$item.patch_c.size_bytes -ne 26753640 -or
       $item.patch_c.release_tag -cne 'optional-v1.0' -or
       $item.patch_c.release_url -cne 'https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/tag/optional-v1.0' -or
       $item.patch_c.asset_download_url -cne 'https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/download/optional-v1.0/Patch-C.mpq' -or
       $item.addon_suite.version -cne 'v2.0.0' -or
       $item.addon_suite.repository -cne 'https://github.com/CosmicCuddle/N-Addon-Collection' -or
       $item.addon_suite.release_page -cne 'https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0' -or
       $item.addon_suite.archive_name -cne 'N-Addon-Collection-v2.0.0.zip' -or
       $item.addon_suite.target_directory -cne 'Interface/AddOns' -or
       $item.addon_suite.archive_sha256 -cne '07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324' -or
       [long]$item.addon_suite.archive_size_bytes -ne 26762217 -or
       (@($item.addon_suite.legacy_folders_to_flag) -join '|') -cne 'NClassicBattlegrounds|ServerDungeonJournal' -or
       [bool]$item.addon_suite.archive_verification_approved -or
       [bool]$item.addon_suite.automatic_download_approved -or
       [bool]$item.addon_suite.install_approved -or
       [bool]$item.addon_suite.standalone_talent_calculator_included -or
       (@($item.addon_suite.required_with_suite) -join '|') -cne 'NCore' -or
       (@($item.addon_suite.optional_folders) -join '|') -cne
        'IndividualProgressionAddon|DungeonJournal|MultiBot|NaxxLootLottery'){
        throw 'Unreviewed optional content policy. No review may continue.'
    }
    return $item
}
function Assert-NaxxOptionalChoice([bool]$Vanilla,[bool]$Tbc){
    if($Vanilla -and $Tbc){
        throw 'Patch-C (TBC login) and Patch-J (Vanilla login) are mutually exclusive. Select only one.'
    }
}

# These four are *future NCore activation preferences*, not a promise to
# extract a custom subset of the release ZIP. NCore remains mandatory.
function Resolve-NaxxAddonModules([bool]$UseSuite,[string]$Choices){
    if(-not $UseSuite){
        if($null -ne $Choices){throw 'Addon modules require selecting N Addon Suite first.'}
        return
    }
    $allowed=@('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
    if($null -eq $Choices){
        foreach($name in $allowed){Write-Output $name}
        return
    }
    if($Choices -ceq 'None'){return}
    $pieces=@($Choices.Split(','))
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach($piece in $pieces){
        $item=$piece.Trim()
        if($allowed -cnotcontains $item -or -not $seen.Add($item)){
            throw 'Invalid, repeated or unrecognised addon module selection; use approved folder names only.'
        }
    }
    foreach($name in $allowed){
        if($seen.Contains($name)){Write-Output $name}
    }
}
# Inspect just the immediate child names and filesystem metadata: no TOC/Lua
# code execution, recursive file content reads, hashing or directory creation.
# Never follow linked addon roots, junctions, or symlinks.
function Get-NaxxAddonInventory([string]$Client,[object]$Catalog){
    if([string]::IsNullOrWhiteSpace($Client) -or
       -not (Test-Path -LiteralPath $Client -PathType Container)){
        throw 'Choose a valid existing client folder before reviewing addons.'
    }
    $clientNode=Get-Item -LiteralPath $Client -Force -ErrorAction Stop
    if(($clientNode.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
        throw 'Linked client folders are not allowed in the addon preview.'
    }
    $cursor=$Client
    foreach($segment in @('Interface','AddOns')){
        $cursor=Join-Path $cursor $segment
        if(Test-Path -LiteralPath $cursor){
            $node=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if(($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'Linked Interface or AddOns directories are unsafe; nothing was changed.'
            }
            if(-not $node.PSIsContainer){
                throw 'Interface/AddOns contains an unexpected file instead of a directory.'
            }
        }else{
            # Missing parent means no addon inventory; preserve user files.
            $known=@($Catalog.addon_suite.required_with_suite)+
                @($Catalog.addon_suite.optional_folders)+
                @($Catalog.addon_suite.legacy_folders_to_flag)
            foreach($name in $known){
                [pscustomobject]@{folder=[string]$name;state='absent'}
            }
            return
        }
    }
    $children=@(Get-ChildItem -LiteralPath $cursor -Force -ErrorAction Stop)
    $known=@($Catalog.addon_suite.required_with_suite)+
        @($Catalog.addon_suite.optional_folders)+
        @($Catalog.addon_suite.legacy_folders_to_flag)
    foreach($name in $known){
        # Windows is case-insensitive on most disks. Multiple case variants
        # must not be mistaken for a single safe installed addon directory.
        $found=@($children|Where-Object {$_.Name -eq $name})
        $state='absent'
        if($found.Count -gt 1){
            $state='ambiguous'
        }elseif($found.Count -eq 1){
            if(($found[0].Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                $state='linked_unsafe'
            }elseif(-not $found[0].PSIsContainer){
                $state='not_a_folder'
            }else{
                $state='present_unverified'
            }
        }
        [pscustomobject]@{folder=[string]$name;state=$state}
    }
}
function Add-NaxxOptionalReview(
    [object]$Report,[object]$Catalog,[bool]$UseTbc,[bool]$UseSuite,
    [string[]]$Modules,[string]$Client
){
    $expected=@('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
    if(-not $UseSuite -and @($Modules).Count -gt 0){
        throw 'Addon module selections require N Addon Suite.'
    }
    if(@($Modules|Where-Object {$expected -cnotcontains $_}).Count -gt 0 -or
       @($Modules|Select-Object -Unique).Count -ne @($Modules).Count){
        throw 'Addon module selections are invalid or duplicated.'
    }
    $inventory=@(Get-NaxxAddonInventory $Client $Catalog)
    $extra=New-Object 'System.Collections.Generic.List[string]'
    $notes=New-Object 'System.Collections.Generic.List[string]'
    if($UseTbc){
        $notes.Add('Patch-C is checked against the pinned patchset-0002 by the read-only file planner. No installation or redistribution is authorised.')
    }else{
        $notes.Add('Patch-C is optional; an unselected existing MPQ is never automatically removed.')
    }
    if($UseSuite){
        $extra.Add('N Addon Suite v2.0.0 is planning only. Archive contents, installation, SavedVariables backup and recovery have not been approved. No addon files are changed.')
        $notes.Add('NCore and all four optional addon folders are packaged in the published suite; choices describe proposed NCore module activation, NOT selective installation.')
    }else{
        $notes.Add('N Addon Suite is not selected. Existing addon folders are inspected by name only, with no changes.')
    }
    foreach($row in $inventory){
        if($row.state -in @('linked_unsafe','not_a_folder','ambiguous')){
            $extra.Add(('Addon folder '+$row.folder+' is '+$row.state+'. Stop and review manually; no changes made.'))
        }
        if($row.folder -in @('NClassicBattlegrounds','ServerDungeonJournal') -and
           $row.state -eq 'present_unverified'){
            $notes.Add(('Legacy addon '+$row.folder+' is present. The suite release flags potential duplicate functionality; manual review required. Nothing will be removed.'))
        }
    }
    if($UseSuite -or $extra.Count -gt 0){
        $Report.status='read_only_player_review_BLOCKED_MANUAL_REVIEW'
    }
    $Report.concerns=@($Report.concerns)+@($extra.ToArray())
    $Report.notes=@($Report.notes)+@($notes.ToArray())
    $Report | Add-Member -NotePropertyName patch_c_reference_sha256 -NotePropertyValue ([string]$Catalog.patch_c.sha256) -Force
    $Report | Add-Member -NotePropertyName patch_c_reference_size_bytes -NotePropertyValue ([long]$Catalog.patch_c.size_bytes) -Force
    $Report | Add-Member -NotePropertyName patch_c_release_tag -NotePropertyValue ([string]$Catalog.patch_c.release_tag) -Force
    $Report | Add-Member -NotePropertyName tbc_login_selected -NotePropertyValue $UseTbc -Force
    $Report | Add-Member -NotePropertyName addon_suite_selected -NotePropertyValue $UseSuite -Force
    $Report | Add-Member -NotePropertyName addon_modules_planned -NotePropertyValue @($Modules) -Force
    $Report | Add-Member -NotePropertyName addon_folder_inventory -NotePropertyValue @($inventory) -Force
    $Report | Add-Member -NotePropertyName addon_suite_archive_reference_sha256 -NotePropertyValue ([string]$Catalog.addon_suite.archive_sha256) -Force
    $Report | Add-Member -NotePropertyName addon_suite_archive_reference_size_bytes -NotePropertyValue ([long]$Catalog.addon_suite.archive_size_bytes) -Force
    $Report | Add-Member -NotePropertyName optional_content_approval -NotePropertyValue 'read_only_no_install_authorisation' -Force
    $Report | Add-Member -NotePropertyName optional_content_downloads_authorised -NotePropertyValue $false -Force
    $Report | Add-Member -NotePropertyName optional_content_file_writes_authorised -NotePropertyValue $false -Force
    $Report | Add-Member -NotePropertyName addon_suite_version -NotePropertyValue ([string]$Catalog.addon_suite.version) -Force
    $Report | Add-Member -NotePropertyName addon_suite_folders -NotePropertyValue @('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery') -Force
    return $Report
}
function Get-NaxxOptionalSummary([object]$Report){
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('OPTIONAL ADDONS - NO DOWNLOADS OR INSTALLS')
    $lines.Add(('Patch-C (TBC login): '+$(if($Report.tbc_login_selected){'SELECTED - read-only six-file check'}else{'OFF'})))
    $lines.Add(('N Addon Suite '+$Report.addon_suite_version+': '+$(if($Report.addon_suite_selected){'PLANNED - BLOCKED until approved'}else{'OFF'})))
    $lines.Add('NCore is required within the suite; Classic Battlegrounds is built into NCore.')
    $lines.Add('Optional NCore module preferences (no files installed):')
    foreach($folder in @('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')){
        $state=if(@($Report.addon_modules_planned) -ccontains $folder){'ON'}else{'OFF'}
        $lines.Add(('  '+$folder+': '+$state))
    }
    $lines.Add('Existing addon folders (names only, NOT verified or installed by this tool):')
    foreach($row in @($Report.addon_folder_inventory)){
        $lines.Add(('  '+$row.folder+': '+$row.state))
    }
    $lines.Add('N Talent Calculator is not included. Legacy addon folders are never deleted. SavedVariables are never modified.')
    return ($lines -join [Environment]::NewLine)
}
