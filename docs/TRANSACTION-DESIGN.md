# Milestone 3 — Backup-first installer transaction design

**Design status:** specification only; **no file-writing installation engine exists**.  
**Reviewed:** 10 October 2026  
**Depends on:** [Milestone 2 read-only installer plan](INSTALLER-PLAN.md), [project roadmap](ROADMAP.md), [project handover](PROJECT-HANDOVER.md).

## Goal and scope

Turn a **validated, read-only plan** into a safe, explicitly approved *local* transaction that can be reversed without erasing player changes. The first executable stage must run **only on disposable test fixtures**. After test gates are satisfied, a separate, backed-up copy of a legitimate 3.3.5a installation may be considered for an owner-controlled manual test.

This design does **not** license, download, or redistribute `patch-V.mpq`, `patch-Z.mpq`, `Patch-J.mpq`, `Patch-U.mpq`, or Blizzard's original game files. All four patch records currently set `public_distribution_approved: false`. A player's own locally held, verified file is not the same thing as permission for the project to host or distribute it.

## Safety invariants

1. **Destination is a separate client copy.** Never make the owner's only working game folder the automatic test target. Require an explicit destination and a separate backup location.
2. **V/Z remain mandatory.** No completed Naxxramas installation can report success without both `Data/patch-V.mpq` and `Data/patch-Z.mpq` matching the active reviewed patchset.
3. **Optional means optional.** J and U are independent choices. Deselecting a feature **does not** mean deleting a pre-existing patch.
4. **Every replaced file has an exact prior-state backup.** Preserve the original bytes, size and SHA-256 before any replacement; never reconstruct a former file from an assumed default.
5. **No unlisted writes.** The first transaction's allowlist contains only the four exact client patch paths and the enUS realmlist; any future addon additions need their own reviewed allowlist.
6. **No silent deletion of personal or unknown files.** Nothing under `WTF`, `Cache`, `Screenshots`, `Logs`, personal addons or unknown directories should be touched.
7. **No unsafe path traversal.** Reject volume roots, ambiguous paths, symlinks/reparse points/junctions, nested source/destination/backup folders and files that escape the canonical destination. Re-check at actual write time, not just preview time.
8. **Unknown hashes block destructive operations.** An unknown existing patch is preserved; the user must investigate it separately.
9. **Consent comes after a new preflight.** Display precise file-by-file actions and backup location, request explicit approval, then revalidate all source/destination hashes immediately before the first write.
10. **An incomplete session is never reported as success.** A power loss or failed operation must leave a recoverable journal and require recovery before another install/update.
11. **Rollback must respect player changes.** If the current file differs from the session's expected installed SHA-256, do not overwrite or delete it automatically.
12. **No network upload of local content.** Session metadata and backups stay on the user's machine. Do not send realmlist contents, absolute local paths, backup files, user data or MPQ bytes to GitHub or remote telemetry.

## State machine

| State | Meaning | Allowed next states |
| --- | --- | --- |
| `planned` | Read-only proposal available, not approved | `validated`, `cancelled` |
| `validated` | All plan inputs, sources, paths and disk limits rechecked | `approved`, `cancelled`, `blocked` |
| `approved` | User confirms exact actions and backup location | `staging`, `cancelled` |
| `staging` | Proposed sources copied to a *private, separate staging directory*, then SHA-256/size verified | `backing_up`, `failed_recoverable` |
| `backing_up` | All files that would be overwritten copied and byte-for-byte verified into immutable session backup | `committing`, `failed_recoverable` |
| `committing` | Operations applied and each completion checkpoint journalled | `verifying`, `failed_recoverable` |
| `verifying` | Full required V/Z and selected-file final state checked | `completed`, `failed_recoverable` |
| `completed` | Final hashes correct; all steps audited; restore data retained | `rollback_requested` |
| `failed_recoverable` | Stop writes and display guided recovery, never claim success | `restoring`, `support_required` |
| `rollback_requested` | User approves reversal of a specific completed session | `restoring`, `cancelled` |
| `restoring` | Reverse recorded steps in reverse order, guarding against player edits | `restored`, `conflict_requires_review` |
| `conflict_requires_review` | An affected file has changed since installation or a backup is missing/corrupt | `support_required`, `restoring` |
| `restored` | Reversible changes are undone and recovery evidence retained | terminal |
| `cancelled`, `blocked`, `support_required` | No assumption of successful setup | terminal pending new plan/review |

