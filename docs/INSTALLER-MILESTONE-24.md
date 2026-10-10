# Milestone 24 — Interrupted journal writes and destination-collision safety

**Status:** Windows validation pending. Work applies only to **tiny, expressly marked disposable synthetic fixtures**. It does not make real WoW installation or download available.

## Starting checkpoint

M23 Windows [run 38063451573](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38063451573) passed, with simulated low-space, stage-write failures and changed staged files. M15 still permits only eight specified dummy paths, 256 KiB maximum per file, 1 MiB total, and exact separate source/destination marker files. Explicit confirmation is mandatory before Copy and Rollback.

## New M24 failure scenarios

Three confirmed-Copy-only simulation flags in `tools/Test-Client-Copy-Fixture.ps1`:

| Switch | Synthetic interruption | Required result |
| --- | --- | --- |
| `-SimulateInterruptedStageOwnerWrite` | Creates only a truncated stage ownership marker, before any staged file | An untrusted stage folder remains, no destination journal or file is created, and the M22 read-only inspector blocks it |
| `-SimulateInterruptedJournalWrite` | Leaves a deliberately truncated `.naxx-fixture-copy-journal.json` after staging but before any promotion | Partial journal is **preserved**, future Copy and Rollback must refuse it, staged files are cleaned only when verified and safe |
| `-SimulateDestinationCollisionBeforePromotion` | Creates a small unowned dummy file at the first destination path immediately after the staged/source checks | Promotion refuses overwrite, unowned bytes remain untouched, verified owned stage is cleaned; subsequent Copy refuses occupied destination |

The collision file uses `FileMode.CreateNew`, so even the test cannot overwrite another file already at that location. This is **controlled deterministic fault injection**, not a real concurrent external process or fully eliminated race condition.

## Additional safety changes

- Copy failure handling no longer automatically deletes a known-uncertain partially written journal; it reports **manual intervention required**.
- Unexpected journal-replacement sidecars (`.writing` / `.previous`) are no longer blindly deleted when handling a copy failure. Unknown residue is retained for investigation.
- Copy-only injection options are refused during Plan and Rollback; ordinary action confirmation, locked manifest and client-path restrictions remain.
- The M22 stage-cleanup guard still uses nonrecursive verified deletion only for owned, unchanged tiny fixture files. Partial/invalid stage ownership is never accepted for cleanup.
- Recovery decisions remain manual. Do not rename, repair or delete uncertain journals/stages without a separately designed validated workflow.

## Windows regression tests

Expanded `tests/Test-Client-Copy-Fixture.ps1` verifies refusal without explicit confirmation, preservation of incomplete stage markers, refusal by M22 stage audit, preservation and blocking of incomplete destination journals, and collision non-overwrite. The dummy test harness deliberately removes its own injected collision and journal only after asserting safety; that cleanup **does not** add a user-facing repair action.

All existing M14–M23 tests must still pass, along with WinForms smoke tests and preview ZIP packaging, before the milestone is marked complete.

## Known boundaries and remaining work

- These simulations are deterministic checkpoints, **not** proof of crash durability or resistance to a real concurrent path-swap, symlink or hostile writer between validation and deletion/move.
- Interrupted journal replacement during `File.Replace`, power loss during filesystem metadata updates and tamperproof transaction ownership require more design.
- A truncated stage-owner marker is not proof of ownership; an untrusted stage is preserved.
- Full-client content sources, distribution rights and independently authenticated base hashes remain unresolved; real-client downloads and installs stay disabled.
- Do not upload MPQs, client executables, private inventory JSON or any player account settings.
- The feature remains on an unmerged draft PR. No local client testing or 17+ GB hash scan is required.

## Next engineering task

Build a strictly **read-only, privacy-safe synthetic transaction status report** covering valid/invalid destination journals and stage sidecars, then design explicit manual recovery choices. Validate concurrent path changes and journal replacement residues in more realistic isolated tests before considering any production installation design.

**Windows CI:** pending.
