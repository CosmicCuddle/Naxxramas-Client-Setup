# Naxxramas Client Setup — Development Roadmap

**Last reviewed:** 10 October 2026  
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
- [ ] Confirm Windows execution succeeds; legacy read-only scripts still need regression tests.

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
- [x] Estimate staging/backup space, check local free disk and reject overlapping roots and reparse points (pending Windows validation).
- [x] Provide text and JSON previews without uploading MPQ bytes or personal file paths.
- [x] Add synthetic cases for current/missing/older/unknown patches, source mismatch, J/U selection, realmlist, collisions and no-write behaviour.
- [ ] Confirm CI execution and add missing-path, junction/symlink, low-disk and malformed-policy cases.
- [x] Document prototype and limits in [INSTALLER-PLAN.md](INSTALLER-PLAN.md).

**Exit gate:** the entire proposed operation can be reviewed and tested without a single mutation to the WoW folder.

## Milestone 3 — Backup-first local transaction

**Blocked until the read-only planner is tested and sources are confirmed appropriate for local use.**

- [ ] Build a transaction engine for allowlisted configuration/approved assets only.
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

## Decision and progress log

### 10 October 2026 — Continuity baseline

- Verified the latest available repository commit was `869c9c6` (realmlist template and backup guidance).
- Re-read the README, first milestone, inventory, patch update policy, realmlist documentation and current manifest.
- Confirmed an actual write-capable installer, updater, rollback and uninstall are **not yet present**.
- Created a dedicated roadmap and handover as living project records.
- Added the read-only planner, Windows launcher, synthetic test suite, CI workflow and [preview documentation](INSTALLER-PLAN.md).
- Windows tests have been authored but **not yet confirmed passing** in the current environment.
- **Next task:** confirm Windows CI, correct failures, extend path-safety tests and meet the preview exit gate before any write-capable installer.
