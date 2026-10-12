# N Addon Suite — Local TOC evidence and future reversible upgrade gate

**Status:** design + read-only metadata review, 12 October 2026. **Not permission to install, download, copy, back up, delete, restore, migrate, repair or publish any addon.**

## Current observable evidence

The wizard checks the seven explicitly listed addon roots (`NCore`, `IndividualProgressionAddon`, `DungeonJournal`, `MultiBot`, `NaxxLootLottery`, and legacy `NClassicBattlegrounds` and `ServerDungeonJournal`). It does not traverse arbitrary player addons, inspect `WTF`, execute Lua, or search embedded XML/Lua files.

A regular folder may contain one immediate, same-named `FolderName.toc`. The read-only inspector observes this text with a **64 KiB limit**, a read-only file handle, and a rejection for linked TOCs, extra same-name case variants, directories masquerading as TOCs, malformed or repeated `## Version`/`## Interface` headers and inaccessible files. It reports **only** syntactically bounded Version and Interface declarations. The client target is interface **30300**; a different declared interface is distinguishable, but not proof of incompatibility or a reason to overwrite.

`toc_metadata_state` distinguishes `not_present`, `folder_unsafe_not_inspected`, `toc_missing`, `toc_ambiguous`, `toc_linked_unsafe`, `toc_not_a_file`, `toc_too_large`, `toc_read_error`, `toc_missing_or_conflicting_fields`, `toc_claims_supported_interface_unverified` and `toc_claims_other_interface_unverified`. Where safe, `toc_declared_version` and `toc_declared_interface` expose **claims**, never an authenticated installed version.

The historical `detected_version=unknown_not_inspected` and `version_or_provenance_verified=false` remain intentionally conservative. `toc_claim_trusted=false` for every result. **Do not silently reinterpret a matching `5.2.0` claim or Interface 30300 as proof of N Addon Suite v2.0.0.** The published suite version is not the same concept as the underlying versions of its component addons. A player can change TOC text while leaving all Lua files modified, missing or malicious. TOC observations are not an atomic snapshot; a linked object or rename could race the checks. No hashes of complete installed addon trees or trusted upstream per-file digests are compared.

## Design contract for a future upgrade (not implemented)

1. **Identity and source gate.** Independently reauthenticate approved release bytes against an immutable, reviewed manifest that lists each complete target path, SHA-256, byte length, exact lettercase and file type. Resolve distribution rights and signed-source policy. The 796-member CRC verification of the source v2 ZIP is not proof of safety or redistribution rights.
2. **Complete preflight.** Require a separate, closed WoW client and opt-in for exact selected addon folders. Inspect all immediate and nested entries with reparse-point and hardlink protection; reject collisions, aliases, unsafe names, unknown files, concurrent changes, disabled permissions and stale target/source identity. Do not use TOC metadata as a permission gate. Never assume `NCore` preferences imply a partial ZIP extraction: all five folders are in the release.
3. **Preserve every original.** Before any candidate overwrite, capture the **complete byte-for-byte tree of every existing affected addon folder**, not just its named TOC or known scripts. Capture **all existing WTF files for all accounts, realms, characters and profiles**; known SavedVariables names are only a discovery aid, not a safe backup allowlist. Preserve metadata needed for a faithful restore. Affected folders and private WTF data must not be uploaded into Actions or public reports.
4. **Verified, independently held backups.** A future operator must use a separately approved backup destination outside the client, create a fresh transaction-specific directory without overwriting an existing backup, record per-file length/hash, independently compare exact copied bytes, enumerate all original paths, and address names, case, link identity, ACLs, space, storage power-loss semantics, interrupted partial copies and atomic checkpoint publication. A matching read-only copy today is **not** proof of a recoverable durable snapshot.
5. **Frozen plan and consent.** A review must specify exact folder paths, original and proposed contents, account-wide settings preservation scope, backup target, known legacy conflicts and source fingerprint. Require real authenticated, single-use consent tied to fresh client/source/backup identities and a replay-resistant protected journal authority. A preview checkbox, TOC match or synthetic HMAC receipt is never consent.
6. **Staged, journaled replacement.** Only if separately approved, stage verified files under safe destination filesystem semantics. Durably journal each checkpoint *before* modifying originals, and never touch unselected, unknown or third-party addons. `NClassicBattlegrounds` and `ServerDungeonJournal` must always receive manual decisions, not automatic deletion or migration.
7. **Conflict-aware recovery.** An interrupted session is a blocker until an authenticated checkpoint and independently verified complete backup are available. Before any hypothetical rollback, re-check destination bytes against the transaction's known writes. If a player or another updater changed anything, refuse automatic restore and retain both copies for manual resolution. Never overwrite newer SavedVariables or delete unknown files. A successful restore rehearsal on disposable fixtures is required before any real operations are authorised.

