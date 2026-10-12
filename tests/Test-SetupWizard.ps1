#requires -Version 5.1
# Disposable Windows fake WoW files only. No actual MPQs or user account data.
[CmdletBinding()]
param(
    # Local developer/manual UI acceptance, using ONLY an auto-cleaned
    # synthetic fake client. Never use a real game client for this mode.
    [switch]$ManualReview,
    [ValidateSet('Ready','Blocked')][string]$ManualScenario='Ready',
    # CI-only verification of the exact same fixture branch without ShowDialog.
    [switch]$ManualHeadless
)
if($ManualHeadless -and -not $ManualReview){
    throw 'ManualHeadless requires ManualReview.'
}
if($ManualReview -and -not $ManualHeadless -and
   ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')){
    throw 'Interactive manual review is forbidden in unattended CI.'
}
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Check([bool]$Yes,[string]$What){
    if(-not $Yes){throw ('TEST FAILED: '+$What)}
    Write-Host ('PASS: '+$What) -ForegroundColor Green
}
function Save([string]$Path,[string]$Value){
    [IO.File]::WriteAllText($Path,$Value,(New-Object Text.UTF8Encoding($false)))
}
function Fingerprint([string]$Path){
    return [pscustomobject]@{
        sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes=[long](Get-Item -LiteralPath $Path).Length
    }
}
function Tree([string]$Root){
    return (@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Root.Length)+':'+
                (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }) -join '|')
}
function Execute([string[]]$Arguments,[string]$Label){
    # Windows PowerShell 5.1 can split a native child process error across
    # stderr records. Preserve its full message before failing the fixture.
    $oldPreference=$ErrorActionPreference
    try{
        $ErrorActionPreference='Continue'
        $output=(& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $wizard @Arguments 2>&1 | Out-String)
        $exitCode=$LASTEXITCODE
    }finally{
        $ErrorActionPreference=$oldPreference
    }
    if($exitCode -ne 0){
        throw ('TEST FAILED: '+$Label+' (exit '+$exitCode+')'+[Environment]::NewLine+$output)
    }
    return ($output|ConvertFrom-Json)
}
$repo=Split-Path -Parent $PSScriptRoot
$wizard=Join-Path $repo 'tools/Start-Naxxramas-SetupWizard.ps1'
$bat=Join-Path $repo 'tools/Start-Naxxramas-SetupWizard.bat'
$root=Join-Path ([IO.Path]::GetTempPath()) ('NaxxWizard-'+[guid]::NewGuid().ToString('N'))
$client=Join-Path $root 'client'
$source=Join-Path $root 'source'
$backup=Join-Path $root 'backup'
$tools=Join-Path $root 'tools'
$config=Join-Path $root 'config'
$history=Join-Path $config 'patch-versions'
try{
    Check (Test-Path -LiteralPath $wizard -PathType Leaf) 'Read-only Windows wizard exists'
    Check (Test-Path -LiteralPath (Join-Path $repo 'tools/Naxxramas-WizardDetails.ps1') -PathType Leaf) 'Read-only detailed review helper exists'
    Check (Test-Path -LiteralPath $bat -PathType Leaf) 'Double-click Windows launcher exists'
    $launcher=[IO.File]::ReadAllText($bat)
    Check ($launcher.Contains('-STA') -and
        $launcher.Contains('Start-Naxxramas-SetupWizard.ps1')) 'Double-click entrypoint uses STA Windows PowerShell'

    # Window itself is created headlessly, never displayed in CI.
    $layout=Execute @('-Diagnostics') 'WinForms layout smoke test'
    Check ($layout.kind -ceq 'read_only_windows_setup_wizard_layout' -and
        $layout.form_built -and -not $layout.form_displayed) 'The real Windows Form builds without showing a modal window'
    Check ($layout.folder_count -eq 3 -and
        $layout.optional_patch_toggle_count -eq 2 -and
        $layout.mandatory_patch_toggle_count -eq 0) 'Three folder pickers and two independent optional toggles'
    Check ($layout.preview_read_only -and $layout.selection_changes_clear_stale_review) 'Read-only scrolling result and stale-review invalidation on optional or realm edits'
    Check ($layout.contrast_matches_windows -and $layout.theme_preserves_standard_palette -and
        $layout.high_contrast_palette_uses_system_colours -and
        $layout.contrast_applied_to_actual_controls) 'Wizard uses the active Windows palette and the High Contrast palette resolves OS system colours'
    Check ($layout.review_status_accessible -and $layout.clear_and_close_accessible -and
        $layout.initial_keyboard_focus_target -ceq 'ClientFolder') 'Review status descriptions, safe buttons and initial keyboard focus remain available'
    Check ($layout.scrollable_layout -and $layout.minimum_scroll_height -ge 950 -and
        $layout.optional_controls_do_not_overlap -and $layout.optional_status_inside_scroll_extent -and
        $layout.preview_inside_scroll_extent) 'Stacked choices, visible option summary and review remain available by scrolling'
    Check ($layout.optional_status_accessible -and
        $layout.optional_status_text.Contains('Patch-J OFF') -and
        $layout.optional_status_text.Contains('Patch-U OFF') -and
        -not $layout.combined_overlap_warning_shown -and
        $layout.mandatory_core_reminder.Contains('Core patches V and Z are always required')) 'Initial J/U status is descriptive, accessible and does not offer a core patch toggle'
    Check ($layout.form_height -le $layout.working_area_height) 'Initial wizard fits within Windows desktop working-area height'
    Check ($layout.folder_browse_buttons_inside_viewport -and $layout.action_buttons_inside_viewport) 'Right-anchored browse and review controls fit inside initial viewport'
    Check ($layout.default_keyboard_action -ceq 'ReviewOnly' -and
        $layout.cancel_keyboard_action -ceq 'CloseWizard') 'Enter reviews only; Escape closes safely'
    Check (@($layout.action_labels).Count -eq 7 -and
        @($layout.action_labels) -ccontains 'Review Only' -and
        @($layout.action_labels) -ccontains 'Clear Review' -and
        @($layout.action_labels) -ccontains 'View File Details...') 'Review details added without Apply or confirmation control'
    Check ($layout.details_action_initially_disabled -and $layout.detail_view_is_read_only) 'Detailed view disabled until real successful inspection'
    Check (-not $layout.actual_installer_action_present -and
        -not $layout.consent_action_present -and
        -not $layout.rollback_action_present -and
        -not $layout.client_files_changed -and -not $layout.backups_created) 'No real installation or consent surfaced'
    $choices=Execute @('-Diagnostics','-VanillaLogin','-VanillaLoading') 'Independent selections in WinForms'
    Check ($choices.optional_login_selected -and $choices.optional_loading_selected) 'Both optional checkboxes can be independently selected'
    Check ($choices.combined_overlap_warning_shown -and $choices.optional_status_accessible -and
        $choices.optional_status_text.Contains('Patch-J ON') -and
        $choices.optional_status_text.Contains('Patch-U ON') -and
        $choices.optional_status_text.Contains('Combined appearance is untested')) 'Both J and U selected display plain-text overlap warning immediately'
    $choices=Execute @('-Diagnostics','-VanillaLoading') 'Loading-only WinForms choice'
    Check (-not $choices.optional_login_selected -and $choices.optional_loading_selected) 'U can be selected without selecting J'
    Check (-not $choices.combined_overlap_warning_shown -and
        $choices.optional_status_text.Contains('Patch-J OFF') -and $choices.optional_status_text.Contains('Patch-U ON')) 'U alone does not incorrectly claim J/U overlap'

    # Test the actual GUI->read-only-viewer bridge using the same strict
    # synthetic setup as the existing player-review integration suite.
    foreach($p in @($client,$source,$backup,$tools,$history,
        (Join-Path $client 'Data/enUS'),(Join-Path $source 'Data'))){
        $null=New-Item -ItemType Directory -Path $p -Force
    }
    foreach($name in @('Show-Naxxramas-InstallReview.ps1','Plan-Naxxramas-Install.ps1','Start-Naxxramas-SetupWizard.ps1','Naxxramas-WizardDetails.ps1')){
        Copy-Item -LiteralPath (Join-Path $repo ('tools/'+$name)) -Destination $tools
    }
    $wizard=Join-Path $tools 'Start-Naxxramas-SetupWizard.ps1'
    $policy=@()
    foreach($i in 0..3){
        $name=@('patch-V.mpq','patch-Z.mpq','Patch-J.mpq','Patch-U.mpq')[$i]
        $path='Data/'+$name
        $target=Join-Path $source $path
        Save $target ('FAKE_NEW_'+$name)
        $fp=Fingerprint $target
        $policy+=@{path=$path;required=($i -lt 2);allow_disable=($i -ge 2);
            sha256=$fp.sha256;size_bytes=$fp.size_bytes;public_distribution_approved=$false}
    }
    Save (Join-Path $config 'client-patches.json') (@{
        schema_version=1;patch_set_version='patchset-0001';patch_set_revision=1;
        target_client=@{build=12340;locale='enUS'};patches=$policy
    }|ConvertTo-Json -Depth 8)
    Save (Join-Path $config 'realm.json') (@{
        schema_version=1;relative_path='Data/enUS/realmlist.wtf';host='naxx.example.test'
    }|ConvertTo-Json -Depth 5)
    $v=Join-Path $client 'Data/patch-V.mpq'
    $realm=Join-Path $client 'Data/enUS/realmlist.wtf'
    Save $v 'FAKE_OLD_V'
    $old=Fingerprint $v
    Save (Join-Path $history 'patchset-0000.json') (@{
        schema_version=1;revision=0;version='patchset-0000';
        patches=@(@{path='Data/patch-V.mpq';sha256=$old.sha256;size_bytes=$old.size_bytes})
    }|ConvertTo-Json -Depth 7)
    Copy-Item -LiteralPath (Join-Path $source 'Data/patch-Z.mpq') -Destination (Join-Path $client 'Data/patch-Z.mpq')
    Save (Join-Path $client 'Data/Patch-J.mpq') 'UNSELECTED_USER_LOGIN'
    Save $realm 'set realmlist prior.example.test'
    Save (Join-Path $backup 'original-sentinel.txt') 'NEVER OVERWRITE'
    $fakeExe=@'
using System.Reflection;
[assembly:AssemblyVersion("3.3.5.12340")]
[assembly:AssemblyFileVersion("3.3.5.12340")]
public static class NaxxWizardFixture {public static int Main(){return 0;}}
'@
    Add-Type -TypeDefinition $fakeExe -OutputAssembly (Join-Path $client 'Wow.exe') -OutputType ConsoleApplication -ErrorAction Stop
    $beforeClient=Tree $client
    $beforeSource=Tree $source
    $beforeBackup=Tree $backup
    if($ManualReview){
        # This path is intentionally *not* in the player ZIP. It launches the
        # real read-only WinForms window only against freshly created test data.
        # Everything is in $root (a fresh temporary directory) and its final
        # cleanup runs even if the GUI raises an error or the test is aborted.
        $manualArgs=@('-ClientPath',$client,'-PatchSourcePath',$source,'-VanillaLoading')
        if($ManualScenario -eq 'Blocked'){
            Save $v 'FAKE_UNRECOGNISED_CORE_V_FOR_MANUAL_REVIEW'
            $beforeClient=Tree $client
            # Also omit a separate backup folder deliberately, to exercise
            # more blocked warnings without touching any backup folder.
        }else{
            $manualArgs+=@('-BackupRoot',$backup)
        }
        if($ManualHeadless){
            $manual=Execute (@('-PreviewJson')+$manualArgs) 'Disposable manual fixture planner'
            $expectedStatus=if($ManualScenario -eq 'Blocked'){
                'read_only_player_review_BLOCKED_MANUAL_REVIEW'
            }else{
                'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED'
            }
            Check ($manual.status -ceq $expectedStatus -and
                @($manual.file_reviews).Count -eq 5 -and
                -not $manual.client_files_modified -and
                -not $manual.original_backups_created -and
                -not $manual.file_writes_authorised) ('Manual '+$ManualScenario+' fixture returns five real read-only file reviews')
            $detail=Execute (@('-DetailDiagnostics')+$manualArgs) 'Disposable manual fixture file details'
            Check ($detail.review_status -ceq $expectedStatus -and
                $detail.file_count -eq 5 -and $detail.grid_read_only -and
                $detail.warnings_read_only -and $detail.no_approval_or_installation) ('Manual '+$ManualScenario+' fixture details behave safely')
        }else{
            Write-Host ''
            Write-Host ('MANUAL ACCESSIBILITY CHECK - '+$ManualScenario) -ForegroundColor Cyan
            Write-Host 'All paths are freshly generated FAKE files in a temporary folder.'
            Write-Host 'The wizard is REVIEW ONLY; no game file will be installed or backed up.'
            Write-Host 'Test the window, keyboard, scaling and screen-reader accessibility.'
            Write-Host 'You can change J/U selections and press Review Only / View File Details.'
            Write-Host 'Close the wizard to trigger file-hash verification and cleanup.'
            Write-Host ''
            & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $wizard @manualArgs
            if($LASTEXITCODE -ne 0){
                throw ('The disposable manual wizard exited with code '+$LASTEXITCODE)
            }
        }
        Check ((Tree $client) -ceq $beforeClient -and
            (Tree $source) -ceq $beforeSource -and
            (Tree $backup) -ceq $beforeBackup) ('Manual '+$ManualScenario+' fixture did not change any synthetic files')
        Write-Host 'Disposable accessibility fixture checks passed; temporary files will be cleaned.' -ForegroundColor Green
        return
    }
    $reviewParams=@('-PreviewJson','-ClientPath',$client,'-PatchSourcePath',$source,
        '-BackupRoot',$backup,'-VanillaLoading')
    $summary=Execute $reviewParams 'GUI viewer bridge to actual current planner'
    Check ($summary.kind -ceq 'read_only_player_facing_installation_review') 'Wizard consumes genuine read-only planner report'
    Check ($summary.status -ceq 'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') 'Even no-blocker preview is not consent'
    Check ($summary.proposed_replace_after_backup_count -eq 2 -and
        $summary.proposed_new_file_count -eq 1) 'Previous V and realmlist are original-backup candidates, new U added in preview'
    Check (-not $summary.vanilla_login_selected -and $summary.vanilla_loading_selected) 'Independent J/U selection correctly forwarded'
    Check (@($summary.file_reviews | Where-Object {
        $_.relative_path -ceq 'Data/Patch-J.mpq' -and $_.proposed_action -ceq 'leave_existing'
    }).Count -eq 1) 'Existing unselected J remains untouched'
    Check ($summary.review_required -and -not $summary.client_files_modified -and
        -not $summary.file_writes_authorised -and -not $summary.genuine_user_consent_collected -and
        -not $summary.original_backups_created) 'Wizard cannot authenticate or write files'
    $detailArgs=@('-DetailDiagnostics','-ClientPath',$client,'-PatchSourcePath',$source,
        '-BackupRoot',$backup,'-VanillaLoading')
    $detail=Execute $detailArgs 'Construct actual read-only file details dialog without displaying'
    Check ($detail.kind -ceq 'read_only_windows_wizard_file_details_diagnostics' -and
        $detail.detail_window_created -and -not $detail.detail_window_displayed) 'Actual details dialog constructs with no modal window'
    Check ($detail.file_count -eq 5 -and @($detail.file_names).Count -eq 5) 'Exactly five file rows displayed in detailed review'
    Check (@($detail.backup_labels | Where-Object {$_ -ceq 'YES - not created'}).Count -eq 2) 'V and realmlist clearly identify originals not yet backed up'
    Check (@($detail.proposed_actions | Where-Object {$_ -match 'replace ONLY after an exact original backup'}).Count -eq 2) 'Detailed action table explains the exact replacement gate'
    Check ($detail.grid_read_only -and $detail.grid_add_delete_disabled -and
        $detail.warnings_read_only -and $detail.no_approval_or_installation) 'File details cannot edit data or authorise a write'
    Check ($detail.detail_matches_system_contrast -and $detail.details_notes_accessible) 'File Details colour palette matches Windows mode and warning reader has accessible context'
    Check ($detail.warnings_scrollable -and $detail.warnings_expand_with_window -and
        $detail.keyboard_tab_order) 'Details warnings can scroll and grow on resize; table and warnings have predictable keyboard order'
    Check ($detail.compact_viewport_checked -and $detail.compact_details_scrollable -and
        $detail.compact_details_no_overlap -and $detail.compact_details_right_edges_visible -and
        $detail.initial_details_fits_desktop) 'Compact 640x480 details viewport scrolls without overlapping file grid, warnings, backup note or Close Review'
    Check ($detail.review_status -ceq 'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') 'Expanded no-blocker view still denies approval'
    Check ((Tree $client) -ceq $beforeClient -and
        (Tree $source) -ceq $beforeSource -and
        (Tree $backup) -ceq $beforeBackup) 'Dialog and planner bridge leave fake client/source/backup bytes intact'

    $reviewParams=@('-PreviewJson','-ClientPath',$client,'-PatchSourcePath',$source,'-VanillaLoading')
    $summary=Execute $reviewParams 'Wizard reports omitted backup folder'
    Check ($summary.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Missing backup folder blocks hypothetical changes'
    $detailArgs=@('-DetailDiagnostics','-ClientPath',$client,'-PatchSourcePath',$source,'-VanillaLoading')
    $detail=Execute $detailArgs 'Expanded details with missing separate backup folder'
    Check ($detail.review_status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW' -and
        $detail.concerns_count -gt 0) 'Detailed read-only dialog highlights blocked preflight'
    Save $v 'UNKNOWN_USER_V'
    $reviewParams=@('-PreviewJson','-ClientPath',$client,'-PatchSourcePath',$source,
        '-BackupRoot',$backup,'-VanillaLoading')
    $summary=Execute $reviewParams 'Wizard refuses unknown V'
    Check ($summary.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Unknown core patch is refused'
    $detailArgs=@('-DetailDiagnostics','-ClientPath',$client,'-PatchSourcePath',$source,
        '-BackupRoot',$backup,'-VanillaLoading')
    $detail=Execute $detailArgs 'Expanded details on unfamiliar core patch'
    Check ($detail.review_status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW') 'Detailed view never disguises an unrecognised V patch'

    $raw=(& powershell.exe -NoProfile -STA -File $wizard -Diagnostics | Out-String)
    Check (-not $raw.Contains($root)) 'Layout diagnostic never reveals private client paths'
    Write-Host 'All read-only Windows setup wizard tests passed.' -ForegroundColor Green
}finally{
    if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
