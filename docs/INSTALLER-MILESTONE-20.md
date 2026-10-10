# Milestone 20 — Synthetic interruption-recovery readiness audit

**Status:** **Windows CI passed** — [run 38060443793](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38060443793) at tested implementation commit `22ccd6a3558ed202bc1676eb63abfc6f7a7cde53`. All tests, preview ZIP packaging and prior safety fixtures passed. **Not** a real WoW recovery tool or installer.

## Purpose

M15 already has an explicit journal, simulated ordinary failures, verified source copies, a tiny-file size cap and an owner-confirmed Rollback action. A hard interruption can instead leave an "applying" journal with **some copied files missing**. Before a later process attempts any rollback, it must be able to check what remains without risking unrecognised files or personal directories.

## Added utility (no writes)

- `tools/Inspect-Fixture-Recovery.ps1`, used only by developers and Windows synthetic tests.
- Requires exact M15 source and destination marker files, a `naxx_synthetic_copy_fixture` JSON manifest and the existing `.naxx-fixture-copy-journal.json`.
- Requires source/destination to be distinct folders outside the repository, with no symbolic links/junctions.
- Manifest paths remain the **same eight-item maximum allowlist** used by M15, including required dummy `Wow.exe`, V and Z, tiny files (at most 256 KiB each), maximum 1 MiB in total.
- Journal source, destination, file paths, sizes and hashes must exactly agree with the local synthetic manifest.
- Checks only explicitly expected fixture folder levels; unknown files and **unknown empty folders** block readiness, and unknown names are not printed.
- For `applying`, missing expected files are acceptable after an interruption; any present expected file must match its expected length and SHA-256.
- For `copied`, every expected file must be present and hash-matched.
- **READY_FOR_MANUAL_ROLLBACK** is not an action or promise of full recovery; it means only that the examined snapshot meets the conservative conditions to consider a separate, explicitly confirmed M15 fixture-only Rollback.
- Refuses forged journals, modified files, unexpected destination entries, missing markers and missing journals.
- Does **not** enumerate or delete orphan stage folders outside destination, copy files, perform rollback, install or download.
- Uses fixed, **synthetic-only** filenames and local inspection. Does not access WoW folders, account data, SavedVariables, addon settings or unrelated files.

## Windows dummy-fixture validation

A new `tests/Test-Fixture-Recovery.ps1` builds a disposable marked client fake and tests empty applying, partial applying, falsely completed, modified copy, unknown file, unknown empty folder, forged journal, missing journal and missing marker. The test must confirm source bytes remain unchanged and **the auditor creates no files**.

**Known remaining gaps:** M15 rollback is not atomic across multiple files; interruption *during* rollback, interrupted journal replacement, orphan staging cleanup, disk exhaustion and concurrent changes remain to be handled in separate strictly synthetic milestones. The new auditor is deliberately read-only and makes none of those problems disappear.

## Next engineering steps

Add a dedicated safe manual cleanup/recovery process for marked fixture stages, with durable per-file journal states and interruption injection, and test concurrent filesystem modification/disk-space errors. Do not lift M15's marker requirements or 1 MiB synthetic-only cap until separately authorised production security design and rights/integrity source verification.

No action or repeat scan is required from the owner. Their backed-up working WoW client is not involved.
