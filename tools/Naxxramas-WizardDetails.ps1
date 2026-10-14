#requires -Version 5.1
<#
Read-only Windows Forms presentation helpers for the Naxxramas setup wizard.
Only accepts the established player review report. No file operations.
Loaded by Start-Naxxramas-SetupWizard.ps1 after Windows Forms assemblies.
#>
Set-StrictMode -Version Latest
function Assert-WizardReadOnlyReport([object]$Report){
    $paths=@('Data/patch-V.mpq','Data/patch-Z.mpq','Data/Patch-J.mpq',
             'Data/Patch-C.mpq','Data/Patch-U.mpq','Data/enUS/realmlist.wtf')
    $actions=@('no_change','leave_existing','not_selected','install',
               'replace_after_backup','blocked')
    if($null -eq $Report -or
       $Report.kind -cne 'read_only_player_facing_installation_review' -or
       [int]$Report.schema_version -ne 1 -or
       $Report.status -cnotin @('read_only_player_review_BLOCKED_MANUAL_REVIEW',
          'read_only_player_review_NO_PREFLIGHT_BLOCKERS_NOT_APPROVED') -or
       @($Report.file_reviews).Count -ne 6 -or
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
    for($i=0;$i -lt 6;$i++){
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
# Resolve a testable palette at construction time. In Windows High Contrast,
# use OS colours instead of fixed light-theme colours. This is not a claim
# of validated screen-reader behaviour or live DPI adjustment.

# Original, vector-only decorative artwork. Compiled locally from source on
# Windows PowerShell 5.1; no game images, downloaded assets or file writes.
# This is intentionally NOT a custom renderer for keyboard-operable controls.
if(-not ('NaxxramasNecropolisHeader' -as [type])){
    Add-Type -ReferencedAssemblies @('System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class NaxxramasNecropolisHeader : Panel
{
    private readonly Timer glowTimer;
    private int glowFrame;
    private bool motionRequested = true;

    [DllImport("user32.dll", SetLastError = false)]
    private static extern bool SystemParametersInfo(uint action, uint param,
        out int value, uint update);

    public NaxxramasNecropolisHeader()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        TabStop = false;
        glowTimer = new Timer();
        glowTimer.Interval = 170;
        glowTimer.Tick += delegate(object sender, EventArgs args)
        {
            glowFrame = (glowFrame + 1) % 720;
            Invalidate();
        };
    }

    public bool MotionAvailable
    {
        get
        {
            // Respect Windows' Reduce animation settings and High Contrast.
            // Failure to read system motion preference disables motion.
            if (SystemInformation.HighContrast || !SystemInformation.UIEffects)
                return false;
            int enabled = 0;
            return SystemParametersInfo(0x1042, 0, out enabled, 0) && enabled != 0;
        }
    }

    public bool MotionEnabled
    {
        get { return motionRequested && MotionAvailable; }
        set { motionRequested = value; SyncMotion(); Invalidate(); }
    }

    public bool AnimationRunning { get { return glowTimer.Enabled; } }
    public bool OriginalVectorArt { get { return true; } }

    private void SyncMotion()
    {
        if (IsHandleCreated && MotionEnabled)
            glowTimer.Start();
        else
            glowTimer.Stop();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        SyncMotion();
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        glowTimer.Stop();
        base.OnHandleDestroyed(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            glowTimer.Stop();
            glowTimer.Dispose();
        }
        base.Dispose(disposing);
    }

    private static PointF P(float x, float y) { return new PointF(x, y); }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (SystemInformation.HighContrast)
            return; // Never paint fantasy colours over Windows contrast settings.

        Graphics g = e.Graphics;
        SmoothingMode before = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        float w = ClientSize.Width;
        float h = ClientSize.Height;
        float cx = w - 195f, cy = h * 0.61f;
        float pulse = MotionEnabled
            ? (float)(0.5 + 0.5 * Math.Sin(glowFrame * 0.18))
            : 0.45f;
        try
        {
            using (var fog = new LinearGradientBrush(
                new PointF(w * 0.50f, 0), new PointF(w, h),
                Color.FromArgb(0, 14, 28, 30), Color.FromArgb(90, 18, 65, 65)))
            {
                g.FillRectangle(fog, w * 0.46f, 0, w * 0.54f, h);
            }

            // Framed antique-gold tracery and one static lower guide line.
            using (var line = new Pen(Color.FromArgb(95, 162, 143, 104), 1.2f))
            {
                g.DrawLine(line, 12, 10, 12, h - 13);
                g.DrawLine(line, 12, 10, 48, 10);
                g.DrawLine(line, 12, h - 13, 48, h - 13);
                g.DrawLine(line, w - 12, 12, w - 55, 12);
                g.DrawLine(line, w - 12, 12, w - 12, h - 14);
                g.DrawLine(line, w - 12, h - 14, w - 55, h - 14);
            }

            // A floating rune-gate, not traced from a game asset.
            using (var outer = new Pen(Color.FromArgb(65 + (int)(31*pulse),
                66, 189, 167), 6.0f))
            using (var inner = new Pen(Color.FromArgb(128 + (int)(36*pulse),
                113, 215, 188), 1.6f))
            {
                g.DrawEllipse(outer, cx - 70, cy - 65, 140, 130);
                g.DrawArc(inner, cx - 63, cy - 60, 126, 120, 195, 293);
            }

            // Floating stone island and original tiered spires.
            PointF[] island = {
                P(cx-148,cy+45), P(cx-107,cy+33), P(cx-56,cy+41),
                P(cx+23,cy+28), P(cx+111,cy+38), P(cx+143,cy+47),
                P(cx+96,cy+59), P(cx+40,cy+68), P(cx-28,cy+64),
                P(cx-89,cy+70), P(cx-130,cy+59)
            };
            using (var stone = new SolidBrush(Color.FromArgb(16, 25, 33)))
            using (var edge = new Pen(Color.FromArgb(130, 107, 141, 139), 1.3f))
            {
                g.FillPolygon(stone, island);
                g.DrawLines(edge, island);
            }
            using (var citadel = new SolidBrush(Color.FromArgb(29, 48, 56)))
            using (var outline = new Pen(Color.FromArgb(158, 121, 163, 151), 1.4f))
            {
                PointF[] keep = { P(cx-77,cy+37), P(cx-77,cy-17),
                    P(cx-49,cy-17), P(cx-49,cy-37), P(cx-28,cy-37),
                    P(cx-28,cy-55), P(cx,cy-72), P(cx+28,cy-55),
                    P(cx+28,cy-37), P(cx+48,cy-37), P(cx+48,cy-15),
                    P(cx+80,cy-15), P(cx+80,cy+39) };
                g.FillPolygon(citadel,keep);
                g.DrawLines(outline,keep);
                // Three needle spires and rune-lit windows.
                float[] towers = {cx-82,cx,cx+81};
                for(int i=0;i<towers.Length;i++)
                {
                    float x=towers[i];
                    float tip=(i==1?cy-108:cy-63);
                    PointF[] spire={P(x-12,cy+30),P(x-12,tip+21),
                        P(x,tip),P(x+12,tip+21),P(x+12,cy+30)};
                    g.FillPolygon(citadel,spire);
                    g.DrawLines(outline,spire);
                }
            }
            // Carved, glowing gate and slim windows.
            using (var lamp = new Pen(Color.FromArgb(127 + (int)(50*pulse),
                106, 215, 185), 2.0f))
            {
                g.DrawArc(lamp,cx-14,cy+9,28,29,180,180);
                g.DrawLine(lamp,cx-14,cy+23,cx-14,cy+39);
                g.DrawLine(lamp,cx+14,cy+23,cx+14,cy+39);
                g.DrawLine(lamp,cx-47,cy-22,cx-47,cy-2);
                g.DrawLine(lamp,cx+47,cy-22,cx+47,cy-2);
            }
            // Five rune diamonds drift only in brightness; no moving controls.
            for(int i=0;i<5;i++)
            {
                float x=cx-129+i*65, y=cy-40+(i%2)*18;
                int alpha=105+(int)(30*pulse);
                using (var pen=new Pen(Color.FromArgb(alpha,112,204,188),1.35f))
                {
                    g.DrawLines(pen,new PointF[]{
                        P(x,y-9),P(x+6,y),P(x,y+9),P(x-6,y),P(x,y-9)});
                    g.DrawLine(pen,x-4,y,x+4,y);
                }
            }
        }
        finally { g.SmoothingMode = before; }
    }
}
'@
}

function Get-WizardTheme([bool]$HighContrast){
    if($HighContrast){
        return [pscustomobject]@{
            HighContrast=$true
            Window=[Drawing.SystemColors]::Window
            Text=[Drawing.SystemColors]::WindowText
            Header=[Drawing.SystemColors]::Control
            HeaderText=[Drawing.SystemColors]::ControlText
            HeaderSecondary=[Drawing.SystemColors]::ControlText
            MutedText=[Drawing.SystemColors]::ControlText
            Input=[Drawing.SystemColors]::Window
            InputText=[Drawing.SystemColors]::WindowText
            Accent=[Drawing.SystemColors]::Highlight
            AccentText=[Drawing.SystemColors]::HighlightText
            SectionText=[Drawing.SystemColors]::WindowText
            Surface=[Drawing.SystemColors]::Control
            SurfaceText=[Drawing.SystemColors]::ControlText
            Border=[Drawing.SystemColors]::ControlDark
        }
    }
    return [pscustomobject]@{
        HighContrast=$false
        # Original Naxxramas-inspired colours; no copyrighted game textures.
        # Keep Segoe UI/native focus and scroll behaviour for accessibility.
        Window=[Drawing.Color]::FromArgb(19,29,40)
        Text=[Drawing.Color]::FromArgb(235,242,245)
        Header=[Drawing.Color]::FromArgb(12,20,30)
        HeaderText=[Drawing.Color]::FromArgb(241,246,247)
        HeaderSecondary=[Drawing.Color]::FromArgb(181,201,205)
        MutedText=[Drawing.Color]::FromArgb(181,201,205)
        Input=[Drawing.Color]::FromArgb(36,49,60)
        InputText=[Drawing.Color]::FromArgb(241,246,247)
        Accent=[Drawing.Color]::FromArgb(34,91,95)
        AccentText=[Drawing.Color]::White
        SectionText=[Drawing.Color]::FromArgb(219,189,125)
        Surface=[Drawing.Color]::FromArgb(36,49,60)
        SurfaceText=[Drawing.Color]::FromArgb(235,242,245)
        Border=[Drawing.Color]::FromArgb(120,147,142)
    }
}
function New-WizardDetailsForm([object]$Report){
    Assert-WizardReadOnlyReport $Report
    $theme=Get-WizardTheme ([Windows.Forms.SystemInformation]::HighContrast)
    $win=New-Object Windows.Forms.Form
    $win.Name='ReadOnlyFileDetails'
    $win.Text='Naxxramas - File Details (Review Only)'
    $win.StartPosition=[Windows.Forms.FormStartPosition]::CenterParent
    $win.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
    $win.Font=New-Object Drawing.Font('Segoe UI',10)
    $win.ClientSize=New-Object Drawing.Size(900,730)
    $win.MinimumSize=New-Object Drawing.Size(550,410)
    $win.AutoScroll=$true
    $win.AutoScrollMinSize=New-Object Drawing.Size(0,730)
    $win.BackColor=$theme.Window
    # The contents have a minimum *scroll extent*, not a screen-sized minimum
    # window. Bottom anchors resolve against this region, so shrinking a
    # laptop-size viewport cannot pile warnings and buttons on top of the grid.
    $content=New-Object Windows.Forms.Panel
    $content.Name='ReadOnlyDetailsContent'
    $content.Location=New-Object Drawing.Point(0,0)
    $content.Size=New-Object Drawing.Size(900,730)
    $content.BackColor=$theme.Window
    $win.Controls.Add($content)
    $banner=New-Object Windows.Forms.Label
    $banner.Name='ReadOnlyDetailsBanner'
    $banner.Text='FILE REVIEW ONLY - No files will be changed.'
    $banner.Location=New-Object Drawing.Point(22,17)
    $banner.Size=New-Object Drawing.Size(854,34)
    $banner.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
    $banner.ForeColor=$theme.SectionText
    $banner.AccessibleName='Read-only file review, no files changed'
    $banner.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $content.Controls.Add($banner)
    $summary=New-Object Windows.Forms.Label
    $summary.Name='ReadOnlyDetailsSummary'
    $summary.Text=('Proposed additions: '+$Report.proposed_new_file_count+
        '  |  Originals needing future backup: '+$Report.proposed_replace_after_backup_count)
    $summary.Location=New-Object Drawing.Point(22,54)
    $summary.ForeColor=$theme.Text
    $summary.AccessibleName='Summary of proposed additions and originals needing future backup'
    $summary.Size=New-Object Drawing.Size(854,28)
    $summary.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $content.Controls.Add($summary)
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
    # Apply an explicit palette in BOTH modes. High Contrast entries are
    # Windows SystemColors rather than hard-coded fantasy colours.
    $grid.BackgroundColor=$theme.Input
    $grid.DefaultCellStyle.BackColor=$theme.Input
    $grid.DefaultCellStyle.ForeColor=$theme.InputText
    $grid.DefaultCellStyle.SelectionBackColor=$theme.Accent
    $grid.DefaultCellStyle.SelectionForeColor=$theme.AccentText
    $grid.EnableHeadersVisualStyles=$false
    $grid.ColumnHeadersDefaultCellStyle.BackColor=$theme.Surface
    $grid.ColumnHeadersDefaultCellStyle.ForeColor=$theme.SurfaceText
    $grid.GridColor=$theme.Border
    $grid.ColumnHeadersHeight=38
    $grid.ColumnHeadersHeightSizeMode=[Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.AccessibleName='Six read-only game file actions'
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
    $content.Controls.Add($grid)
    $heading=New-Object Windows.Forms.Label
    $heading.Text='Issues and important notes'
    $heading.Location=New-Object Drawing.Point(22,353)
    $heading.Size=New-Object Drawing.Size(820,29)
    $heading.Font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
    $heading.ForeColor=$theme.SectionText
    $content.Controls.Add($heading)
    $notes=New-Object Windows.Forms.RichTextBox
    $notes.Name='ReadOnlyIssues'
    $notes.ReadOnly=$true
    $notes.BackColor=$theme.Input
    $notes.ForeColor=$theme.InputText
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
    $notes.AccessibleDescription='Read-only scrollable warning text; nothing approved or changed'
    $lines=New-Object 'System.Collections.Generic.List[string]'
    if($Report.status -ceq 'read_only_player_review_BLOCKED_MANUAL_REVIEW'){
        $lines.Add('Manual review required. Do not replace any files.')
    }else{
        $lines.Add('No preflight blockers observed. No installation permission has been granted.')
    }
    foreach($c in @($Report.concerns)){$lines.Add(('- '+$c))}
    foreach($n in @($Report.notes)){$lines.Add(('- '+$n))}
    $notes.Text=$lines -join [Environment]::NewLine
    $content.Controls.Add($notes)
    $footer=New-Object Windows.Forms.Label
    $footer.Name='ReadOnlyStorageNotice'
    $footer.Text=('Original bytes needing future backup: '+$Report.original_bytes_that_would_need_backup+
       '. Separate backup folder selected: '+$(if($Report.separate_backup_folder_selected){'Yes'}else{'No'})+
       '. No backups created or space reserved.')
    $footer.Location=New-Object Drawing.Point(22,551)
    $footer.ForeColor=$theme.Text
    $footer.AccessibleName='Original backup requirement and storage notice'
    $footer.Size=New-Object Drawing.Size(850,62)
    $footer.Anchor=[Windows.Forms.AnchorStyles]::Bottom -bor
        [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $content.Controls.Add($footer)
    $close=New-Object Windows.Forms.Button
    $close.Name='CloseDetails'
    $close.Text='Close Review'
    $close.Location=New-Object Drawing.Point(730,662)
    $close.Size=New-Object Drawing.Size(146,41)
    $close.Anchor=[Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Right
    $close.AccessibleName='Close read-only file details'
    $close.ForeColor=$theme.Text
    if(-not $theme.HighContrast){
        $close.UseVisualStyleBackColor=$false
        $close.BackColor=$theme.Surface
        $close.ForeColor=$theme.SurfaceText
        $close.FlatStyle=[Windows.Forms.FlatStyle]::Flat
        $close.FlatAppearance.BorderColor=$theme.Border
        $close.FlatAppearance.BorderSize=1
    }
    $close.TabIndex=2
    # This callback executes *after* New-WizardDetailsForm has returned.
    # Local $win is then out of scope in an event callback (StrictMode would
    # throw an unhandled exception). Resolve the actual owning form from the
    # clicked control instead; no file operations are involved.
    $close.Add_Click({
        param($sender,$eventArgs)
        $owner=[Windows.Forms.Control]$sender
        $parentForm=$owner.FindForm()
        if($null -ne $parentForm){$parentForm.Close()}
    })
    $content.Controls.Add($close)
    $win.AcceptButton=$close
    $win.CancelButton=$close
    # Leave enough width for the Windows scrollbar while keeping the
    # horizontal controls inside the viewport. This does not change DPI.
    $win.Add_ClientSizeChanged({
        param($sender,$eventArgs)
        $region=[Windows.Forms.Panel]$sender.Controls['ReadOnlyDetailsContent']
        $reserved=[Windows.Forms.SystemInformation]::VerticalScrollBarWidth+4
        $region.Size=New-Object Drawing.Size(
            ([Math]::Max(500,$sender.ClientSize.Width-$reserved)),
            ([Math]::Max(730,$sender.ClientSize.Height)))
    })
    $area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $initialWidth=[Math]::Min(900,[Math]::Max(560,$area.Width-72))
    $initialHeight=[Math]::Min(730,[Math]::Max(390,$area.Height-100))
    $win.ClientSize=New-Object Drawing.Size($initialWidth,$initialHeight)
    $win.PerformLayout()
    return $win
}
