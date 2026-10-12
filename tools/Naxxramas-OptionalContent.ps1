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
       $null -ne $item.addon_suite.archive_sha256 -or
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
function Add-NaxxOptionalReview([object]$Report,[object]$Catalog,[bool]$UseTbc,[bool]$UseSuite){
    # Strict original report validation is performed by the calling wizard.
    # In particular, never add a fictitious verified sixth MPQ row.
    $extra=New-Object 'System.Collections.Generic.List[string]'
    $notes=New-Object 'System.Collections.Generic.List[string]'
    if($UseTbc){
        $notes.Add('Patch-C (TBC login) is checked against the pinned patchset-0002 reference by the read-only file planner. This does not authorise installation or redistribution.')
    }else{
        $notes.Add('Patch-C (TBC login) is optional and included in the six-file inspection; an unselected existing MPQ is never automatically removed.')
    }
    if($UseSuite){
        $extra.Add('N Addon Suite v2.0.0 is selected for FUTURE planning only. Its package checksum and installation/rollback approval are outstanding; no addon operation is available.')
    }else{
        $notes.Add('N Addon Suite v2.0.0 is optional, not selected and never downloaded by this preview.')
    }
    if($UseSuite){
        $Report.status='read_only_player_review_BLOCKED_MANUAL_REVIEW'
    }
    $Report.concerns=@($Report.concerns)+@($extra.ToArray())
    $Report.notes=@($Report.notes)+@($notes.ToArray())
    $Report | Add-Member -NotePropertyName patch_c_reference_sha256 -NotePropertyValue ([string]$Catalog.patch_c.sha256) -Force
    $Report | Add-Member -NotePropertyName patch_c_reference_size_bytes -NotePropertyValue ([long]$Catalog.patch_c.size_bytes) -Force
    $Report | Add-Member -NotePropertyName patch_c_release_tag -NotePropertyValue ([string]$Catalog.patch_c.release_tag) -Force
    $Report | Add-Member -NotePropertyName tbc_login_selected -NotePropertyValue $UseTbc -Force
    $Report | Add-Member -NotePropertyName addon_suite_selected -NotePropertyValue $UseSuite -Force
    $Report | Add-Member -NotePropertyName optional_content_approval -NotePropertyValue 'six_file_read_only_no_install_authorisation' -Force
    $Report | Add-Member -NotePropertyName optional_content_downloads_authorised -NotePropertyValue $false -Force
    $Report | Add-Member -NotePropertyName optional_content_file_writes_authorised -NotePropertyValue $false -Force
    $Report | Add-Member -NotePropertyName addon_suite_version -NotePropertyValue ([string]$Catalog.addon_suite.version) -Force
    $Report | Add-Member -NotePropertyName addon_suite_folders -NotePropertyValue @('NCore','IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery') -Force
    return $Report
}
function Get-NaxxOptionalSummary([object]$Report){
    return @(
        'OPTIONAL CONTENT - PLANNING ONLY; NO DOWNLOADS OR INSTALLS',
        ('Patch-C (TBC login): '+$(if($Report.tbc_login_selected){'SELECTED - six-file read-only check'}else{'OFF - preserve existing file'})),
        'Patch-C and Patch-J cannot be selected together. C fingerprint is pinned; no installation is authorised.',
        ('N Addon Suite '+$Report.addon_suite_version+': '+$(if($Report.addon_suite_selected){'SELECTED - BLOCKED UNTIL VERIFIED'}else{'OFF'})),
        'Suite folders: NCore (required); IndividualProgressionAddon, DungeonJournal, MultiBot, NaxxLootLottery (optional).',
        'N Talent Calculator is not included in v2.0.0. Existing addons and SavedVariables will not be changed.'
    ) -join [Environment]::NewLine
}
