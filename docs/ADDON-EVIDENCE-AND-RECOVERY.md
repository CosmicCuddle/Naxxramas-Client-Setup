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
