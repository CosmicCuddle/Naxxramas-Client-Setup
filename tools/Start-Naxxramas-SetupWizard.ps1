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
    [switch]$TbcLogin,
    [switch]$AddonSuite,
    [string]$AddonModules,
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
. (Join-Path $PSScriptRoot 'Naxxramas-OptionalContent.ps1')
$optionalCatalog=Read-NaxxOptionalCatalog
Assert-NaxxOptionalChoice ([bool]$VanillaLogin) ([bool]$TbcLogin)
$addonModulesExplicit=[bool]$PSBoundParameters.ContainsKey('AddonModules')
$initialAddonModules=@(Resolve-NaxxAddonModules ([bool]$AddonSuite) $AddonModules $addonModulesExplicit)
if(-not (Test-Path -LiteralPath $reviewTool -PathType Leaf)){
    throw 'The read-only planner review is missing.'
}
function Invoke-ReadOnlyReview(
    [string]$Client,[string]$Source,[string]$Backup,[string]$Realm,
    [bool]$UseLogin,[bool]$UseLoading,[bool]$UseTbc,[bool]$AsJson
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
    if($UseTbc){$p.TbcLogin=$true}
    if($AsJson){$p.Json=$true}
    $result=(& $reviewTool @p | Out-String).TrimEnd()
    if([string]::IsNullOrWhiteSpace($result)){throw 'The read-only planner returned no review.'}
    return $result
}
if($PreviewJson){
    $report=Invoke-ReadOnlyReview $ClientPath $PatchSourcePath $BackupRoot $RealmHost ([bool]$VanillaLogin) ([bool]$VanillaLoading) ([bool]$TbcLogin) $true
    $data=$report | ConvertFrom-Json
    $data=Add-NaxxOptionalReview $data $optionalCatalog ([bool]$TbcLogin) ([bool]$AddonSuite) $initialAddonModules $ClientPath
    Write-Output ($data | ConvertTo-Json -Depth 7)
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
    $l.ForeColor=if($Bold){$wizardTheme.SectionText}else{$wizardTheme.Text}
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
    $field.BackColor=$wizardTheme.Input
    $field.ForeColor=$wizardTheme.InputText
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
    Set-NaxxramasSecondaryButton $browse
    return [pscustomobject]@{Caption=$caption;Field=$field;Browse=$browse}
}
# Native controls retain their system keyboard/focus, role and screen-reader
# semantics. Only ordinary (not High Contrast) colours/borders are themed.
function Set-NaxxramasSecondaryButton([Windows.Forms.Button]$Button){
    if(-not $wizardTheme.HighContrast){
        $Button.UseVisualStyleBackColor=$false
        $Button.BackColor=$wizardTheme.Surface
        $Button.ForeColor=$wizardTheme.SurfaceText
        $Button.FlatStyle=[Windows.Forms.FlatStyle]::Flat
        $Button.FlatAppearance.BorderColor=$wizardTheme.Border
        $Button.FlatAppearance.BorderSize=1
    }
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
$form.AutoScrollMinSize=New-Object Drawing.Size(0,1570)
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
# Non-interactive accent trim: outside the text and native focus areas.
$headerTrim=New-Object Windows.Forms.Panel
$headerTrim.Name='NaxxramasHeaderTrim'
$headerTrim.Location=New-Object Drawing.Point(0,86)
$headerTrim.Size=New-Object Drawing.Size(962,3)
$headerTrim.BackColor=$wizardTheme.Border
$headerTrim.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$header.Controls.Add($headerTrim)
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
$tbc=New-Object Windows.Forms.CheckBox
$tbc.Name='TbcLogin'
$tbc.Text='TBC login screen (Patch-C) - optional, included in review'
$tbc.Checked=[bool]$TbcLogin
$tbc.Location=New-Object Drawing.Point(27,477)
$tbc.Size=New-Object Drawing.Size(820,32)
$tbc.TabIndex=8
$tbc.AccessibleName='Optional TBC login Patch-C, incompatible with Vanilla login Patch-J'
$login.ForeColor=$wizardTheme.Text
$loading.ForeColor=$wizardTheme.Text
$tbc.ForeColor=$wizardTheme.Text
$login.BackColor=$wizardTheme.Window
$loading.BackColor=$wizardTheme.Window
$tbc.BackColor=$wizardTheme.Window
$form.Controls.AddRange(@($login,$loading,$tbc))
$core=New-Label 'Core patches V and Z are always required for this setup.' 515
$core.ForeColor=$wizardTheme.MutedText
$form.Controls.Add($core)
# Always expose independent J/U status. When both are selected, show the
# known loading-screen overlap BEFORE reviewing, not only in planner notes.
$optionInfo=New-Label '' 555
$optionInfo.Name='OptionalPatchStatus'
$optionInfo.Size=New-Object Drawing.Size(914,70)
$optionInfo.AccessibleName='Optional patches J, U and C status and incompatibility warnings'
$form.Controls.Add($optionInfo)
$form.Controls.Add((New-Label '3. Optional N Addon Suite (future setup only)' 641 $true))
$suite=New-Object Windows.Forms.CheckBox
$suite.Name='AddonSuite'
$suite.Text='Include N Addon Suite v2.0.0 in a future setup (not installed by this preview)'
$suite.Checked=[bool]$AddonSuite
$suite.Location=New-Object Drawing.Point(27,677)
$suite.Size=New-Object Drawing.Size(914,34)
$suite.TabIndex=9
$suite.AccessibleName='Optional N Addon Suite version 2, planning only'
$suite.ForeColor=$wizardTheme.Text
$suite.BackColor=$wizardTheme.Window
$form.Controls.Add($suite)
$moduleChecks=@()
$moduleNames=@('IndividualProgressionAddon','DungeonJournal','MultiBot','NaxxLootLottery')
$moduleLabels=@('Individual Progression Companion','Dungeon Journal','MultiBot Chatless','N Loot Ledger (WIP)')
for($i=0;$i -lt 4;$i++){
    $check=New-Object Windows.Forms.CheckBox
    $check.Name=$moduleNames[$i]
    $check.Text=($moduleLabels[$i]+' (future NCore setting)')
    $check.Location=New-Object Drawing.Point(48,(723+($i*39)))
    $check.Size=New-Object Drawing.Size(890,32)
    $check.TabIndex=(10+$i)
    $check.Checked=(-not $addonModulesExplicit -or $initialAddonModules -ccontains $moduleNames[$i])
    $check.Enabled=$suite.Checked
    $check.ForeColor=$wizardTheme.Text
    $check.BackColor=$wizardTheme.Window
    $check.AccessibleName=($moduleLabels[$i]+' preference, only active when suite selected')
    $form.Controls.Add($check)
    $moduleChecks+=,$check
}
$addonInfo=New-Label '' 892
$addonInfo.Name='AddonSuiteCatalog'
$addonInfo.Size=New-Object Drawing.Size(914,82)
$addonInfo.AccessibleName='Addon collection includes NCore and four separately configurable modules'
$addonInfo.Text='NCore is always part of the suite and includes Classic Battlegrounds.'+[Environment]::NewLine+
    'These checkboxes describe future NCore settings, NOT which folders are copied. No addons or SavedVariables are changed.'
$addonInfo.AccessibleDescription=$addonInfo.Text
$form.Controls.Add($addonInfo)
$form.Controls.Add((New-Label 'Realm address (optional override, blank uses configured value)' 990 $true))
$realm=New-Object Windows.Forms.TextBox
$realm.Name='RealmAddress'
$realm.Text=$RealmHost
$realm.Location=New-Object Drawing.Point(24,1022)
$realm.Size=New-Object Drawing.Size(914,30)
$realm.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$realm.AccessibleName='Optional realm address'
$realm.BackColor=$wizardTheme.Input
$realm.ForeColor=$wizardTheme.InputText
$realm.TabIndex=14
$form.Controls.Add($realm)

$form.Controls.Add((New-Label '4. Review proposed changes' 1078 $true))
$review=New-Object Windows.Forms.Button
$review.Name='ReviewOnly'
$review.Text='Review Only'
$review.Location=New-Object Drawing.Point(24,1118)
$review.Size=New-Object Drawing.Size(165,40)
$review.BackColor=$wizardTheme.Accent
$review.ForeColor=$wizardTheme.AccentText
$review.FlatStyle=[Windows.Forms.FlatStyle]::Flat
$review.UseVisualStyleBackColor=$false
$review.FlatAppearance.BorderColor=$wizardTheme.Border
$review.FlatAppearance.BorderSize=1
$review.AccessibleName='Read-only review of proposed changes'
$review.TabIndex=15
$clear=New-Object Windows.Forms.Button
$clear.Name='ClearReview'
$clear.Text='Clear Review'
$clear.Location=New-Object Drawing.Point(203,1118)
$clear.Size=New-Object Drawing.Size(140,40)
$clear.TabIndex=16
$clear.AccessibleName='Clear the current read-only review'
$clear.ForeColor=$wizardTheme.Text
$close=New-Object Windows.Forms.Button
$close.Name='CloseWizard'
$close.Text='Close'
$close.Location=New-Object Drawing.Point(817,1118)
$close.Size=New-Object Drawing.Size(121,40)
$close.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$close.TabIndex=11
$details=New-Object Windows.Forms.Button
$details.Name='ViewFileDetails'
$details.Text='View File Details...'
$details.Location=New-Object Drawing.Point(357,1118)
$details.Size=New-Object Drawing.Size(207,40)
$details.AccessibleName='Open larger read-only file action table'
$details.Enabled=$false
$details.TabIndex=17
$details.ForeColor=$wizardTheme.Text
$readText=New-Object Windows.Forms.Button
$readText.Name='ReadReviewText'
$readText.Text='Read Review Text'
$readText.Location=New-Object Drawing.Point(24,1169)
$readText.Size=New-Object Drawing.Size(183,40)
$readText.TabIndex=18
$readText.AccessibleName='Focus the read-only review text'
$readText.AccessibleDescription='Moves keyboard focus to the review result. It never installs, approves or changes files.'
$readText.ForeColor=$wizardTheme.Text
$close.TabIndex=19
$close.AccessibleName='Close the read-only setup wizard'
$close.ForeColor=$wizardTheme.Text
foreach($button in @($clear,$details,$close,$readText)){
    Set-NaxxramasSecondaryButton $button
}
$form.Controls.AddRange(@($review,$clear,$details,$close,$readText))
$status=New-Label 'Not reviewed - no files have been changed.' 1169
$status.Name='ReviewStatus'
$status.Location=New-Object Drawing.Point(222,1166)
$status.Size=New-Object Drawing.Size(712,51)
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
$preview.Location=New-Object Drawing.Point(24,1231)
$preview.Size=New-Object Drawing.Size(914,171)
$preview.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
$preview.AccessibleName='Read-only proposed file changes and review messages'
$preview.TabIndex=20
$form.Controls.Add($preview)
$script:status=$status
$script:preview=$preview
$script:details=$details
$script:currentReview=$null
function Set-ReviewStatus([string]$Message){
    $script:status.Text=$Message
    $script:status.AccessibleDescription=$Message
    # Static accessible metadata is not guaranteed to trigger a screen-reader
    # announcement. Keep the focusable read-only reader's description current.
    $script:preview.AccessibleDescription=('Review status: '+$Message+
        ' Read-only result. Use Read Review Text to read it with the keyboard.')
}
Set-ReviewStatus $status.Text
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
    $c=if($tbc.Checked){'ON'}else{'OFF'}
    $info='Optional selection: Patch-J '+$j+' | Patch-U '+$u+' | Patch-C '+$c+'.'
    if($login.Checked -and $loading.Checked){
        $info+=[Environment]::NewLine+
            'WARNING: J and U overlap on two loading screens. Combined appearance is untested.'
    }else{
        $info+=[Environment]::NewLine+
            'Patch-C (TBC login) and Patch-J (Vanilla login) cannot be used together.'
    }
    if($tbc.Checked){
        $info+=[Environment]::NewLine+'Patch-C fingerprint registered. Existing Patch-J MPQs still block incompatible login choices.'
    }
    $optionInfo.Text=$info
    $optionInfo.AccessibleDescription=$info
}
$login.Add_CheckedChanged({
    if($login.Checked -and $tbc.Checked){$tbc.Checked=$false}
    Clear-Preview
    Update-OptionalStatus
})
$loading.Add_CheckedChanged({Clear-Preview; Update-OptionalStatus})
$tbc.Add_CheckedChanged({
    if($tbc.Checked -and $login.Checked){$login.Checked=$false}
    Clear-Preview
    Update-OptionalStatus
})
$suite.Add_CheckedChanged({
    foreach($item in $moduleChecks){$item.Enabled=$suite.Checked}
    Clear-Preview
})
foreach($item in $moduleChecks){$item.Add_CheckedChanged({Clear-Preview})}
function Get-SelectedAddonModules {
    if(-not $suite.Checked){return}
    foreach($item in $moduleChecks){
        if($item.Checked){Write-Output ([string]$item.Name)}
    }
}
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
        $json=Invoke-ReadOnlyReview $clientField.Field.Text $sourceField.Field.Text $backupField.Field.Text $realm.Text $login.Checked $loading.Checked $tbc.Checked $true
        $data=$json | ConvertFrom-Json
        Assert-WizardReadOnlyReport $data
        $modules=@(Get-SelectedAddonModules)
        $data=Add-NaxxOptionalReview $data $optionalCatalog $tbc.Checked $suite.Checked $modules $clientField.Field.Text
        $script:preview.Text=(Format-WizardSummary $data)+[Environment]::NewLine+[Environment]::NewLine+(Get-NaxxOptionalSummary $data)
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
# Explicit keyboard path to the existing read-only, scrollable result. This
# control never invokes the planner and never changes a file or grants consent.
$readText.Add_Click({
    $form.ActiveControl=$script:preview
    $script:preview.Select(0,0)
    $script:preview.ScrollToCaret()
})
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
        $json=Invoke-ReadOnlyReview $ClientPath $PatchSourcePath $BackupRoot $RealmHost ([bool]$VanillaLogin) ([bool]$VanillaLoading) ([bool]$TbcLogin) $true
        $data=$json|ConvertFrom-Json
        Assert-WizardReadOnlyReport $data
        $data=Add-NaxxOptionalReview $data $optionalCatalog ([bool]$TbcLogin) ([bool]$AddonSuite) $initialAddonModules $ClientPath
        $dialog=New-WizardDetailsForm $data
        try{
            $grid=@($dialog.Controls.Find('ReadOnlyFileActionGrid',$true))[0]
            $issues=@($dialog.Controls.Find('ReadOnlyIssues',$true))[0]
            $region=@($dialog.Controls.Find('ReadOnlyDetailsContent',$true))[0]
            $footer=@($dialog.Controls.Find('ReadOnlyStorageNotice',$true))[0]
            $closeReview=@($dialog.Controls.Find('CloseDetails',$true))[0]
            $banner=@($dialog.Controls.Find('ReadOnlyDetailsBanner',$true))[0]
            $theme=Get-WizardTheme ([Windows.Forms.SystemInformation]::HighContrast)
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
                tbc_login_selected=[bool]$data.tbc_login_selected
                addon_suite_selected=[bool]$data.addon_suite_selected
                addon_modules_planned=@($data.addon_modules_planned)
                addon_folder_inventory=@($data.addon_folder_inventory)
                optional_content_blocked=([bool]$data.addon_suite_selected) -and
                    $data.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW'
                concerns_count=@($data.concerns).Count
                grid_read_only=$grid.ReadOnly
                grid_add_delete_disabled=(-not $grid.AllowUserToAddRows -and -not $grid.AllowUserToDeleteRows)
                warnings_read_only=$issues.ReadOnly
                detail_matches_system_contrast=($dialog.BackColor -eq $theme.Window -and
                    $banner.ForeColor -eq $theme.SectionText -and
                    $issues.BackColor -eq $theme.Input -and
                    $issues.ForeColor -eq $theme.InputText -and
                    $grid.DefaultCellStyle.BackColor -eq $theme.Input -and
                    $grid.DefaultCellStyle.ForeColor -eq $theme.InputText -and
                    $grid.ColumnHeadersDefaultCellStyle.BackColor -eq $theme.Surface -and
                    $grid.ColumnHeadersDefaultCellStyle.ForeColor -eq $theme.SurfaceText)
                details_notes_accessible=(-not [string]::IsNullOrWhiteSpace($issues.AccessibleName) -and
                    $issues.AccessibleDescription.Contains('Read-only'))
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
                close_review_click_closes_dialog=$false
                no_approval_or_installation=$true
            }
            # Dispatch the REAL registered Click event without Show/ShowDialog.
            # The protected WinForms OnClick method invokes the handler even
            # while the test form is not visible, catching event-scope defects
            # that static geometry diagnostics cannot detect.
            $clickMethod=[Windows.Forms.Control].GetMethod('OnClick',
                ([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
            if($null -eq $clickMethod){throw 'Cannot exercise the Close Review click handler.'}
            [void]$clickMethod.Invoke($closeReview,[object[]]@([EventArgs]::Empty))
            $info.close_review_click_closes_dialog=[bool]$dialog.IsDisposed
            Write-Output ($info|ConvertTo-Json -Depth 5)
        }finally{$dialog.Dispose()}
    }finally{$form.Dispose()}
    return
}
if($Diagnostics){
    # Verify the actual CheckedChanged handler clears stale details.
    # This is an in-memory UI-only event; no planner or client is accessed.
    $initialLogin=$login.Checked
    $initialTbc=$tbc.Checked
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $login.Checked=(-not $initialLogin)
    $eventClearsStaleReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $login.Checked=$initialLogin
    # J is exclusive with C; an exercised J toggle may have switched C off.
    # Restore the initially requested diagnostic selection before reporting.
    $tbc.Checked=$initialTbc
    $originalRealm=$realm.Text
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $realm.Text=($originalRealm+'fixture.invalid')
    $realmChangeClearsReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $realm.Text=$originalRealm
    # Toggle the actual C/J handlers; they must never remain checked together.
    $wasC=$tbc.Checked
    $wasJ=$login.Checked
    $tbc.Checked=$true
    $cDeselectsJ=($tbc.Checked -and -not $login.Checked)
    $login.Checked=$true
    $jDeselectsC=($login.Checked -and -not $tbc.Checked)
    $login.Checked=$wasJ
    $tbc.Checked=$wasC
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $suite.Checked=(-not $suite.Checked)
    $suiteClearsReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $suite.Checked=(-not $suite.Checked)
    $script:currentReview=[pscustomobject]@{fixture_only=$true}
    $script:details.Enabled=$true
    $moduleChecks[0].Checked=(-not $moduleChecks[0].Checked)
    $moduleClearsReview=($null -eq $script:currentReview -and -not $details.Enabled)
    $moduleChecks[0].Checked=(-not $moduleChecks[0].Checked)
    $contrastTheme=Get-WizardTheme $true
    $buttons=@($review,$clear,$details,$readText,$close,
        $clientField.Browse,$sourceField.Browse,$backupField.Browse)
    # Exercise the ACTUAL registered click handler while the form is hidden:
    # this checks the keyboard-focus route without showing a window or
    # reading any client path / file.
    $readerClick=[Windows.Forms.Control].GetMethod('OnClick',
        ([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
    if($null -eq $readerClick){throw 'Cannot exercise Read Review Text click handler.'}
    [void]$readerClick.Invoke($readText,[object[]]@([EventArgs]::Empty))
    $readerFocusesResult=($form.ActiveControl -eq $preview -and
        $preview.SelectionStart -eq 0)
    $form.ActiveControl=$clientField.Field
    $report=[pscustomobject][ordered]@{
        kind='read_only_windows_setup_wizard_layout'
        schema_version=1
        title=$form.Text
        form_built=$true
        form_displayed=$false
        folder_count=3
        optional_patch_toggle_count=3
        mandatory_patch_toggle_count=0
        optional_addon_toggle_count=5
        addon_module_names=@($moduleChecks|ForEach-Object {$_.Name})
        addon_module_choice_count=@($moduleChecks|Where-Object {$_.Checked}).Count
        module_choices_depend_on_suite=(@($moduleChecks|Where-Object {$_.Enabled -ne $suite.Checked}).Count -eq 0)
        addon_module_changed_clears_review=$moduleClearsReview
        tbc_login_selected=$tbc.Checked
        addon_suite_selected=$suite.Checked
        tbc_and_vanilla_mutually_exclusive=($cDeselectsJ -and $jDeselectsC -and
            -not ($tbc.Checked -and $login.Checked))
        addon_catalog_visible=($addonInfo.Parent -eq $form -and
            $addonInfo.Text.Contains('NCore') -and @($moduleChecks).Count -eq 4)
        optional_login_selected=$login.Checked
        optional_loading_selected=$loading.Checked
        optional_status_text=$optionInfo.Text
        optional_status_accessible=($optionInfo.AccessibleDescription -ceq $optionInfo.Text)
        system_contrast_enabled=[bool]$wizardTheme.HighContrast
        contrast_matches_windows=([bool]$wizardTheme.HighContrast -eq
            [bool][Windows.Forms.SystemInformation]::HighContrast)
        theme_preserves_standard_palette=(
            $wizardTheme.HighContrast -or
            ($form.BackColor -eq $wizardTheme.Window -and
             $header.BackColor -eq $wizardTheme.Header -and
             $review.BackColor -eq $wizardTheme.Accent))
        high_contrast_palette_uses_system_colours=(
            $contrastTheme.Window -eq [Drawing.SystemColors]::Window -and
            $contrastTheme.Text -eq [Drawing.SystemColors]::WindowText -and
            $contrastTheme.Accent -eq [Drawing.SystemColors]::Highlight -and
            $contrastTheme.AccentText -eq [Drawing.SystemColors]::HighlightText)
        naxx_preview_theme_controls=(
            $headerTrim.BackColor -eq $wizardTheme.Border -and
            $clientField.Field.BackColor -eq $wizardTheme.Input -and
            $clientField.Field.ForeColor -eq $wizardTheme.InputText -and
            $clientField.Caption.ForeColor -eq $wizardTheme.SectionText -and
            $login.BackColor -eq $wizardTheme.Window -and
            $suite.BackColor -eq $wizardTheme.Window -and
            ($wizardTheme.HighContrast -or
             ($clear.BackColor -eq $wizardTheme.Surface -and
              $clear.ForeColor -eq $wizardTheme.SurfaceText -and
              $review.BackColor -eq $wizardTheme.Accent)))
        high_contrast_extra_palette_uses_system_colours=(
            $contrastTheme.SectionText -eq [Drawing.SystemColors]::WindowText -and
            $contrastTheme.Surface -eq [Drawing.SystemColors]::Control -and
            $contrastTheme.SurfaceText -eq [Drawing.SystemColors]::ControlText -and
            $contrastTheme.Border -eq [Drawing.SystemColors]::ControlDark)
        contrast_applied_to_actual_controls=(
            $form.BackColor -eq $wizardTheme.Window -and
            $header.BackColor -eq $wizardTheme.Header -and
            $review.ForeColor -eq $wizardTheme.AccentText -and
            $preview.BackColor -eq $wizardTheme.Input)
        review_status_accessible=($status.AccessibleDescription -ceq $status.Text -and
            $status.AccessibleName -ceq 'Read-only review status')
        result_reader_status_synchronised=($preview.AccessibleDescription.Contains(
            'Review status: '+$status.Text) -and $preview.ReadOnly)
        read_review_text_accessible=($readText.TabStop -and
            $readText.TabIndex -eq 18 -and $close.TabIndex -eq 19 -and
            $preview.TabIndex -eq 20 -and
            $readText.AccessibleName -ceq 'Focus the read-only review text')
        read_review_text_click_focuses_result=$readerFocusesResult
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
        optional_status_inside_scroll_extent=($optionInfo.Bottom -le $form.AutoScrollMinSize.Height -and $addonInfo.Bottom -le $form.AutoScrollMinSize.Height)
        optional_controls_do_not_overlap=($loading.Top -ge $login.Bottom -and
            $tbc.Top -ge $loading.Bottom -and $suite.Top -ge $optionInfo.Bottom -and
            $addonInfo.Bottom -lt $realm.Top -and
            $moduleChecks[0].Top -ge $suite.Bottom -and
            $moduleChecks[3].Bottom -le $addonInfo.Top)
        folder_browse_buttons_inside_viewport=($clientField.Browse.Right -le $form.ClientSize.Width -and
            $sourceField.Browse.Right -le $form.ClientSize.Width -and
            $backupField.Browse.Right -le $form.ClientSize.Width)
        action_buttons_inside_viewport=($close.Right -le $form.ClientSize.Width -and
            $details.Right -le $form.ClientSize.Width -and
            $readText.Right -le $form.ClientSize.Width)
        form_height=$form.Height
        working_area_height=$workingArea.Height
        preview_inside_scroll_extent=($preview.Bottom -le $form.AutoScrollMinSize.Height)
        default_keyboard_action=$form.AcceptButton.Name
        cancel_keyboard_action=$form.CancelButton.Name
        selection_changes_clear_stale_review=($eventClearsStaleReview -and $realmChangeClearsReview -and $suiteClearsReview -and $moduleClearsReview)
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
