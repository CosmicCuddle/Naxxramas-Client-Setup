# Naxxramas Client Setup — Development Roadmap

**Last reviewed:** 11 October 2026  
**Current baseline:** `main`, `patchset-0001`  
**Overall status:** read-only preflight and installer-plan prototypes. **No installer, updater, uninstaller or redistributable game package is ready.**

This is the working plan for development, handovers and release checks. Update this file **with every meaningful project change**: mark completed work, record what was verified, explain what remains, and nominate the next task. Detailed ongoing context is in [PROJECT-HANDOVER.md](PROJECT-HANDOVER.md).

## Project outcome

Give people with an independently obtained, legitimate WoW **3.3.5a / build 12340 / enUS** client an understandable, backup-first way to prepare that client for Naxxramas. Do **not** package an 18.6 GB game installation, proprietary Blizzard archives, private player data, or any third-party assets without the necessary distribution rights.

Keep the installer independent of the AzerothCore server, individual-progression module, playerbots, and existing addon repositories.

## Non-negotiable requirements

1. **Mandatory core:** `Data/patch-V.mpq` and `Data/patch-Z.mpq` are required. A complete Naxxramas setup must never omit, disable, remove or silently replace either.
2. **Optional visuals:** `Data/Patch-J.mpq` is optional login-screen visuals and `Data/Patch-U.mpq` is optional loading-screen visuals. Offer independent choices, not a requirement.
3. **J/U overlap:** The two patches contain different versions of two loading screens. Warn users; do not merge or claim joint compatibility without testing neither/J/U/both in game.
4. **Source integrity:** Compare patch SHA-256 and byte size to the currently reviewed version. Unrecognised files must not be silently overwritten or marked trusted.
5. **Changes need backups:** Save existing bytes before overwriting any permitted destination file. Every successful write must have an audit trail and a reversible outcome.
6. **Safe boundaries:** Reject source/destination collisions, unsafe traversal, links/junctions and operations on the owner's sole working client. Use an explicit, separate test/client destination.
7. **No surprises:** Present a complete proposed change list and require confirmation before a write. Never silently clean `WTF`, `Cache`, `Screenshots`, `Logs`, personal addons or unknown files.
8. **Approved delivery only:** No public patch/assets/third-party redistribution before origin and licensing review. A checksum alone does not grant rights.
9. **Version history stays immutable:** A new patch revision creates `config/patch-versions/patchset-XXXX.json`; do not rewrite historic approved records.
10. **Accessibility:** Instructions should be short, explicit, readable, and usable through drag-and-drop where practical. Keep technical details in expandable/advanced documentation.

## Completed foundation

