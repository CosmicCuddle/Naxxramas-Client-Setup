# Naxxramas Client Setup — Project Handover

**Purpose:** Permanent continuation reference for future chats, maintainers, and development sessions. **Read this document first** when starting again after context loss. Update the *Current checkpoint*, *Completed work*, *Open decisions* and *Next steps* whenever a milestone or recovery fix is completed. Keep it in the repository, not only in a conversation.

**Status as of 10 October 2026:** Milestones 15 and 16 passed Windows CI (M16 run [38054974809](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38054974809)). The owner has now supplied and successfully reviewed a private M14 full-hash inventory; aggregate results and two unknown MPQ follow-up documented under M17 (Windows CI [38056648893](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38056648893) **passed**). No full-game download, public client or production installation is enabled.

**Latest M17 locale allowlist follow-up:** Windows run [38057682710](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38057682710) **completed successfully** on checkpoint `8d1c717e9640f1f6327f8a0a4de4befd613ecfaf`. M14 scanner, M16 reviewer and M17 classifier all recognise base-enUS/backup-enUS by filename only; synthetic fixture tests passed. No real-client installation is enabled.

**Milestone 18 (Windows CI [38058231220](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38058231220) passed):** A read-only, console-only support candidate audit checks 13 fixed root-level filenames and four directory-presence statuses, with no client file contents or personal data read and no reports saved. See `docs/INSTALLER-MILESTONE-18.md`. No fresh game downloads or production installation.

- **Latest M19 passing Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38059211057 (checkpoint `4ad1618fa464cdabe97a3cf21a89f984de14062a`)
- **Latest M18 passing Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38058231220 (implementation checkpoint `477b138e46714fcf6579cb50b205b4081f82ce0e`)

**M19 implementation verified:** [Windows CI run 38059211057](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38059211057) passed at checkpoint `4ad1618fa464cdabe97a3cf21a89f984de14062a`. The M14/M16 root allowlists now recognise `ijl15.dll`/`dbghelp.dll` as **unpinned candidates**; M18 screenshot observations are recorded in M19. The workflow also parses all PowerShell tests before executing them.

**M20 validated (Windows CI [38060443793](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38060443793) passed):** A separate read-only inspector checks the safety of explicitly marked tiny synthetic copy fixtures after interrupted M15 operations. It verifies journal identity, manifest file hashes, partial/complete states and unknown contents. It never removes anything or accesses a real WoW installation. Next work is durable recovery and safe stage cleanup in synthetic tests.

- **Milestone 20 successful Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38060443793 (tested implementation checkpoint `22ccd6a3558ed202bc1676eb63abfc6f7a7cde53`)

**Milestone 21 — verified (Windows [run 38061485117](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38061485117) passed):** M15's strictly synthetic copy-fixture rollback now records a resumable `rolling_back` journal state, checks unknown files/empty folders and stale journal sidecars, and supports an injected interruption with later explicit confirmation. M20's read-only auditor recognises this state. No real-client copying enabled.

- **Milestone 21 successful Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38061485117 (tested implementation commit `e5e4c7a14fb1120eed78f06fb99f6c8bea313843`)

**M22 verified (Windows [run 38062420201](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38062420201) passed):** New stage-owner metadata is written before disposable dummy files enter an M15 staging folder. Unconditional recursive stage deletion is replaced by verified, narrowly scoped cleanup. A separate M22 read-only auditor checks one explicitly supplied orphan stage and refuses unknown/changed content. No game-client file writes or automatic orphan cleanup.

- **Milestone 22 passing Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38062420201 (tested implementation commit `844f2a91cecf11cc243c41a0c1185d2549037eb1`)

**Milestone 23 verified (Windows [run 38063285602](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38063285602) passed):** Deterministic dummy-only low-space, partial stage-write failure and staged-file tampering scenarios added. M15 now checks source and staged file bytes immediately before promoting test files; M22 preserved-stage inspector rejects mutated content. No real disk filling, full-client download, real-game install or game writes.

