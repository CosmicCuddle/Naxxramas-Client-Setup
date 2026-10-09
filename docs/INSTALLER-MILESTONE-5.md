# Milestone 5 — Direct verified ZIP staging and staging-failure recovery

**Status: development branch only. Do NOT use this alpha installer on a live WoW client.**

The local installer prototype now supports an independent verified N Addon Suite v2.0.0 ZIP as its **direct source of addon files**.

## What changed

The new `-AddonSuiteArchivePath` parameter is an alternative to `-AddonSuitePath`. Using both is rejected.

When given the ZIP, the prototype verifies the 26,762,217-byte GitHub Release v2.0.0 asset against its pinned SHA-256 reference. It reads ZIP entries in memory, rejects invalid or duplicate paths, oversized/suspicious archive data, symlink entries and missing TOC files, and only selects:

- NCore (always when selecting the suite)
- IndividualProgressionAddon (optional)
- DungeonJournal (optional)
- MultiBot (optional)
- NaxxLootLottery (optional)

N Talent Calculator is **not** part of v2.0.0.

Selected files are **streamed directly from the verified open ZIP** into the installer's temporary staging area. They receive individual SHA-256 checksums and enter the same rollback journal as the selected patches and realmlist. The ZIP is kept open while these files are processed rather than trusting a separately extracted folder.

No MPQs, full WoW client files or addon ZIP assets are committed to this repository.

## Read-only preview command

The following is an illustrative command only, for a separate test client with its own legal MPQ source:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Setup-Prototype.ps1" -Action Plan -ClientPath "D:\Test-WoW" -PatchSourcePath "D:\LocalPatches" -AddonSuiteArchivePath "D:\Downloads\N-Addon-Collection-v2.0.0.zip" -Addons DungeonJournal,MultiBot
~~~

Do **not** use the write switches on your working client. Install, rollback and recovery remain blocked unless the target is an explicitly marked disposable test fixture.

The older extracted-folder test input still exists solely to maintain backwards-compatible fixture tests. For eventual production installation, **the direct ZIP path is preferred**, and the folder-only path must be removed or strictly authenticated.

## Failure safety

Before creating the active transaction journal, the installer stages and checks all incoming data and backs up all to-be-overwritten files.

A new fixture-only `-SimulateStagingFailureAfter` switch imitates an interrupted staging or access-denied event. The script discards only its new temporary session directory and never starts writing game destination files. The test suite verifies no active installation remains and existing files are unmodified.

This does not fully simulate Windows ACL denial, antivirus locking, filesystem races, physical drive failure or power loss during journal creation. Those conditions still require dedicated testing.

## Remaining work before public use

1. Manual verification of the real official addon ZIP (synthetic tests are currently used).
2. Fault handling for failed journal writes and incomplete transactions.
3. Hardening file-path and permission checks for Windows junctions, case-insensitivity and Windows protected folders.
4. Source and licensing review of the MPQs, plus approval of permitted distribution channels.
5. An accessible Windows interface showing current state, optional selections, planned file changes, progress and an explicit undo path.

No real client writes or downloads have been enabled.
