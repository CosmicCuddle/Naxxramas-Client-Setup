#requires -Version 5.1
<#
Read-only Windows Forms presentation helpers for the Naxxramas setup wizard.
Only accepts the established player review report. No file operations.
Loaded by Start-Naxxramas-SetupWizard.ps1 after Windows Forms assemblies.
#>
Set-StrictMode -Version Latest
function Assert-WizardReadOnlyReport([object]$Report){
    $paths=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
             'Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
    $actions=@('no_change','leave_existing','not_selected','install',
               'replace_after_backup','blocked')
    if($null -eq $Report -or
       $Report.kind -cne 'read_only_player_facing_installation_review' -or
       [int]$Report.schema_version -ne 1 -or
       $Report.status -cnotin @('read_only_player_review_BLOCKED_MANUAL_REVIEW',
          'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') -or
       @($Report.file_reviews).Count -ne 5 -or
       -not [bool]$Report.read_only -or
       -not [bool]$Report.review_required -or
       [bool]$Report.client_files_modified -or
       [bool]$Report.original_backups_created -or
       [bool]$Report.file_writes_authorised -or
       [bool]$Report.automatic_resume_authorised -or
       [bool]$Report.rollback_authorised -or
       [bool]$Report.genuine_user_consent_collected -or
       [bool]$Report.public_patch_distribution_authorised){
        throw 'Unexpected review data or permission fields.'
    }
    for($i=0;$i -lt 5;$i++){
        if($Report.file_reviews[$i].relative_path -cne $paths[$i] -or
           $Report.file_reviews[$i].proposed_action -cnotin $actions -or
           [bool]$Report.file_reviews[$i].original_backup_created){
            throw 'Unexpected file/action order or backup state.'
        }
    }
}
function Get-WizardInputHint([string]$Client,[string]$Source,[string]$Backup){
    if([string]::IsNullOrWhiteSpace($Client)){
        return 'Choose your existing WoW client folder first.'
    }
    if(-not (Test-Path -LiteralPath $Client.Trim() -PathType Container)){
        return 'Client folder not found. Browse to the existing folder containing Wow.exe.'
    }
    if(-not [string]::IsNullOrWhiteSpace($Source) -and
       -not (Test-Path -LiteralPath $Source.Trim() -PathType Container)){
        return 'Patch-source folder not found. Choose an existing local folder or leave it blank if no replacement source is needed.'
    }
    if(-not [string]::IsNullOrWhiteSpace($Backup) -and
       -not (Test-Path -LiteralPath $Backup.Trim() -PathType Container)){
        return 'Backup folder not found. Choose an existing separate folder. Nothing will be created.'
    }
    return ''
}
function Format-WizardSummary([object]$Report){
    Assert-WizardReadOnlyReport $Report
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('REVIEW ONLY - NOTHING INSTALLED, BACKED UP OR APPROVED')
    $lines.Add(('Patch set: '+$Report.patch_set_version+' | Realm: '+$Report.realm_address))
    $lines.Add('')
    $lines.Add('PROPOSED ACTIONS')
    foreach($entry in $Report.file_reviews){
        $lines.Add(('- '+$entry.name+': '+$entry.player_explanation))
    }
    $lines.Add('')
    if($Report.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW'){
        $lines.Add('ISSUES REQUIRE ATTENTION')
        foreach($issue in @($Report.concerns)){$lines.Add(('- '+$issue))}
    }else{
        $lines.Add('No preflight blockers observed. This is NOT installation permission.')
    }
    $lines.Add('')
    $lines.Add('Use View File Details for a larger table, backup needs and notes.')
    return ($lines -join [Environment]::NewLine)
}
function New-WizardDetailsForm([object]$Report){
    Assert-WizardReadOnlyReport $Report
    $win=New-Object Windows.Forms.Form
    $win.Name='ReadOnlyFileDetails'
    $win.Text='Naxxramas - File Details (Review Only)'
    $win.StartPosition=[Windows.Forms.FormStartPosition]::CenterParent
    $win.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
    $win.ClientSize=New-Object Drawing.Size(900,730)
    $win.MinimumSize=New-Object Drawing.Size(780,665)
    $win.Font=New-Object Drawing.Font('Segoe UI',10)
    $win.BackColor=[Drawing.Color]::FromArgb(247,249,252)
    $banner=New-Object Windows.Forms.Label
    $banner.Name='ReadOnlyDetailsBanner'
    $banner.Text='FILE REVIEW ONLY - No installation, backups, approval or rollback.'
    $banner.Location=New-Object Drawing.Point(22,17)
    $banner.Size=New-Object Drawing.Size(854,34)
    $banner.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
    $banner.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $win.Controls.Add($banner)
    $summary=New-Object Windows.Forms.Label
    $summary.Name='ReadOnlyDetailsSummary'
    $summary.Text=('Proposed additions: '+$Report.proposed_new_file_count+
        '  |  Originals needing future backup: '+$Report.proposed_replace_after_backup_count)
    $summary.Location=New-Object Drawing.Point(22,54)
    $summary.Size=New-Object Drawing.Size(854,28)
    $summary.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $win.Controls.Add($summary)
    $grid=New-Object Windows.Forms.DataGridView
    $grid.Name='ReadOnlyFileActionGrid'
    $grid.Location=New-Object Drawing.Point(22,94)
    $grid.Size=New-Object Drawing.Size(854,244)
    $grid.Anchor=[Windows.Forms.AnchorStyles]::Top -bor
        [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $grid.ReadOnly=$true
    $grid.AllowUserToAddRows=$false
    $grid.AllowUserToDeleteRows=$false
    $grid.AllowUserToResizeRows=$false
    $grid.RowHeadersVisible=$false
    $grid.MultiSelect=$false
    $grid.SelectionMode=[Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.AutoSizeColumnsMode=[Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.AutoSizeRowsMode=[Windows.Forms.DataGridViewAutoSizeRowsMode]::AllCells
    $grid.DefaultCellStyle.WrapMode=[Windows.Forms.DataGridViewTriState]::True
    $grid.ColumnHeadersHeight=38
    $grid.ColumnHeadersHeightSizeMode=[Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.AccessibleName='Five read-only game file actions'
    $grid.TabIndex=0
    $grid.TabStop=$true
    [void]$grid.Columns.Add('File','Game file')
    [void]$grid.Columns.Add('Proposed','Proposed action - nothing changed')
    [void]$grid.Columns.Add('Backup','Backup original first?')
    $grid.Columns[0].FillWeight=25
    $grid.Columns[1].FillWeight=55
    $grid.Columns[2].FillWeight=20
    foreach($column in $grid.Columns){
        $column.SortMode=[Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    }
    foreach($entry in $Report.file_reviews){
        $backup=if($entry.original_backup_required){'YES - not created'}else{'No'}
        [void]$grid.Rows.Add([string]$entry.name,
            [string]$entry.player_explanation,$backup)
    }
    $grid.ClearSelection()
    $win.Controls.Add($grid)
    $heading=New-Object Windows.Forms.Label
    $heading.Text='Issues and important notes'
    $heading.Location=New-Object Drawing.Point(22,353)
    $heading.Size=New-Object Drawing.Size(820,29)
    $heading.Font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
    $win.Controls.Add($heading)
    $notes=New-Object Windows.Forms.RichTextBox
    $notes.Name='ReadOnlyIssues'
    $notes.ReadOnly=$true
    $notes.DetectUrls=$false
    $notes.Location=New-Object Drawing.Point(22,390)
    $notes.Size=New-Object Drawing.Size(854,145)
    # Expand the long-warning reader on taller screens, but keep the fixed
    # footer and Close Review control visible when the window is reduced.
    $notes.Anchor=[Windows.Forms.AnchorStyles]::Top -bor
        [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right -bor
        [Windows.Forms.AnchorStyles]::Bottom
    $notes.ScrollBars=[Windows.Forms.RichTextBoxScrollBars]::Vertical
    $notes.WordWrap=$true
    $notes.TabIndex=1
    $notes.AccessibleName='Read-only warnings and issues'
    $lines=New-Object 'System.Collections.Generic.List[string]'
    if($Report.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW'){
        $lines.Add('Manual review required. Do not replace any files.')
    }else{
        $lines.Add('No preflight blockers observed. No installation permission has been granted.')
    }
    foreach($c in @($Report.concerns)){$lines.Add(('- '+$c))}
    foreach($n in @($Report.notes)){$lines.Add(('- '+$n))}
    $notes.Text=$lines -join [Environment]::NewLine
    $win.Controls.Add($notes)
    $footer=New-Object Windows.Forms.Label
    $footer.Name='ReadOnlyStorageNotice'
    $footer.Text=('Original bytes needing future backup: '+$Report.original_bytes_that_would_need_backup+
       '. Separate backup folder selected: '+$(if($Report.separate_backup_folder_selected){'Yes'}else{'No'})+
       '. No backups created or space reserved.')
    $footer.Location=New-Object Drawing.Point(22,551)
    $footer.Size=New-Object Drawing.Size(850,62)
    $footer.Anchor=[Windows.Forms.AnchorStyles]::Bottom -bor
        [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $win.Controls.Add($footer)
    $close=New-Object Windows.Forms.Button
    $close.Name='CloseDetails'
    $close.Text='Close Review'
    $close.Location=New-Object Drawing.Point(730,662)
    $close.Size=New-Object Drawing.Size(146,41)
    $close.Anchor=[Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Right
    $close.AccessibleName='Close read-only file details'
    $close.TabIndex=2
    $close.Add_Click({$win.Close()})
    $win.Controls.Add($close)
    $win.AcceptButton=$close
    $win.CancelButton=$close
    return $win
}