- **Milestone 23 successful Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38063285602 (tested implementation checkpoint `1bccc4df469e6e6709864db818ccbbab34cf2834`)

**M24 verified (Windows [run 38064037936](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38064037936) passed):** Enhanced M15's tiny synthetic Copy with deterministic interrupted stage-marker/journal writes and a last-moment destination collision. Unknown journals/stages or unowned destination files are preserved; Copy-only switches are rejected by Plan/Rollback. Existing fixture limits and disabled real-client source are unchanged. Refer to `docs/INSTALLER-MILESTONE-24.md`.

- **Milestone 24 passing Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38064037936 (tested implementation commit `39cc99e20f7444b09eec3cc6d1d168cdb856dfd2`)

**Milestone 25 verified (Windows [run 38064980775](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38064980775) passed):** Added developer-only `Inspect-Fixture-Transaction-Status.ps1` to summarise strictly marked tiny synthetic journals, transaction residues, and an optionally specified stage, without modifying files or exposing user paths. It delegates verification to existing M20/M22 read-only inspectors. Do not interpret a consistent result as permission to erase files or deploy the game.

- **Milestone 25 passing Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38064980775 (tested implementation commit `c836aa728f568bde861c85ab6239c1167303fa18`)

**M26 verified (Windows [run 38066008592](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38066008592) passed):** Added developer-only `Plan-Fixture-Recovery.ps1`: translates M25 verified dummy transaction status into fixed, privacy-safe, read-only guidance and explicitly states `PERMITTED AUTOMATIC ACTIONS: NONE`. It never searches sibling stages, repairs journals, executes rollback, or touches WoW clients.

- **Milestone 26 successful Windows CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38066008592 (tested implementation checkpoint `a01fb5ee35720c690d478bf89e69058206cc2ffd`)

## 1. Project and critical GitHub links

- **Main repository:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup
- **Development branch:** `feature/backup-first-installer-alpha`
- **Draft PR #1:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/1
- **GitHub Actions:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/workflows/validate-tools.yml
- **Milestone 17 locale allowlist follow-up CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38057682710 (checkpoint `8d1c717e9640f1f6327f8a0a4de4befd613ecfaf`)
- **Milestone 17 passing CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38056648893 (implementation commit `94838fba72a4dc9733f9d3cd433e8f405b59307d`)
- **Milestone 16 passing CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38054974809 (commit `3ab55d8791dc153b3c761d54c6d70730ae305c60`)
- **Milestone 15 passing CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38054045414 (implementation commit `8350949c6ffde50ca10c459a6d8f7f4f3e99970c`)
- **Milestone 14 passing CI:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38053138014
- **Milestone 14 tested implementation commit:** `f69aa14938d0e2fc944025afbc02176b9aaf0c22`
- **Previous Milestone 13 passing run:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38051954866 (commit `d2016a9`)
- **Main branch at previous verification:** `869c9c6f2f0427e079530b8a0a2f58119d35ee50` (unchanged through Milestone 13).
- **Patch assets repository:** https://github.com/CosmicCuddle/Naxxramas-Server-Patches
- **Addon suite repository:** https://github.com/CosmicCuddle/N-Addon-Collection

**Do not merge PR #1 into main without the owner's explicit request.** Main is intentionally not the live installer.

## 2. Owner's final goal and confirmed requirements

Build a **polished classic-WoW-style Windows launcher/installer** for the Naxxramas AzerothCore 3.3.5a server. A player should ultimately be able to start with **no game files at all** and prepare a working Naxxramas client, including all mandatory patches, chosen optional appearance patches, NCore/selected addons and realmlist. Also support players who already have a compatible client.

**The fresh-client source is NOT ready:** Do not implement unauthorised redistribution of Blizzard game archives. `config/base-client-source.json` is disabled pending an adequately authorised, verified full-client source. A privately held or reverse-engineered copy is useful as a personal technical test reference; possession is not blanket redistribution permission.

