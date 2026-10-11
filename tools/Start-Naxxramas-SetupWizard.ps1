#requires -Version 5.1
<#
Naxxramas Client Setup — READ-ONLY Windows wizard.
No client modifications, approvals, downloads, backups or restoration.
#>
[CmdletBinding()]
param(
    [string]$ClientPath,
    [string]$PatchSourcePath,
    [string]$BackupRoot,
    [string]$RealmHost,
    [switch]$VanillaLogin,
    [switch]$VanillaLoading,
    [switch]$Diagnostics,
    [switch]$PreviewJson,
    [switch]$DetailDiagnostics
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
    throw 'The guided review requires Windows.'
}
$reviewTool=Join-Path $PSScriptRoot 'Show-Naxxramas-InstallReview.ps1'
if(-not (Test-Path -LiteralPath $reviewTool -PathType Leaf)){
    throw 'The read-only planner review is missing.'
}
function Invoke-ReadOnlyReview(
    [string]$Client,[string]$Source,[string]$Backup,[string]$Realm,
    [bool]$UseLogin,[bool]$UseLoading,[bool]$AsJson
){
    if([string]::IsNullOrWhiteSpace($Client)){
        throw 'Choose an existing client folder first.'
    }
    $p=@{ClientPath=$Client.Trim()}
    if(-not [string]::IsNullOrWhiteSpace($Source)){$p.PatchSourcePath=$Source.Trim()}
    if(-not [string]::IsNullOrWhiteSpace($Backup)){$p.BackupRoot=$Backup.Trim()}
    if(-not [string]::IsNullOrWhiteSpace($Realm)){$p.RealmHost=$Realm.Trim()}
    if($UseLogin){$p.VanillaLogin=$true}
    if($UseLoading){$p.VanillaLoading=$true}
    if($AsJson){$p.Json=$true}
    $result=(& $reviewTool @p | Out-String).TrimEnd()
    if([string]::IsNullOrWhiteSpace($result)){throw 'The read-only planner returned no review.'}
    return $result
}
if($PreviewJson){
    $report=Invoke-ReadOnlyReview $ClientPath $PatchSourcePath $BackupRoot $RealmHost ([bool]$VanillaLogin) ([bool]$VanillaLoading) $true
    Write-Output $report
    return
}
if([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA){
    throw 'Start this wizard using Windows PowerShell in STA mode (powershell.exe -STA).'
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Naxxramas-WizardDetails.ps1')
$wizardTheme=Get-WizardTheme ([Windows.Forms.SystemInformation]::HighContrast)
function New-Font([float]$Size,[bool]$Bold=$false){
    $style=if($Bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
    return New-Object Drawing.Font('Segoe UI',$Size,$style)
}
function New-Label([string]$Text,[int]$Y,[bool]$Bold=$false){
    $l=New-Object Windows.Forms.Label
    $l.Text=$Text
    $l.Location=New-Object Drawing.Point(24,$Y)
    $l.Size=New-Object Drawing.Size(910,27)
    $l.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $l.Font=New-Font $(if($Bold){11}else{10}) $Bold
    $l.ForeColor=$wizardTheme.Text
    return $l
}
function New-FolderControls([string]$Name,[string]$Label,[int]$Y,[string]$Initial,[int]$Index){
    $caption=New-Label $Label $Y $true
    $field=New-Object Windows.Forms.TextBox
    $field.Name=$Name
    $field.Text=$Initial
    $field.Location=New-Object Drawing.Point(24,($Y+27))
    $field.Size=New-Object Drawing.Size(775,30)
    $field.Font=New-Font 10
    $field.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $field.TabIndex=$Index
    $field.AccessibleName=$Label
    $browse=New-Object Windows.Forms.Button
    $browse.Name=($Name+'Browse')
    $browse.Text='Browse...'
    $browse.Location=New-Object Drawing.Point(818,($Y+25))
    $browse.Size=New-Object Drawing.Size(120,32)
    $browse.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
    $browse.TabIndex=($Index+1)
    $browse.AccessibleName=('Browse existing '+$Label)
    $browse.ForeColor=$wizardTheme.Text
    return [pscustomobject]@{Caption=$caption;Field=$field;Browse=$browse}
}
$form=New-Object Windows.Forms.Form
$form.Name='NaxxramasReadOnlySetup'
$form.Text='Naxxramas Client Setup - Review Only'
# Choose the DPI-aware font before calculating the initial viewport dimensions.
$form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
$form.Font=New-Font 10
$workingArea=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
# Fit the initial window inside the desktop working area; scrolling exposes the
# remaining controls on smaller screens rather than hiding the lower review.
$initialWidth=[Math]::Min(962,[Math]::Max(720,$workingArea.Width-80))
$initialHeight=[Math]::Min(910,[Math]::Max(520,$workingArea.Height-100))
$form.ClientSize=New-Object Drawing.Size(962,910)
$form.MinimumSize=New-Object Drawing.Size(740,540)
$form.AutoScroll=$true
$form.AutoScrollMinSize=New-Object Drawing.Size(0,1000)
$form.StartPosition=[Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor=$wizardTheme.Window

$header=New-Object Windows.Forms.Panel
$header.Size=New-Object Drawing.Size(962,89)
$header.BackColor=$wizardTheme.Header
$header.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$heading=New-Label 'NAXXRAMAS  |  CLIENT SETUP' 15 $true
$heading.Font=New-Font 18 $true
$heading.ForeColor=$wizardTheme.HeaderText
$subheading=New-Label 'READ-ONLY PREVIEW  -  No installation, backup, approval or recovery.' 56
$subheading.ForeColor=$wizardTheme.HeaderSecondary
$header.Controls.AddRange(@($heading,$subheading))
$form.Controls.Add($header)
$form.Controls.Add((New-Label '1. Choose folders' 101 $true))
$clientField=New-FolderControls 'ClientFolder' 'Existing World of Warcraft client' 132 $ClientPath 0
$sourceField=New-FolderControls 'PatchSourceFolder' 'Local patch-source folder (when needed)' 207 $PatchSourcePath 2
$backupField=New-FolderControls 'BackupFolder' 'Separate existing backup folder (for future use)' 282 $BackupRoot 4
foreach($group in @($clientField,$sourceField,$backupField)){
    $form.Controls.AddRange(@($group.Caption,$group.Field,$group.Browse))
}
$form.Controls.Add((New-Label '2. Optional appearance' 372 $true))
$login=New-Object Windows.Forms.CheckBox
$login.Name='VanillaLogin'
$login.Text='Vanilla login screen (Patch-J)'
$login.Checked=[bool]$VanillaLogin
$login.Location=New-Object Drawing.Point(27,407)
$login.Size=New-Object Drawing.Size(600,32)
$login.TabIndex=6
$login.AccessibleName='Optional Vanilla login screen patch J'
$loading=New-Object Windows.Forms.CheckBox
$loading.Name='VanillaLoading'
$loading.Text='Vanilla loading screens (Patch-U)'
$loading.Checked=[bool]$VanillaLoading
$loading.Location=New-Object Drawing.Point(27,442)
$loading.Size=New-Object Drawing.Size(600,32)
$loading.TabIndex=7
$loading.AccessibleName='Optional Vanilla loading screens patch U'
$login.ForeColor=$wizardTheme.Text
$loading.ForeColor=$wizardTheme.Text
$form.Controls.AddRange(@($login,$loading))
$core=New-Label 'Core patches V and Z are always required for this setup.' 480
$core.ForeColor=$wizardTheme.MutedText
$form.Controls.Add($core)
# Always expose independent J/U status. When both are selected, show the
# known loading-screen overlap BEFORE reviewing, not only in planner notes.
$optionInfo=New-Label '' 520
$optionInfo.Name='OptionalPatchStatus'
$optionInfo.Size=New-Object Drawing.Size(914,58)
$optionInfo.AccessibleName='Optional patches J and U status and overlap warning'
$form.Controls.Add($optionInfo)
$form.Controls.Add((New-Label 'Realm address (optional override, blank uses configured value)' 581 $true))
$realm=New-Object Windows.Forms.TextBox
$realm.Name='RealmAddress'
$realm.Text=$RealmHost
$realm.Location=New-Object Drawing.Point(24,613)
$realm.Size=New-Object Drawing.Size(914,30)
$realm.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$realm.AccessibleName='Optional realm address'
$realm.BackColor=$wizardTheme.Input
$realm.ForeColor=$wizardTheme.InputText
$realm.TabIndex=8
$form.Controls.Add($realm)

$form.Controls.Add((New-Label '3. Review proposed changes' 653 $true))
$review=New-Object Windows.Forms.Button
$review.Name='ReviewOnly'
$review.Text='Review Only'
$review.Location=New-Object Drawing.Point(24,693)
$review.Size=New-Object Drawing.Size(165,40)
$review.BackColor=$wizardTheme.Accent
$review.ForeColor=$wizardTheme.AccentText
$review.FlatStyle=[Windows.Forms.FlatStyle]::Flat
$review.AccessibleName='Read-only review of proposed changes'
$review.TabIndex=9
$clear=New-Object Windows.Forms.Button
$clear.Name='ClearReview'
$clear.Text='Clear Review'
$clear.Location=New-Object Drawing.Point(203,693)
$clear.Size=New-Object Drawing.Size(140,40)
$clear.TabIndex=10
$clear.AccessibleName='Clear the current read-only review'
$clear.ForeColor=$wizardTheme.Text
$close=New-Object Windows.Forms.Button
$close.Name='CloseWizard'
$close.Text='Close'
$close.Location=New-Object Drawing.Point(817,693)
$close.Size=New-Object Drawing.Size(121,40)
$close.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$close.TabIndex=11
$details=New-Object Windows.Forms.Button
$details.Name='ViewFileDetails'
$details.Text='View File Details...'
$details.Location=New-Object Drawing.Point(357,693)
$details.Size=New-Object Drawing.Size(207,40)
$details.AccessibleName='Open larger read-only file action table'
$details.Enabled=$false
$details.TabIndex=11
$details.ForeColor=$wizardTheme.Text
$close.TabIndex=12
$close.AccessibleName='Close the read-only setup wizard'
$close.ForeColor=$wizardTheme.Text
$form.Controls.AddRange(@($review,$clear,$details,$close))
$status=New-Label 'Not reviewed - no files have been changed.' 746
$status.Name='ReviewStatus'
$status.AccessibleName='Read-only review status'
$status.AccessibleDescription=$status.Text
$form.Controls.Add($status)
$preview=New-Object Windows.Forms.RichTextBox
$preview.Name='ReadOnlyResult'
$preview.Text='No current review. Select folders and press Review Only.'
$preview.ReadOnly=$true
$preview.DetectUrls=$false
$preview.WordWrap=$true
$preview.ScrollBars=[Windows.Forms.RichTextBoxScrollBars]::Vertical
$preview.BackColor=$wizardTheme.Input
$preview.ForeColor=$wizardTheme.InputText
$preview.Font=New-Font 10
$preview.Location=New-Object Drawing.Point(24,778)
$preview.Size=New-Object Drawing.Size(914,171)
$preview.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$preview.AccessibleName='Read-only proposed file changes and review messages'
$preview.TabIndex=13
$form.Controls.Add($preview)
$script:status=$status
$script:preview=$preview
$script:details=$details
$script:currentReview=$null
function Set-ReviewStatus([string]$Message){
    $script:status.Text=$Message
    $script:status.AccessibleDescription=$Message
}
function Clear-Preview {
    $script:currentReview=$null
    $script:details.Enabled=$false
    $script:preview.Text='No current review. Select folders and press Review Only.'
    Set-ReviewStatus 'Selections changed. Run Review Only again.'
}
foreach($f in @($clientField.Field,$sourceField.Field,$backupField.Field,$realm)){
    $f.Add_TextChanged({Clear-Preview})
}
function Update-OptionalStatus {
    $j=if($login.Checked){'ON'}else{'OFF'}
    $u=if($loading.Checked){'ON'}else{'OFF'}
    $info='Optional selection: Patch-J '+$j+' | Patch-U '+$u+'.'
    if($login.Checked -and $loading.Checked){
        $info+=[Environment]::NewLine+
            'WARNING: J and U overlap on two loading screens. Combined appearance is untested.'
    }else{
        $info+=[Environment]::NewLine+
            'J and U are separate choices. Review Only never changes files.'
    }
    $optionInfo.Text=$info
    $optionInfo.AccessibleDescription=$info
}
$login.Add_CheckedChanged({Clear-Preview; Update-OptionalStatus})
$loading.Add_CheckedChanged({Clear-Preview; Update-OptionalStatus})
Update-OptionalStatus
foreach($group in @($clientField,$sourceField,$backupField)){
    $group.Browse.Tag=$group.Field
    $group.Browse.Add_Click({
        param($sender,$e)
        $field=[Windows.Forms.TextBox]$sender.Tag
        $dlg=New-Object Windows.Forms.FolderBrowserDialog
        try{
            $dlg.Description='Choose an existing folder. No files will be changed.'
            $dlg.ShowNewFolderButton=$false
            if(Test-Path -LiteralPath $field.Text -PathType Container){
                $dlg.SelectedPath=$field.Text
            }
            if($dlg.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){
                $field.Text=$dlg.SelectedPath
            }
        }finally{$dlg.Dispose()}
    })
}
$review.Add_Click({
    $review.Enabled=$false
    Clear-Preview
    Set-ReviewStatus 'Inspecting selected files (read-only)...'
    $form.Refresh()
    try{
        $hint=Get-WizardInputHint $clientField.Field.Text $sourceField.Field.Text $backupField.Field.Text
        if($hint){throw $hint}
        $json=Invoke-ReadOnlyReview $clientField.Field.Text $sourceField.Field.Text $backupField.Field.Text $realm.Text $login.Checked $loading.Checked $true
        $data=$json | ConvertFrom-Json
        Assert-WizardReadOnlyReport $data
        $script:preview.Text=Format-WizardSummary $data
        $script:preview.SelectionStart=0
        $script:preview.ScrollToCaret()
        $script:currentReview=$data
        $script:details.Enabled=$true
        if($data.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW'){
            Set-ReviewStatus 'Needs review - see View File Details. No changes made.'
        }else{
            Set-ReviewStatus 'No preflight blockers - still preview only. Nothing approved.'
        }
    }catch{
        $script:currentReview=$null
        $script:details.Enabled=$false
        $hint=Get-WizardInputHint $clientField.Field.Text $sourceField.Field.Text $backupField.Field.Text
        if(-not $hint){
            $hint='Review could not finish. Check the client version, patch source, separate backup folder and realm address.'
        }
        $script:preview.Text=$hint+[Environment]::NewLine+
            'No files were installed, replaced or backed up.'
        Set-ReviewStatus 'Review unavailable - no changes made.'
    }finally{$review.Enabled=$true}
})
$details.Add_Click({
    if($null -eq $script:currentReview){return}
    $dialog=New-WizardDetailsForm $script:currentReview
    try{[void]$dialog.ShowDialog($form)}
    finally{$dialog.Dispose()}
})
$clear.Add_Click({Clear-Preview})
$close.Add_Click({$form.Close()})
$form.AcceptButton=$review
$form.CancelButton=$close
# Start keyboard navigation at the first existing-client folder, not an action.
$form.ActiveControl=$clientField.Field
# Lay out all controls at their full-width design size first. Only then shrink
# to the available desktop viewport so right-anchored folder fields and buttons
# move into view, rather than starting beyond the right edge on small screens.
$form.ClientSize=New-Object Drawing.Size($initialWidth,$initialHeight)
$form.PerformLayout()
if($DetailDiagnostics){
    try{
        $json=Invoke-ReadOnlyReview $ClientPath $PatchSourcePath $BackupRoot $RealmHost ([bool]$VanillaLogin) ([bool]$VanillaLoading) $true
        $data=$json|ConvertFrom-Json
        Assert-WizardReadOnlyReport $data
        $dialog=New-WizardDetailsForm $data
        try{
            $grid=@($dialog.Controls.Find('ReadOnlyFileActionGrid',$true))[0]
            $issues=@($dialog.Controls.Find('ReadOnlyIssues',$true))[0]
            $region=@($dialog.Controls.Find('ReadOnlyDetailsContent',$true))[0]
            $footer=@($dialog.Controls.Find('ReadOnlyStorageNotice',$true))[0]
            $closeReview=@($dialog.Controls.Find('CloseDetails',$true))[0]
            # Inspect the actual controls after shrinking to a laptop-sized
            # viewport. This is NOT a simulation of Windows DPI scaling.
            $initialFitsDesktop=($dialog.Height -le [Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height)
            $dialog.ClientSize=New-Object Drawing.Size(640,480)
            $dialog.PerformLayout()
            $compactNoOverlap=($grid.Bottom -lt $issues.Top -and
                $issues.Bottom -lt $footer.Top -and
                $footer.Bottom -lt $closeReview.Top)
            $compactRightEdges=($grid.Right -le $region.Width -and
                $issues.Right -le $region.Width -and
                $footer.Right -le $region.Width -and
                $closeReview.Right -le $region.Width)
            $info=[pscustomobject][ordered]@{
                kind='read_only_windows_wizard_file_details_diagnostics'
                schema_version=1
                detail_window_created=$true
                detail_window_displayed=$false
                file_count=$grid.Rows.Count
                file_names=@($grid.Rows | ForEach-Object {$_.Cells[0].Value})
                proposed_actions=@($grid.Rows | ForEach-Object {$_.Cells[1].Value})
                backup_labels=@($grid.Rows | ForEach-Object {$_.Cells[2].Value})
                review_status=[string]$data.status
                concerns_count=@($data.concerns).Count
                grid_read_only=$grid.ReadOnly
                grid_add_delete_disabled=(-not $grid.AllowUserToAddRows -and -not $grid.AllowUserToDeleteRows)
                warnings_read_only=$issues.ReadOnly
                compact_viewport_checked=$true
                compact_details_scrollable=($dialog.AutoScroll -and
                    $dialog.AutoScrollMinSize.Height -ge $region.Height -and
                    $region.Height -gt $dialog.ClientSize.Height)
                compact_details_no_overlap=$compactNoOverlap
                compact_details_right_edges_visible=$compactRightEdges
                initial_details_fits_desktop=$initialFitsDesktop
                warnings_scrollable=($issues.ScrollBars -eq [Windows.Forms.RichTextBoxScrollBars]::Vertical)
                warnings_expand_with_window=(($issues.Anchor -band [Windows.Forms.AnchorStyles]::Bottom) -ne 0)
                keyboard_tab_order=($grid.TabIndex -eq 0 -and $issues.TabIndex -eq 1)
                no_approval_or_installation=$true
            }
            Write-Output ($info|ConvertTo-Json -Depth 5)
        }finally{$dialog.Dispose()}
    }finally{$form.Dispose()}
    return
}
if($Diagnostics){
    # Verify the actual CheckedChanged handler clears stale details.
    # This is an in-memory UI-only event; no planner or client is accessed.
    $initialLogin=$login.Checked
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $login.Checked=(-not $initialLogin)
    $eventClearsStaleReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $login.Checked=$initialLogin
    $originalRealm=$realm.Text
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $realm.Text=($originalRealm+'fixture.invalid')
    $realmChangeClearsReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $realm.Text=$originalRealm
    $buttons=@($review,$clear,$details,$close,$clientField.Browse,$sourceField.Browse,$backupField.Browse)
    $report=[pscustomobject][ordered]@{
        kind='read_only_windows_setup_wizard_layout'
        schema_version=1
        title=$form.Text
        form_built=$true
        form_displayed=$false
        folder_count=3
        optional_patch_toggle_count=2
        mandatory_patch_toggle_count=0
        optional_login_selected=$login.Checked
        optional_loading_selected=$loading.Checked
        optional_status_text=$optionInfo.Text
        optional_status_accessible=($optionInfo.AccessibleDescription -ceq $optionInfo.Text)
        system_contrast_enabled=[bool]$wizardTheme.HighContrast
        contrast_matches_windows=([bool]$wizardTheme.HighContrast -eq
            [bool][Windows.Forms.SystemInformation]::HighContrast)
        contrast_theme=Get-WizardTheme $true
        theme_preserves_standard_palette=(
            $wizardTheme.HighContrast -or
            ($form.BackColor -eq $wizardTheme.Window -and
             $header.BackColor -eq $wizardTheme.Header -and
             $review.BackColor -eq $wizardTheme.Accent))
        high_contrast_palette_uses_system_colours=(
            $contrast_theme.Window -eq [Drawing.SystemColors]::Window -and
            $contrast_theme.Text -eq [Drawing.SystemColors]::WindowText -and
            $contrast_theme.Accent -eq [Drawing.SystemColors]::Highlight -and
            $contrast_theme.AccentText -eq [Drawing.SystemColors]::HighlightText)
        contrast_applied_to_actual_controls=(
            $form.BackColor -eq $wizardTheme.Window -and
            $header.BackColor -eq $wizardTheme.Header -and
            $review.ForeColor -eq $wizardTheme.AccentText -and
            $preview.BackColor -eq $wizardTheme.Input)
        review_status_accessible=($status.AccessibleDescription -ceq $status.Text -and
            $status.AccessibleName -ceq 'Read-only review status')
        initial_keyboard_focus_target=$form.ActiveControl.Name
        clear_and_close_accessible=(-not [string]::IsNullOrWhiteSpace($clear.AccessibleName) -and
            -not [string]::IsNullOrWhiteSpace($close.AccessibleName))
        combined_overlap_warning_shown=($optionInfo.Parent -eq $form -and $optionInfo.Text.Contains('WARNING: J and U overlap'))
        mandatory_core_reminder=$core.Text
        action_labels=@($buttons | ForEach-Object {$_.Text})
        details_action_initially_disabled=(-not $details.Enabled)
        detail_view_is_read_only=$true
        preview_read_only=$preview.ReadOnly
        scrollable_layout=$form.AutoScroll
        minimum_scroll_height=$form.AutoScrollMinSize.Height
        optional_status_inside_scroll_extent=($optionInfo.Bottom -le $form.AutoScrollMinSize.Height)
        optional_controls_do_not_overlap=($loading.Top -ge $login.Bottom)
        folder_browse_buttons_inside_viewport=($clientField.Browse.Right -le $form.ClientSize.Width -and
            $sourceField.Browse.Right -le $form.ClientSize.Width -and
            $backupField.Browse.Right -le $form.ClientSize.Width)
        action_buttons_inside_viewport=($close.Right -le $form.ClientSize.Width -and
            $details.Right -le $form.ClientSize.Width)
        form_height=$form.Height
        working_area_height=$workingArea.Height
        preview_inside_scroll_extent=($preview.Bottom -le $form.AutoScrollMinSize.Height)
        default_keyboard_action=$form.AcceptButton.Name
        cancel_keyboard_action=$form.CancelButton.Name
        selection_changes_clear_stale_review=($eventClearsStaleReview -and $realmChangeClearsReview)
        actual_installer_action_present=$false
        consent_action_present=$false
        rollback_action_present=$false
        client_files_changed=$false
        backups_created=$false
    }
    try{Write-Output ($report | ConvertTo-Json -Depth 4)}
    finally{$form.Dispose()}
    return
}
try{[void]$form.ShowDialog()}
finally{$form.Dispose()}
