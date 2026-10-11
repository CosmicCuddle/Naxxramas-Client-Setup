# Milestone 3 — Read-only V/Z crash-boundary fixtures

**Status:** synthetic classifier and Windows PowerShell tests only. It does **not** install, stage, back up, restore, remove or inspect any actual game file. It does not create a real journal or use trusted signing keys.

## Purpose

A WoW 3.3.5a Naxxramas setup needs BOTH mandatory core patches, V and Z, to match the intended patchset. A partial update can leave the client mismatched if power fails between replacing these files. This prototype defines how **untrusted, simulated** observations should be classified and verifies that no outcome triggers automatic file writes, rollback or resume.

## Developer-only command

On Windows PowerShell 5.1:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-CrashFixture.ps1"`

The test suite creates small JSON fixture files in a disposable temporary folder. It does not need or modify an existing WoW client.

The read-only inspector itself accepts a developer-supplied `-FixturePath` and optional `-Json`:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Review-Naxxramas-CrashFixture.ps1" -FixturePath "C:\TemporarySyntheticFixture\crash.json" -Json`

No other files are read, created, changed or removed by the inspector.

## Wire format (synthetic schema v1)

The input is a fixed seven-element positional JSON array; object keys are intentionally not accepted:

`[1, "fixture-session-123", "patchset-0001", "session_checkpoint", "anchor_claim", ["Data/patch-V.mpq", "action", "backup", "destination", "file_checkpoint"], ["Data/patch-Z.mpq", "action", "backup", "destination", "file_checkpoint"]]`

The two core file records must appear **exactly V then Z**. No arbitrary paths, extra operations, wildcards, personal addon paths or unknown states are permitted.

- **Actions:** `install` (new file, no original backup) or `replace_after_backup`.
- **Backup claims:** `not_required` (only when installing new), `missing`, `verified`, `corrupt`.
- **Destination claims:** `absent`, `original`, `installed`, `modified`, `missing`, `unknown`.
- **File checkpoints:** `planned`, `staged`, `backup_started`, `backup_verified`, `intent_durable`, `write_started`, `write_verified`, `committed`.
- **Session checkpoints:** `planned`, `staged`, `backup_started`, `backups_verified`, `intent_durable`, `write_started`, `files_verified`, `finalising`, `completed`, `rollback_requested`.
- **External anchor CLAIM:** `matches`, `missing`, `stale`, `ahead`, `unverified`.

**These labels are only fabricated fixture claims**, not independent file measurements or evidence that any backup, journal flush, signature or Windows transaction actually happened. The label `intent_durable` is an intended future checkpoint name, **not proof that a journal is durable**.

## Crash-cutpoint classifications

| Synthetic case | Expected behaviour |
| --- | --- |
| Before backup, during stage, or during backup copy | Incomplete: require manual review |
| Corrupted claimed original backup | Preserve and report original-backup corruption |
| Backups verified but no file committed | Incomplete: require manual review |
| Intent recorded before first replacement | Incomplete: require manual review |
| V appears installed, but V checkpoint still says write started | Ambiguous commit: require manual review |
| V installed and Z still original | Partial core: require manual review |
| Installed bytes with no intent checkpoint | Suspicious write ordering: require manual review |
| Both files appear installed, but per-file commit is not complete | Incomplete: require manual review |
| Session claims completed, but V or Z is absent | Report missing core file |
| Destination changed unexpectedly or contains unknown bytes | Preserve player contents; manual review |
| Original backup missing when replacement may already have happened | Unavailable backup: manual review |
| Latest-state anchor claim missing/stale/ahead/unverified | Unverified authority: manual review |
| Both V/Z appear committed and all fixture labels match | `fixture_fields_consistent_NOT_trusted`, **not** installation success |

An invalid schema or unknown file path fails without producing a status. All reported outcomes set:

- `allow_file_writes = false`
- `allow_automatic_resume = false`
- `authorises_rollback = false`

The JSON report does not include local fixture paths or session identifiers.

## Why a matching fixture is not trustworthy

1. The fixture is entirely caller-controlled. It does not examine the real destination or backup filesystem, compute MPQ fingerprints, authenticate an approval, or verify a signed journal.
2. A claimed anchor match does **not** establish an independent monotonic latest state. Replay of all journal/registration/anchor inputs remains possible.
3. There is no tested write ordering, flush guarantee or atomic file-replacement engine. The suite tests a **decision table**, not actual crash survival.
4. A genuine partially updated V/Z pair cannot be rolled back from these status labels; a later writer will require exact original byte backups, ownership and conflict tests, explicit consent, and a separate safety review.
5. The logic covers V and Z only; J, U and `Data/enUS/realmlist.wtf` are managed by existing allowlist policy but are **not** simulated as crash operations by this particular fixture.
6. No WoW archive is licensed for distribution merely by inclusion in the manifest.

## Separate design decisions before any file-writing experiment

- Approve a **versioned, independently authenticated** installation registration tied to the selected client and explicit user consent.
- Decide a protected latest-state anchor design and the recovery policy for missing keys, migrated accounts or replayed private files. **DPAPI and an ordinary signed JSON file are not proof of non-rollbackable state**.
- Design concrete, reviewable checkpoint sequencing: staging, verified exact original backups, *intent before destination replacement*, same-volume atomic operations where supported, verification, then final journal/anchor commit.
- Define how the system handles crash ambiguity between final data replacement and journal/anchor persistence. Never silently proceed or delete a player's edits.
- Validate filesystem APIs, directory handles, mount points, process locks, changing free space and failure recovery **on disposable fixtures**, with a separate approval before any write-capable experiment.
- Retain a documented uninstall and manual restore route that never deletes unknown files.

See [Journal Durability](JOURNAL-DURABILITY.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Registration Fixture Review](REGISTRATION-FIXTURE-REVIEW.md), [Transaction Design](TRANSACTION-DESIGN.md) and [Project Handover](PROJECT-HANDOVER.md).

**A result of “fields consistent” is never permission to install, resume or roll back.**