**Owner preferences:**
- Clear, step-by-step guidance suitable for a dyslexic reader; do not overwhelm with unstructured instructions.
- Back up before important changes, keep every action reversible, and never silently overwrite existing files.
- The user prefers a classic Wrath/Vanilla World of Warcraft launcher appearance, with their fixed sunset **Horde/Alliance** artwork.
- **No player-facing artwork picker.** Publisher replaces only `assets/default/launcher-art.png` (optional `launcher-logo.png`). Personal artwork is **not committed to public GitHub**. To personalise new CI preview ZIPs, copy that file from an owner's previous private preview; do not assume it exists in a new session.
- **No separate Paste buttons.** Keep a clean single Browse button next to each path field. Dark text fields support direct Ctrl+V and normalise surrounding Explorer quotes when they lose focus.
- Optional patches J and C are **mutually exclusive**; U is separately selectable.
- Do not claim a feature works on a live game client merely because dummy-fixture CI passes.

## 3. Confirmed local reference-client state

The owner submitted a private `client-inventory.txt` and a sanitised `client-reference-*.json`. **These files are not committed** and can expire from previous chat uploads; request them again if fresh analysis is essential.

Results of the verified sanitised JSON:
- World of Warcraft **3.3.5a build 12340** (`enUS`).
- **V and Z both verified** against pinned SHA-256 and byte size; both mandatory.
- **U is already installed and verified**; preserve it. This corrects an early incorrect assumption that it was absent.
- **J (Vanilla login)** and **C (TBC login)** not installed in the reference; choose zero or one, never both.
- **NCore, IndividualProgressionAddon, DungeonJournal, MultiBot, NaxxLootLottery** all have matching TOC files present. **Presence does NOT prove pinned release ZIP identity, versions or runtime compatibility.**
- `realmlist.wtf` exists, but its contents were deliberately not inspected by the reference-report generator.
- **21 MPQ files, total 17,773,795,353 bytes** (aggregate only; does not certify a complete base-client inventory).
- Existing client's actual game binaries or private settings have never been uploaded to this repository.

### 10 October 2026 — owner full-hash report reviewed privately

The owner supplied the local M14 `game-files-*.json` in SHA-256-per-file mode. M16 reports **REPORT STRUCTURE: CONSISTENT**. Aggregate findings only (do not commit report or base-game hashes): 23 allowlisted files; 17,585,778,958 bytes across those files; 16 base archive candidates with recorded SHA-256 (not independently verified against a clean release); 4 root binary candidates; V/Z/U full pinned-reference matches; J/C absent; 2 unclassified MPQs whose names are deliberately hidden by the shared report. The 19 named MPQs plus 2 unclassified fit the earlier reported count of 21, but there is no proof that snapshots are identical. This is **not** a complete base-client file manifest or approval for redistribution.

M17 adds a **local-console-only** inspection of those unclassified filenames/sizes, without writing a report or altering the client. Do not guess their names, remove them or treat them as malicious solely for being unclassified.

### Owner's M17 classification result (10 October 2026)

The owner's local-only screenshot identifies `Data/enUS/backup-enUS.MPQ` (167,245,856 bytes) and `Data/enUS/base-enUS.MPQ` (29,176,975 bytes). Both are now recognised **by filename only** as unpinned `base_archive_candidate` files by the read-only M14 inventory, M16 reviewer and M17 local classifier (Windows CI on these updates pending). No owner game bytes, original base-client checksums, or private scan JSON were committed. Do not remove, rename, rewrite, or upload either MPQ.

Numerical reconciliation: the previous 23-file scan (including four binaries) plus those two files yields an **estimated** 25 allowlisted files (18 base MPQs, three Naxxramas MPQs and four binaries) and an MPQ-only total of **17,773,795,353 bytes**, exactly matching the earlier reference aggregate. This supports the count reconciliation, **not** base-client authenticity, runtime compatibility or redistribution rights. New totals remain estimates until rerun. See `docs/INSTALLER-MILESTONE-17.md`.

