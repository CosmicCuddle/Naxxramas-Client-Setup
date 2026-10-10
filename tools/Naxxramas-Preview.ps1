#requires -Version 5.1
<#
Classic-inspired Naxxramas Windows launcher, development PREVIEW ONLY.
Only an explicit, confirmed patch-source download may write files, always outside the game; no client installs, rollbacks, or modifications.
The owner changes artwork by replacing assets/default/launcher-art.png in the package.
#>
[CmdletBinding()]
param([switch]$SmokeTest)
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
$topTitle=Label $top 'NAXXRAMAS' 19 8 295 43 $title $gold
[void](Label $top 'CLASSIC CLIENT LAUNCHER  /  3.3.5a BUILD 12340' 325 20 430 23 $f $cream)
$mode=Label $top 'READ-ONLY' 0 16 140 27 $f $green
$mode.TextAlign='MiddleCenter'
$mode.AutoEllipsis=$true
$mode.Anchor='Top,Right'
$top.Add_SizeChanged({
 $mode.Left=[math]::Max(756,$top.ClientSize.Width-$mode.Width-18)
}.GetNewClosure())
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
# One owner-managed default artwork location; no player selection or overrides.
$repositoryRoot=Split-Path -Parent $PSScriptRoot
$defaultArtPath=Join-Path $repositoryRoot 'assets/default'
$images=New-Object 'System.Collections.Generic.List[System.Drawing.Image]'
function Read-LauncherImage([string]$fullPath){
 if(-not (Test-Path -LiteralPath $fullPath -PathType Leaf)){return $null}
 $item=Get-Item -LiteralPath $fullPath -Force
 if($item.Extension.ToLowerInvariant() -notin @('.png','.jpg','.jpeg')){
  throw 'Default launcher artwork must be a PNG or JPEG.'
 }
 if($item.Length -le 0 -or $item.Length -gt 31457280){
  throw 'Launcher artwork must be a nonempty image smaller than 30 MB.'
 }
 $stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try{
  $src=[Drawing.Image]::FromStream($stream)
  try{$copy=[Drawing.Bitmap]::new($src)}
  finally{$src.Dispose()}
  $images.Add($copy)
  return $copy
 }finally{$stream.Dispose()}
}
function LoadImage([string]$filename){
 return Read-LauncherImage (Join-Path $defaultArtPath $filename)
}
$hero=LoadImage 'launcher-art.png'
$logo=LoadImage 'launcher-logo.png'
# Old custom GDI drawing left disjointed borders and resized badly.
# The classic launcher now uses real WinForms image controls.
$artLayout=New-Object Windows.Forms.TableLayoutPanel
$artLayout.Dock='Fill';$artLayout.ColumnCount=1;$artLayout.RowCount=1
$artLayout.BackColor=C '#101d22'
$artLayout.Margin=New-Object Windows.Forms.Padding(0)
$artLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
$artLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))|Out-Null
$art.Controls.Add($artLayout)
$artCanvas=New-Object Windows.Forms.Panel
$artCanvas.Dock='Fill';$artCanvas.Margin=New-Object Windows.Forms.Padding(7)
$artCanvas.BackColor=C '#102129'
$artLayout.Controls.Add($artCanvas,0,0)
$artImage=New-Object Windows.Forms.PictureBox
$artImage.Dock='Fill'
$artImage.SizeMode=[Windows.Forms.PictureBoxSizeMode]::Zoom
$artImage.BackColor=C '#0b161b'
$artImage.Image=$hero
$artImage.Visible=($null -ne $hero)
$artCanvas.Controls.Add($artImage)
$emptyArt=New-Object Windows.Forms.Label
$emptyArt.Dock='Fill'
$emptyArt.BackColor=C '#102129'
$emptyArt.ForeColor=$gold
$emptyArt.Font=New-Object Drawing.Font('Georgia',13)
$emptyArt.TextAlign='MiddleCenter'
$emptyArt.Text='LAUNCHER ARTWORK UNAVAILABLE'
$emptyArt.Visible=($null -eq $hero)
$artCanvas.Controls.Add($emptyArt)
if($null -ne $logo){
 $topLogo=New-Object Windows.Forms.PictureBox
 $topLogo.Image=$logo
 $topLogo.SizeMode=[Windows.Forms.PictureBoxSizeMode]::Zoom
 $topLogo.Location=New-Object Drawing.Point(17,4)
 $topLogo.Size=New-Object Drawing.Size(297,50)
 $topLogo.BackColor=$top.BackColor
 $top.Controls.Add($topLogo)
 $topTitle.Visible=$false
}
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
# A fresh launcher has empty folder boxes; never pass an empty path to Test-Path.
function Get-NaxxBrowseInitialFolder([string]$candidate){
 if([string]::IsNullOrWhiteSpace($candidate)){return $null}
 try{
  if(Test-Path -LiteralPath $candidate -PathType Container -ErrorAction Stop){
   return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
  }
 }catch{
  # Invalid or stale directory: let FolderBrowserDialog start normally.
 }
 return $null
}
# File Explorer's "Copy as path" wraps paths in double quotes. Normalize
# clipboard text in one place; neither clipboard access nor path validation writes files.
function Normalize-NaxxInputPath([string]$value){
 if([string]::IsNullOrWhiteSpace($value)){return ''}
 $candidate=$value.Trim()
 if($candidate.Length -ge 2 -and $candidate.StartsWith('"') -and $candidate.EndsWith('"')){
  $candidate=$candidate.Substring(1,$candidate.Length-2).Trim()
 }
 return $candidate
}
function Picker([string]$caption,[int]$y,[bool]$zipMode,[int]$tab){
 [void](Label $options $caption 2 $y 380 20 $small $muted)
 $box=New-Object Windows.Forms.TextBox
 $box.Location=New-Object Drawing.Point(2,($y+21))
 $box.Size=New-Object Drawing.Size(272,25);$box.Anchor='Top,Left,Right'
 $box.BackColor=$well;$box.ForeColor=$cream
 $box.BorderStyle='FixedSingle';$box.TabIndex=$tab
 $options.Controls.Add($box)
 $box.Add_Leave({
  $normal=Normalize-NaxxInputPath $box.Text
  if($box.Text -cne $normal){$box.Text=$normal}
 }.GetNewClosure())
 $tip.SetToolTip($box,'Type a path or press Ctrl+V to paste a path from File Explorer. Quoted paths work.')
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
  $dialog=$null
  try{
   if($zipMode){
    $dialog=New-Object Windows.Forms.OpenFileDialog
    $dialog.Title=$caption;$dialog.Filter='ZIP archives (*.zip)|*.zip'
    $dialog.CheckFileExists=$true
    if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dialog.FileName}
   }else{
    $dialog=New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description=$caption;$dialog.ShowNewFolderButton=$false
    $initialFolder=Get-NaxxBrowseInitialFolder (Normalize-NaxxInputPath $box.Text)
    if(-not [string]::IsNullOrWhiteSpace($initialFolder)){
     $dialog.SelectedPath=$initialFolder
    }
    if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){$box.Text=$dialog.SelectedPath}
   }
  }catch{
   # Prevent the generic .NET unhandled-event exception window.
   [void][Windows.Forms.MessageBox]::Show(
    $form,('Unable to open the file or folder browser: '+$_.Exception.Message),
    'Naxxramas - Browse error',
    [Windows.Forms.MessageBoxButtons]::OK,
    [Windows.Forms.MessageBoxIcon]::Warning)
  }finally{
   if($null -ne $dialog){$dialog.Dispose()}
  }
 }.GetNewClosure())
 return $box
}
$client=Picker 'Existing WoW 3.3.5a client' 6 $false 0
$patch=Picker 'Local patch source (optional)' 70 $false 2
$zip=Picker 'N-Addon Collection v2.0.0 ZIP (optional)' 134 $true 4
[void](Label $options 'LOGIN SCREEN (CHOOSE ONE)' 2 199 350 25 $heading $gold)
function Check([string]$name,[int]$x,[int]$y,[int]$tab){
 $cb=New-Object Windows.Forms.CheckBox
 $cb.Text=$name;$cb.Location=New-Object Drawing.Point($x,$y)
 $cb.Size=New-Object Drawing.Size(185,24)
 $cb.ForeColor=$cream;$cb.TabIndex=$tab
 $options.Controls.Add($cb);return $cb
}
$login=Check 'Vanilla login (J)' 3 225 6
$tbc=Check 'TBC login (C)' 191 225 7
$login.Add_CheckedChanged({if($login.Checked){$tbc.Checked=$false}}.GetNewClosure())
$tbc.Add_CheckedChanged({if($tbc.Checked){$login.Checked=$false}}.GetNewClosure())
$loading=Check 'Vanilla loading (U)' 3 254 8
[void](Label $options 'N-ADDON COLLECTION' 2 288 350 25 $heading $gold)
$core=Label $options 'NCore - select a suite ZIP to enable' 3 316 355 24 $small $gold
$definitions=@(
 @{Id='IndividualProgressionAddon';Title='Individual Progression'},
 @{Id='DungeonJournal';Title='Dungeon Journal'},
 @{Id='MultiBot';Title='MultiBot'},
 @{Id='NaxxLootLottery';Title='Naxxramas Loot Ledger'}
)
$addonChecks=@{}
for($i=0;$i -lt $definitions.Count;$i++){
 $d=$definitions[$i]
 $cb=Check $d.Title 3 (343+$i*29) (9+$i)
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
$download=Button '&Get patches' 138 '#4f5940'
$preview=Button '&PREVIEW' 217 '#687a4c'
$preview.Font=New-Object Drawing.Font('Georgia',15,[Drawing.FontStyle]::Bold)
$form.AcceptButton=$preview
$status=Label $footer 'READ-ONLY PREVIEW' 380 25 360 25 $small $green
$reflow={
 $inspect.Location=New-Object Drawing.Point(12,10)
 $clear.Location=New-Object Drawing.Point(137,10)
 $cancel.Location=New-Object Drawing.Point(249,10)
 $download.Location=New-Object Drawing.Point(366,10)
 $preview.Location=New-Object Drawing.Point(([math]::Max(650,$footer.ClientSize.Width-232)),9)
 $status.Left=([math]::Max(515,$preview.Left-135))
 $status.Width=([math]::Max(100,$preview.Left-$status.Left-6))
}.GetNewClosure()
$footer.Add_SizeChanged($reflow);& $reflow
$tip.SetToolTip($preview,'Alt+P or Enter: read-only verification.')
$tip.SetToolTip($inspect,'Alt+I: read-only recovery-state inspection.')
$tip.SetToolTip($cancel,'Cancel an active preview or download. A cancelled download may leave a temporary partial file in the separate source folder.')
$tip.SetToolTip($download,'Download and SHA-256 verify selected missing official MPQs into a separate source folder; never into your WoW client.')
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
   ($script:currentMode -eq 'Inspect' -and $message.Contains('READ-ONLY INSPECTION COMPLETE')) -or
   ($script:currentMode -eq 'Download' -and $message.Contains('PATCH DOWNLOAD COMPLETE')))
 if($ok){$status.Text='PREVIEW COMPLETE';$status.ForeColor=$green}
 else{$status.Text='REVIEW ERRORS';$status.ForeColor=$red}
 Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
 $preview.Enabled=$true;$inspect.Enabled=$true;$download.Enabled=$true;$cancel.Enabled=$false
})
function Launch([string]$action){
 if($null -ne $script:activeJob){return}
 try{
  $selected=@()
  foreach($d in $definitions){if($addonChecks[$d.Id].Checked){$selected+=([string]$d.Id)}}
  if($action -eq 'Download'){
   $request=New-NaxxSourceDownloadRequest -ClientPath $client.Text -PatchSourcePath $patch.Text -VanillaLogin $login.Checked -TbcLogin $tbc.Checked -VanillaLoading $loading.Checked
   $question='Download missing selected patches directly from the pinned Naxxramas GitHub Releases?' + [Environment]::NewLine + [Environment]::NewLine +
    'Files will be saved ONLY to:' + [Environment]::NewLine + [string]$request.Parameters.PatchSourcePath + [Environment]::NewLine + [Environment]::NewLine +
    'The World of Warcraft client will NOT be changed. Only SHA-256 verified downloads are retained. Continue?'
   $answer=[Windows.Forms.MessageBox]::Show($form,$question,'Confirm patch-source download',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
   if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
  }else{
   $request=New-NaxxPreviewRequest -Mode $action -ClientPath $client.Text -PatchSourcePath $patch.Text -AddonSuiteArchivePath $zip.Text -VanillaLogin $login.Checked -TbcLogin $tbc.Checked -VanillaLoading $loading.Checked -Addons $selected
  }
  $preview.Enabled=$false;$inspect.Enabled=$false;$download.Enabled=$false;$cancel.Enabled=$true
  $status.Text=if($action -eq 'Download'){'GETTING PATCHES'}else{'CHECKING FILES'}
  $status.ForeColor=$gold
  $result.Text=if($action -eq 'Download'){'Downloading selected patch files into the separate source folder...'}else{'Reading local files. Checking large patches may take a little while...'}
  $script:currentMode=$action
  $script:activeJob=Start-Job -ScriptBlock {
   param([string]$entry,[hashtable]$options)
   & $entry @options 2>&1|Out-String
  } -ArgumentList $request.ScriptPath,$request.Parameters
  $timer.Start()
 }catch{
  $status.Text='PREVIEW NOT READY';$status.ForeColor=$red
  $result.Text='Could not start preview: '+$_.Exception.Message
  $preview.Enabled=$true;$inspect.Enabled=$true;$download.Enabled=$true;$cancel.Enabled=$false
 }
}
$preview.Add_Click({Launch 'Plan'})
$download.Add_Click({Launch 'Download'})
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
 $preview.Enabled=$true;$inspect.Enabled=$true;$download.Enabled=$true;$cancel.Enabled=$false
 $status.Text='CANCELLED';$status.ForeColor=$muted
 $result.Text='Operation cancelled. The WoW client was not changed. Incomplete source downloads may leave a .partial file outside the game.'
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
   if($null -eq $tbc -or ($login.Checked -and $tbc.Checked) -or
      $null -eq $art -or $null -eq $result -or $null -eq $options -or
      $null -eq $artImage -or $artLayout.RowCount -ne 1 -or
      $artLayout.ClientSize.Width -le 0 -or
      $mode.Text -ne 'READ-ONLY' -or
      $null -eq $preview -or $null -eq $download -or $form.AcceptButton -ne $preview -or $cancel.Enabled -or
      $download.Right -ge $preview.Left -or
      $preview.Right -gt $footer.ClientSize.Width -or $options.ClientSize.Height -lt 300){
    throw "Classic launcher layout failed at width $($size.Width)."
   }
  }
  # Regression: empty first-run path boxes and stale paths must not throw.
  foreach($empty in @('', ' ', "`t")){
   if($null -ne (Get-NaxxBrowseInitialFolder $empty)){
    throw 'Empty Browse folder incorrectly returned a path.'
   }
  }
  $validFolder=(Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath
  if((Get-NaxxBrowseInitialFolder $validFolder) -cne $validFolder){
   throw 'Browse failed to recognise an existing folder.'
  }
  $missing=Join-Path $PSScriptRoot ('missing-naxx-browse-'+[guid]::NewGuid().ToString('N'))
  if($null -ne (Get-NaxxBrowseInitialFolder $missing)){
   throw 'Browse accepted a nonexistent directory.'
  }
  # Ctrl+V into editable fields works, and quoted Explorer paths are cleaned.
  $quoted='"'+$validFolder+'"'
  if((Normalize-NaxxInputPath $quoted) -cne $validFolder){throw 'Quoted Explorer path did not normalize.'}
  if((Normalize-NaxxInputPath ('  "'+$validFolder+'"  ')) -cne $validFolder){throw 'Quoted path with whitespace did not normalize.'}
  if((Normalize-NaxxInputPath '   ') -cne ''){throw 'Blank path did not normalize safely.'}
  if(@($options.Controls | Where-Object {$_.Text -eq 'Paste'}).Count -ne 0){
   throw 'An unwanted Paste button remains.'
  }
  Write-Host 'DIRECT CTRL+V PATH TEST PASSED'
  Write-Host 'EMPTY FOLDER BROWSE TEST PASSED'
  # Ensure the image placeholder and image control behave consistently.
  if(($null -eq $hero -and $artImage.Visible) -or
     ($null -ne $hero -and $artImage.Image -ne $hero)){
   throw 'Artwork image state is inconsistent.'
  }
  # Avoid DrawToBitmap on nested native image controls in a hidden STA form:
  # WinForms may block waiting for a paint message that cannot be dispatched.
  # Validate dimensions and the image source without capturing hidden controls.
  if($artCanvas.ClientSize.Width -lt 100 -or $artCanvas.ClientSize.Height -lt 60) {
   throw 'Launcher artwork region has invalid layout dimensions.'
  }
  Write-Host 'GUI PREVIEW WINDOW CONSTRUCTED; NO CLIENT WRITES'
  if($null -ne $hero){
   Write-Host ('DEFAULT ARTWORK SHA256: '+(Get-FileHash -LiteralPath (Join-Path $defaultArtPath 'launcher-art.png') -Algorithm SHA256).Hash.ToLowerInvariant())
  }
  Write-Host 'CLASSIC LAUNCHER ART IMAGE CONTROL CHECKED'
  Write-Host 'CLASSIC LAUNCHER LAYOUT TEST PASSED'
 }else{[void]$form.ShowDialog()}
}finally{
 $timer.Dispose();$tip.Dispose()
 foreach($img in $images){$img.Dispose()}
 $form.Dispose()
}
