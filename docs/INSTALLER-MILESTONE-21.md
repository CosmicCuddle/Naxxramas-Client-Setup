# Milestone 21 — Resumable rollback of disposable copy fixtures

**Status: Windows CI passed** ([run 38061485117](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38061485117), tested commit `e5e4c7a14fb1120eed78f06fb99f6c8bea313843`). This only operates on the tiny, explicitly marked **synthetic M15 test fixtures**, never real WoW installations.

## What was changed

M15 previously removed verified dummy files during rollback, then deleted the journal. If the process died halfway through, the journal still reported `copied` while some files were missing, preventing another confirmed rollback.

M21 adds a durable `rolling_back` state and an intentionally injected interruption test:

1. Read the exact synthetic manifest and copy journal, require both M15 markers and separate paths outside the repository.
2. Validate every present expected file against size and SHA-256, and ensure every journal file agrees with the manifest. A normal `copied` journal still requires all files present.
3. Check **root, Data and Data/enUS immediate entries**, refusing unknown files, **unknown empty directories** and symlinks/junctions instead of trusting only recursive file enumeration.
4. Refuse unexplained `.rollback-writing` or `.rollback-previous` sidecar files from an interrupted atomic journal transition; preserve them for review.
5. Before deleting anything, replace the existing journal with state `rolling_back` using a writing file and `File.Replace` backup; refuse if transition fails.
6. For each remaining expected test file: revalidate its bytes immediately before deletion. When the run is deliberately interrupted after a chosen number of deletions, keep the journal in `rolling_back` state.
7. A second **explicitly confirmed** rollback accepts missing files only when state is `rolling_back` (or original `applying`), checks all remaining files, and finishes. It never deletes altered files or unknown contents.

The optional `-SimulateRollbackInterruptionAfter N` test switch is valid **only** with `-Action Rollback -ConfirmDisposableFixture`. It simulates an interruption in Windows tests; it does not kill a process. It is not exposed to the player launcher.

M20's **read-only** `Inspect-Fixture-Recovery.ps1` recognises `rolling_back` and reports counts while allowing expected missing entries, without changing anything.

## Safety and limitations

- Only eight allowlisted dummy filenames; each file at most 256 KiB and a total cap of 1 MiB, with exact synthetic source and destination markers.
- No real WoW game files, actual MPQs, ownership changes, unlisted folders, downloads or overwrites. The fresh-client source gate remains **disabled**.
- Both source and destination must be outside the repository, and not overlap.
- Rollback removes only verified owned dummy test files. Unknown files, directories, changed expected files and unknown journal sidecars **block removal**. A marker remains after successful rollback.
- There is **no automatic or unattended rollback**. Each attempt still requires `-ConfirmDisposableFixture`.
- Windows SHA-256 validation is a pre-delete check, not a filesystem transaction; concurrent hostile modification or path changes during deletion remain a potential race.
- If power fails during the journal's `File.Replace` transition, remaining sidecars are preserved and manual review is required. The feature does not yet reconcile these automatically.
- Orphan staging folders **outside** the destination remain outside this tool's scope. Disk exhaustion and concurrent-change simulations need additional hardening.
- Even a fully passing test suite does **not** authorise real-client installation or redistribution of copyrighted game archives.

## Windows validation

Expanded `tests/Test-Client-Copy-Fixture.ps1` exercises unknown empty directory rejection, leftover journal sidecars, interruption after two deletions, persisted `rolling_back`, refusal to delete a modified remaining file, repair of that synthetic fixture, then successful confirmed resume. Existing copy-failure tests continue to run. Expanded M20 recovery tests accept partial `rolling_back` journals without considering copied-but-incomplete journals safe.

**CI result:** [run 38061485117](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38061485117) completed successfully. Synthetic rollback interruption/resume, unknown-folder/sidecar refusal, M20 recovery-state tests, earlier fixture safety tests, GUI smoke tests and preview ZIP packaging all passed. No real client was used.

## Next milestone

Build an independent **read-only orphan stage directory inspector** with positive synthetic ownership evidence, then design explicitly authorised cleanup that never deletes unexplained files. Add disk-space and concurrent-file mutation fault injection on tiny dummy files. Keep M15 write locks and immutable patch/source policies.
