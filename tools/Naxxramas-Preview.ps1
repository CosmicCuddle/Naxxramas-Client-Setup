#requires -Version 5.1
<#
Naxxramas Preview: Windows Forms GUI, read-only analysis ONLY.
No install, backup modification, download, recovery or rollback controls.
#>
[CmdletBinding()]
param([switch]$SmokeTest)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Windows is required.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'GUI-Preview-Lib.ps1')
function Color([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
$bg=Color '#0f1726';$surface=Color '#1c2a3e';$field=Color '#111d30'
$gold=Color '#dcb778';$white=Color '#f0f3fa';$muted=Color '#abbacc'
$green=Color '#83ddba';$red=Color '#f2aaa4'
$f=New-Object Drawing.Font('Segoe UI',10)
$sm=New-Object Drawing.Font('Segoe UI',9)
$h=New-Object Drawing.Font('Segoe UI Semibold',11,[Drawing.FontStyle]::Bold)
$form=New-Object Windows.Forms.Form
$form.Text='Naxxramas Client Setup - Read-Only Preview'
$form.ClientSize=New-Object Drawing.Size(930,810)
$form.MinimumSize=New-Object Drawing.Size(855,690)
$form.StartPosition='CenterScreen';$form.AutoScaleMode='Dpi'
$form.BackColor=$bg;$form.ForeColor=$white;$form.Font=$f;$form.ShowIcon=$false
$form.KeyPreview=$true
$tips=New-Object Windows.Forms.ToolTip
$tips.AutoPopDelay=15000;$tips.InitialDelay=450;$tips.ReshowDelay=150
$scroll=New-Object Windows.Forms.Panel
$scroll.Dock='Fill';$scroll.AutoScroll=$true
$scroll.Padding=New-Object Windows.Forms.Padding(15)
$form.Controls.Add($scroll)
$stack=New-Object Windows.Forms.TableLayoutPanel
$stack.Dock='Top';$stack.ColumnCount=1;$stack.RowCount=7;$stack.Height=859
$stack.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
foreach($height in @(88,236,223,60,38,177,37)){
 $stack.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,$height)))|Out-Null
}
$scroll.Controls.Add($stack)
function Label([Windows.Forms.Control]$parent,[string]$message,[int]$x,[int]$y,[int]$w,[int]$height,[Drawing.Font]$font,[Drawing.Color]$color) {
 $l=New-Object Windows.Forms.Label
 $l.Text=$message;$l.Location=New-Object Drawing.Point($x,$y)
 $l.Size=New-Object Drawing.Size($w,$height)
 $l.Font=$font;$l.ForeColor=$color;$l.BackColor=[Drawing.Color]::Transparent
 $parent.Controls.Add($l);return $l
}
function Card([int]$row) {
 $p=New-Object Windows.Forms.Panel
 $p.Dock='Fill';$p.Margin=New-Object Windows.Forms.Padding(0,0,0,8)
 $p.BackColor=$surface;$p.BorderStyle='FixedSingle'
 $stack.Controls.Add($p,0,$row);return $p
}
$head=New-Object Windows.Forms.Panel
$head.Dock='Fill';$head.Margin=New-Object Windows.Forms.Padding(0,0,0,8)
$stack.Controls.Add($head,0,0)
[void](Label $head 'NAXXRAMAS  /  CLIENT SETUP' 0 3 845 43 (New-Object Drawing.Font('Segoe UI Semibold',20,[Drawing.FontStyle]::Bold)) $gold)
[void](Label $head 'Choose your client, select optional features and preview changes safely.' 2 53 850 22 $f $muted)
$paths=Card 1
[void](Label $paths '01   CLIENT AND LOCAL SOURCES' 16 11 820 25 $h $gold)
function Picker([Windows.Forms.Control]$pickerPanel,[string]$caption,[int]$y,[bool]$zip) {
 [void](Label $pickerPanel $caption 18 $y 830 20 $sm $muted)
 $box=New-Object Windows.Forms.TextBox
 $box.Location=New-Object Drawing.Point(18,($y+20))
 $box.Size=New-Object Drawing.Size(620,27);$box.Anchor='Top,Left,Right'
 $box.BackColor=$field;$box.ForeColor=$white;$box.BorderStyle='FixedSingle'
 $pickerPanel.Controls.Add($box)
 $browse=New-Object Windows.Forms.Button
 $browse.Text='Browse...';$browse.Size=New-Object Drawing.Size(107,28)
 $browse.FlatStyle='Flat';$browse.BackColor=Color '#304761';$browse.ForeColor=$white
 $pickerPanel.Controls.Add($browse)
 $browse.TabStop=$true
 if ($y -eq 38) { $browse.TabIndex=1 }
 elseif ($y -eq 99) { $browse.TabIndex=3 }
 else { $browse.TabIndex=5 }
 $reflow={
  $browse.Location=New-Object Drawing.Point(([math]::Max(650,$pickerPanel.ClientSize.Width-126)),($y+19))
  $box.Width=[math]::Max(490,$browse.Left-28)
 }.GetNewClosure()
 $pickerPanel.Add_SizeChanged($reflow)
 & $reflow
 $browse.Add_Click({
  if ($zip) {
   $dlg=New-Object Windows.Forms.OpenFileDialog
   $dlg.Title=$caption;$dlg.Filter='ZIP archives (*.zip)|*.zip'
   $dlg.CheckFileExists=$true
   if($dlg.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dlg.FileName}
  } else {
   $dlg=New-Object Windows.Forms.FolderBrowserDialog
   $dlg.Description=$caption;$dlg.ShowNewFolderButton=$false
   if(Test-Path -LiteralPath $box.Text -PathType Container){$dlg.SelectedPath=$box.Text}
   if($dlg.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dlg.SelectedPath}
  }
 }.GetNewClosure())
 return $box
}
$client=Picker $paths 'WoW 3.3.5a folder (containing Wow.exe)' 38 $false
$patch=Picker $paths 'Separate local patch source (optional when V and Z are already installed)' 99 $false
$zip=Picker $paths 'Official N-Addon Collection v2.0.0 ZIP (optional)' 160 $true
$client.TabIndex=0;$patch.TabIndex=2;$zip.TabIndex=4
$tips.SetToolTip($client,'Required: choose an existing client folder containing Wow.exe.')
$tips.SetToolTip($patch,'Optional: separate local source with Data/patch-V.mpq and Data/patch-Z.mpq.')
$tips.SetToolTip($zip,'Optional: official N-Addon Collection v2.0.0 ZIP; no download is performed.')
$options=Card 2
[void](Label $options '02   OPTIONAL FEATURES' 16 11 820 25 $h $gold)
$login=New-Object Windows.Forms.CheckBox
$login.Text='Vanilla login screen (Patch J)';$login.Location=New-Object Drawing.Point(19,46)
$login.Size=New-Object Drawing.Size(370,27);$login.ForeColor=$white
$options.Controls.Add($login)
$login.TabIndex=6
$loading=New-Object Windows.Forms.CheckBox
$loading.Text='Vanilla loading screens (Patch U)';$loading.Location=New-Object Drawing.Point(439,46)
$loading.Size=New-Object Drawing.Size(390,27);$loading.ForeColor=$white
$options.Controls.Add($loading)
$loading.TabIndex=7
[void](Label $options 'ADDONS - NCore is required when installing the suite' 19 83 830 23 $sm $muted)
$core=New-Object Windows.Forms.CheckBox
$core.Text='NCore (mandatory for suite)';$core.Enabled=$false
$core.Location=New-Object Drawing.Point(19,110)
$core.Size=New-Object Drawing.Size(410,25);$core.ForeColor=$gold
$options.Controls.Add($core)
$definitions=@(
 @{Id='IndividualProgressionAddon';Title='Individual Progression'},
 @{Id='DungeonJournal';Title='Dungeon Journal'},
 @{Id='MultiBot';Title='MultiBot'},
 @{Id='NaxxLootLottery';Title='Naxxramas Loot Ledger'}
)
$addonChecks=@{}
for($i=0;$i -lt $definitions.Count;$i++){
 $d=$definitions[$i];$cb=New-Object Windows.Forms.CheckBox
 $cb.Text=$d.Title
 $cb.Location=New-Object Drawing.Point((19+($i%2)*414),(142+[int][math]::Floor($i/2)*29))
 $cb.Size=New-Object Drawing.Size(390,26)
 $cb.ForeColor=$white;$cb.Enabled=$false
 $options.Controls.Add($cb);$addonChecks[$d.Id]=$cb
 $cb.TabIndex=8+$i
}
# A narrow / high-DPI window uses a single vertical column instead of clipping checkboxes.
# Row heights stay fixed for a chosen layout so the outer panel can scroll normally.
$reflowOptions={
 $available=$options.ClientSize.Width
 $compact=$available -lt 880
 if($compact) {
  $loading.Location=New-Object Drawing.Point(19,76)
  $loading.Size=New-Object Drawing.Size(([math]::Max(320,$available-40)),27)
  $core.Location=New-Object Drawing.Point(19,151)
  for($i=0;$i -lt $definitions.Count;$i++) {
   $check=$addonChecks[$definitions[$i].Id]
   $check.Location=New-Object Drawing.Point(19,(182+$i*29))
   $check.Width=[math]::Max(315,$available-40)
  }
  $stack.RowStyles[2].Height=314
  $stack.Height=950
 } else {
  $loading.Location=New-Object Drawing.Point(439,46)
  $loading.Size=New-Object Drawing.Size(385,27)
  $core.Location=New-Object Drawing.Point(19,110)
  for($i=0;$i -lt $definitions.Count;$i++) {
   $check=$addonChecks[$definitions[$i].Id]
   $check.Location=New-Object Drawing.Point((19+($i%2)*414),(142+[int][math]::Floor($i/2)*29))
   $check.Width=385
  }
  $stack.RowStyles[2].Height=223
  $stack.Height=859
 }
}.GetNewClosure()
$options.Add_SizeChanged($reflowOptions)
$zip.Add_TextChanged({
 $enabled=-not [string]::IsNullOrWhiteSpace($zip.Text)
 $core.Checked=$enabled
 foreach($check in $addonChecks.Values){
  $check.Enabled=$enabled
  if(-not $enabled){$check.Checked=$false}
 }
}.GetNewClosure())
$buttons=New-Object Windows.Forms.Panel
$buttons.Dock='Fill';$buttons.Margin=New-Object Windows.Forms.Padding(0,0,0,8)
$stack.Controls.Add($buttons,0,3)
function MakeButton([string]$title,[int]$x,[string]$hex) {
 $b=New-Object Windows.Forms.Button
 $b.Text=$title;$b.Location=New-Object Drawing.Point($x,3)
 $b.Size=New-Object Drawing.Size(185,42)
 $b.BackColor=Color $hex;$b.ForeColor=$white;$b.FlatStyle='Flat'
 $buttons.Controls.Add($b);return $b
}
$preview=MakeButton '&Preview changes' 0 '#326255'
$inspect=MakeButton '&Inspect recovery state' 196 '#304e72'
$clear=MakeButton 'C&lear results' 392 '#2c3c54'
$cancel=MakeButton 'Cancel check' 588 '#59454a'
$cancel.Enabled=$false
$preview.TabIndex=12;$inspect.TabIndex=13;$clear.TabIndex=14;$cancel.TabIndex=15
$form.AcceptButton=$preview
$tips.SetToolTip($preview,'Alt+P or Enter: run read-only checks and calculate the install preview.')
$tips.SetToolTip($inspect,'Alt+I: inspect prior setup transaction records without changing anything.')
$tips.SetToolTip($cancel,'Stop the current read-only check. It does not undo or install anything.')
$statePanel=New-Object Windows.Forms.Panel
$statePanel.Dock='Fill';$statePanel.Margin=New-Object Windows.Forms.Padding(0)
$stack.Controls.Add($statePanel,0,4)
$status=Label $statePanel 'READ ONLY: this window cannot install, delete or change WoW files.' 4 3 850 29 $sm $green
$report=Card 5
[void](Label $report '03   PREVIEW RESULTS' 16 8 840 26 $h $gold)
$result=New-Object Windows.Forms.TextBox
$result.Multiline=$true;$result.ReadOnly=$true;$result.WordWrap=$false
$result.ScrollBars='Both';$result.BorderStyle='None'
$result.BackColor=$field;$result.ForeColor=$white
$result.Font=New-Object Drawing.Font('Consolas',9)
$result.Location=New-Object Drawing.Point(16,38)
$result.Size=New-Object Drawing.Size(780,117)
$result.Anchor='Top,Left,Right,Bottom'
$result.Text="Select the folder containing Wow.exe and press Preview changes.`r`n`r`nV and Z are always required. J, U and addons are optional.`r`nNo installation or download controls are enabled."
$report.Controls.Add($result)
$result.TabIndex=16
$result.AccessibleName='Read-only installation preview output'
$result.AccessibleDescription='Displays file verification, disk-space estimates and errors. Read-only.'
$report.Add_SizeChanged({$result.Width=[math]::Max(540,$report.ClientSize.Width-32)}.GetNewClosure())
$foot=New-Object Windows.Forms.Panel
$foot.Dock='Fill';$foot.Margin=New-Object Windows.Forms.Padding(0)
$stack.Controls.Add($foot,0,6)
[void](Label $foot 'PREVIEW ONLY   /   Alt+P Preview   /   Alt+I Inspect   /   Esc Close   /   No file writes' 3 4 860 24 $sm $muted)
$script:activeJob=$null;$script:currentMode=''
$timer=New-Object Windows.Forms.Timer
$timer.Interval=350
$timer.Add_Tick({
 if($null -eq $script:activeJob){return}
 if($script:activeJob.State -notin @('Completed','Failed','Stopped')){return}
 $timer.Stop()
 $job=$script:activeJob;$script:activeJob=$null
 $lines=@(Receive-Job -Job $job -ErrorAction SilentlyContinue)
 $output=($lines|ForEach-Object{[string]$_}) -join "`r`n"
 if([string]::IsNullOrWhiteSpace($output)){$output='No results received. Please review the repository installation tools.'}
 $result.Text=$output
 $ok=$job.State -eq 'Completed' -and
  (($script:currentMode -eq 'Plan' -and $output.Contains('READ-ONLY PLAN COMPLETE')) -or
  ($script:currentMode -eq 'Inspect' -and $output.Contains('READ-ONLY INSPECTION COMPLETE')))
 if($ok){$status.Text='Analysis finished. No client files changed.';$status.ForeColor=$green}
 else{$status.Text='Analysis could not complete. Review the results; no installation occurred.';$status.ForeColor=$red}
 Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 $preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
})
function Launch([string]$mode) {
 if($null -ne $script:activeJob){return}
 try{
  $selected=@()
  foreach($d in $definitions){if($addonChecks[$d.Id].Checked){$selected+=([string]$d.Id)}}
  $request=New-NaxxPreviewRequest -Mode $mode -ClientPath $client.Text -PatchSourcePath $patch.Text -AddonSuiteArchivePath $zip.Text -VanillaLogin $login.Checked -VanillaLoading $loading.Checked -Addons $selected
  $preview.Enabled=$false;$inspect.Enabled=$false;$cancel.Enabled=$true
  $result.Text='Checking local files. Large patch hashes can take some time...'
  $status.Text='Running '+$mode+' in the background (read-only)...'
  $status.ForeColor=$gold;$script:currentMode=$mode
  # Hashtable splatting avoids treating file paths as executable PowerShell code.
  $script:activeJob=Start-Job -ScriptBlock {
   param([string]$entry,[hashtable]$parameters)
   & $entry @parameters 2>&1 | Out-String
  } -ArgumentList $request.ScriptPath,$request.Parameters
  $timer.Start()
 }catch{
  $status.Text='Preview could not start: '+$_.Exception.Message
  $status.ForeColor=$red;$preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
 }
}
$cancel.Add_Click({
 if($null -eq $script:activeJob){return}
 $timer.Stop()
 $job=$script:activeJob;$script:activeJob=$null
 Stop-Job -Job $job -ErrorAction SilentlyContinue
 Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 $preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
 $status.Text='Read-only check cancelled. No installation was attempted.'
 $status.ForeColor=$muted
 $result.Text='The preview was cancelled. Choose Preview changes to try again.'
})
$preview.Add_Click({Launch 'Plan'})
$inspect.Add_Click({Launch 'Inspect'})
$clear.Add_Click({
 if($null -ne $script:activeJob){return}
 $result.Clear();$status.Text='Results cleared. No files changed.';$status.ForeColor=$green
})
# Escape closes the form; Windows Forms also supports Alt+P / Alt+I / Alt+L.
$form.Add_KeyDown({
 if($_.KeyCode -eq [Windows.Forms.Keys]::Escape) {
  $_.Handled=$true
  $form.Close()
 }
})
$form.Add_FormClosing({
 $timer.Stop()
 if($null -ne $script:activeJob){
  Stop-Job -Job $script:activeJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
  $script:activeJob=$null
 }
})
if($SmokeTest) {
 # CI builds the WinForms tree without showing an interactive window.
 $form.CreateControl()
 $scroll.PerformLayout()
 $stack.PerformLayout()
 & $reflowOptions
 $form.ClientSize=New-Object Drawing.Size(865,725)
 $scroll.PerformLayout()
 $stack.PerformLayout()
 & $reflowOptions
 if($stack.RowStyles[2].Height -ne 314 -or $loading.Top -ne 76) {
  throw ('Compact GUI layout failed at minimum desktop width (options width={0}, row height={1}, loading top={2}).' -f $options.ClientSize.Width,$stack.RowStyles[2].Height,$loading.Top)
 }
 $form.ClientSize=New-Object Drawing.Size(1000,850)
 $scroll.PerformLayout()
 $stack.PerformLayout()
 & $reflowOptions
 if($stack.RowStyles[2].Height -ne 223 -or $loading.Top -ne 46) {
  throw ('Two-column GUI layout failed at desktop width (options width={0}, row height={1}, loading top={2}).' -f $options.ClientSize.Width,$stack.RowStyles[2].Height,$loading.Top)
 }
 if($null -eq $client -or $null -eq $preview -or $null -eq $inspect -or
    $null -eq $result -or $null -eq $zip -or $null -eq $cancel -or
    $form.AcceptButton -ne $preview -or $cancel.Enabled) {
  throw 'Preview form controls did not initialise.'
 }
 Write-Host 'GUI PREVIEW WINDOW CONSTRUCTED; NO CLIENT WRITES'
 $timer.Dispose();$form.Dispose()
 exit 0
}
[void]$form.ShowDialog()
$timer.Dispose();$form.Dispose()