### Owner M18 screenshot and M19 extension (10 October 2026)

M18 local-only audit reports **six root support candidates present**: Wow.exe (7,699,456 bytes), Scan.dll (47,876), DivxDecoder.dll (413,696), unicows.dll (245,408), **ijl15.dll (372,736)** and **dbghelp.dll (1,039,728)**. Seven candidates were absent: Launcher.exe, Repair.exe, BackgroundDownloader.exe, Storm.dll, WowError.exe, fmod.dll and fmodex.dll. Data, Data/enUS, Interface and Interface/AddOns directory presence checks were all positive. Absence of optional candidates **does not imply broken client**, and no client repairs/copy operations were authorized.

M19 extends the fixed **read-only** M14 root allowlist and M16 report validator by **exactly ijl15.dll and dbghelp.dll**. Both are \`client_binary_candidate\`, **not pinned**, not required and not approved for distribution. An unchanged development copy would therefore yield an estimated **27 allowlisted files**, 18 base MPQs, V/Z/U, six root binaries, 0 unclassified MPQs and 17,783,614,253 bytes across allowlisted files. **These are arithmetic projections, not independently verified results of a new scan.** Do not commit personal JSON, game files or hashes. M15 copy safety remains dummy-only.

## 4. Pinned component and source policy

Read source-of-truth manifests rather than hardcoding new fingerprints:
- `config/client-patches.json` / immutable `config/patch-versions/patchset-0002.json`: 5 files; V/Z mandatory, J/C/U optional.
- `config/patch-downloads.json`: owner-published URLs for V (`v1.0.6.8.4`), Z (`v1.0.6.7`), J/C/U (`optional-v1.0`); downloads are staged and SHA-256 checked **outside the client**.
- `config/addon-suite.json`: N-Addon Collection v2.0.0 with **NCore required**; opt-in IndividualProgressionAddon, DungeonJournal, MultiBot and NaxxLootLottery. **NTalentCalculator excluded**. Protect unrelated/personal addon folders.
- `config/realm.json`: Naxxramas default `Data/enUS/realmlist.wtf` = `set realmlist 85.190.254.242`; backup before ever changing a real client.
- `config/base-client-source.json`: disabled full-client source with an explicit rights/integrity gate. No WoW downloads.

**Important overlap:** J and U include some duplicate loading-screen texture paths; in-game precedence is not fully verified. J and C replace the same login system and must not coexist.

## 5. Completed development history

| Milestone / work | What is implemented |
|---|---|
| M1–M7 | Read-only patch preflight, version history, config validation, guarded fake-client installation, backups, atomic journals, rollback/recovery and addon ZIP integrity/extraction fixtures |
| M8 | Classic-style Windows Forms launcher, fixed replaceable publisher artwork, headless GUI tests and package artifact |
| M9 | Optional TBC Patch C, J/C conflict policy, tests, and immutable `patchset-0002` |
| M10 | Separate verified patch-download source folder and a confirmed **Get patches** button; no real-client installation |
| Browse refinements | Fixed first-run blank path errors; removed redundant Paste buttons, retained Browse + Ctrl+V |
| M11 | Existing-client and **Fresh client — planning only** modes; blocked full-game source gate; no actual fresh install |
| M12 | Sanitised read-only existing-client inspection tool; tests for privacy, build/version, V/Z integrity, J/C conflict |
| M13 | Read-only plan for V/Z, J/C/U, NCore, optional addons and realmlist based only on a sanitised JSON; corrections for existing U and addons |
| **M14 — complete** | Whitelisted local per-file game binary/MPQ inventory, SHA-256 by default, `-Quick` sizes-only mode, privacy exclusions, dummy-file Windows tests. **CI 38053138014 passed**. |
| **M15 — complete** | Disposable **synthetic-only** copy/verify/rollback prototype: strict test markers, manifest type, tiny-file size cap, separate staging, SHA-256 verification, journal and rollback, failure injection. **CI 38054045414 passed.** Not a real WoW installer. |
| **M16 — complete (CI 38054974809)** | Read-only M14 JSON report consistency review: privacy allowlist, per-file size/hash and pinned V/Z/J/C/U patch summary comparisons, no game file reads. |
| **M17 — complete (CI 38056648893)** | Owner's private scan aggregate review plus a local-console-only tool to identify unclassified MPQ filenames and sizes; no output report and no game modifications. |
| **M18 — complete (CI 38058231220)** | Local-only metadata scan of 13 explicit root support file candidates and 4 directory-presence checks. Absent candidates are informational; no contents, hashes, personal files, game writes or downloads. |
| **M19 — complete (CI 38059211057)** | Owner M18 result reviewed; only ijl15.dll and dbghelp.dll added to read-only root binary inventory and JSON reviewer, with dummy-only tests. No write/download enabled. |
| **M20 — complete (CI 38060443793)** | Developer-only read-only recovery readiness audit for disposable partial/completed copy fixtures; detects changed/unknown contents and validates M15 journal vs manifest without modifying anything. |
| **M21 — complete (CI 38061485117)** | Durable `rolling_back` journal state, simulated interrupted rollback, explicit resume, unexpected empty-folder and journal-sidecar blockers, plus M20 read-only-state coverage. Synthetic-only; no game writes. |
| **M22 — complete (CI 38062420201)** | Synthetic stage owner marker, nonrecursive guarded cleanup, and developer-only read-only single-stage inspection with unknown-folder/tamper tests. No automated orphan removal. |
| **M23 — complete (CI 38063285602)** | Controlled low-space, interrupted stage-write and staged-file mutation fault switches, with prepromotion source/stage verification; tiny synthetic fixtures only, not real concurrent writes. |
| **M24 — complete (CI 38064037936)** | Deterministic interrupted stage-owner and destination-journal writes, promotion-time dummy collision, conservative retention of uncertain state; synthetic-only fixture tests. |
| **M25 — complete (CI 38064980775)** | Read-only synthetic transaction status overview, safe journal and stage classifications, privacy-safe console output, no modifications or automated recovery. |
| **M26 — complete (CI 38066008592)** | Read-only fixture recovery decision planner, fixed review labels for interrupted copy/rollback, uncertain journal/stage and completed copy, no commands or automatic file changes. |

**Read:** `docs/INSTALLER-MILESTONE-8.md` through `docs/INSTALLER-MILESTONE-15.md` for detailed rationale.

## 6. Tools and their write boundaries

- `tools/Naxxramas-Preview.ps1` / `tools/Launch-Naxxramas-Preview.bat`: Windows Forms GUI. Existing mode Plan/Inspect read-only on clients; **Get patches** may download verified files ONLY into separate source directory. Fresh mode is a read-only plan.
- `tools/Setup-Prototype.ps1`: Install/Rollback/Recover are **restricted to disposable dummy fixtures**, marker `.naxx-test-fixture` with exact content `NAXXRAMAS_DISPOSABLE_FIXTURE_V1` plus explicit `-Apply -ConfirmDisposableFixture`; no production game installation. Do not bypass this lock.
- `tools/Get-Patch-Sources.ps1`: pinned HTTPS downloads to separate source directory, with explicit confirmation and no client writes.
- `tools/Inspect-Reference-Client.ps1` + `.bat`: creates private, sanitised client reference JSON **outside WoW**; reads only build and known files.
- `tools/Plan-Reference-Components.ps1` + `.bat`: reads reference JSON and emits safe component choices, no game writes.
- `tools/Plan-Fresh-Client.ps1`: validates an empty destination and describes a blocked source; never installs anything.
- **M14:** `tools/Inventory-Game-Files.ps1` + `.bat`: enumerates only whitelisted root game binaries and Data/enUS MPQs, hashes locally, produces a private report **outside WoW**; no game writes, no complete-client claim.
- **M15:** `tools/Test-Client-Copy-Fixture.ps1`: tiny synthetic-only local copy/verify/rollback experiment; never expose to real WoW paths or player launcher. Requires exact marker files, synthetic-only manifest, empty destination and explicit confirmation.
- **M16:** `tools/Review-Game-File-Report.ps1` + `.bat`: reads a previously saved, sanitised inventory JSON and pinned policy only; refuses inconsistent/private paths, reports Quick as unverified and never touches game files.
- **M17:** `tools/Inspect-Unclassified-MPQs.ps1` + `.bat`: reports only the unknown Data/enUS MPQ names and byte sizes locally after explicit drag/drop. No report or network; never modify clients.
- **M18:** `tools/Inspect-Client-Support-Files.ps1` + `.bat`: checks a narrow list of root file presence/size and well-known directory existence, console-only. No file content reads, recursion, writes, network or reports.
- **M19:** no additional player tool; extends M14 root allowlist and M16 JSON validator for exactly ijl15.dll/dbghelp.dll. Existing Windows dummy fixture tests expanded, no new permissions.
- **M20:** `tools/Inspect-Fixture-Recovery.ps1`: developer-only, read-only audit for M15 synthetic fixture journal+manifest after interruption. READY is a recovery *inspection*, not rollback or game repair.
- **M21:** M15's `Test-Client-Copy-Fixture.ps1` now supports `rolling_back` and injected rollback interruption for marked disposable fixtures only. Remaining confirmed rollback can be resumed; `Inspect-Fixture-Recovery.ps1` sees the new state. Not a player feature. 
- **M22:** `tools/Inspect-Fixture-Stage.ps1`: developer-only, read-only review of a single explicit disposable stage folder. M15 writes stage-owner metadata and keeps suspicious stages, not recursive cleanup.
- **M23:** M15 dummy-only copy adds `-SimulateAvailableDiskBytes`, `-SimulateDiskWriteFailureAfterStagedFiles`, and `-SimulateStagedFileMutationBeforePromotion`. All are explicitly confirmed Copy-only test switches; staged mutation never changes a real source.
- **M24:** M15 synthetic copy adds `-SimulateInterruptedStageOwnerWrite`, `-SimulateInterruptedJournalWrite`, and `-SimulateDestinationCollisionBeforePromotion`. Added fixtures check partial journal retention, invalid stage marker rejection, non-overwriting collision. No real-client copy.
- **M25:** `tools/Inspect-Fixture-Transaction-Status.ps1`: developer-only summary from M15/M20/M22 disposable fixtures, with explicit optional stage selection. Never scans siblings, saves a report, or performs cleanup.
- **M26:** `tools/Plan-Fixture-Recovery.ps1`: developer-only *read-only* recovery decision guidance from M25 output. No report file, rollback, deletion, copy or game-client writes.
- `tests/*.ps1`: Windows-only disposable synthetic fixtures. CI does not need any full WoW archive, personal data or actual large MPQs.

## 7. Test, packaging and branch workflow

1. Make changes to **`feature/backup-first-installer-alpha`**, preferably atomic multi-file commits; never edit the owner's personal game install.
2. Inspect and back up configuration or manifests before changing them; avoid rewriting immutable patch history.
3. Run `.github/workflows/validate-tools.yml` through PR CI. Windows runner uses **PowerShell 5.1** (watch compatibility: nested `Join-Path` when joining 3 parts, no PowerShell 7 syntax).
4. Review the *latest run's* fixture results, GUI headless tests and ZIP packaging. Do not claim success until CI reports **completed/success**.
5. From the latest Actions run, download artifact `naxxramas-launcher-preview`. Usually this is a GitHub Actions artifact containing `Naxxramas-Client-Preview.zip`. It does **not** include proprietary game archives or the owner's personal artwork.
6. Update **this handover document**, new milestone documentation, README and PR #1 description, preserving the verified last passing commit/run and explicit next action.
7. Keep draft PR and main unchanged unless owner explicitly wants a release or merge.

## 8. Current checkpoint and exactly where to resume

**Last verified implementation step:** M26 read-only human recovery decision planner `tools/Plan-Fixture-Recovery.ps1` translates validated M25 synthetic state classifications into fixed review advice without any rollback, deletion, installation, network activity or saved report; every result states `PERMITTED AUTOMATIC ACTIONS: NONE`. M26 test fixtures, prior rollback and staging safety suites, addons/patches, GUI smoke tests and preview ZIP packaging passed at implementation checkpoint `a01fb5ee35720c690d478bf89e69058206cc2ffd` in [run 38066008592](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38066008592). This is not a real WoW client installer. Prior M25 status inspector passed [run 38065169395](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38065169395).

**Previous step:** Milestone 14, read-only privacy-limited per-file inventory, commit `f69aa149`, successful CI run `38053138014`. Before that was Milestone 13, source classification, commit `d2016a9` and passing CI run `38051954866`.

**Current next task:** M26 read-only recovery decision planner and all existing Windows CI suites **passed** ([run 38066008592](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38066008592)). No owner test is needed. Next M27: isolated synthetic test-only true **external-process concurrent changes** to source, stage and destination between checks; refuse overwrites and preserve unexpected bytes. Do not claim real-world race freedom from the deterministic M24 injections. Preserve exact M15 markers, eight dummy paths, 1 MiB cap, no unpinned downloads/proprietary game files, disabled complete-client source, draft PR and explicit owner approval before merge.

**Remaining work after M14–M16:**
1. Owner first preserves an untouched full backup, then makes a **separate development copy**.
2. Owner runs new game file inventory against the development copy. Its local JSON must be reviewed before sharing and never committed; the files aren't copied.
3. Compare inventoried base candidates against known patchset V/Z/U; explicitly mark missing/unknown components. **Do not infer complete client validity from 21 MPQs or a partial allowlist.**
4. **Milestone 15 implements a first disposable synthetic-only copy/verify prototype** independent of the owner's real manifest. Once CI passes, inspect the gaps (partial crash recovery, filesystem races, large file support, audit coverage) before considering any real-client action.
5. Continue integrating independent pinned addon downloads, version checks and safe configuration updates.
6. Production full-client installation/download remains blocked pending a technically verified complete source and applicable redistribution authorisation.

## 9. Critical constraints and common pitfalls

- Preserve **backup-first**, no destructive overwrite, exact bytes recoverable, uninstall/revert and crash recovery.
- No internet-delivered executable or game archive from arbitrary URLs; only trusted pinned sources with SHA-256, size and separate staging.
- Differentiate **patch checksum verified** from **addon TOC present**.
- Current launcher has a single Browse per input, dark editable Ctrl+V path, **no Paste** buttons and no player artwork selector.
- Windows Forms PowerShell event closures require careful `.GetNewClosure()` usage; test blank path Browse and fake Windows GUI.
- Any current client inventory containing an unknown MPQ should not expose personal filenames in the published file list; unknown items need separate owner review.
- Never rely on previous chat's sandbox download URLs or expired files. Refresh artifacts via GitHub Actions; only link sandbox files created/verified in the current runtime.
- When the user says **“continue”**, resume from section 8 of this handover, inspect branch/CI, do substantive work, test it, and update this file.

**Owner-facing next instruction:** “Milestone 26 Windows validation passed. You do not need to test locally or rehash your WoW client. The decision planner produces only human review guidance for disposable fixtures. Next we will simulate true concurrent filesystem changes on fake files.”

---

*This document is part of the working repository and should be updated at every major milestone so a future chat can resume without depending on prior conversation history.*
