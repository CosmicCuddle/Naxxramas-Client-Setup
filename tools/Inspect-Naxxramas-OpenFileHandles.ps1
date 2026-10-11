#requires -Version 5.1
<#
Naxxramas Client Setup — READ-ONLY Windows file-handle inventory.
Opens only the five client files or four local source patch paths.
Holds all existing handles with FileAccess.Read/FileShare.Read while hashing.
Does NOT install, lock a whole directory, create backups or approve a write.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RootPath,
    [ValidateSet('Client','Source')][string]$Scope='Client',
    [switch]$Json
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
    throw 'Windows file-handle inspection requires Windows.'
}

function Assert-NoReparse([string]$Path){
    $cursor=[IO.Path]::GetFullPath($Path)
    while($true){
        if(Test-Path -LiteralPath $cursor){
            $item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                throw 'Reparse-point, junction and symlink paths are not accepted.'
            }
        }
        $parent=[IO.Directory]::GetParent($cursor)
        if($null -eq $parent){break}
        $cursor=$parent.FullName
    }
}
function Require-Root([string]$Path){
    if(-not (Test-Path -LiteralPath $Path -PathType Container)){
        throw 'The selected local folder must exist.'
    }
    Assert-NoReparse $Path
    $resolved=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath)
    Assert-NoReparse $resolved
    if($resolved.StartsWith('\\',[StringComparison]::Ordinal) -or
       $resolved.TrimEnd('\').Equals(([IO.Path]::GetPathRoot($resolved)).TrimEnd('\'),
          [StringComparison]::OrdinalIgnoreCase)){
        throw 'Network paths and volume roots are not supported.'
    }
    return $resolved
}
function Initialize-FileIdApi {
    if(-not ('NaxxReadOnlyOpenFileIdV1' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.Security.Cryptography;
using System.Text;
public static class NaxxReadOnlyOpenFileIdV1 {
    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_ID_INFO {
        public ulong VolumeSerialNumber;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public byte[] FileId;
    }
    [DllImport("kernel32.dll", EntryPoint="GetFileInformationByHandleEx",SetLastError=true)]
    [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetInfo(SafeFileHandle handle, int kind,
        out FILE_ID_INFO info, uint cb);
    public static string Observe(SafeFileHandle handle) {
        FILE_ID_INFO info;
        uint size=(uint)Marshal.SizeOf(typeof(FILE_ID_INFO));
        if(!GetInfo(handle,18,out info,size))
            throw new Win32Exception(Marshal.GetLastWin32Error(),
                "Read-only file ID inspection failed.");
        if(info.FileId==null || info.FileId.Length!=16)
            throw new InvalidOperationException("Windows returned invalid file ID.");
        byte[] raw=new byte[24];
        Buffer.BlockCopy(BitConverter.GetBytes(info.VolumeSerialNumber),0,raw,0,8);
        Buffer.BlockCopy(info.FileId,0,raw,8,16);
        byte[] prefix=Encoding.ASCII.GetBytes("NAXX-OPEN-FILE-ID-V1:");
        byte[] message=new byte[prefix.Length+raw.Length];
        Buffer.BlockCopy(prefix,0,message,0,prefix.Length);
        Buffer.BlockCopy(raw,0,message,prefix.Length,raw.Length);
        using(SHA256 sha=SHA256.Create()) {
            byte[] digest=sha.ComputeHash(message);
            return BitConverter.ToString(digest).Replace("-","").ToLowerInvariant();
        }
    }
}
'@ -ErrorAction Stop
    }
}
$root=Require-Root $RootPath
$allowed=@('Data/patch-V.mpq','Data/patch-Z.mpq',
           'Data/Patch-J.mpq','Data/Patch-U.mpq')
if($Scope -ceq 'Client'){$allowed+=@('Data/enUS/realmlist.wtf')}
$opened=New-Object 'System.Collections.Generic.List[object]'
$results=New-Object 'System.Collections.Generic.List[object]'
$missingRequired=New-Object 'System.Collections.Generic.List[string]'
try {
    # Open EVERY existing allowed file before hashing any of them.
    # Read sharing denies new ordinary writable/delete handles while held.
    foreach($relative in $allowed){
        $full=Join-Path $root ($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
        Assert-NoReparse $full
        if(Test-Path -LiteralPath $full -PathType Container){
            throw 'A known file path resolves to a directory.'
        }
        if(-not (Test-Path -LiteralPath $full -PathType Leaf)){
            if($relative -cin @('Data/patch-V.mpq','Data/patch-Z.mpq')){
                $missingRequired.Add($relative)
            }
            $results.Add([pscustomobject][ordered]@{
                path=$relative;state='missing';size_bytes=$null;
                sha256=$null;file_object_fingerprint_sha256=$null
            })
            continue
        }
        $stream=New-Object IO.FileStream($full,[IO.FileMode]::Open,
             [IO.FileAccess]::Read,[IO.FileShare]::Read,65536,
             [IO.FileOptions]::SequentialScan)
        $opened.Add([pscustomobject]@{path=$relative;handle=$stream})
    }
    Initialize-FileIdApi
    foreach($entry in $opened){
        $stream=$entry.handle
        $lengthBefore=[int64]$stream.Length
        $fileId=[NaxxReadOnlyOpenFileIdV1]::Observe($stream.SafeFileHandle)
        $sha=[Security.Cryptography.SHA256]::Create()
        try{
            $stream.Position=0
            $digest=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant()
        }finally{$sha.Dispose()}
        if([int64]$stream.Length -ne $lengthBefore -or
           [int64]$stream.Position -ne $lengthBefore -or
           [NaxxReadOnlyOpenFileIdV1]::Observe($stream.SafeFileHandle) -cne $fileId){
            throw 'Open file identity or length changed during hashing.'
        }
        $results.Add([pscustomobject][ordered]@{
            path=$entry.path;state='observed_untrusted';size_bytes=$lengthBefore;
            sha256=$digest;file_object_fingerprint_sha256=$fileId
        })
    }
    # Reorder to the exact allowlist so missing entries appear in original position.
    $ordered=foreach($relative in $allowed){
        @($results | Where-Object {$_.path -ceq $relative})[0]
    }
    $report=[pscustomobject][ordered]@{
        kind='read_only_open_file_handle_inventory'
        schema_version=1
        scope=$Scope.ToLowerInvariant()
        status=$(if($missingRequired.Count){'missing_mandatory_patches_manual_review'}else{'observed_NOT_authenticated'})
        file_share='read_only_read_sharing'
        files=@($ordered)
        missing_mandatory_patch_paths=@($missingRequired.ToArray())
        review_required=$true
        allow_file_writes=$false
        allow_automatic_resume=$false
        authorises_rollback=$false
        records_real_consent=$false
        public_distribution_authorised=$false
        limitations='Handles protect only already opened ordinary local files while held. Missing files cannot be locked; files may change before open or after close. No whole-directory snapshot, provenance, consent, monotonic history, signed hashes, future write permission or race-free installer is provided.'
    }
    if($Json){$report|ConvertTo-Json -Depth 5}
    else{
        Write-Host 'Naxxramas - READ ONLY OPEN FILE HANDLES' -ForegroundColor Cyan
        foreach($item in $ordered){Write-Host ('{0}: {1}' -f $item.path,$item.state)}
        Write-Host ('Result: '+$report.status)
        Write-Host 'No installation, backup or rollback has been performed.' -ForegroundColor Yellow
    }
}
finally{
    for($i=$opened.Count-1;$i -ge 0;$i--){
        if($null -ne $opened[$i].handle){$opened[$i].handle.Dispose()}
    }
}
