# Naxxramas Client Setup — Project Handover

**Purpose:** Permanent continuation reference for future chats, maintainers, and development sessions. **Read this document first** when starting again after context loss. Update the *Current checkpoint*, *Completed work*, *Open decisions* and *Next steps* whenever a milestone or recovery fix is completed. Keep it in the repository, not only in a conversation.

**Status as of 10 October 2026:** Milestone 14 has passed Windows CI. **Milestone 15 is implementing a strictly synthetic fixture-only copy/verify/rollback experiment.** Do not treat it as complete until the new Windows CI run is green. No full-game download, public client or production installation is enabled.

## 1. Project and critical GitHub links

- **Main repository:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup
- **Development branch:** `feature/backup-first-installer-alpha`
- **Draft PR #1:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/pull/1
- **GitHub Actions:** https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/workflows/validate-tools.yml
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
| **M15 — in CI** | Disposable **synthetic-only** copy/verify/rollback prototype: strict test markers, manifest type, tiny-file size cap, separate staging, SHA-256 verification, journal and rollback, failure injection. Not a real WoW installer. |

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

**Last verified implementation step:** Milestone 14, read-only allowlisted per-file game binary/MPQ inventory and privacy-focused tests, commit `f69aa149` and passing Windows Actions run `38053138014`.

**Previous step:** Milestone 13, source classification report, commit `d2016a9`, passing Actions run `38051954866`.

**Current next task:** Verify the new Milestone 15 Windows CI run, record its green run and commit here, then ask the owner to scan a **separate backed-up development copy** with M14's `Inventory-Game-Files.bat` and send the private `game-files-*.json` for real-client coverage analysis. Milestone 15 copy testing uses *only generated dummy fixtures* and must not accept the owner's real-client inventory.

**After M14 (next milestone):
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

**Owner-facing next instruction:** “Back up your working client, create a separate development copy, then drag its containing folder onto `tools/Inventory-Game-Files.bat`. The SHA-256 scan of the 17+ GiB client may take several minutes. Review the local `game-files-*.json` file before sending it privately here.”

---

*This document is part of the working repository and should be updated at every major milestone so a future chat can resume without depending on prior conversation history.*