## Required acceptance tests before considering a writer

| Fixture (disposable clients only) | Minimum required decision |
| --- | --- |
| No existing addons; source archive correct | Preview addition, but deny all writes until approved |
| TOC says matching version, installed Lua altered | Treat as **unknown modified**, never trusted current |
| Missing, conflicting, oversized, linked or locked TOC | Unknown / unsafe; preserve |
| Unknown extra files within a known addon folder | Preserve full original; block assumed clean replacement |
| Both legacy duplicate folders present | Human migration plan only; no automatic removal |
| Multiple accounts, realms, character SavedVariables trees | Prove whole-tree preservation, not just named variables |
| Partial backup, corrupt backup, full disk, different volume, hardlink alias | Refuse transaction/recovery; retain originals |
| Concurrent client/game write during read, stage or recovery | Invalidate earlier review; refuse automatic action |
| Interrupted staged replacement at every checkpoint | Unambiguous, separately authenticated recovery state required |
| Modified player file or WTF since transaction | No automatic overwrite during rollback |
| Copied client, lost key, moved backup, old journal replay | Fail closed and require supported manual recovery |

## Accessibility and manual QA still required

The current WinForms summary reports seven short addon metadata statuses in the read-only results, while File Details shows scrollable concerns and notes. Physical **100%, 125%, 150%, 200% DPI**, High Contrast, keyboard-only operation and real screen-reader navigation must be performed on a disposable synthetic client. Check non-overlapping controls, long text, focus order, readable status updates and that “claimed version” is never announced as verified. Record evidence without player folder paths or `WTF` contents.

**Decision:** next work may continue improving observation and human review. Every install, download, file mutation, backup creation, automatic recovery and public release remains disabled pending separately documented approval.

## Synthetic complete-original scope rehearsal (Milestone 5 follow-up)

A **developer-only, fixture-gated** read-only tool, `tools/review_synthetic_addon_original_scope.py`, enumerates filesystem **metadata only** beneath the exact five suite addon directories, both named legacy addon directories and **all** contents of a disposable fake client's `WTF` tree. It does not read private configuration contents, execute addon Lua, hash files, enumerate arbitrary third-party addon contents, or emit account/realm/character/folder filenames.

The tool requires an explicit `--synthetic-fixture-client` argument and an exact `.naxx-synthetic-only` marker. **The marker is not cryptographic authentication; this is not a tool to run against a real client.** Its output includes only safe hardcoded scope labels, observed counts/sizes and fixed error categories. It rejects linked or junction paths, hardlinked files, invalid filesystem types, case-colliding entries and overly deep/large trees. Any incomplete observation is `unsafe_preserve_manual_review`; even a fully observed scope is `present_unverified_metadata`, not a complete or trusted backup manifest. Missing `WTF` is reported without creating it.

Windows and Linux disposable tests simulate two accounts, three realms, three characters, extra unknown character SavedVariables, a custom file within a known addon, a standalone legacy addon, and unrelated third-party addon files. They check unchanged fixture bytes, link/hardlink fail-closed behaviour, refusal without the fake-client marker, budget limits and privacy-safe report fields. This tests a **scope-planning assumption**, not verified copied originals, crash durability, live game compatibility, consent, installation or recoverability.

