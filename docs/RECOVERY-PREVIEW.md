# Read-only recovery preview (Milestone 3 foundation)

**Status:** development-only review tool, **not** a rollback/uninstall function.  
**Script:** `tools/Review-Naxxramas-Recovery.ps1`

The future Naxxramas installer will need a reliable record of every file it created or replaced. Before building code that can *restore* anything, this tool checks a **local test session manifest** and predicts which recovery actions would be safe to review.

It never creates, changes, copies, restores, deletes, downloads or uploads client files, original backups or session JSON.

## Current audience and limits

This tool is for **developers and disposable synthetic test fixtures only**. No real installer currently creates `session.json` records. **Do not fabricate a session against your working WoW client** or attempt to perform the suggested operations manually. The actual write-capable backup/rollback system is still unimplemented.

No WoW client data, account settings, game assets or real MPQs are bundled.

## PowerShell usage (developers)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-Recovery.ps1" -ClientPath "D:\Disposable-WoW-Fixture" -SessionDirectory "E:\Fixture-Backup\sessions\session-001"
```

Add `-Json` for a machine-readable local console result.

The session directory must contain `session.json` and any original backups referenced under `originals/`. Both client and session directories must already exist and must **not** be nested in one another or be links/junctions. This early prototype understands only five exact relative client paths: V, Z, J, U, and `Data/enUS/realmlist.wtf`. It does not inspect or propose actions for executables, personal addons, `WTF`, `Cache`, logs or unrelated files.

## Meaning of the results

| Proposed recovery | What was detected | Policy for eventual rollback |
| --- | --- | --- |
| `restore_after_approval` | Session says a known original existed, the current file matches the recorded installed hash, and its exact backup is verified | May restore after explicit confirmation and renewed write-time validation |
| `remove_after_approval` | Session says it created the file and current bytes still match what it installed | May remove after confirmation and renewed validation |
| `already_original` | The original bytes are already present | Leave alone |
| `already_absent` | A file originally absent is still absent | Leave alone |
| `conflict_preserve_current` | Current file differs from the original and installed states, or a prior original has disappeared | Preserve current data; manual review required |
| `blocked_backup_unavailable` | A needed original backup is missing or fails SHA-256/size verification | Do not attempt restore |

The entire preview is tagged `read_only_recovery_preview_not_restore_authorisation`. A result of `review_only_no_conflicts` is **not** permission for automatic writes.

## Manifest acceptance rules

- Session format version is exactly 1, with kind `local_naxxramas_setup_transaction`, valid session ID, target build 12340, locale `enUS`, and `patchset-XXXX`.
- Session contains 1–5 unique files from the exact allowed relative paths.
- Only `install` (originally absent) and `replace_after_backup` (originally present) operations are accepted.
- Stored pre-install and installed checksums must be 64 hex digits, and stored file sizes must be non-negative integers.
- A replaced file must reference `originals/0001.bin`-style relative backup paths only; backups are hashed and compared to the recorded original bytes.
- Linked folders and files, nested session/client locations, oversized session JSON (over 1 MiB), duplicate paths, unknown session states and path traversal are rejected.
- The preview does not trust the session record enough to perform a write. Any future transaction engine must authenticate its own journals, revalidate before each change and handle interruption checkpoints.

See [Transaction Design](TRANSACTION-DESIGN.md) for the complete state-machine and backup/rollback contract.

## Automated tests

Run the fixture-only Windows PowerShell 5.1 test:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-RecoveryPreview.ps1"
```

The tests create a throwaway *fake* client, session and backups. They check normal restoration/removal suggestions, player-modified files, missing/corrupt backups, already-reverted states, invalid relative paths, duplicate operations, mismatched action/existence fields, invalid checksums/states and strict no-write snapshots.

GitHub Actions runs these fixtures on Windows through `.github/workflows/recovery-preview-tests.yml`. CI results must be checked separately; adding a workflow file does not prove it has passed.

## What comes next

1. Confirm and fix Windows PowerShell CI results for this preview.
2. Add a test for symlink/junction inputs, oversized JSON and additional malformed manifests.
3. Review durable journal design and authenticated session ownership.
4. Only then begin **fixture-only** staged-write/recovery experiments; do not alter a real WoW client or distribute MPQs.
