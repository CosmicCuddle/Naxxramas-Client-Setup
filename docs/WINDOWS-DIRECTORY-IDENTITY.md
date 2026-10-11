# Read-only Windows directory identity preview

**Status:** Windows PowerShell 5.1 synthetic test tool. It performs **no installation, backup, restore, deletion, registration or filesystem writes**.

## What problem is this solving?

A directory path alone is not enough to identify the particular game folder that a future installer would be allowed to manage. A player can rename a folder, copy a client elsewhere, move storage, or create a different folder at the old path.

This prototype reads the Windows **filesystem object identifier** from an existing directory handle instead of relying on the folder name. Microsoft defines the combination of `FILE_ID_INFO`'s volume serial and 128-bit file ID as identifying a file on one computer. This provides an observation, **not** secure installation registration.

## Inspector

`tools/Inspect-Naxxramas-DirectoryIdentity.ps1`

The script:

1. Validates an existing local directory, rejecting missing folders, drive roots, UNC paths and reparse-point ancestors (junctions, linked folders and mounted-folder paths).
2. Opens a directory handle using `CreateFileW` with **zero desired access** and the flags `FILE_FLAG_BACKUP_SEMANTICS` and `FILE_FLAG_OPEN_REPARSE_POINT`.
3. Requests `FileIdInfo` with `GetFileInformationByHandleEx`. If Windows cannot provide a valid ID, it fails closed.
4. SHA-256 hashes a version tag plus the in-memory volume serial and 128-bit object ID, producing a pseudonymous local fingerprint.
5. Optionally compares the observed identity of a second selected directory.
6. Outputs the fingerprint, optional comparison and limitations. Absolute paths and raw volume serial numbers are not printed.

The fingerprint is **not a secret**, cryptographic ownership proof or protected Windows registration. It is a repeatable, potentially correlatable local value.

## Tests (developer-only)

From the repository checkout, run this using **Windows PowerShell 5.1**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-DirectoryIdentity.ps1"`

All tests use disposable fake client folders, not Blizzard files. They establish that:
- The same directory consistently returns the same identity.
- A rename on one filesystem preserves its directory ID.
- A newly copied directory with identical contents has a different object identity.
- Parent and child folders have different IDs.
- Missing locations, files masquerading as directories, drive roots and junctions are rejected.
- JSON reports omit local paths and test file contents.
- Read-only identity queries preserve file snapshots.

You can compare two **synthetic** folders with:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Inspect-Naxxramas-DirectoryIdentity.ps1" -ClientPath "C:\SyntheticA" -ComparePath "C:\SyntheticB" -Json`

`same_filesystem_object` is `true`, `false` or `null` if no comparison was requested. A match means the observed Windows filesystem identity bytes matched, **not** that a future installation or rollback is authorised.

## Safety limitations and design decisions

**Do not treat this as a permanent authenticated installation ID.**

- Filesystem IDs can change or be recycled after deletion, volume moves or restores. The hash does not prevent spoofing, replay or registration loss.
- Copies are distinct objects even when files are identical. The prototype does not verify `Wow.exe`, client build, V/Z hashes, locale or player files.
- Some filesystems and network paths may not expose this information. Missing or unsupported IDs are **not** assumed safe.
- A path could be replaced between reparse inspection and opening the handle. A future **writer** needs separately reviewed, handle-based write-time identity checks to protect against such races.
- The tool neither saves identity registrations nor connects to the synthetic signed journal/backup recovery tools.
- A journal and a caller-controlled identity value remain replayable with other caller-controlled records. **DPAPI-protecting a key does not by itself create monotonic anti-rollback state.**
- Real-client installation still requires explicit consent, source/provenance approval, byte-for-byte backups, safe staged operations, and crash-recovery testing.

## Before a trusted identity system can exist

1. Specify separately protected local registration that is never inferred only from untrusted journal data.
2. Define conservative rename, copy, migration, missing-registration and changed-volume behaviour (default: **manual review**).
3. Bind approved plan, install-target identity, signed journal and independent latest-state anchor without accepting arbitrary supplied key paths.
4. Ensure the future writer revalidates file and directory handles immediately before changes, with TOCTOU and process-lock safeguards.
5. Decide whether a genuinely monotonic external/hardware/administrative trust anchor is needed. A local JSON file, hash, HMAC and ordinary user ACL cannot guarantee nonrollback.
6. Test crash and conflict cases **only on disposable fixtures** before proposing any write-capable implementation.

## Microsoft API references

- [Obtaining a handle to a directory](https://learn.microsoft.com/en-us/windows/win32/fileio/obtaining-a-handle-to-a-directory)
- [GetFileInformationByHandleEx](https://learn.microsoft.com/en-us/windows/desktop/api/winbase/nf-winbase-getfileinformationbyhandleex)
- [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)

**Next:** design safe registration/anchor recovery and review crash ordering without adding any game-client writes.