The next meaningful design gate is a separately approved and **still synthetic-only** detailed original-to-copy integrity and restore-conflict model. It must preserve complete original data, distinguish original and player-modified bytes, and refuse any ambiguous/partial checkpoint. Future real-client scanning and all file writes remain separately blocked.


## Synthetic addon original-to-copy and recovery-conflict comparison (PR pending)

The next separate developer-only reviewer, `tools/review_synthetic_addon_recovery.py`, accepts **only a disposable fake fixture root** with an explicit `.naxx-recovery-synthetic-only` marker and four pre-existing synthetic directories: `original`, `backup`, `claimed_after`, and `current`. The Python reviewer itself is **read only**. Only its unit-test setup creates and changes fake fixture bytes. Neither this tool nor its tests appear in the strict player ZIP allowlist. The marker is an accidental-use guard, not proof of ownership or source authenticity.

For exactly five published suite addon roots, two legacy roots and the **entire** `WTF` tree (all accounts, realms, characters and unknown files), the inspector reads bounded synthetic file bytes in SHA-256 streams, compares exact relative file *and empty-directory* names, file lengths and digests, and takes two sequential observations. It refuses linked/reparse entries, linked files, case-colliding directory names, hardlinked files, nonstandard objects, unsafe folder spelling, excessive scan depth/count/size and file changes during each observed read. A changing observation between passes is flagged. These are best-effort read-only observations and **not atomic or race-resistant Windows production file handles**.

- `matching_observed_bytes_not_backup_proof`: fake backup was observed to contain the same scoped original bytes and directory layout; not independently held, authenticated, durable or known to be recoverable.
- `missing_or_extra_entries_preserve` / `changed_bytes_preserve`: complete copy mismatch; preserve everything and investigate rather than assuming it is usable.
- `already_original_preserve`: synthetic current tree matches the original and needs no hypothetical restore.
- `matches_untrusted_after_claim_not_recovery_permission`: a non-settings addon happens to match a caller-controlled after-image; this is **not** an approved restore.
- `player_or_unknown_changes_preserve`: current addon differs from both original and claimed after-image; no automatic overwriting.
- `settings_changed_preserve_manual_review`: any synthetic `WTF` difference from original is a manual conflict, **even when current matches a claimed after-image**.
- `unsafe_manual_review`: a path/identity/read error or between-pass change prevents reliable scope comparison. Partial scope counts are not passed off as complete.

The JSON intentionally returns only fixed known scope labels, aggregate counts and safe classification names, not private account/realm/character filenames, file data, or hashes. All approvals stay false: `backup_created`, `original_backup_authenticated_or_durable`, `journal_authenticity_verified`, `client_updated`, `restore_or_delete_performed`, `automatic_recovery_authorised`, `installation_or_backup_authorised`, and `public_release_authorised`.

Run the **CI-only synthetic regression**, not on a player folder: `python -m unittest discover -s tests -p test_synthetic_addon_recovery.py -v`. Cross-platform Windows and Linux Python 3.12 tests construct throwaway trees covering matching bytes, missing/extra and corrupted copies, untouched unknown addon files, full two-account/three-character `WTF` scopes, changed player files, matching untrusted after-images, unsafe symlinks/hardlinks, missing markers and injected between-pass changes. No protected journal, genuine one-use consent, backup writer, restore implementation, disk crash consistency, actual client scan, human physical DPI/screen reader acceptance or public release is established.

**Next after this fixture:** a separate synthetic journal/checkpoint-state classifier (complete vs incomplete/forged/stale sessions) and proof of refusal at every interrupted stage, then manual real Windows accessibility checks. Installation and restoration remain prohibited.

## Synthetic addon journal cutpoints and coherent replay (Milestone 5)

