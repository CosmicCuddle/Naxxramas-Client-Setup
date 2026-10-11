# Milestone 3 — Windows read-only open-file handle review

**Status: developer-only file inspection, not an installer, update, backup, approval, rollback or removal system.** This milestone uses actual local Windows file handles, but **only reads** selected client or source files.

## Purpose

The [Live Plan Recheck](LIVE-PLAN-RECHECK.md) compares two complete planner/Windows directory scans. Its two matching passes are not atomic: files can change between individual opens and immediately after scans.

This milestone adds a focused read-only inventory that opens **all existing allowlisted files before computing any hashes**. Every opened file is held using `System.IO.FileStream` with `FileAccess.Read` and `FileShare.Read`. On ordinary Windows filesystem shares, other programs cannot open those same handles for new writes or deletion while these read handles remain open. The inventory reads SHA-256, byte size and a pseudonymous fingerprint derived from `GetFileInformationByHandleEx(FILE_ID_INFO)` on the same open handle.

This is a *development safety probe*, not a lock the later installer can automatically rely upon. The scanner closes every handle before returning.

## Exact allowlists

Client scope:

- `Data/patch-V.mpq` — mandatory
- `Data/patch-Z.mpq` — mandatory
- `Data/Patch-J.mpq` — optional login screen
- `Data/Patch-U.mpq` — optional loading screens
- `Data/enUS/realmlist.wtf` — client configuration

Source scope (existing separate, independently obtained local directory): four patch paths V, Z, J, U only; the realmlist is generated from the selected realm policy in the existing planner.

Mandatory patches V and Z must not be silently omitted from the overall Naxxramas setup. The tool **reports their absence for manual review** but never supplies, creates or replaces them. Optional patch absence is merely observed.

## Read-only developer commands

From a downloaded repository checkout on **Windows PowerShell 5.1**:

Inspect an already-owned **test copy** of the client:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Inspect-Naxxramas-OpenFileHandles.ps1" -RootPath "D:\WoW-TEST" -Scope Client -Json`

Inspect a separate folder of local patch files already held by the user:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Inspect-Naxxramas-OpenFileHandles.ps1" -RootPath "E:\Local-Naxx-Patches" -Scope Source -Json`

These are example locations; no such paths are assumed to exist. No output file is created.

The scanner **does not need the user's 18.6 GB archive** and does not download MPQs or probe unspecified client files. It reads only its explicit allowlist. Since patch V can be hundreds of megabytes, a full SHA-256 scan may be noticeable.

## Handling and output

For each existing file, the tool opens a Windows FileStream with read-only access, shares **read only**, obtains its object ID from the **open handle** (not a later path lookup), reads the SHA-256 digest, and checks the open handle's identity and length again. A writer that already holds an incompatible writable share causes inspection to fail closed rather than trusting a partial result.

The report lists only the allowlisted **relative paths**, file presence, digest, byte size and pseudonymous file ID. The report deliberately does **not** contain the selected absolute client path or local source path. Nevertheless, hashes/IDs can be correlatable; don't publish personal inspection reports unnecessarily.

The tool always returns:

- `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`
- `records_real_consent=false`, `public_distribution_authorised=false`, `review_required=true`

Even if every file is present, its status is `observed_NOT_authenticated`, **not** approval for installation. Missing V/Z yields `missing_mandatory_patches_manual_review`.

## Windows CI coverage

Test command:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-OpenFileHandles.ps1"`

The Windows test creates **small, disposable text files** with fake `.mpq` names and a fake `realmlist.wtf`. It checks the hashes against Windows `Get-FileHash`, sizes, pseudonymous object fingerprints, missing mandatory and optional patches, source vs client allowlists, incompatible concurrent writable handles, attempted opening for write while `FileShare.Read` is held, safe rejection of a junction (where supported), no leaked absolute paths, and unchanged fixture content after inspections.

Fixture writing and cleanup are confined to a uniquely generated temporary directory. There are **no real Blizzard client files, private custom MPQs, backups or server changes** involved.

## Limitations and remaining implementation gates

1. **Not an atomic directory snapshot.** A file can change before its open, after the handles are closed, or in ways not prohibited by normal share semantics (including powerful local attackers). Files missing at open time cannot be locked; replacing directory path ancestors remains a risk. Symlink/reparse checks and opens are not an atomic operation.
2. **No cryptographic ownership proof.** Win32 file IDs can be recycled and changed, and their hashes are not authenticated. A file digest proves the bytes read, not that an owner approved replacement, that rights exist, or that all historical records are current.
3. **No persistent transaction.** The scanner deliberately closes the read handles before returning. It does not retain them for a future writer, validate an actual approved plan under durable identity, issue a one-use receipt or prepare originals.
4. **No backup or recovery guarantee.** Separate original-backup preservation and Windows filesystem durability/flush/error semantics still require a dedicated safety design and tests.
5. **No redistribution.** The pinned custom V/Z/J/U patch checksums identify expected bytes only; the repository explicitly does not approve public patch distribution.

Before a production writer is considered, review an exact **open-handle, path, ownership and file-ID protocol through the *entire* transaction**, including missing/new targets and directory ancestors; also review authentic one-time consent, independent latest-state/used-token authority, backup proof, crash safety, and source rights.

Related: [Live Plan Recheck](LIVE-PLAN-RECHECK.md), [Roadmap](ROADMAP.md), [Project Handover](PROJECT-HANDOVER.md), [Journal Durability](JOURNAL-DURABILITY.md), [Consent Lifecycle](CONSENT-LIFECYCLE-REVIEW.md).

**This inspector is strictly read-only. No file writes are permitted or performed.**
