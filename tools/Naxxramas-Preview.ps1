#requires -Version 5.1
<#
Classic-inspired Naxxramas Windows launcher, development PREVIEW ONLY.
No install, download, change, rollback, or update operations are available.
Locally supplied artwork can be placed in assets/local; never bundled.
#>
[CmdletBinding()]
param([switch]$SmokeTest,[string]$ArtRoot)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Windows required.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'GUI-Preview-Lib.ps1')
function C([string]$hex){return [Drawing.ColorTranslator]::FromHtml($hex)}
$dark=C '#13100d';$surface=C '#29231c';$well=C '#141b1e'
$gold=C '#d7b573';$cream=C '#eee3c8';$muted=C '#b4a68e'
$green=C '#8ed8ae';$red=C '#edada4'
$f=New-Object Drawing.Font('Segoe UI',9)
$small=New-Object Drawing.Font('Segoe UI',8)
$heading=New-Object Drawing.Font('Georgia',12,[Drawing.FontStyle]::Bold)
$title=New-Object Drawing.Font('Georgia',24,[Drawing.FontStyle]::Bold)
$form=New-Object Windows.Forms.Form
$form.Text='Naxxramas - Classic Launcher Preview'
$form.ClientSize=New-Object Drawing.Size(1110,710)
$form.MinimumSize=New-Object Drawing.Size(950,660)
$form.StartPosition='CenterScreen';$form.AutoScaleMode='Dpi'
$form.BackColor=$dark;$form.ForeColor=$cream;$form.Font=$f
$form.KeyPreview=$true;$form.ShowIcon=$false
$tip=New-Object Windows.Forms.ToolTip
$tip.InitialDelay=400;$tip.AutoPopDelay=14000
function Label([Windows.Forms.Control]$p,[string]$text,[int]$x,[int]$y,[int]$w,[int]$height,[Drawing.Font]$font,[Drawing.Color]$color){
 $l=New-Object Windows.Forms.Label
 $l.Text=$text;$l.Location=New-Object Drawing.Point($x,$y)
 $l.Size=New-Object Drawing.Size($w,$height)
 $l.Font=$font;$l.ForeColor=$color;$l.BackColor=[Drawing.Color]::Transparent
 $p.Controls.Add($l);return $l
}
function Card([Windows.Forms.Control]$p,[Drawing.Color]$color){
 $c=New-Object Windows.Forms.Panel
 $c.Dock='Fill';$c.BackColor=$color;$c.BorderStyle='FixedSingle'
 $p.Controls.Add($c);return $c
}
$grid=New-Object Windows.Forms.TableLayoutPanel
$grid.Dock='Fill';$grid.Padding=New-Object Windows.Forms.Padding(10,9,10,9)
$grid.RowCount=3;$grid.ColumnCount=1
$grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,64)))|Out-Null
$grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
$grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,69)))|Out-Null
$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
$form.Controls.Add($grid)
$top=New-Object Windows.Forms.Panel
$top.Dock='Fill';$top.BackColor=C '#231c15';$top.BorderStyle='FixedSingle'
$top.Margin=New-Object Windows.Forms.Padding(0,0,0,7)
$grid.Controls.Add($top,0,0)
[void](Label $top 'NAXXRAMAS' 19 8 295 43 $title $gold)
[void](Label $top 'CLASSIC CLIENT LAUNCHER  /  3.3.5a BUILD 12340' 325 20 540 23 $f $cream)
$mode=Label $top 'PREVIEW ONLY' 0 21 144 24 $heading $green
$mode.Anchor='Top,Right'
$top.Add_SizeChanged({$mode.Left=[math]::Max(770,$top.ClientSize.Width-160)}.GetNewClosure())
$main=New-Object Windows.Forms.TableLayoutPanel
$main.Dock='Fill';$main.ColumnCount=2;$main.RowCount=1
$main.Margin=New-Object Windows.Forms.Padding(0,0,0,7)
$main.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,57)))|Out-Null
$main.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,43)))|Out-Null
$main.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
$grid.Controls.Add($main,0,1)
$left=New-Object Windows.Forms.TableLayoutPanel
$left.Dock='Fill';$left.ColumnCount=1;$left.RowCount=2
$left.Margin=New-Object Windows.Forms.Padding(0,0,8,0)
$left.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,69)))|Out-Null
$left.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,31)))|Out-Null
$main.Controls.Add($left,0,0)
$art=Card $left (C '#1d2c2f')
$art.Margin=New-Object Windows.Forms.Padding(0,0,0,8)
$art.AccessibleName='Launcher artwork'
$assetPath=if([string]::IsNullOrWhiteSpace($ArtRoot)){
 Join-Path (Split-Path -Parent $PSScriptRoot) 'assets/local'
}else{$ArtRoot}
$images=New-Object 'System.Collections.Generic.List[System.Drawing.Image]'
function LoadImage([string]$filename){
 $path=Join-Path $assetPath $filename
 if(-not (Test-Path -LiteralPath $path -PathType Leaf)){return $null}
 $item=Get-Item -LiteralPath $path -Force
 if($item.Length -gt 31457280){throw 'Local launcher image exceeds the 30 MB limit.'}
 $stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try{
  $src=[Drawing.Image]::FromStream($stream)
  try{$copy=[Drawing.Bitmap]::new($src)}
  finally{$src.Dispose()}
  $images.Add($copy)
  return $copy
 }finally{$stream.Dispose()}
}
$hero=LoadImage 'launcher-art.png'
$logo=LoadImage 'launcher-logo.png'
$art.Add_Paint({
 param($sender,$e)
 $g=$e.Graphics
 $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $bounds=$sender.ClientRectangle
 if($null -ne $hero){
  $scale=[math]::Max($bounds.Width/[double]$hero.Width,$bounds.Height/[double]$hero.Height)
  $sw=[int][math]::Ceiling($bounds.Width/$scale)
  $sh=[int][math]::Ceiling($bounds.Height/$scale)
  $sx=[int][math]::Max(0,($hero.Width-$sw)/2)
  $sy=[int][math]::Max(0,($hero.Height-$sh)/2)
  $g.DrawImage($hero,$bounds,([Drawing.Rectangle]::new($sx,$sy,$sw,$sh)),[Drawing.GraphicsUnit]::Pixel)
 }else{
  $grad=[Drawing.Drawing2D.LinearGradientBrush]::new($bounds,(C '#183b42'),(C '#080e16'),[Drawing.Drawing2D.LinearGradientMode]::Vertical)
  try{$g.FillRectangle($grad,$bounds)}
  finally{$grad.Dispose()}
  $pen=[Drawing.Pen]::new((C '#3e5960'),2)
  try{
   foreach($i in @(1,2,3,4)){
    $x=[int]($bounds.Width*$i/5)
    $g.DrawArc($pen,($x-53),([int]($bounds.Height*.17)),106,190,190,160)
   }
  }finally{$pen.Dispose()}
 }
 $shade=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(160,3,8,13))
 try{$g.FillRectangle($shade,0,0,$bounds.Width,125)}
 finally{$shade.Dispose()}
 if($null -ne $logo){
  $w=[int][math]::Min($bounds.Width-70,420)
  $h=[int]($w*$logo.Height/[double]$logo.Width)
  if($h -gt 110){$h=110;$w=[int]($h*$logo.Width/[double]$logo.Height)}
  $g.DrawImage($logo,([Drawing.Rectangle]::new(([int](($bounds.Width-$w)/2)),14,$w,$h)))
 }else{
  $brush=[Drawing.SolidBrush]::new($gold)
  try{$g.DrawString('NAXXRAMAS',$title,$brush,25,25)}
  finally{$brush.Dispose()}
 }
 $framePen=[Drawing.Pen]::new($gold,2)
 try{
  $g.DrawRectangle($framePen,6,6,[math]::Max(0,$bounds.Width-13),[math]::Max(0,$bounds.Height-13))
  $g.DrawLine($framePen,24,[math]::Max(0,$bounds.Height-47),[math]::Max(24,$bounds.Width-24),[math]::Max(0,$bounds.Height-47))
 }finally{$framePen.Dispose()}
 $subBrush=[Drawing.SolidBrush]::new($cream)
 try{$g.DrawString('PREPARE YOUR JOURNEY',$heading,$subBrush,24,[math]::Max(6,$bounds.Height-40))}
 finally{$subBrush.Dispose()}
}.GetNewClosure())
$news=Card $left $surface
$news.Margin=New-Object Windows.Forms.Padding(0)
[void](Label $news 'LATEST NEWS  /  VERIFICATION LOG' 12 8 500 27 $heading $gold)
$result=New-Object Windows.Forms.TextBox
$result.Multiline=$true;$result.ReadOnly=$true;$result.WordWrap=$true
$result.ScrollBars='Vertical';$result.BackColor=$well;$result.ForeColor=$cream
$result.Font=New-Object Drawing.Font('Consolas',9)
$result.BorderStyle='FixedSingle'
$result.Location=New-Object Drawing.Point(12,38)
$result.Size=New-Object Drawing.Size(445,95)
$result.Anchor='Top,Bottom,Left,Right'
$result.AccessibleName='Read-only installation preview output'
$result.Text="Welcome to Naxxramas Client Setup.`r`nCore patches V and Z are required.`r`nChoose your client folder and click PREVIEW."
$news.Controls.Add($result)
$news.Add_SizeChanged({
 $result.Width=[math]::Max(300,$news.ClientSize.Width-24)
 $result.Height=[math]::Max(55,$news.ClientSize.Height-48)
}.GetNewClosure())
$right=Card $main $surface
$right.Margin=New-Object Windows.Forms.Padding(0)
[void](Label $right 'INSTALLATION OPTIONS' 14 9 400 28 $heading $gold)
$options=New-Object Windows.Forms.Panel
$options.Location=New-Object Drawing.Point(14,43)
$options.Size=New-Object Drawing.Size(380,453)
$options.Anchor='Top,Bottom,Left,Right'
$options.AutoScroll=$true;$options.BackColor=$surface
$right.Controls.Add($options)
$right.Add_SizeChanged({
 $options.Width=[math]::Max(335,$right.ClientSize.Width-28)
 $options.Height=[math]::Max(305,$right.ClientSize.Height-54)
}.GetNewClosure())
function Picker([string]$caption,[int]$y,[bool]$zipMode,[int]$tab){
 [void](Label $options $caption 2 $y 380 20 $small $muted)
 $box=New-Object Windows.Forms.TextBox
 $box.Location=New-Object Drawing.Point(2,($y+21))
 $box.Size=New-Object Drawing.Size(272,25);$box.Anchor='Top,Left,Right'
 $box.BackColor=$well;$box.ForeColor=$cream
 $box.BorderStyle='FixedSingle';$box.TabIndex=$tab
 $options.Controls.Add($box)
 $browse=New-Object Windows.Forms.Button
 $browse.Text='Browse';$browse.Location=New-Object Drawing.Point(284,($y+20))
 $browse.Size=New-Object Drawing.Size(74,26)
 $browse.BackColor=C '#63523a';$browse.ForeColor=$cream
 $browse.FlatStyle='Flat';$browse.TabIndex=($tab+1)
 $options.Controls.Add($browse)
 $resize={
  $browse.Left=[math]::Max(270,$options.ClientSize.Width-82)
  $box.Width=[math]::Max(175,$browse.Left-10)
 }.GetNewClosure()
 $options.Add_SizeChanged($resize);& $resize
 $browse.Add_Click({
  if($zipMode){
   $dialog=New-Object Windows.Forms.OpenFileDialog
   $dialog.Title=$caption;$dialog.Filter='ZIP archives (*.zip)|*.zip'
   $dialog.CheckFileExists=$true
   if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dialog.FileName}
  }else{
   $dialog=New-Object Windows.Forms.FolderBrowserDialog
   $dialog.Description=$caption;$dialog.ShowNewFolderButton=$false
   if(Test-Path -LiteralPath $box.Text -PathType Container){$dialog.SelectedPath=$box.Text}
   if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dialog.SelectedPath}
  }
 }.GetNewClosure())
 return $box
}
$client=Picker 'Existing WoW 3.3.5a client' 6 $false 0
$patch=Picker 'Local patch source (optional)' 70 $false 2
$zip=Picker 'N-Addon Collection v2.0.0 ZIP (optional)' 134 $true 4
[void](Label $options 'VANILLA VISUALS' 2 199 350 25 $heading $gold)
function Check([string]$name,[int]$x,[int]$y,[int]$tab){
 $cb=New-Object Windows.Forms.CheckBox
 $cb.Text=$name;$cb.Location=New-Object Drawing.Point($x,$y)
 $cb.Size=New-Object Drawing.Size(185,24)
 $cb.ForeColor=$cream;$cb.TabIndex=$tab
 $options.Controls.Add($cb);return $cb
}
$login=Check 'Login screen (J)' 3 225 6
$loading=Check 'Loading screens (U)' 191 225 7
[void](Label $options 'N-ADDON COLLECTION' 2 259 350 25 $heading $gold)
$core=Label $options 'NCore - select a suite ZIP to enable' 3 287 355 24 $small $gold
$definitions=@(
 @{Id='IndividualProgressionAddon';Title='Individual Progression'},
 @{Id='DungeonJournal';Title='Dungeon Journal'},
 @{Id='MultiBot';Title='MultiBot'},
 @{Id='NaxxLootLottery';Title='Naxxramas Loot Ledger'}
)
$addonChecks=@{}
for($i=0;$i -lt $definitions.Count;$i++){
 $d=$definitions[$i]
 $cb=Check $d.Title 3 (314+$i*29) (8+$i)
 $cb.Enabled=$false
 $addonChecks[$d.Id]=$cb
}
$zip.Add_TextChanged({
 $enabled=-not [string]::IsNullOrWhiteSpace($zip.Text)
 $core.Text=if($enabled){'NCore - included (required)'}else{'NCore - select a suite ZIP to enable'}
 foreach($c in $addonChecks.Values){$c.Enabled=$enabled;if(-not $enabled){$c.Checked=$false}}
}.GetNewClosure())
$footer=New-Object Windows.Forms.Panel
$footer.Dock='Fill';$footer.Margin=New-Object Windows.Forms.Padding(0)
$footer.BackColor=C '#241c14';$footer.BorderStyle='FixedSingle'
$grid.Controls.Add($footer,0,2)
function Button([string]$label,[int]$width,[string]$hex){
 $b=New-Object Windows.Forms.Button
 $b.Text=$label;$b.Size=New-Object Drawing.Size($width,43)
 $b.BackColor=C $hex;$b.ForeColor=$cream;$b.FlatStyle='Flat'
 $b.FlatAppearance.BorderColor=$gold
 $footer.Controls.Add($b);return $b
}
$inspect=Button '&Inspect' 118 '#5a4c39'
$clear=Button 'C&lear' 105 '#41392f'
$cancel=Button '&Cancel' 110 '#563c37'
$cancel.Enabled=$false
$preview=Button '&PREVIEW' 217 '#687a4c'
$preview.Font=New-Object Drawing.Font('Georgia',15,[Drawing.FontStyle]::Bold)
$form.AcceptButton=$preview
$status=Label $footer 'READ-ONLY PREVIEW' 380 25 360 25 $small $green
$reflow={
 $inspect.Location=New-Object Drawing.Point(12,10)
 $clear.Location=New-Object Drawing.Point(137,10)
 $cancel.Location=New-Object Drawing.Point(249,10)
 $preview.Location=New-Object Drawing.Point(([math]::Max(650,$footer.ClientSize.Width-232)),9)
 $status.Left=([math]::Max(371,$preview.Left-205))
 $status.Width=([math]::Max(100,$preview.Left-$status.Left-6))
}.GetNewClosure()
$footer.Add_SizeChanged($reflow);& $reflow
$tip.SetToolTip($preview,'Alt+P or Enter: read-only verification.')
$tip.SetToolTip($inspect,'Alt+I: read-only recovery-state inspection.')
$tip.SetToolTip($cancel,'Cancel a lengthy read-only check.')
$script:activeJob=$null;$script:currentMode=''
$timer=New-Object Windows.Forms.Timer
$timer.Interval=350
$timer.Add_Tick({
 if($null -eq $script:activeJob){return}
 if($script:activeJob.State -notin @('Completed','Failed','Stopped')){return}
 $timer.Stop();$job=$script:activeJob;$script:activeJob=$null
 $lines=@(Receive-Job -Job $job -ErrorAction SilentlyContinue)
 $message=($lines|ForEach-Object{[string]$_}) -join "`r`n"
 if([string]::IsNullOrWhiteSpace($message)){$message='No verification results returned.'}
 $result.Text=$message
 $ok=($job.State -eq 'Completed') -and
  (($script:currentMode -eq 'Plan' -and $message.Contains('READ-ONLY PLAN COMPLETE')) -or
   ($script:currentMode -eq 'Inspect' -and $message.Contains('READ-ONLY INSPECTION COMPLETE')))
 if($ok){$status.Text='PREVIEW COMPLETE';$status.ForeColor=$green}
 else{$status.Text='REVIEW ERRORS';$status.ForeColor=$red}
 Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 $preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
})
function Launch([string]$action){
 if($null -ne $script:activeJob){return}
 try{
  $selected=@()
  foreach($d in $definitions){if($addonChecks[$d.Id].Checked){$selected+=([string]$d.Id)}}
  $request=New-NaxxPreviewRequest -Mode $action -ClientPath $client.Text -PatchSourcePath $patch.Text -AddonSuiteArchivePath $zip.Text -VanillaLogin $login.Checked -VanillaLoading $loading.Checked -Addons $selected
  $preview.Enabled=$false;$inspect.Enabled=$false;$cancel.Enabled=$true
  $status.Text='CHECKING FILES';$status.ForeColor=$gold
  $result.Text='Reading local files. Checking large patches may take a little while...'
  $script:currentMode=$action
  $script:activeJob=Start-Job -ScriptBlock {
   param([string]$entry,[hashtable]$options)
   & $entry @options 2>&1|Out-String
  } -ArgumentList $request.ScriptPath,$request.Parameters
  $timer.Start()
 }catch{
  $status.Text='PREVIEW NOT READY';$status.ForeColor=$red
  $result.Text='Could not start preview: '+$_.Exception.Message
  $preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
 }
}
$preview.Add_Click({Launch 'Plan'})
$inspect.Add_Click({Launch 'Inspect'})
$clear.Add_Click({
 if($null -ne $script:activeJob){return}
 $result.Clear();$status.Text='RESULTS CLEARED';$status.ForeColor=$green
})
$cancel.Add_Click({
 if($null -eq $script:activeJob){return}
 $timer.Stop();$job=$script:activeJob;$script:activeJob=$null
 Stop-Job -Job $job -ErrorAction SilentlyContinue
 Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 $preview.Enabled=$true;$inspect.Enabled=$true;$cancel.Enabled=$false
 $status.Text='CANCELLED';$status.ForeColor=$muted
 $result.Text='Read-only check cancelled. No installation was attempted.'
})
$form.Add_KeyDown({
 if($_.KeyCode -eq [Windows.Forms.Keys]::Escape){$_.Handled=$true;$form.Close()}
})
$form.Add_FormClosing({
 $timer.Stop()
 if($null -ne $script:activeJob){
  Stop-Job -Job $script:activeJob -ErrorAction SilentlyContinue
  Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
  $script:activeJob=$null
 }
})
try{
 if($SmokeTest){
  $form.CreateControl()
  foreach($size in @((New-Object Drawing.Size(950,660)),(New-Object Drawing.Size(1110,710)))){
   $form.ClientSize=$size
   $grid.PerformLayout();$main.PerformLayout()
   $right.PerformLayout();$footer.PerformLayout();$left.PerformLayout()
   if($null -eq $art -or $null -eq $result -or $null -eq $options -or
      $null -eq $preview -or $form.AcceptButton -ne $preview -or $cancel.Enabled -or
      $preview.Right -gt $footer.ClientSize.Width -or $options.ClientSize.Height -lt 300){
    throw "Classic launcher layout failed at width $($size.Width)."
   }
  }
  Write-Host 'GUI PREVIEW WINDOW CONSTRUCTED; NO CLIENT WRITES'
  Write-Host 'CLASSIC LAUNCHER LAYOUT TEST PASSED'
 }else{[void]$form.ShowDialog()}
}finally{
 $timer.Dispose();$tip.Dispose()
 foreach($img in $images){$img.Dispose()}
 $form.Dispose()
}
