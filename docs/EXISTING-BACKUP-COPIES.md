# Milestone 3 — Read-only existing backup copy comparison

**Status:** read-only Windows developer review. Does **not** create copies, reserve storage, restore originals, approve any write, prove authentic backup provenance, record genuine player consent or enable rollback.

## Why we added this

[Original Backup Readiness](BACKUP-ORIGINALS-READINESS.md) uses the real installation planner and read-only file handles to identify each existing file that *would* need preserving before a future `replace_after_backup` action. That does not confirm that any original has already been copied.

The new `tools/Review-Naxxramas-ExistingBackupCopies.ps1` inspects an **already-existing** backup directory using the same [Windows open-file-handle scanner](OPEN-FILE-HANDLE-REVIEW.md). It compares the actual contents of each original-candidate file against its corresponding separate copy **without creating or modifying either one**.

The file layout is strictly mirror-relative to the *chosen* backup root: an original candidate `Data/patch-V.mpq` is checked against `<BackupRoot>\Data\patch-V.mpq`; similarly for Z/J/U and `Data/enUS/realmlist.wtf`. The tool never searches a computer for backups or guesses dates or versioned folder names. This is a developer **comparison convention only**, not a proposed production backup naming scheme.

## What a meaningful match requires

For every action already classified as `replace_after_backup`:

1. The original-candidate reviewer must be able to run its existing real planner and file-handle scans, including all source, file, client, backup location and preflight checks.
2. The mirrored copy must already exist as a regular file in a selected, separate local directory. Windows junctions/symlinks in known file paths are rejected by the existing inspector.
3. The copied bytes and exact byte count must match the original's observed SHA-256 and length.
4. The copy's Win32 `FILE_ID_INFO`-derived fingerprint must **differ** from the original's fingerprint. A Windows **hard link** can point to the same underlying file, even though both names have matching bytes: it must **not** count as a separate backup.

Non-candidates remain untouched and do not need mirrored copies. For example, current patch Z or an unselected existing J is **not** a backup-original requirement, and missing `Data/patch-Z.mpq` in a backup root is not automatically an error unless the current plan genuinely proposes replacing an older Z.

## Developer command

Open Windows PowerShell 5.1 in a local repository checkout. **Use your own separately backed-up test client first**, not your sole working WoW installation.

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-ExistingBackupCopies.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Patches" -BackupRoot "F:\Previous-Originals" -Json`

These are illustrative example paths. The backup folder and any mirrored file content must **already exist**; nothing is created. Use `-VanillaLogin`, `-VanillaLoading` and `-RealmHost` consistently with any previous planner preview.

## Output and its meaning

For every original candidate, the report classifies the observed mirrored backup copy:

| Observed state | Meaning |
| --- | --- |
| `same_bytes_distinct_observed_file_object_NOT_CERTIFIED` | SHA-256 and size match, and the scanned file object ID differs. **Still not an authenticated or durable backup** |
| `missing` | The expected mirrored file is absent |
| `bytes_do_not_match_original` | Contents or length differ |
| `same_file_object_as_original` | The candidate appears to be a hard link or other alias to the original; this is **not** independent preservation |

It reports `matching_existing_copies_observed_NOT_RECOVERY_PROOF` only when all current candidate observations match, no hard link is detected, and the upstream original-readiness planner is not blocked. All other mismatches or upstream blockers yield `manual_review_existing_backup_copy_blocked`. When no file replacement requires an original, the output is `no_original_replacements_to_compare_NOT_APPROVED`.

**Every report** sets:

- `backup_created=false`
- `authentic_backup_provenance_verified=false`
- `durable_backup_verified=false`
- `originals_backed_up_and_verified=false`
- `restores_authorised=false`
- `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `records_real_consent=false`, `public_distribution_authorised=false`

A matching digest means **matching observed bytes only**. It does not prove *when* or *how* a file was created, that it was the original before any previous installation, that it survived an actual flush/power outage, that it is independent of the current storage device, or that rollback would avoid overwriting later player changes.

## Windows CI

Run from a checkout:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-ExistingBackupCopies.ps1"`

The suite creates **small fake MPQ-named text files**, a fake versioned executable, a synthetic patch manifest and an existing fake older patch V + changed realmlist. It separately creates copies inside a disposable backup directory (these writes happen **only in the test setup**, not in production tools). The test verifies:

- Both original candidates can be observed with matching bytes and distinct Win32 file identities.
- An altered copy, absent copy and concurrent writer sharing conflict are detected or fail closed.
- A **hard link** to the original, when supported by the runner, is rejected despite identical SHA-256.
- Unknown original V, missing local patch source or forbidden backup overlap remains blocked.
- The production scanner does not modify the client, source or backup directory and never exposes absolute temporary paths.

The test setup is disposed after execution. No Blizzard client content or private MPQ is included.

## Transaction-scoped interrupted staging review

The [Transaction Backup Checkpoints](TRANSACTION-BACKUP-CHECKPOINT.md) milestone uses these **actual read-only existing-copy observations** to classify an already-existing transaction-specific `originals` folder plus an untrusted local phase/digest claim. It detects leftover `.part` staging files and source/copy drift. The Windows regression test creates tiny staged files only inside a generated temporary folder and simulates interruption and corruption; **the runtime inspector remains read-only**, and a matching claim still cannot prove durability, original provenance or safe restoration.

## Still required for a safe installer

The actual production backup writer must create an **immutable, transaction-scoped, original-preserving backup** under a separately selected, adequately sized and trustworthy location. It must verify it byte-for-byte while maintaining safe file/directory handles; explicitly journal a backup-verified stage, handle failure/interruptions without losing originals, re-open/verify the backup before any future restore, and refuse to replace files changed by the player.

Fresh explicit **one-time authenticated owner consent**, source rights, an independently trustworthy used-token/latest journal state, and proven Windows flush and crash semantics are still outstanding. The current tools cannot substitute for any of those requirements.

Related: [Original Backup Readiness](BACKUP-ORIGINALS-READINESS.md), [Transaction Design](TRANSACTION-DESIGN.md), [Journal Durability](JOURNAL-DURABILITY.md), [Project Handover](PROJECT-HANDOVER.md).

**There is no file-writing installer, backup creator, or automatic restore capability in this milestone.**
