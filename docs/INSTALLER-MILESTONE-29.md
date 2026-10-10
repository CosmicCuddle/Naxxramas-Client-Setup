# Milestone 29 — Disposable Windows junction-swap and rollback identity safeguards

**Status:** Windows CI passed ([run 38071718543](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38071718543), tested implementation commit `eba842f9e49ca16ab508be9738e3048b6cdbd1a1`). This milestone tests only the explicitly marked, tiny M15 dummy-copy experiment. It does not install or download World of Warcraft game files.

## Why this milestone

M28 showed that the copier can detect an ordinary directory being replaced after the `applying` journal was written. A junction is a different risk: Windows can redirect a trusted-looking `Data` path into an unrelated directory. The existing link/ancestor check should refuse that, but it needs a **separate-process regression test** and the rollback path needs stronger native directory identity checkpoints.

## Changes

- New `-SyntheticExternalPauseBeforeRollbackSeconds` flag (0–15, default 0), valid **only** for explicitly confirmed synthetic Rollback. It pauses after the durable `rolling_back` journal is recorded, and before any dummy-file deletion.
- Rollback now captures the native source and destination directory identities at entry and rechecks those identities and exact fixture markers before each deletion, and the destination identity before final folder/journal removal.
- The rollback journal transition adds extra identity and link checks around the creation and replacement of the `.rollback-writing` and `.rollback-previous` sidecars. Any interruption is retained for manual review rather than guessed away.
- The new pause is refused for Plan and Copy. All the M27 Copy-only fault switches remain refused for Rollback.

## Independent process tests

New `tests/Test-Fixture-Junction-Swaps.ps1` creates three independent dummy test setups. A separate Windows PowerShell process performs the confirmed fixture action, while the parent test process waits for a parseable journal and then **renames** a disposable `Data` folder and substitutes a Windows junction to the moved folder:

| Synthetic case | Expected result |
| --- | --- |
| **Copy / source Data junction** | Source link is refused; no promoted test file survives; the original source's tiny files and the external sentinel are retained |
| **Copy / stage Data junction** | Staged link is refused; copied test file is not promoted, and the suspicious stage is preserved for inspection |
| **Rollback / destination Data junction** | Rollback link is refused before deletion; the durable `rolling_back` journal, dummy files and junction target remain intact |

Each scenario requires the explicit **`Linked/junction paths are not supported`** diagnostic rather than counting any unrelated failure. The harness verifies its external sentinel and dummy archive survived.

The junction target is always a folder inside the test's own newly created temporary root. A junction is only unlinked after checking that the test-created path is still a reparse point. **Only the test harness**, not the user-facing installer, may recursively remove its own disposable test root afterwards.

## Limits

- A path/link check is a **snapshot**. A hostile process might replace a path between the check and a subsequent deletion/move. M29 does **not** prove that Win32 file handles are held throughout a transaction, or that arbitrary concurrent filesystem changes cannot cause damage.
- Junction creation and rollback deletion tests are Windows-specific. Future work should investigate file-handle-pinned operations and narrower check-to-action races, not simply add more sleeps.
- The Win32 native identity helper remains restricted to the M15 tiny fixture workflow. Maximum eight fixed fake client paths, 256 KiB/file, 1 MiB combined, distinct exact marker files, source/patch authenticity and the disabled complete-game download source remain unchanged.
- There is **no** automated orphan cleaner, full-client redistribution, real WoW copy or unchecked overwrite.
- The draft branch remains separate from `main`; no release or merge without explicit owner approval.
- No local WoW client scan, Windows script run or new backup is required for this milestone.

## Next engineering stage

M30 should prototype a safer held-handle/identity-aware operation model (including atomic journal updates) exclusively on disposable test paths, and document the remaining Windows filesystem race assumptions before any real-client copy could be considered.

**Windows CI passed:** [run 38071718543](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38071718543). The three separate-process source/stage/rollback destination junction substitutions were explicitly refused. Original synthetic dummy files, external sentinel data and rollback journal states were preserved as expected. All earlier fixture copy/rollback, M20–M28 recovery, patch/addon, WinForms smoke and preview ZIP tests also passed. These remain limited to tiny synthetic fixtures and do not establish production race freedom.
