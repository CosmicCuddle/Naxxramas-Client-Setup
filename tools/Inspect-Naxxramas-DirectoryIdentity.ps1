#requires -Version 5.1
<#
Naxxramas Client Setup - READ-ONLY directory handle identity preview.
This reports a pseudonymous Windows filesystem object fingerprint.
It is NOT proof of installer ownership, a durable/monotonic trust anchor,
or permission to modify the selected folder. All inputs are read only.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ClientPath,
    [string]$ComparePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'The read-only filesystem identity inspector requires Windows.'
}

function Assert-NotLinked([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $entry = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Linked, mounted-folder or junction ancestors are not allowed in identity previews.'
            }
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent) { break }
        $current = $parent.FullName
    }
}
function Require-SafeFolder([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Selected directory must exist.'
    }
    Assert-NotLinked $Path
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $full = [IO.Path]::GetFullPath($resolved)
    Assert-NotLinked $full
    if ($full.StartsWith('\\',[StringComparison]::Ordinal)) {
        throw 'UNC network locations are not supported for local identity inspection.'
    }
    if ($full.TrimEnd('\').Equals(([IO.Path]::GetPathRoot($full)).TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Drive or volume roots are not valid selected client directories.'
    }
    return $full
}
function Initialize-IdentityApi {
    if (-not ('NaxxDirectoryHandleIdentityV1' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class NaxxDirectoryHandleIdentityV1 {
    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_ID_INFO {
        public ulong VolumeSerialNumber;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public byte[] FileId;
    }

    [DllImport("kernel32.dll", EntryPoint="CreateFileW", CharSet=CharSet.Unicode,
        SetLastError=true)]
    private static extern SafeFileHandle CreateDirectoryHandle(
        string name, uint desiredAccess, uint shareMode, IntPtr security,
        uint creationDisposition, uint flags, IntPtr template);

    [DllImport("kernel32.dll", EntryPoint="GetFileInformationByHandleEx",
        SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandleEx(
        SafeFileHandle handle, int infoClass,
        out FILE_ID_INFO info, uint size);

    public static byte[] GetDirectoryObjectId(string directory) {
        // 0 desired access, SHARE_READ|WRITE|DELETE, OPEN_EXISTING,
        // FILE_FLAG_BACKUP_SEMANTICS|OPEN_REPARSE_POINT.
        using (SafeFileHandle handle = CreateDirectoryHandle(
            directory, 0, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
            if (handle.IsInvalid)
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Could not open selected directory handle.");
            FILE_ID_INFO info;
            uint size = (uint)Marshal.SizeOf(typeof(FILE_ID_INFO));
            if (!GetFileInformationByHandleEx(handle, 18, out info, size))
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Windows cannot report 128-bit filesystem identity for this directory.");
            if (info.FileId == null || info.FileId.Length != 16)
                throw new InvalidOperationException("Invalid FILE_ID_INFO from Windows.");
            bool hasId = false;
            foreach (byte b in info.FileId) if (b != 0) hasId = true;
            if (!hasId)
                throw new InvalidOperationException("Filesystem returned an empty file ID.");
            byte[] output = new byte[24];
            Buffer.BlockCopy(BitConverter.GetBytes(info.VolumeSerialNumber), 0, output, 0, 8);
            Buffer.BlockCopy(info.FileId, 0, output, 8, 16);
            return output;
        }
    }
}
'@ -ErrorAction Stop
    }
}
function Read-Fingerprint([string]$Folder) {
    Initialize-IdentityApi
    $raw = [NaxxDirectoryHandleIdentityV1]::GetDirectoryObjectId($Folder)
    # This hash is just a repeatable local observation, NOT authenticated
    # identity and NOT a secret. Do not use it alone to authorise writes.
    $prefix = [Text.Encoding]::ASCII.GetBytes('NAXX-DIR-OBJECT-FP-V1:')
    $buffer = New-Object byte[] ($prefix.Length + $raw.Length)
    [Buffer]::BlockCopy($prefix,0,$buffer,0,$prefix.Length)
    [Buffer]::BlockCopy($raw,0,$buffer,$prefix.Length,$raw.Length)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($buffer))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$client = Require-SafeFolder $ClientPath
$clientFingerprint = Read-Fingerprint $client
$secondFingerprint = $null
$match = $null
if ($ComparePath) {
    $comparison = Require-SafeFolder $ComparePath
    $secondFingerprint = Read-Fingerprint $comparison
    $match = ($clientFingerprint -ceq $secondFingerprint)
}
$report = [pscustomobject][ordered]@{
    kind = 'read_only_windows_directory_identity_preview'
    schema_version = 1
    status = 'observed_not_authenticated'
    identity_method = 'Win32_FILE_ID_INFO_128_and_volume_serial'
    client_fingerprint_sha256 = $clientFingerprint
    comparison_requested = [bool]$ComparePath
    comparison_fingerprint_sha256 = $secondFingerprint
    same_filesystem_object = $match
    no_file_changes = $true
    limitations = 'Filesystem IDs may change or be reused. A local fingerprint cannot prove installer ownership, patch validity, Windows user identity, or prevent journal replay. Never authorise writes from this result.'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 4
} else {
    Write-Host 'Naxxramas Client Setup - READ ONLY FOLDER IDENTITY' -ForegroundColor Cyan
    Write-Host ("Client directory fingerprint: {0}" -f $clientFingerprint)
    if ($ComparePath) {
        Write-Host ("Comparison directory fingerprint: {0}" -f $secondFingerprint)
        Write-Host ("Same observed filesystem object: {0}" -f $match)
    }
    Write-Host 'No files changed. This is not proof of installation ownership.' -ForegroundColor Yellow
}