**Important:** staging, backups and per-file replacements do not make the entire multi-file operation atomic. A crash can interrupt the series of writes. The journal and recovery mechanism must handle every interruption boundary, including between V and Z.

## File ownership and rollback matrix

| Before install | Installer action | Normal uninstall / rollback |
| --- | --- | --- |
| File absent | Create after verified staging | Remove **only if** it still matches the installed hash; otherwise conflict |
| File present, known version | Replace after exact backup and consent | Restore exact backup **only if** current file still matches installed hash |
| File present and already current | No change | Do not touch it, or claim ownership |
| Unknown existing patch | Block selected replacement | Keep original; no automatic change |
| Optional J/U not selected | Leave present or absent as-is | No change |
| Existing realmlist has another recognised address | Replace only after backup + consent | Restore original bytes if file is unchanged since installer |
| Existing realmlist contains extra/unrecognised user content | Leave unchanged or block, requiring manual review | No automatic cleanup |

For future patch upgrades, the **first baseline backup** must remain available so a user can revert to their pre-setup state. A later session must not overwrite previous session backups. If a backup cannot be verified, stop: never improvise a replacement.

## Session manifest format — proposal

Store inside a local, per-session private backup directory such as `<user-selected-backup-location>/sessions/<random-session-id>/`. The exact absolute directory can be recorded *locally* if needed for recovery, but must be excluded from public reports.

Example *structure only* (fake identifiers, no actual files):

```json
{
  "schema_version": 1,
  "session_id": "example-session-id",
  "kind": "local_naxxramas_setup_transaction",
  "status": "planned",
  "target_build": 12340,
  "locale": "enUS",
  "patchset": "patchset-0001",
  "created_utc": "example-timestamp",
  "operations": [
    {
      "relative_path": "Data/patch-V.mpq",
      "action": "replace_after_backup",
      "was_present": true,
      "before_sha256": "example-original-sha256",
      "before_size_bytes": 0,
      "backup_relative_path": "originals/0001.bin",
      "installed_sha256": "example-expected-sha256",
      "installed_size_bytes": 0,
      "checkpoint": "not_started"
    }
  ],
  "conflicts": []
}
```

Actual implementation must validate its schema and reject unknown session states. Checkpoint writes must be durable enough for recovery and must never claim an operation was completed before the destination has actually been verified. This document does not yet choose an on-disk journal write protocol; the implementation must specify **atomic journal update, flush/ordering guarantees and recovery rules** before copying a single client file.

### Integrity ledger for every operation

- Session and manifest version, target client identity, explicit selections and source patchset.
- Relative destination path (never a dangerous caller-supplied absolute write path).
- Known original existence, size and SHA-256; backup relative path and backup hash, if replaced.
- Expected staged bytes and installed size/SHA-256.
- Actual final SHA-256, state transition checkpoint, error and conflict details.
- Backup location, timestamp and local user consent audit record.
- No passwords, private account credentials or unnecessary player identifiers.

## Proposed execution procedure

### Stage 0 — eligibility / source rights

- Review source origin and approved local-use/distribution terms separately from hashes.
- Reject any attempt to install a complete game executable, standard Blizzard MPQs or unknown patch files through the transaction engine.
- Keep an independently obtained legitimate base client as a user precondition; never download it from this project.

### Stage 1 — inspect and lock plan

- Require a distinct client destination, a distinct verified source, and a distinct private backup/staging location.
- Reject if the game client process is in use; failure to determine whether it is safe to write must block, not guess.
- Re-run the read-only planner, verify active `patchset-XXXX`, build 12340, source SHA-256+size, destination SHA-256+size, mandatory patches, options and free space (including space on the backup volume).
- Freeze the proposed file action list and display plain-language approval. Reject a stale preview and any destination changes between the initial preview and final preflight.