- [x] Establish the GitHub project and protective file exclusions.
- [x] Review owner-supplied client inventory; record standard archives, 174 addon folders and items not safe to package.
- [x] Record V/Z mandatory and J/U optional roles.
- [x] Inspect J and U MPQ contents and document the overlapping textures.
- [x] Pin owner-supplied V/Z and inspected J/U SHA-256 values to `patchset-0001`.
- [x] Add read-only client inventory, core-patch hash and patch-update proposal scripts.
- [x] Add read-only client preflight for WoW structure, reported executable build, required/optional patches, addon layout and realmlist comparison.
- [x] Record the owner-provided realmlist address separately in `config/realm.json` and supply a manual `realmlist.wtf` template.
- [x] Write standalone project roadmap and handover notes for chat continuity.
- [x] Add synthetic PowerShell fixture tests and a Windows CI workflow for the new planner.
- [x] Confirm planner and legacy preflight fixture suites pass on GitHub Windows PowerShell 5.1 CI (10 October 2026; PRs #2 and #3).

## Milestone 2 — Installer planning, still READ ONLY

**Goal:** produce a precise plan of actions without changing the player's client.

- [x] Define JSON preview with patchset, options, expected/current hashes, actions, warnings and blockers.
- [x] Implement `tools/Plan-Naxxramas-Install.ps1` and drag-and-drop `.bat` (pending Windows execution checks).
- [x] Classify mandatory V/Z as current, missing, known older or unknown; no skip option.
- [x] Represent J/U independently; preserve unselected existing optional files.
- [x] Compare the intended realmlist against exact existing bytes/recognised host without writing.
- [x] Emit `no_change`, `install`, `replace_after_backup`, `blocked`, `not_selected` and `leave_existing` actions.
- [x] Use an exact four-patch policy allowlist with no file copying.
- [ ] Resolve asset provenance and approved distribution sources before any future copying.
- [x] Estimate staging/backup space, check local free disk and reject overlapping roots and reparse points; Windows fixture tests passed.
- [x] Provide text and JSON previews without uploading MPQ bytes or personal file paths.
- [x] Add synthetic cases for current/missing/older/unknown patches, source mismatch, J/U selection, realmlist, collisions and no-write behaviour.
- [x] Add missing/nested-path and conditional junction rejection fixture assertions.
- [x] Confirm Windows CI and exercise a malformed policy in synthetic fixtures, including a valid build-12340 metadata success case.
- [x] Add deterministic low-space and failed-space-query regression tests, using **fixture-only script copies** without introducing a production override; both fail closed in the real preview logic.
- [x] Verify Windows PowerShell 5.1 CI succeeds for these planner changes (PR #5).
- [x] Add optional `-BackupRoot` capacity preview, path isolation and distinct/shared drive budget reporting with deterministic low/unknown backup drive tests (PR #6; Windows fixtures passed).
- [x] Replace drive-letter assumptions with Win32 *logical volume GUID* checks and directory-specific free-space queries; synthetic tests cover alias GUIDs, distinct volumes and failed queries ([PR #9](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/9); see [Volume Preflight](WINDOWS-VOLUME-PREFLIGHT.md)).
- [x] Document prototype and limits in [INSTALLER-PLAN.md](INSTALLER-PLAN.md).

**Exit gate:** the entire proposed operation can be reviewed and tested without a single mutation to the WoW folder.

## Milestone 3 — Backup-first local transaction

**Write-capable development remains blocked by provenance/approval decisions and remaining failure-path coverage.** A [backup/transaction design](TRANSACTION-DESIGN.md) has been drafted; no game-file writing engine exists.

- [x] Draft the [backup-first transaction and rollback design](TRANSACTION-DESIGN.md), including journal states and recovery tests.
- [x] Implement the [read-only recovery preview](RECOVERY-PREVIEW.md) to evaluate synthetic journal records, original backups and player-modified files without writing.
- [x] Verify read-only recovery preview fixture tests on GitHub Windows PowerShell 5.1 CI (10 October 2026; PR #4).
- [x] Prevent recovery suggestions from uncommitted/unverified journals and reject duplicate backup references; verify Windows CI (PR #5).
- [x] Draft [journal durability and ownership design](JOURNAL-DURABILITY.md) with crash-point tests, permission boundaries and unresolved authentication issues.
- [x] Draft [journal authority proposal](JOURNAL-AUTHORITY.md): versioned trust levels, DPAPI-protected per-installation key proposal, signed event chain and replay caveats. **Production design only**; DPAPI key protection remains unimplemented.
- [x] Implement **synthetic-only** signed journal v2 envelope/anchor inspection with HMAC, predecessor link validation, allowlist checks and Windows fixtures; [format and limits](JOURNAL-V2-FIXTURE.md). No production trust authority or file writes (PR #7).
- [x] Add optional **independently keyed fixture witness** and Windows regression tests proving that a retained newer witness rejects an older journal **plus** its matching old anchor (PR #8). Also prove replaying the witness alongside them remains possible. This is not a production anti-rollback guarantee.
- [x] Add a **read-only Windows filesystem directory handle identity preview** using `FILE_ID_INFO` (128-bit ID plus volume serial); synthetic tests confirm rename persistence, copy distinction, junction/root rejection and no writes ([PR #10](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/10), [Identity Guide](WINDOWS-DIRECTORY-IDENTITY.md)). **Not** a trusted installation registration.
- [x] Add a synthetic-only [registration/session review](REGISTRATION-FIXTURE-REVIEW.md) and Windows test matrix covering renamed/copied client folders, missing registration, stale/ahead sequences, incomplete states and no-write guarantees ([PR #11](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/11)). Intentionally verify that forged registration and coordinated replay remain *untrusted*.
- [x] Add [synthetic V/Z crash-boundary classifier](CRASH-BOUNDARY-FIXTURES.md), with Windows tests for before/after backup, partial V/Z, ambiguous write records, missing patches, changed player files and unverified anchors ([PR #12](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/12)). No actual crash durability or file writing is tested.
- [x] Add [read-only checkpoint ordering fixtures](CHECKPOINT-ORDER-REVIEW.md), Windows test of 13 proposed stages, journal/anchor sequence mismatch and missing/lost protected-state *claims* ([PR #13](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/13)). Actual persistence and trust are still unimplemented.
- [ ] Resolve replay resistance of a journal and its corresponding signed anchor, secure DPAPI key lifecycle and installation identity for a *production* journal.
- [ ] Build a transaction engine for allowlisted configuration/approved assets only after design and sources are approved.
- [ ] Require explicit confirmation and client-closed checks before writing.
- [ ] Stage files, verify SHA-256 and size, then commit by safe replacement.
- [ ] Store exact pre-change files in a per-install backup folder outside the client.
- [ ] Journal the operation before each write with before/after hashes and ownership (pre-existing vs created).
- [ ] Ensure interrupted/failed installs have deterministic recovery.
- [ ] Refuse symlinks/reparse-point files and unsafe relative paths.
- [ ] Keep V/Z mandatory and abort rather than ending with an incomplete core install.
- [ ] Preserve files the player changed later; report conflicts rather than overwriting on rollback.
- [ ] Test install, idempotent repeat, partial failure, rollback, reinstall and uninstall on **disposable fixtures**.
- [ ] Manually test against a *separate backed-up copy* only after fixture tests pass.

**Exit gate:** no silent data loss and every managed change demonstrably recoverable.

## Milestone 4 — Guided Windows setup

- [ ] Design a simple Windows launcher with clear path selection, feature choices, review and result screens.
- [ ] Provide plain-language errors and progress reporting.
- [ ] Show J/U overlap warning and optional feature status.
- [ ] Include advanced views for checksums, patch revision and backups.
- [ ] Provide accessible documentation and screenshots of verified behaviour.

## Milestone 5 — Approved addons and independent versions

- [ ] Review license and approved packaging/source for [N Addon Suite v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0).
- [ ] Require `NCore` when any N Addon Suite modules are selected.
- [ ] Offer `IndividualProgressionAddon`, `DungeonJournal`, `MultiBot` and `NaxxLootLottery` separately once their releases are approved.
- [ ] Keep the standalone `NTalentCalculator` independent; decide whether to list it as an optional standalone download.
- [ ] Pin release versions and hashes; verify layout; back up existing addon folders before replacement.
- [ ] Never delete unrelated third-party or personal addons.

## Milestone 6 — Patch updates, repair and rollback

- [ ] Review new owner-provided `patch-update-proposal.json` files.
- [ ] Register reviewed revisions without overwriting older version history.
- [ ] Identify current, older known, unknown and missing local patches.
- [ ] Implement safe version-to-version update, repair, selective optional-feature changes and rollback.
- [ ] Make the realm host independently configurable from the patch version.
- [ ] Use only explicitly approved distribution channels; do not place MPQs in GitHub by default.

## Milestone 7 — Release approval

- [ ] Validate actual in-game startup and connection with both mandatory V/Z patches.
- [ ] Test J only, U only, both and neither in game and resolve precedence expectations.
- [ ] Confirm source/provenance and redistribution rights for **every** distributed asset.
- [ ] Complete automated and manual test matrix on disposable 3.3.5a copies.
- [ ] Review accessibility, recoverability, data privacy, installer signatures and support instructions.
- [ ] Publish a versioned pre-release only after gates pass; then tag a supported release with change notes.

## Existing project source of truth

| Item | Location | Purpose |
| --- | --- | --- |
| Overview | [../README.md](../README.md) | Public-facing project state |
| Detailed continuity | [PROJECT-HANDOVER.md](PROJECT-HANDOVER.md) | Decisions, known gaps, next task |
| Client review | [CLIENT-INVENTORY-REVIEW.md](CLIENT-INVENTORY-REVIEW.md) | What was inspected and excluded |
| Existing milestone | [INSTALLER-MILESTONE-1.md](INSTALLER-MILESTONE-1.md) | Read-only tool use and limitations |
| Patch updates | [PATCH-UPDATES.md](PATCH-UPDATES.md) | Revision workflow |
| Realm setup | [REALMLIST.md](REALMLIST.md) | Public player configuration and backup |
| Live patch policy | [../config/client-patches.json](../config/client-patches.json) | Active integrity reference |
| History | [../config/patch-versions/patchset-0001.json](../config/patch-versions/patchset-0001.json) | Immutable initial revision |
| Realm policy | [../config/realm.json](../config/realm.json) | Independent realm address |
| Transaction recovery | [RECOVERY-PREVIEW.md](RECOVERY-PREVIEW.md) | Tested read-only session rollback decisions |
| Journal durability | [JOURNAL-DURABILITY.md](JOURNAL-DURABILITY.md) | Design-only crash safety and ownership gates |
| Journal authority | [JOURNAL-AUTHORITY.md](JOURNAL-AUTHORITY.md) | Design-only signed ownership and replay-defense proposal |
| Volume preflight | [WINDOWS-VOLUME-PREFLIGHT.md](WINDOWS-VOLUME-PREFLIGHT.md) | Win32 logical volume identity and free-space checks, with caveats |
| Directory identity | [WINDOWS-DIRECTORY-IDENTITY.md](WINDOWS-DIRECTORY-IDENTITY.md) | Read-only Windows directory object fingerprint and security limits |
| Registration fixture review | [REGISTRATION-FIXTURE-REVIEW.md](REGISTRATION-FIXTURE-REVIEW.md) | Read-only untrusted registration/session matrix and interruption safeguards |
| V/Z crash-boundary classification | [CRASH-BOUNDARY-FIXTURES.md](CRASH-BOUNDARY-FIXTURES.md) | Synthetic V/Z partial-replacement and journal checkpoint cutpoints; no writer |
| Checkpoint ordering model | [CHECKPOINT-ORDER-REVIEW.md](CHECKPOINT-ORDER-REVIEW.md) | Synthetic 13-stage ordering, Win32 flush/replacement constraints and remaining trust gates |
| Trust continuity and migration | [TRUST-CONTINUITY-REVIEW.md](TRUST-CONTINUITY-REVIEW.md) | Read-only lost keys, moved clients, backup/source/anchor blockers and limited local threat model |
| Frozen approval design | [APPROVAL-SNAPSHOT-REVIEW.md](APPROVAL-SNAPSHOT-REVIEW.md) | Synthetic exact-plan consent comparison: client, backups, V/Z, J/U, realmlist and source claims |
| Versioned plan digest | [APPROVAL-PLAN-DIGEST-V2.md](APPROVAL-PLAN-DIGEST-V2.md) | Synthetic Windows PowerShell canonical plan hash, mismatch checks and limitations |
| Single-use consent lifecycle | [CONSENT-LIFECYCLE-REVIEW.md](CONSENT-LIFECYCLE-REVIEW.md) | Synthetic issued/approved/use/revoked event ordering, expiry and coordinated replay limits |
| Synthetic signed journal v2 | [JOURNAL-V2-FIXTURE.md](JOURNAL-V2-FIXTURE.md) | Tested fixture format, limitations and Windows check command |

## Decision and progress log

### 10 October 2026 — Continuity baseline

- Verified the latest available repository commit was `869c9c6` (realmlist template and backup guidance).
- Re-read the README, first milestone, inventory, patch update policy, realmlist documentation and current manifest.
- Confirmed an actual write-capable installer, updater, rollback and uninstall are **not yet present**.
- Created a dedicated roadmap and handover as living project records.
- Added the read-only planner, Windows launcher, synthetic test suite, CI workflow and [preview documentation](INSTALLER-PLAN.md).
- On 10 October 2026, GitHub's Windows PowerShell 5.1 workflows for read-only planner fixtures **passed**, including the synthetic supported-build no-blockers scenario. The legacy preflight suite also **passed** after fixing an inherited exit-code issue.
- PR [#2](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/2) merged expanded safety fixtures and corrected legacy test exit-code handling. PR [#3](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/3) merged a generated versioned executable fixture to test the non-blocking preview.
- Recorded the write-capable design separately in [TRANSACTION-DESIGN.md](TRANSACTION-DESIGN.md), without introducing any installation code.
- PR [#4](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/4) merged a validated read-only recovery inspector, synthetic safety tests and [recovery guide](RECOVERY-PREVIEW.md). Both new recovery and existing preflight workflows passed on Windows.
- PR [#5](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/5): low/unknown-space regression tests, blocked incomplete recovery journals, duplicate backup rejection and [journal durability proposal](JOURNAL-DURABILITY.md). Windows preflight, planner and recovery workflows all passed.
- PR [#6](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/6) extends the read-only planner with optional validated `-BackupRoot`, two-drive budget checks, simulated independent volume failures and path collision tests. Windows planner and existing preflight suites passed. **Drive-root identification is not authoritative physical volume identity.**
- Added [Journal Authority](JOURNAL-AUTHORITY.md) specifying proposed tamper-evident ownership and failure cases, without implementing keys or automatic recovery.
- PR [#7](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/7) adds synthetic signed journal v2 event-chain and anchor checks, a Windows fixture test suite, and [format documentation](JOURNAL-V2-FIXTURE.md). **Only trust properties of the disposable fixture are tested.**
- PR [#8](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/8) adds a separately keyed, read-only **synthetic witness** comparison; tests show older journal+anchor replay detection only when the newer witness is independently retained, and confirm replay of *all* records remains possible without protected monotonic state.
- PR [#9](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/9) upgrades storage classification to Win32 logical volume GUIDs and per-directory capacity, with failure-path tests; physical disk identity, durability and write-time TOCTOU remain unresolved.
- PR [#10](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/10) adds the read-only directory handle inspector and synthetic Windows checks: same directory/rename retain identity, a copy creates a different object, unsafe paths are refused. Windows preflight and new identity tests passed. **Object IDs are not secure registration or replay protection.**
- PR [#11](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/11) adds read-only, synthetic registration/session comparison with strict sequence checks. No record is authenticated or allowed to authorise client writes; even intentionally forged copied-folder identity and coordinated replay can look consistent.
- PR [#12](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/12) adds fixture-only V/Z crash-cutpoint classifications, strict allowlists and a Windows safety suite. Outcomes never permit installation/resume/rollback and all evidence is caller-controlled, not crash-durable.
- PR [#13](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/13) adds a strict read-only timeline for V/Z backups, intents, replacements, verification, journal completion and latest anchor publication. Missing/ahead/lagging anchors, reorders and every incomplete prefix block any automatic write. Full coherent replay remains detectable only with real independent authority.
- PR [#14](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/14) adds a **read-only synthetic trust-continuity model**. Windows fixtures cover moved/copied clients, Windows account/computer migration, lost keys, damaged backups, patch provenance, consent, multiple simultaneous faults and fully coherent replay. Every result blocks write, resume, rollback and silent re-registration.
- PR [#15](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/15) adds a **read-only frozen approval snapshot comparator**. Synthetic Windows tests detect approval missing/expired/revoked and changes to client, backup/source folder fingerprints, mandatory V/Z and optional J/U selections, pre-existing file bytes, realmlist, patchset and provenance. A matching fixture remains **NOT authenticated consent** and never permits writes.
- PR [#16](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/16) adds optional **v2 unkeyed plan-digest comparison** to read-only synthetic approval fixtures, retaining v1 fixture compatibility. The Windows suite validates typed, whitespace-independent digest calculation with an independent golden value, changed/falsified snapshots and forged matching inputs. Every outcome remains **NOT authenticated** and never allows writes.
- PR [#17](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/17) adds a **read-only single-use consent lifecycle fixture** with Windows tests for issuance, approval, expiry, revocation, repeated use, changed plan nonce/hash and all-record replay. A matching unconsumed event list is still **NOT authenticated**, and no fixture may authorise file writes.
- [x] Integrate the [real read-only planner and Win32 folder identity](LIVE-PLAN-RECHECK.md) for **live plan recheck**, using only existing client/source/backup folders. Windows tests exercise disposable real files and a mock executable; no game writes ([PR #18](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/18)).
- PR [#18](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/18) adds a **live read-only** reinspection tool that captures an unsigned plan/folder fingerprint snapshot to stdout and compares fresh planner hash/realm/space results plus actual Windows directory IDs. It detects changed bytes, optional selections, source and backup folder swaps and blocked preflight; a match is NOT approved consent.
- PR [#19](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/19) now requires **two consistent, real read-only planner and Win32 identity passes** before issuing a snapshot, and labels mid-scan changes for manual review in comparison mode. Windows CI deliberately modifies a fake realmlist between passes using a test-only copied planner to prove the detector works. This is not an atomic scan, real consent, protected registration or writer.
- PR [#20](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/20) adds a **read-only Windows stable-open-file inventory** for exact client V/Z/J/U/realmlist or local source V/Z/J/U. All present allowlisted files are opened with `FileAccess.Read`/`FileShare.Read` before hashing on those handles; same-handle Win32 file ID and SHA-256/length observations are returned. CI covers a concurrent writer, missing V/Z vs J/U, junctions and unchanged fake files. This does NOT lock a directory or authorise installs.
- **Next task:** design an integrated live consent-to-transaction protocol that retains appropriate file/directory handles across a proposed write, with reliable ownership, backup provenance and protected one-use journal state. Evaluate path races, missing target creation, backup integrity, Win32 durability and recovery separately. No write-capable installer or public MPQs.
