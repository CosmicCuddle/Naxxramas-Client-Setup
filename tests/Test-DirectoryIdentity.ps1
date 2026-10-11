#requires -Version 5.1
# Synthetic Windows directory identity fixtures. No real game data.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Check([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Snapshot([string]$Folder) {
    return (@(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Folder.Length) + ':' +
                (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
        }) -join '|')
}
function Inspect([string]$Path,[string]$Other='') {
    $argsMap = @{ ClientPath=$Path; Json=$true }
    if ($Other) { $argsMap.ComparePath = $Other }
    return ((& $inspector @argsMap | Out-String) | ConvertFrom-Json)
}
function Must-Throw([string]$Path,[string]$What) {
    $thrown = $false
    try { $null = Inspect $Path } catch { $thrown = $true }
    Check $thrown $What
}
$inspector = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/Inspect-Naxxramas-DirectoryIdentity.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('NaxxFolderIdentity-' + [guid]::NewGuid().ToString('N'))
$junction = Join-Path $temp 'unsafe-junction'
$junctionPresent = $false
try {
    $null = New-Item -ItemType Directory -Path $temp
    $folder = Join-Path $temp 'synthetic-wow-folder'
    $null = New-Item -ItemType Directory -Path $folder
    $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Data/enUS') -Force
    [IO.File]::WriteAllText((Join-Path $folder 'Data/enUS/realmlist.wtf'),'fixture only')
    [IO.File]::WriteAllText((Join-Path $folder 'Wow.exe'),'not a game executable')

    $before = Snapshot $temp
    $first = Inspect $folder
    Check ($first.status -eq 'observed_not_authenticated') 'Local synthetic folder identity observed without claiming authority'
    Check ($first.identity_method -eq 'Win32_FILE_ID_INFO_128_and_volume_serial') 'Windows 128-bit ID and volume serial used'
    Check ($first.client_fingerprint_sha256 -cmatch '^[a-f0-9]{64}$') 'Identity fingerprint is lowercase SHA-256'
    Check (-not $first.comparison_requested) 'Uncompared preview does not silently assert a match'
    Check ($null -eq $first.same_filesystem_object) 'Uncompared preview has null match result'
    Check ((Snapshot $temp) -ceq $before) 'Identity preview preserves all fixture files'
    $again = Inspect $folder
    Check ($again.client_fingerprint_sha256 -ceq $first.client_fingerprint_sha256) 'Repeated lookup of one directory gives stable ID'

    $self = Inspect $folder $folder
    Check ($self.same_filesystem_object) 'Comparing the same filesystem object returns true'
    Check ($self.comparison_fingerprint_sha256 -ceq $first.client_fingerprint_sha256) 'Same object has matching ID bytes'

    $copy = Join-Path $temp 'independent-client-copy'
    Copy-Item -LiteralPath $folder -Destination $copy -Recurse
    $copyResult = Inspect $copy
    Check ($copyResult.client_fingerprint_sha256 -cne $first.client_fingerprint_sha256) 'Copied folder with same contents is a different filesystem object'
    $different = Inspect $folder $copy
    Check ($different.same_filesystem_object -eq $false) 'Original and copied folders do not share identity'
    Check ($different.client_fingerprint_sha256 -cne $different.comparison_fingerprint_sha256) 'Distinct object IDs remain distinguishable'

    $renamed = Join-Path $temp 'synthetic-wow-renamed'
    Rename-Item -LiteralPath $folder -NewName 'synthetic-wow-renamed'
    $renamedResult = Inspect $renamed
    Check ($renamedResult.client_fingerprint_sha256 -ceq $first.client_fingerprint_sha256) 'Renaming folder on same volume preserves filesystem object ID'
    $oldPathMissing = -not (Test-Path -LiteralPath $folder)
    Check $oldPathMissing 'Original folder name no longer exists'
    Must-Throw $folder 'Missing original path fails closed after rename'

    $nested = Join-Path $renamed 'Data/enUS'
    $nestedResult = Inspect $renamed $nested
    Check ($nestedResult.same_filesystem_object -eq $false) 'Parent folder is not its Data/enUS child object'

    $json = & $inspector -ClientPath $renamed -Json | Out-String
    Check (-not $json.Contains($temp)) 'JSON output omits local paths'
    Check (-not $json.Contains('fixture only')) 'JSON output omits player file contents'
    Check ((Snapshot $temp).Length -gt 0) 'Synthetic files remain present for no-write assertion'
    $snapshot = Snapshot $temp
    $null = Inspect $renamed $copy
    Check ((Snapshot $temp) -ceq $snapshot) 'Read-only comparison has no directory or file side effects'

    $missing = Join-Path $temp 'does-not-exist'
    Must-Throw $missing 'Missing directory is rejected'
    Must-Throw (Join-Path $renamed 'Wow.exe') 'A file cannot masquerade as the client folder'
    Must-Throw ([IO.Path]::GetPathRoot($temp)) 'Windows volume root is rejected'

    try {
        $null = New-Item -ItemType Junction -Path $junction -Target $renamed -ErrorAction Stop
        $junctionPresent = $true
    } catch {
        Write-Host 'SKIP: Junction creation unavailable on this Windows fixture runner.'
    }
    if ($junctionPresent) {
        Must-Throw $junction 'Junction-backed root is rejected'
        Must-Throw (Join-Path $junction 'Data') 'Junction in parent path is rejected'
    }
    Write-Host 'All synthetic Windows folder identity tests passed.' -ForegroundColor Green
}
finally {
    $safeCleanup = $true
    if ($junctionPresent -and (Test-Path -LiteralPath $junction)) {
        try {
            $j = Get-Item -LiteralPath $junction -Force
            if (($j.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                throw 'Not a reparse point; unsafe fixture cleanup refused.'
            }
            [IO.Directory]::Delete($junction,$false)
        } catch {
            $safeCleanup = $false
            Write-Warning 'Could not safely remove junction; leaving generated fixture for inspection.'
        }
    }
    if ($safeCleanup -and (Test-Path -LiteralPath $temp)) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
