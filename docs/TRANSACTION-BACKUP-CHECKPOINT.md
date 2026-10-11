# Milestone 3 — Read-only transaction backup checkpoints

**Status: a read-only production inspector and a separately contained disposable Windows test harness. There is no file-writing installer, backup creator, real owner consent, durable recovery record or automatic rollback.**

## Scope

The existing [Original Backup Readiness](BACKUP-ORIGINALS-READINESS.md) identifies *which existing original files need preservation*, and [Existing Backup Copies](EXISTING-BACKUP-COPIES.md) checks *whether already-existing mirrored copies have matching bytes and different observed file IDs*. This milestone adds a **transaction-identifier-scoped checkpoint inspection** to model interrupted staging without changing any real client data.

Given a separately selected local backup root and a restricted ASCII `TransactionId`, the read-only reviewer examines the already-existing layout:

`<BackupRoot>\transactions\<TransactionId>\checkpoint.json`

`<BackupRoot>\transactions\<TransactionId>\originals\Data\patch-V.mpq` (and any other mirrored original candidates)

`<BackupRoot>\transactions\<TransactionId>\stage\Data\patch-V.mpq.part` (optional, indicates incomplete stage when that path exists)

**The tool never creates any of those paths.** It does not search outside its allowlist, remove partial files, complete an interrupted copy, supply missing patches, write a journal or authenticate any state. The checkpoint file is **entirely caller controlled** and **must not be treated as a reliable event log or proof of provenance**.

## Checkpoint schema

`[1, "synthetic-txn-0001", "copy_checked", "0123...64-lowercase-hex..."]`

Exactly four elements are required:

- version `1`
- transaction identifier, 8–80 characters matching `[A-Za-z0-9_-]`
- claimed phase: `prepared`, `copy_started`, `copy_staged` or `copy_checked`
- a SHA-256 **unkeyed fixture digest** of the currently observed original candidates

The digest is built from the existing actual Windows read-only original-candidate reviewer, with exact typed tuples `[relativePath, originalSizeBytes, originalSha256, originalFileIdFingerprintSha256]` in its known V/Z/J/U/realmlist order. PowerShell 5.1 serializes the positional array with `ConvertTo-Json -InputObject $semantic -Compress -Depth 9`. Prefix the UTF-8 bytes with `NAXX-ORIGINAL-CANDIDATES-FIXTURE-1:` and calculate SHA-256 lowercase hex.

**This hash is NOT signed or keyed.** Anyone who can edit both the fake checkpoint and current files can generate an internally consistent matching hash. It is a drift-detection claim only, not actual player approval or backup certification.

## Inspection logic

The reviewer:

1. Rejects transaction identifiers that could allow path traversal. Checks the existing transaction/originals/checkpoint input paths and their ancestors for junctions, symlinks or other reparse points.
2. Rejects missing/oversized/malformed checkpoint JSON and unsupported phases.
3. Runs the **actual read-only original backup readiness scanner** against the selected client and transaction-specific originals root.
4. Runs the **actual held-file-handle-backed existing backup copy scanner** against that same originals root.
5. Recomputes the original-candidate digest from observed original file sizes, hashes and Win32 file IDs, and compares it with the claimed checkpoint hash.
6. Checks for leftover `stage/<candidatePath>.part` files. Any present partial for a candidate is a manual-review blocker, whether or not completed mirrored copies exist.
7. Reports only read-only diagnostics. A status with all claims matching is **not a recovery or installation authorisation**.

### Expected classifications

| Observation | Read-only result |
| --- | --- |
| Claimed `prepared` or `copy_started` | `checkpoint_not_claimed_copy_checked` |
| Mirrored original missing or has different bytes | `required_existing_original_copies_not_matching` |
| Changed original after checkpoint claim | `claimed_original_snapshot_changed` |
| Remaining `.part` original copy | `uncommitted_partial_original_copies_present` |
| Both copies have matching bytes and distinct file IDs, claimed `copy_checked`, no partial | `checkpoint_claims_and_bytes_match_NOT_DURABLE_NOT_AUTHENTICATED` |
| Otherwise | `manual_review_transaction_backup_checkpoint_blocked` |

Even the most favourable classification has these **unconditional** flags:

`backup_created=false`, `checkpoint_authenticated=false`, `durable_backup_verified=false`, `originals_backed_up_and_verified=false`, `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `records_real_consent=false`, `public_distribution_authorised=false`.

The reviewer does not claim that any file was copied by our program or that it was the original before prior modifications. Its own inspection handles close before it returns.

## Running the developer-only read-only review

Use a separate test client and pre-existing local transaction folder on Windows PowerShell 5.1:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-BackupCheckpoint.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Patches" -BackupRoot "F:\Independent-Backups" -TransactionId "test-txn-0001" -Json`

The example locations are placeholders; the tool doesn't create any paths or save output.

**Never use a matching result to install or restore anything.** If the backup is missing, ambiguous, incomplete or stale, preserve all existing data and arrange manual review.

## Windows fixture-only copy experiment

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-BackupCheckpoint.ps1"`

The test creates a temporary directory of **small fake files** (not Blizzard MPQs or player game data), with a harmless synthetic build-number fixture executable, an older fake V, a current fake Z and a changed fake realmlist.

Only *inside that generated test directory*, the test harness:

- Uses `FileMode.CreateNew` for a staged copy, so it refuses overwriting an already-existing original copy.
- Exercises a `.part` interrupted state, a single completed file with another original missing, and both completed copies.
- Calls `FileStream.Flush(true)` on the test-copy stream; this is an API exercise and **does not prove power-loss durability** or atomic metadata commits.
- Compares staged originals with actual fake client originals, then tests copy corruption, a bogus claimed checkpoint digest, changed original contents, and invalid transaction-ID or malformed checkpoint.
- Confirms the fake client/source bytes and an existing separate backup sentinel remain unchanged.

The committed **production reviewer stays entirely read-only**. The only backup-copy creation logic in this milestone exists inside `tests/Test-BackupCheckpoint.ps1` and is constrained by the automatically created disposable Windows test root. It is neither exported as an installer command nor safe or approved for real files.

## Critical limitations before any real backup writer

- **No genuine approval:** Nothing authenticates a player, issues a one-use grant or binds consent to an independently verified installation plan.
- **No trusted latest state:** The local checkpoint, candidate digest and staged files are replayable together. Neither SHA-256 nor local DPAPI alone ensures monotonically increasing journal state.
- **No atomic handle protocol:** Separate scans open and close handles; path swaps, A–B–A races and file changes after inspection are still possible.
- **No verified durable transaction:** `Flush(true)` does not demonstrate safety after sudden power loss; filesystem metadata, directory naming, replacement ordering and recovery need separate supported-Windows analysis.
- **No proven immutable backups:** `CreateNew` rejects an accidental overwrite at the moment of creation; it does not make a file immutable after creation or prove independent physical disk storage.
- **No real safe restoration:** Player-changed originals, stale or missing session records, conflicting file identities and unapproved source rights must never trigger automatic rollback.
- **No public assets:** Mandatory V/Z and optional J/U archives remain externally supplied under rights which must be separately established before public redistribution.

Read [Transaction Design](TRANSACTION-DESIGN.md), [Journal Durability](JOURNAL-DURABILITY.md), [Roadmap](ROADMAP.md) and [Project Handover](PROJECT-HANDOVER.md) before any future implementation changes.

**All real-client installation, updating, backup-writing, rollback and uninstall operations remain unimplemented.**