`tools/review_synthetic_addon_journal.py` is a **developer-only, read-only fixture inspector**. It requires a disposable folder containing **both** exact synthetic markers (`.naxx-recovery-synthetic-only` and `.naxx-synthetic-journal-only`), pre-existing `original`, `backup`, `claimed_after`, `current` fake snapshot trees and two tiny caller-authored local files, `journal.json` and `latest-state.json`. The markers protect against accidents, **not** against an adversary and **not** as identity authentication. This tool is never included in the player scripts-only distribution and must not be pointed at a real WoW folder.

### Synthetic event model (never a production journal)

`journal.json` is a strict object with `schema_version=1`, a `synthetic-...` transaction ID, a caller-controlled 64-character lowercase `scope_digest` and nonempty `events`. Each event is exactly `[sequence, phase, previous_event_sha256, event_sha256]`. An **unkeyed** domain-separated SHA-256 over the claimed transaction, scope, sequence, phase and previous hash checks only local consistency. Sequences start at one, never skip or repeat; phase transitions must follow the finite cutpoint chain below. `latest-state.json` independently *claims* the last event sequence, hash, transaction/scope and one of `claimed_current`, `claimed_stale`, `claimed_revoked`; this second local file provides **no independently trusted latest-state authority**.

The staged sequence is `plan_frozen → backup_started → backup_copied → backup_checked → stage_started → stage_checked → replace_started → replace_finished → postcheck_finished → recovery_requested → recovery_started → recovery_checked → closed`. A hypothetical recovery request may also follow `replace_started` or `replace_finished`, and `closed` may follow `postcheck_finished`; all unlisted transitions are rejected. Every cutpoint is classified, but **none produces any command or consent to act**. Partial backup, unverified copies, partial stage, unconfirmed replacement and interrupted recovery require manual review regardless of a locally consistent hash chain.

The reviewer couples these untrusted claims with the existing **synthetic-only, full-file original/backup/after/current byte-integrity checker**, which already includes all five suite addon roots, two legacy roots, and **every fake WTF account/realm/character settings file**. Backup mismatches, unsafe trees and current player/character settings changes are distinct preservation blockers. It rereads each small claim file before and after the content scan and rejects observed changes; this is **not** an atomic snapshot. The output has fixed phase labels, count totals and blocker codes, never the claimed transaction ID, scope hash, original hashes, account/character names, or source file contents.

The new unit tests build only isolated fake trees and cover all thirteen phase cutpoints, missing/truncated/duplicate/oversized JSON, sequence gaps, wrong hash, illegal transitions, stale/revoked/foreign/latest-pointer claims, missing/tampered markers, hardlinks and symlinks, changes during the read, corrupted backup, character-settings changes, and a **deliberately successful coherent replay** of an older journal *plus* its old latest-state record. Such replay is indistinguishable from genuine latest state using caller-controlled files alone: `coherent_replay_independently_detectable=false` even when the superficial claim is self-consistent. Any real future journal needs a **separately controlled monotonic authority**, authenticated single-use consent, durable checkpoints and independently verified original backups.

**All production permissions remain false without exception:** no real owner authentication, real client writes, download, install, backup copying, automatic resume, rollback, deletion, file restoration or public release. This is test planning for fail-closed behavior, not implementation of a transaction manager.


## Independent authority and power-loss safety — SYNTHETIC gate only

The next milestone adds a separate **developer-only, read-only** classifier for locally claimed authority and crash states, with disposable fake addon/WTF trees and no player-side changes. Detailed contract, false-trust warnings, synthetic crash windows, original preservation and requirements for a genuine independently protected monotonic authority are in [ADDON-AUTHORITY-AND-CRASH-GATES.md](ADDON-AUTHORITY-AND-CRASH-GATES.md). An unkeyed journal hash, claimed owner/epoch, an extra local file and even a fully matching fake backup remain **unauthenticated**, replayable claims; no automatic file action or public release is authorised.