### Stage 2 — stage then back up

- Stage **only** approved allowlisted local files outside the client; verify staged bytes match reviewed source hashes.
- Compute all required backup sizes before writing.
- Copy every original-to-be-overwritten file into unique `originals/` backup paths and verify SHA-256/size; preserve permissions/metadata as needed for accurate restoration.
- Write the initial session manifest and atomic journal checkpoints **outside** the game client.
- If anything fails, leave game files untouched and explain which staging/backup action failed.

### Stage 3 — commit carefully

- Recheck source, destination path identity and original hashes **immediately** before each affected file write.
- Use same-volume per-file staging to permit atomic rename/replacement where the filesystem supports it; verify temp and final paths are not links and no path escapes the destination.
- Journal start/finish checkpoints and post-write hashes in a recovery-friendly order.
- If any step fails, do not report success and do not continue to unrelated writes.
- Before recording `completed`, verify **both** required V/Z against the current patchset, each selected optional file, and any approved realmlist change.

### Stage 4 — recovery / rollback

- At tool startup, search for incomplete previous sessions and **block new installs** until they are resolved.
- Offer a readable recovery report and exact paths backed up, without silently restoring a modified player file.
- Roll back completed writes in reverse order; verify installed hashes before each removal/restoration.
- Verify backup hashes before restoring them. When a conflict exists, keep both the backup and player's changed file intact and request manual resolution.
- Keep the full evidence and backups until the user explicitly chooses safe cleanup.

## Testing gates before any real client operation

Automated **disposable fixture** tests required:

1. Fresh client, pre-existing matching V/Z, both core patches missing, and one missing.
2. Known older V or Z, unknown hash, corrupt source, wrong byte length, deleted source during staging.
3. J only, U only, both, neither; preserve any unselected existing visual patch.
4. Realm already matching, different, with comments, malformed or changed after preview.
5. Incorrect Wow.exe build, missing locale, source equals destination, nested paths, volume-root selection, reparse-point/junction paths and unexpected config schema.
6. Insufficient client/backup free space, permission denial, read-only file, open/locked file, inaccessible backup path.
7. Crash simulation **before and after every journal checkpoint**, each backup, each stage and each per-file commit.
8. Repeated identical install (no duplicate writes), version upgrade, rerun after failure, interrupted rollback, repeat rollback.
9. Player changes/deletes a managed file after successful install; rollback must stop instead of destroying their work.
10. Backup is missing or corrupted; rollback must not fabricate the original bytes.
11. No writes outside the intended allowlist; filesystem snapshots before and after every test.
12. Non-ASCII or unusual path names, long paths, and PowerShell 5.1 error/exit handling.

**Current verification:** the read-only planner's synthetic Windows test workflow and the older read-only tool fixture suite both passed on 10 October 2026. This does **not** validate a future write-capable transaction or test gameplay. The proposed transaction engine has not been coded.

## Remaining design decisions

- Exact Windows-only journal durability strategy (atomic replace + flush approach and crash recovery sequence).
- Folder permission policy and per-user backup placement / retention.
- Safest mechanism for detecting an active WoW client and blocking open files.
- Windows-compatible file replacement API and rollback semantics for metadata / ACL preservation.
- Authorised method for sourcing any redistributable custom patches; none approved for public distribution at this baseline.
- Unit test harness capable of safely simulating write failures without touching a real client.

## Next implementation recommendation

**Completed first slice:** [Recovery Preview](RECOVERY-PREVIEW.md) now reads synthetic session records and inspects current/backup file hashes without changing them. The Windows PowerShell CI fixture suite passed on 10 October 2026.

**Next:** review [Journal Durability](JOURNAL-DURABILITY.md) for the proposed write/checkpoint ordering, ambiguous power-loss states and local session ownership questions. Complete remaining free-space and fail-closed regression coverage. **Do not** code a real-client write-capable engine. Any subsequent write experiments must use disposable fixtures and a separate review gate.
