# Milestone 3 — Read-only original backup readiness

**Status:** development-only preflight, no actual backup file, installation, update, rollback, removal, cryptographic approval or game client modification.

## Purpose

The Naxxramas setup must preserve **the exact original bytes** of any file it intends to replace. The new `tools/Review-Naxxramas-BackupOriginals.ps1` combines:

1. The existing [read-only installation planner](INSTALLER-PLAN.md), which classifies the five expected client paths, validates patchset-0001, build 12340/enUS, checked local sources, separately selected backup directory and estimated capacity.
2. The [read-only Windows open-file handle inspector](OPEN-FILE-HANDLE-REVIEW.md), which observes actual existing file SHA-256, lengths and Win32 FILE_ID_INFO from already opened read-only handles.

It checks that the planner's observations and the separately inspected file bytes still agree, and identifies the **specific existing originals that a future writer would have to preserve before replacement**.

**A backup *candidate* is not a verified backup.** The scanner never creates a backup, reserves space, reads arbitrary backup files or marks data recoverable.

## What files are considered?

The scanner is limited to:

| Relative path | Replacement rule |
| --- | --- |
| `Data/patch-V.mpq` | Mandatory core; a recognized older existing version is a backup candidate |
| `Data/patch-Z.mpq` | Mandatory core; same backup rule as V |
| `Data/Patch-J.mpq` | Optional login visual; only selected + recognized older version can require backup |
| `Data/Patch-U.mpq` | Optional loading visual; same rule as J |
| `Data/enUS/realmlist.wtf` | Existing differing recognized realmlist must be preserved before any future replacement |

Actions `replace_after_backup` enter the `originals_to_preserve` list with the **observed** file's SHA-256, length, object fingerprint and `backup_state=NOT_CREATED`.

`install` means there was no original destination file in the reviewed plan; it never claims a backup already exists or authorizes creating the new file. `leave_existing` and `not_selected` preserve player files untouched, including an existing unselected J/U. `no_change` is not a proposed replacement. Unknown existing patch hashes or unsafe source/target choices remain blocked using the existing planner.

The tool also rechecks any selected install/replacement source patch's observed SHA-256 and size against the planner's pinned version. It does not fetch source files or distribute custom MPQs.

## Read-only Windows commands

From the repository checkout on Windows PowerShell 5.1, with a separate user-owned test client and source:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-BackupOriginals.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Naxx-Backups" -VanillaLoading -Json`

The `-ClientPath` and `-BackupRoot` are **required** and must refer to existing, separate, non-overlapping local directories. The patch source is optional only if the planner has no outstanding selected files requiring one. Optional selections `-VanillaLogin` and `-VanillaLoading` remain independent. `-RealmHost` can preview a different realmlist destination.

The example Windows drive letters are illustrative. Nothing is downloaded or created, and the reviewer does not save a report automatically. Always preserve a separate backup of any working client before future experimentation.

## Results

The report includes:

- The exact **original-file candidates** and their observed SHA-256, byte length and file-ID fingerprints, with `backup_state=NOT_CREATED`.
- The sum of candidate original bytes and the planner's **estimated** backup-volume budget (not a reserved allocation or proof of available future capacity).
- One action per allowlisted file, showing `no_change`, `leave_existing`, `install`, `replace_after_backup`, `not_selected` or `blocked` and whether the existing file still matched the plan.
- Anonymized blocking reasons when the actual open-file inspection differs from planner expectations, a selected patch source fails verification, or the planner itself blocks.
- A limited classification: `originals_identified_NOT_BACKED_UP_NOT_APPROVED` or `manual_review_backup_readiness_blocked`.

All outcomes contain `review_required=true`, `backup_created=false`, `originals_backed_up_and_verified=false`, `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `records_real_consent=false` and `public_distribution_authorised=false`.

There is **no install-ready or backup-complete state** in this tool.

## Windows regression tests

Run from the checked-out repository:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-BackupOriginals.ps1"`

The test creates a **fake executable with file-version metadata** and tiny dummy files named like the four MPQs. It supplies a synthetic current patch manifest, a known-older V history record, a current Z, an existing unselected J, a selected new U, a different existing realmlist and an existing separate backup directory with a sentinel file.

It verifies: exact V and realmlist original candidates, candidate SHA-256 and lengths, source validation, missing mandatory Z (as a *new* file with no original), an unknown V that blocks, invalid source content, incompatible concurrent writer, backup source/client path isolation and **unchanged client/source/backup data during the review**.

These synthetic fixtures only exist in an automatically cleaned temporary test folder; no original game archives or private patches are used.

## What remains necessary before any writer

1. A real Windows approval UI and cryptographically protected, **one-use** owner consent bound to the *specific* current verified plan.
2. A durable transaction/registration ledger with independently trusted latest-state and used-consent status. A locally replayed coherent history is not detected by a checksum alone.
3. Race-aware file/directory handle validation through actual backup, installation and recovery steps, including missing file creation, path/symlink and reparse resistance. The planner and current inspector run **sequentially**, and their file handles are closed after inspection.
4. A securely created **original backup**, verified **byte-for-byte against the actual intended original** before any replacement, in a separately approved location; capacity estimates alone cannot guarantee this.
5. Windows failure injection covering incomplete backups, power interruption, filesystem flushing, later player modifications, rollback conflicts and non-destructive manual recovery.
6. Separately approved rights for any public redistribution; pinned custom patch hashes do not establish legal provenance.

Related: [Roadmap](ROADMAP.md), [Project Handover](PROJECT-HANDOVER.md), [Windows Open-file Handles](OPEN-FILE-HANDLE-REVIEW.md), [Transaction Design](TRANSACTION-DESIGN.md), [Consent Lifecycle](CONSENT-LIFECYCLE-REVIEW.md).

**This is an actual local read-only backup-candidate review, not a backup solution.**
