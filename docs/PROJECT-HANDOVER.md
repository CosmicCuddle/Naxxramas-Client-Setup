# Naxxramas Client Setup — Project Handover

**Updated:** 10 October 2026  
**Repository:** [CosmicCuddle/Naxxramas-Client-Setup](https://github.com/CosmicCuddle/Naxxramas-Client-Setup)  
**Starting reference for this handover:** `main` commit `869c9c6` on 9 October 2026, before these continuity documents were added.  
**Active patch reference:** `patchset-0001`

This document is the first file to read when continuing the project in another development session. It records established owner decisions, what is actually present in GitHub, what has **not** been tested, the next development step and how to preserve continuity. Keep it updated in the same change as the code or docs being worked on.

## 1. What the owner wants

A simple, preferably guided Windows-based setup that helps a player configure an **existing compatible World of Warcraft 3.3.5a client** for the Naxxramas realm. The owner's own client archive is about **18.6 GB** and must **not** be pushed to GitHub or treated as the public download. The expected workflow is to use a separate existing 3.3.5a installation, apply only approved Naxxramas-specific components, configure the realmlist and optionally choose visual patches/addons.

The setup must accommodate future Naxxramas updates, especially repeat revisions to custom MPQs without requiring an unnecessary full-game redownload. It must offer backups, safe repair, rollback and uninstall. The owner particularly values **step-by-step guidance**, no destructive surprises, and clear changelogs/roadmaps in the repository.

## 2. Decisions that must not be lost

| Decision | Exact handling |
| --- | --- |
| Client version | WoW 3.3.5a, target executable build **12340**, current supported locale **enUS**. |
| Core custom patch V | `Data/patch-V.mpq` is **mandatory**, no optional checkbox. |
| Core custom patch Z | `Data/patch-Z.mpq` is **mandatory**, no optional checkbox. |
| Login visuals | `Data/Patch-J.mpq` is **optional**, separately selectable. |
| Loading visuals | `Data/Patch-U.mpq` is **optional**, separately selectable. |
| J/U interaction | Two Eastern Kingdoms and Kalimdor loading textures overlap with different content; no automatic merging or untested compatibility claims. |
| Patch update process | New hashes, sizes and immutable numbered history entries; never overwrite a previous patch-version record. |
| Realm address | `set realmlist 85.190.254.242`, from owner-provided `realmlist.wtf`. Store separately from patch-set version. |
| Ownership / safety | Never damage the owner's existing working client. Validate using a separate copy and back up prior contents. |
| Package policy | GitHub stores scripts, manifests and permissible metadata. **No full client, Blizzard archives, MPQs or other unauthorised game assets.** |
| Addons | Official N Addon Suite v2.0.0 is the starting catalog; not every addon in the owner's personal installation. |
| Standalone talent addon | `NTalentCalculator` is not part of N Addon Suite v2.0.0. Keep it separate unless explicitly approved for the optional catalog. |
| Future client writes | Preview, user consent, allowlist, hash verification, staged writes, backups, journal, rollback and conflict detection. |

### Addon details

The inspected approved suite layout has **five folders**: `NCore` (required within the suite), `IndividualProgressionAddon`, `DungeonJournal`, `MultiBot` and `NaxxLootLottery` (each selectable independently after approval). The release reference is [N-Addon-Collection v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0). This does **not** by itself demonstrate redistribution rights, or guarantee that every component is production-ready. Optional suite support in the current preflight only checks expected local TOC structure; it does not install an addon.

### Known owner inventory

The read-only client inventory reported **22 MPQ archives** (~16.56 GiB by rounded scanner values), **174 addon folders**, and `Wow.exe`. The original archive was described separately as ~18.6 GB. Treat standard MPQs, personal settings, screenshots, `WTF`, `Cache`, logs, custom sounds, unknown DLLs and personal third-party addons as **outside the default package**.

## 3. Current files and implemented behaviour

| Repository path | Current role | Writes to WoW? |
| --- | --- | --- |
| `tools/Inspect-Client.bat` / `.ps1` | Generate a names/sizes-only inventory | No |
| `tools/Check-Naxxramas-Client.bat` and `tools/Test-Naxxramas-Client.ps1` | Check client structure, executable version metadata, V/Z hashes, optional J/U, addons and realmlist | No |
| `tools/Plan-Naxxramas-Install.bat` / `.ps1` | Preview possible V/Z, J/U and realmlist actions, blockers and backup needs (Milestone 2; Windows tests pending) | No |
| `tools/Get-Core-Patch-Hashes.bat` / `.ps1` | Display V/Z SHA-256 and sizes | No |
| `tools/Prepare-Patch-Update.bat` / `.ps1` | Propose new patch metadata in `tools/patch-update-proposal.json` | No (writes a local *report* in repository tools folder) |
| `config/client-patches.json` | Current V/Z and J/U policy, hashes, sizes, overlap warning | N/A |
| `config/patch-versions/patchset-0001.json` | Initial historical version of patch metadata | N/A |
| `config/realm.json` | Server host and supported realm-list location | N/A |
| `templates/realmlist.wtf` | Manual example configuration | No |
| `docs/CLIENT-INVENTORY-REVIEW.md` | Detailed inventory assessment | N/A |
| `docs/INSTALLER-MILESTONE-1.md` | Existing preflight instructions and design | N/A |
| `docs/PATCH-UPDATES.md` | Instructions for future versioned patch changes | N/A |
| `docs/REALMLIST.md` | Manual realmlist backup/configuration guide | N/A |
| `docs/INSTALLER-PLAN.md` | How to run and interpret the new read-only planner | N/A |
| `docs/TRANSACTION-DESIGN.md` | Proposed backup, journal, write-gate, rollback and recovery safety contract; no implementation | N/A |
| `tests/Test-InstallerPlan.ps1` | Synthetic generated-file test cases; not a real game-client test | No |
| `.github/workflows/client-planner-tests.yml` | Windows PowerShell 5.1 fixture workflow; passed on 10 October 2026 | N/A |
| `docs/ROADMAP.md` | Detailed milestones, gates and progress log | N/A |
| `docs/PROJECT-HANDOVER.md` | This running engineering handover | N/A |

### Active patch fingerprints (`patchset-0001`)

| Path | Role | Size in bytes | SHA-256 |
| --- | --- | ---: | --- |
| `Data/patch-V.mpq` | Mandatory | 450631505 | `68ca0d260841a028181fdeac72db5cd96a752da9c5f2798432a065db6dcd70ff` |
| `Data/patch-Z.mpq` | Mandatory | 47337608 | `5eb17ce5dc7b87990dd173a7c3dd3ff5be7d34219be407eaa854d95625011b3a` |
| `Data/Patch-J.mpq` | Optional | 5739890 | `24385046f0db6c17db5f549fa0f418f5d5ed1d4c2100059f1db9bede709113c9` |
| `Data/Patch-U.mpq` | Optional | 11050502 | `51fc8cbd1786537772ea7f59eac7be244eedabf7e6487ee41e5ce2009ecd9a6d` |

**Provenance note:** V/Z SHA-256 and sizes were transcribed from an owner-provided read-only tool screenshot dated 9 October 2026. J/U references derive from owner-provided archive analysis. These are integrity references, **not** independent proof of licensing or game compatibility.

## 4. What has been verified, and what has not

**Established from documentation, owner data or read-only output**
- `Wow.exe` version metadata appeared as 3,3,5,12340 in an owner-provided screenshot.
- The required V/Z and optional J/U distinction was explicitly confirmed by the owner.
- Local copies of J/U were inspected: J includes login and some loading assets; U includes four loading-screen textures.
- The realm address was transcribed from an owner-provided 28-byte realmlist file.
- The preflight and proposal tools exist as source code in GitHub.

**Not established**
- Production-game end-to-end testing and a write-capable installer. Synthetic Windows fixture suites passed on 10 October 2026, but these do **not** validate real client gameplay or any installer writes.
- Full client runtime compatibility, working real-world Naxxramas login, or external reachability of the realm address.
- In-game precedence when J and U are both installed.
- Internals, dependencies, origin and redistribution rights of V/Z patches.
- Redistribution rights for J/U or any addon package.
- Any safe automatic installation, repair, update, rollback or uninstall.

Do **not** reinterpret an owner screenshot, a tool implementation, an SHA-256 match or a staged plan as a completed end-to-end functional test.

## 5. Backups and working rules

1. Start each resumed session by checking current `main` and recent commits, then read this handover, [ROADMAP.md](ROADMAP.md), `README.md` and the exact file(s) about to change.
2. Before edits, identify the task's rollback path (Git revert for repository changes; a separate safe client copy and byte-for-byte backups for client-side testing).
3. Never ask the owner to try destructive installer behaviour on their only working game folder.
4. Keep powershell scripts compatible with Windows PowerShell 5.1 where practical.
5. Protect user data: no paths, account details, SavedVariables or full inventories in publicly uploaded reports.
6. Any later installer operations should use an allowlist of relative paths under the selected destination, verify canonical paths against the destination root, and reject reparse points.
7. Require explicit consent to change any existing file. Preserve the original bytes and SHA-256 for robust rollback.
8. Add tests and update this document's implemented/untested/next-step sections every time source behaviour changes.
9. Commit cohesive updates with descriptive messages. Do not rewrite historical patch-set records or the mandatory/optional patch rules without an explicit owner decision.
10. Give the owner short, copy-ready test steps after a testable milestone rather than requesting repeated manual tests after every tiny commit.

## 6. Immediate next task

**Milestone 2: validate and harden the read-only installer planner**, not the write-capable installer.

Current implemented slice:
1. `tools/Plan-Naxxramas-Install.ps1` emits a console plan or optional JSON using the existing patch and realm manifests, with no writes. Windows drag-and-drop launcher added.
2. V/Z are mandatory, J/U independent, and unselected existing optional files are preserved. Current, missing, known-older and unknown versions are classified; unrecognised selected patches are blocked.
3. Realmlist is previewed from `config/realm.json`. Future replacements require backup. J/U overlap, path collisions, reparse points, version metadata and estimated free space are checked.
4. `tests/Test-InstallerPlan.ps1` covers required/optional patches, realm safety, invalid source/path/policy, junctions and a test-only generated versioned executable. Its Windows PowerShell CI run **passed** on 10 October 2026. It checks before/after file fingerprints to catch unexpected writes.

Next checks before leaving Milestone 2:
1. **Completed:** Windows workflows passed; corrected the legacy preflight suite's stale subprocess exit code. Preserve those passing baseline tests.
2. **Completed:** missing/nested-path, junction and malformed-policy fixture checks passed on Windows. **Still needed:** deterministic low-disk regression and additional fail-closed testing.
3. **Completed for fixture scope:** JSON does not include absolute fixture paths; source and destination snapshots remain unchanged across tested previews. Continue reviewing data privacy for any new planner fields.
4. **Completed:** updated the owner-facing milestone documentation and verified Windows results in this handover and ROADMAP. Document any further checks with the same precision.
5. Read [TRANSACTION-DESIGN.md](TRANSACTION-DESIGN.md) for the **design-only** transaction proposal. Build a separate read-only session/journal recovery evaluator before developing code capable of writing game files.

Do **not** treat this task as permission to copy or distribute MPQ files. It is a design/validation step.

## 7. Open decisions for later, not blockers for initial planner

- Exact approved source and redistribution mechanism for the four MPQs. All currently have `public_distribution_approved: false`.
- In-game visual comparison for J only, U only and both together.
- Final default addon selections and whether to list standalone talent calculator.
- Installer interface/packaging technology, once the safe file operation design is proven.
- Final release, update and support channel.

## 8. Session continuation log

### 10 October 2026 — Handover created

- Reconnected to GitHub and reviewed available commit history. Most recent previously existing commit: `869c9c6`, 'docs: add Naxxramas realmlist template with backup guidance.'
- Inspected current README, patch manifest, patch version history, realm config, first milestone docs, inventory review, patch update rules and preflight code.
- Noted that the README contains a five-step outline but that a dedicated `docs/PROJECT-HANDOVER.md` and `docs/ROADMAP.md` were absent at the start of the continuation.
- Added these continuity documents to preserve the full constraints and nominate the read-only planner as next feature.
- Implemented `tools/Plan-Naxxramas-Install.ps1` and `.bat`: read-only checks and a proposed action for each of the four patches and realmlist.
- Added generated-file fixture tests (including missing/nested paths, a conditional junction check, and preserving realmlist comments), a Windows workflow and `docs/INSTALLER-PLAN.md`. No proprietary game files are present.
- Both Windows PowerShell 5.1 workflows passed on 10 October 2026 after opening PRs to trigger full checks. The original preflight workflow initially failed due to a stale child-process `LASTEXITCODE`; that harness bug was corrected and reverified.
- Expanded tests merged in PR #2 and non-blocking valid-build fixture merged in PR #3. The read-only success path and core negative tests are now covered; real game runtime and installation remain untested.
- Created [TRANSACTION-DESIGN.md](TRANSACTION-DESIGN.md) with a transaction state machine, backup ownership rules, conflict-safe rollback and crash-recovery gates.
- **Next engineering action:** finish low-space/fail-closed tests, then implement and test a **read-only journal-state recovery planner** against synthetic session data. Do not touch genuine client files.
