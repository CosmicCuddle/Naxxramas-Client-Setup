# Milestone 15 — Synthetic client copy, integrity verification and rollback

**Status: development/test-fixtures only. Never run this against your actual WoW installation.**

## Why this milestone exists

Milestone 14 introduced the read-only, privacy-safe `game-files-*.json` file inventory. The next risk is the *actual copy stage*: copying large files, ensuring integrity, refusing accidental overwrites and being able to undo changes. Before trusting that on a real client, Milestone 15 uses **tiny synthetic files** with an explicit write lock.

This milestone implements `tools/Test-Client-Copy-Fixture.ps1`, a separate command-line PowerShell 5.1 prototype. It is intentionally **not** in the player launcher or installer UI.

## Security gates

- Requires exactly two markers: `.naxx-copy-test-source` with `NAXX_SYNTHETIC_COPY_SOURCE_V1` and `.naxx-copy-test-destination` with `NAXX_SYNTHETIC_COPY_DESTINATION_V1`.
- Requires manifest `kind=naxx_synthetic_copy_fixture`, `synthetic_fixture=true` and `complete_game_client=false`. A regular real-client file inventory is **rejected**.
- Accepts only eight exact fixture names: `Wow.exe`, `Data/common.mpq`, `Data/enUS/locale-enUS.mpq`, V/Z/U and mutually exclusive J/C. The manifest must include Wow.exe and V/Z.
- Hard limits: **3–8 entries**, **256 KiB per file**, **1 MiB total**. No real 3.3.5a client MPQs fit these limits.
- Source and destination cannot be identical, nested, linked/junction paths or inside the launcher repository.
- Destination must contain **only its test marker** before copying. No existing files can be overwritten.
- Explicit `-ConfirmDisposableFixture` is required to copy or roll back. `Plan` reads and hashes only.
- Files are staged in a separate sibling folder, hashed again, promoted only after rechecking destination, and verified after writing.
- A tracked JSON journal records owned files and hashes. Rollback refuses modified files or unexpected destination files and only deletes owned verified dummy files. Interrupted `applying` journals can be inspected/rolled back with hash checks.
- Simulated mid-copy failure automatically rolls back every just-promoted file whose checksum still matches.
- PowerShell Windows tests use only tiny synthetic files, with no WoW game assets or uploaded personal manifests.

## Commands — developers only

Example, assuming you have generated your *own artificial test files and test manifest*:

~~~powershell
.\tools\Test-Client-Copy-Fixture.ps1 -SourcePath "C:\Fixtures\Source" -DestinationPath "C:\Fixtures\EmptyTarget" -ManifestPath "C:\Fixtures\test.json" -Action Plan

.\tools\Test-Client-Copy-Fixture.ps1 -SourcePath "C:\Fixtures\Source" -DestinationPath "C:\Fixtures\EmptyTarget" -ManifestPath "C:\Fixtures\test.json" -Action Copy -ConfirmDisposableFixture

.\tools\Test-Client-Copy-Fixture.ps1 -SourcePath "C:\Fixtures\Source" -DestinationPath "C:\Fixtures\EmptyTarget" -ManifestPath "C:\Fixtures\test.json" -Action Rollback -ConfirmDisposableFixture
~~~

**Do not create fixture markers inside a real game directory.** Use `tests/Test-Client-Copy-Fixture.ps1` for repeatable fixtures instead.

## What's still missing

Passing a dummy-file test **does not make full-client installation ready**. Before that, development still needs:

1. The owner's local `game-files-*.json` report from a backup development copy, then a review of missing/unknown files and required base-client components.
2. Coverage and an authorised source for an actual complete base client; no public full-game redistribution without the appropriate rights.
3. Full-copy support for many-gigabyte files, disk-space constraints, resumable verified staging, crash/restart recovery, trusted ownership metadata, rollback and uninstall.
4. Safe Naxxramas patch/addon integration on a **separate disposable development client**, never directly against the owner's only working original.

**Milestone 15 changes no client files, and no public game download is enabled.**
