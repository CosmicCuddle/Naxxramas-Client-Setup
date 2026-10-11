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
function New-Font([float]$Size,[bool]$Bold=$false){
    $style=if($Bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
    return New-Object Drawing.Font('Segoe UI',$Size,$style)
}
function New-Label([string]$Text,[int]$Y,[bool]$Bold=$false){
    $l=New-Object Windows.Forms.Label
    $l.Text=$Text
    $l.Location=New-Object Drawing.Point(24,$Y)
    $l.Size=New-Object Drawing.Size(910,27)
    $l.Font=New-Font $(if($Bold){11}else{10}) $Bold
    $l.ForeColor=[Drawing.Color]::FromArgb(40,54,70)
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
    return [pscustomobject]@{Caption=$caption;Field=$field;Browse=$browse}
}
$form=New-Object Windows.Forms.Form
$form.Name='NaxxramasReadOnlySetup'
$form.Text='Naxxramas Client Setup - Review Only'
$form.ClientSize=New-Object Drawing.Size(962,853)
$form.MinimumSize=New-Object Drawing.Size(860,800)
$form.StartPosition=[Windows.Forms.FormStartPosition]::CenterScreen
$form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
$form.Font=New-Font 10
$form.BackColor=[Drawing.Color]::FromArgb(247,249,252)

$header=New-Object Windows.Forms.Panel
$header.Size=New-Object Drawing.Size(962,89)
$header.BackColor=[Drawing.Color]::FromArgb(27,44,64)
$header.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$heading=New-Label 'NAXXRAMAS  |  CLIENT SETUP' 15 $true
$heading.Font=New-Font 18 $true
$heading.ForeColor=[Drawing.Color]::White
$subheading=New-Label 'READ-ONLY PREVIEW  -  No installation, backup, approval or recovery.' 56
$subheading.ForeColor=[Drawing.Color]::FromArgb(221,231,240)
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
$login.Size=New-Object Drawing.Size(424,32)
$login.TabIndex=6
$login.AccessibleName='Optional Vanilla login screen patch J'
$loading=New-Object Windows.Forms.CheckBox
$loading.Name='VanillaLoading'
$loading.Text='Vanilla loading screens (Patch-U)'
$loading.Checked=[bool]$VanillaLoading
$loading.Location=New-Object Drawing.Point(482,407)
$loading.Size=New-Object Drawing.Size(450,32)
$loading.TabIndex=7
$loading.AccessibleName='Optional Vanilla loading screens patch U'
$form.Controls.AddRange(@($login,$loading))
$core=New-Label 'Core patches V and Z are always required for this setup.' 443
$core.ForeColor=[Drawing.Color]::FromArgb(88,99,111)
$form.Controls.Add($core)
$form.Controls.Add((New-Label 'Realm address (optional override, blank uses configured value)' 475 $true))
$realm=New-Object Windows.Forms.TextBox
$realm.Name='RealmAddress'
$realm.Text=$RealmHost
$realm.Location=New-Object Drawing.Point(24,507)
$realm.Size=New-Object Drawing.Size(914,30)
$realm.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$realm.AccessibleName='Optional realm address'
$realm.TabIndex=8
$form.Controls.Add($realm)

$form.Controls.Add((New-Label '3. Review proposed changes' 547 $true))
$review=New-Object Windows.Forms.Button
$review.Name='ReviewOnly'
$review.Text='Review Only'
$review.Location=New-Object Drawing.Point(24,583)
$review.Size=New-Object Drawing.Size(165,40)
$review.BackColor=[Drawing.Color]::FromArgb(33,75,114)
$review.ForeColor=[Drawing.Color]::White
$review.FlatStyle=[Windows.Forms.FlatStyle]::Flat
$review.AccessibleName='Read-only review of proposed changes'
$review.TabIndex=9
$clear=New-Object Windows.Forms.Button
$clear.Name='ClearReview'
$clear.Text='Clear Review'
$clear.Location=New-Object Drawing.Point(203,583)
$clear.Size=New-Object Drawing.Size(140,40)
$clear.TabIndex=10
$close=New-Object Windows.Forms.Button
$close.Name='CloseWizard'
$close.Text='Close'
$close.Location=New-Object Drawing.Point(817,583)
$close.Size=New-Object Drawing.Size(121,40)
$close.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$close.TabIndex=11
$details=New-Object Windows.Forms.Button
$details.Name='ViewFileDetails'
$details.Text='View File Details...'
$details.Location=New-Object Drawing.Point(357,583)
$details.Size=New-Object Drawing.Size(207,40)
$details.AccessibleName='Open larger read-only file action table'
$details.Enabled=$false
$details.TabIndex=11
$close.TabIndex=12
$form.Controls.AddRange(@($review,$clear,$details,$close))
$status=New-Label 'Not reviewed - no files have been changed.' 638
$status.Name='ReviewStatus'
$form.Controls.Add($status)
$preview=New-Object Windows.Forms.RichTextBox
$preview.Name='ReadOnlyResult'
$preview.Text='No current review. Select folders and press Review Only.'
$preview.ReadOnly=$true
$preview.DetectUrls=$false
$preview.WordWrap=$true
$preview.ScrollBars=[Windows.Forms.RichTextBoxScrollBars]::Vertical
$preview.BackColor=[Drawing.Color]::White
$preview.Font=New-Font 10
$preview.Location=New-Object Drawing.Point(24,669)
$preview.Size=New-Object Drawing.Size(914,158)
$preview.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right -bor [Windows.Forms.AnchorStyles]::Bottom
$preview.AccessibleName='Read-only proposed file changes and review messages'
$preview.TabIndex=13
$form.Controls.Add($preview)
$script:status=$status
$script:preview=$preview
$script:details=$details
$script:currentReview=$null
function Clear-Preview {
    $script:currentReview=$null
    $script:details.Enabled=$false
    $script:preview.Text='No current review. Select folders and press Review Only.'
    $script:status.Text='Selections changed. Run Review Only again.'
}
foreach($f in @($clientField.Field,$sourceField.Field,$backupField.Field,$realm)){
    $f.Add_TextChanged({Clear-Preview})
}
$login.Add_CheckedChanged({Clear-Preview})
$loading.Add_CheckedChanged({Clear-Preview})
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
    $script:status.Text='Inspecting selected files (read-only)...'
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
            $script:status.Text='Needs review - see View File Details. No changes made.'
        }else{
            $script:status.Text='No preflight blockers - still preview only. Nothing approved.'
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
        $script:status.Text='Review unavailable - no changes made.'
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
if($DetailDiagnostics){
    try{
        $json=Invoke-ReadOnlyReview $ClientPath $PatchSourcePath $BackupRoot $RealmHost ([bool]$VanillaLogin) ([bool]$VanillaLoading) $true
        $data=$json|ConvertFrom-Json
        Assert-WizardReadOnlyReport $data
        $dialog=New-WizardDetailsForm $data
        try{
            $grid=@($dialog.Controls.Find('ReadOnlyFileActionGrid',$true))[0]
            $issues=@($dialog.Controls.Find('ReadOnlyIssues',$true))[0]
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
        action_labels=@($buttons | ForEach-Object {$_.Text})
        details_action_initially_disabled=(-not $details.Enabled)
        detail_view_is_read_only=$true
        preview_read_only=$preview.ReadOnly
        default_keyboard_action=$form.AcceptButton.Name
        cancel_keyboard_action=$form.CancelButton.Name
        selection_changes_clear_stale_review=$eventClearsStaleReview
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
