# Naxxramas Client Setup

**[PROJECT HANDOVER — read this first when resuming development](docs/PROJECT-HANDOVER.md)**  
This is the permanent source of truth for the aim, prior milestones, latest work, safety requirements, GitHub state, testing, and precise next steps. Update it whenever a substantial milestone is completed.

Official setup and update project for the **Naxxramas World of Warcraft 3.3.5a server**.

> **Project status: preflight plus test-only backup/rollback alpha.** No production installer or downloadable game client is available yet.

## Purpose

**Fresh-client setup is now a separate planned workflow.** The GUI provides **Existing client** and **Fresh client - planning only** choices. Fresh mode lets the user select an empty destination, preview all planned components, and see why complete-client downloading is blocked pending verified redistribution authorisation. Existing-client patch downloads remain available; no real-client installation is enabled.

[Milestone 11: fresh-client planning and source requirements](docs/INSTALLER-MILESTONE-11.md). The full-game source is **not configured**, and the repo does not contain a copy of WoW.

The finished launcher is intended for **two player journeys**: setting up a complete authorised World of Warcraft 3.3.5a (build 12340) client from scratch, or preparing an existing compatible client. Both will add the Naxxramas patches, addons and realmlist. **At present only the existing-client preparation tools and a read-only fresh-client plan exist**; downloading the base game is blocked until a legitimate redistributable source is validated.

Planned features:

- Guided connection setup, including a server-specific realmlist configuration.
- Installation and updating of **redistributable** Naxxramas-specific files.
- Validation of mandatory `patch-V.mpq` and `patch-Z.mpq`; optional Vanilla/TBC visual patches `Patch-J.mpq`, `Patch-C.mpq` and `Patch-U.mpq`.
- Optional installation of supported Naxxramas addons.
- Version checks, backups, and a clear way to undo installer changes.
- Simple instructions, including support for less technical players.

## Important: what this repository does not contain

This repository is **not** a full World of Warcraft client download. Do not upload the original game installation, Blizzard's proprietary game archives, or modified game assets without the required redistribution rights.

Do not commit personal game settings, account data, screenshots, logs, or the owner's 18.6 GB client archive. The `.gitignore` includes protective exclusions, but it is **not** a substitute for reviewing files before committing.

## Verified reference client (your working V/Z copy)

The owner-provided sanitised JSON report confirms **WoW 3.3.5a build 12340**, required **Patch V and Patch Z verified**, and optional **Patch U also verified**. Optional login patches **J and C are absent**. The five inspected addon TOC files—**NCore, IndividualProgressionAddon, DungeonJournal, MultiBot and NaxxLootLottery**—are already **present**, although **their versions and package integrity are not verified**. There are 21 MPQs totalling 17,773,795,353 bytes, which is an aggregate rather than a verified clean-client file manifest.

The new `tools/Inspect-Reference-Client.bat` reads the existing client, checks `Wow.exe` build 12340 and the pinned V/Z hashes, and creates a **sanitised JSON report** in the launcher `tools` folder. It records **presence only** for optional patches and NCore/addons. It never opens or exports `WTF`, SavedVariables, Cache, screenshots, account names, realmlist content or absolute client paths. It never modifies game files.

**Before using it, make a separate backup of your known-working game client.** Drag the folder containing `Wow.exe` onto `Inspect-Reference-Client.bat`, then review the `client-reference-*.json` report. See [Milestone 12](docs/INSTALLER-MILESTONE-12.md). Never upload the complete game client or private settings to this repository.

## Disposable synthetic client copy verification (Milestone 15)

The new `tools/Test-Client-Copy-Fixture.ps1` is a **fixture-only** copy/verify/rollback prototype. It accepts only **purpose-made dummy files smaller than 256 KiB each**, a manifest explicitly marked synthetic, and two folders containing exact independent test markers. An empty destination and explicit confirmation are required. The tool stages into a separate temporary folder, verifies source/staged/destination SHA-256 hashes, records file ownership, refuses to overwrite any existing data, and supports verified rollback. **It cannot copy a real game client**, and is not wired to the player launcher.

See [Milestone 15](docs/INSTALLER-MILESTONE-15.md). We are deliberately testing the safety mechanisms before permitting any live-client writes. The owner's private `game-files-*.json` is still needed to improve coverage of the actual local client.

## Safe game-file inventory (Milestone 14)

Use `tools/Inventory-Game-Files.bat` against a **backed-up development copy** of the 3.3.5a client. It produces a private per-file report of a restricted set of game executables and MPQ archives, with SHA-256 hashes by default. The game files are read-only, and the report is created outside the game. Personal directories (`WTF`, `Cache`, `Screenshots`, addon SavedVariables) are never scanned. This **is not yet a verified complete base-client inventory**; files outside the deliberately limited allowlist are not included. Use `-Quick` from PowerShell for sizes-only results, which do not prove file identity. See [Milestone 14](docs/INSTALLER-MILESTONE-14.md).

## Reference component separation (Milestone 13)

Use `tools/Plan-Reference-Components.bat` with a sanitised `client-reference-*.json` report to generate a **read-only component plan**. It distinguishes base-game files that remain unidentified, mandatory V/Z, optional J/C/U, NCore, optional addons and the realmlist without touching the client.

The planner **reuses verified patches** where appropriate, **preserves unselected existing addons and visuals**, and never treats an addon folder as proof that its release is current. If a future selection conflicts with another login MPQ or a required patch is mismatched, the plan displays a blocker rather than overwriting files. See [Milestone 13](docs/INSTALLER-MILESTONE-13.md). The tool has **no install or download action**.

## First step: inspect the existing client safely

The included inventory tool lists filenames and approximate sizes only. It does **not** read the contents of account settings, saved variables, passwords, or realm configuration.

1. Download this repository as a ZIP and extract it somewhere **outside** your game installation.
2. In the extracted folder, open `tools`.
3. **Drag your current WoW client folder onto `Inspect-Client.bat`.**
4. The tool writes `tools/client-inventory.txt`.
5. Review that text file, then share it privately with the project maintainer for planning.

The tool does not alter the WoW installation and does not upload any files. See [client inventory guide](docs/CLIENT-SETUP.md).

## Server connection

The owner-provided [realmlist configuration](config/realm.json) defaults to `set realmlist 85.190.254.242` for the enUS client (`Data/enUS/realmlist.wtf`). The read-only checker now reports whether a selected client's realmlist matches this setting. A public network connectivity check has not been performed. See [Realmlist setup](docs/REALMLIST.md), including a [manual template](templates/realmlist.wtf) and backup instructions.

## Core and optional client patches

The server owner requires **both `Data/patch-V.mpq` and `Data/patch-Z.mpq`** for a complete Naxxramas client installation. Neither may be skipped or disabled. `Data/Patch-J.mpq` provides the optional Vanilla login screen, `Data/Patch-C.mpq` provides the optional Burning Crusade Dark Portal login screen, and `Data/Patch-U.mpq` adds Vanilla loading screens. **Never combine J and C**: they replace the same login-screen system. U can accompany either J or C. J/U have overlapping loading textures whose combined priority requires in-game testing. A pre-existing conflicting login MPQ blocks a new selection; the test installer never silently deletes it.

The [patch policy manifest](config/client-patches.json) records those installer requirements. **It does not provide or license the MPQ files.** No installer has been implemented yet.

## Verified patch source downloads (development)

Milestone 10 adds a separate **patch-source download tool**, not an installer. It uses pinned GitHub Releases for V (v1.0.6.8.4), Z (v1.0.6.7), and optional J/C/U (optional-v1.0). All five URLs and their published digests were checked against `patchset-0002`.

`tools/Get-Patch-Sources.ps1` defaults to an entirely read-only download plan. Its explicit `-Action Download -ConfirmDownload` option saves only missing, hash-verified MPQs to a **separate directory outside both the game and the launcher**. It never overwrites a mismatched source, never writes to the game folder, and never changes existing client patches. See [Milestone 10](docs/INSTALLER-MILESTONE-10.md) for how to use it and how to troubleshoot download failures.

## Test-only local installer alpha

A transaction prototype is under development in `tools/Setup-Prototype.ps1`. It plans patch/realmlist changes and selected local N Addon Suite folders, stages files, backs up originals, and supports interrupted-session recovery and rollback in disposable test fixtures. **All write operations are deliberately locked to disposable test fixtures**, not real game installations. See [Milestone 2](docs/INSTALLER-MILESTONE-2.md) and [Milestone 3 safety checks](docs/INSTALLER-MILESTONE-3.md).

## Approved addon ZIP fingerprint (local verification only)

The N Addon Suite v2.0.0 release metadata specifies SHA-256 `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324` for its `N-Addon-Collection-v2.0.0.zip`. The expected bytes and checksum are stored in [addon-suite.json](config/addon-suite.json).

Drag the **locally downloaded official ZIP** onto `tools/Verify-Addon-Release.bat` to verify it against the pinned reference without installing anything. **An extracted folder is not yet authenticated against this ZIP**. The working installer remains limited to synthetic test fixtures.

## Offline verified addon ZIP extraction

The [Milestone 4 extractor](docs/INSTALLER-MILESTONE-4.md) validates the approved v2.0.0 addon archive and can extract only the five approved folders to a **new folder outside the WoW client**. Default is a read-only preview; extraction requires `-Extract`. A verification report is recorded for inspection, but the folder is not automatically trusted as a future installation source. The [Milestone 5 test installer](docs/INSTALLER-MILESTONE-5.md) can now take the **verified ZIP directly** and stage selected addons from it, without relying on an extracted directory.

## Transaction state inspection

The [Milestone 6 recovery inspection](docs/INSTALLER-MILESTONE-6.md) adds read-only diagnostics for damaged or incomplete installation journals. Drag an existing WoW client folder onto `tools/Inspect-Naxxramas-State.bat` to inspect recorded setup state without modifying it. File-writing operations remain restricted to disposable fixtures.

## Windows graphical preview (development only)

The path fields are directly editable. Click a dark field and press **Ctrl+V** to paste a path from File Explorer, including a quoted **Copy as path** value. The launcher strips surrounding quotation marks when you leave the field. Each location keeps only a single **Browse** button for a cleaner look.

A first Windows graphical interface is available at `tools/Launch-Naxxramas-Preview.bat`. It allows users to select their existing client, an optional separate patch source, and a locally downloaded official N Addon Suite ZIP; choose optional Vanilla or TBC login visuals, Vanilla loading screens, and addon modules; and run a **read-only installation preview** or transaction-state inspection. Large file checks run in the background. The interface has **no Install, Apply or Rollback** action for real clients. An explicit **Get patches** action downloads validated files only into a separate source folder, never into the game. A confirmation dialog appears before network access or writing sources.

See [Milestone 7: Windows GUI preview](docs/INSTALLER-MILESTONE-7.md). This is a **development preview**, not a finished player installer. It uses Windows PowerShell 5.1 and WinForms; Windows CI validates window construction at narrow and wide sizes without showing it. The preview now supports Tab navigation, Alt+P / Alt+I shortcuts, Escape to close and cancelling a running check.

## Classic-era launcher redesign (preview)

The graphical preview now follows the familiar *classic WoW launcher* arrangement: a large hero-art panel and framed news/verification log on the left, compact setup choices on the right, and a fixed row of launcher-style controls with a prominent **PREVIEW** button. The main window no longer scrolls as a long form; the narrow right-hand options panel and verification log scroll independently when needed.

The launcher displays a single owner-managed image: `assets/default/launcher-art.png` (and an optional `launcher-logo.png`). To change the artwork in a future release, replace the file using the **same filename** and rebuild the ZIP. There are no player-facing artwork buttons, overrides or status messages. Do not distribute imagery without appropriate rights.

A Windows CI job produces a **downloadable preview ZIP artifact** once its tests pass. The ZIP includes scripts and configuration but does not contain a WoW client, MPQs, Blizzard logos or other proprietary artwork; it cannot install files. See [Milestone 8](docs/INSTALLER-MILESTONE-8.md).

## Milestone 16 — Private game-file report review

After running the Milestone 14 file inventory on a **backed-up development client**, drag the resulting private **game-files-*.json** onto **tools/Review-Game-File-Report.bat**. This checks the report against its pinned V/Z/J/C/U patch policy and detects inconsistent or private file entries **without reading WoW game files**. It does not verify every base-game file or enable installation. See [Milestone 16](docs/INSTALLER-MILESTONE-16.md).

## Milestone 17 — Read-only local MPQ classification

The owner's private full-hash report is internally consistent: **23 allowlisted files, 16 base archive candidates, required V/Z plus optional U verified, and 2 unclassified MPQ filenames**. No private report has been committed. To inspect the two unclassified names without uploading files, drag a **separate backed-up development client** onto `tools/Inspect-Unclassified-MPQs.bat`. It only displays filenames and byte sizes locally and writes nothing. See [Milestone 17](docs/INSTALLER-MILESTONE-17.md). It is not a full-client verification or installer.

### Expanded enUS MPQ filename coverage

The owner's local-only scan identified `Data/enUS/base-enUS.MPQ` and `Data/enUS/backup-enUS.MPQ`. Updated **read-only** tools recognise both as **unpinned base archive candidates**, not authenticated clean-client assets. An unchanged reference copy is now expected to have 25 allowlisted files (21 MPQs plus four binaries); this is a projection until a fresh scan. Do not delete either archive or publish a private inventory. See [Milestone 17](docs/INSTALLER-MILESTONE-17.md).

## Milestone 18 — Read-only non-MPQ support-file audit

Now that the MPQ filename count is reconciled, the next work is checking **non-MPQ support-file candidates**. The new `tools/Inspect-Client-Support-Files.bat` checks only 13 fixed root file names and four directory-presence flags on a **separate backed-up development client**. It reads only presence/size metadata, never file contents, addon data, account settings, paths or hashes; there is no report, network access or client write. Absent optional candidates are not automatically problems. [Milestone 18 guidance](docs/INSTALLER-MILESTONE-18.md).

## Milestone 19 — Two support DLLs added to private inventory coverage

The owner's M18 read-only audit found six candidate root files and all four directory checks present. Seven other candidates were not present; this is **not** a failure. The scanner and JSON reviewer now explicitly recognise **`ijl15.dll`** and **`dbghelp.dll`** as unpinned root binary candidates. If the development client has not changed, a future report should contain **27 allowlisted files**; that is a prediction rather than a fresh verified scan. No installer/client writes or full-client downloads are enabled. See [Milestone 19](docs/INSTALLER-MILESTONE-19.md).

## Milestone 20 — Read-only synthetic interrupted-copy recovery audit

A new developer-only `tools/Inspect-Fixture-Recovery.ps1` inspects the status of an intentionally **disposable, marker-locked** M15 copy fixture after a simulated interruption. It checks expected files, hashes, journal ownership and unexpected destination entries, and returns **READY_FOR_MANUAL_ROLLBACK** or **BLOCKED**. It does not perform rollback, cleanup, writes, real WoW installation or download, and does not scan player folders. See [Milestone 20](docs/INSTALLER-MILESTONE-20.md). No action is needed from the client owner.

## Milestone 21 — Resumable synthetic-only rollback

The M15 **disposable dummy-file** copy prototype can now mark rollback as `rolling_back` before deletion, pause after an injected interruption, and resume only after another explicit confirmation. It rejects unexpected empty folders, changed files and leftover journal-replacement sidecars. The M20 read-only recovery inspector recognises the new state. **No real WoW client files are affected** and no installer downloads are enabled. See [Milestone 21](docs/INSTALLER-MILESTONE-21.md).

## Milestone 22 — Orphan stage inspection (disposable fixtures only)

New synthetic copy stages contain an explicit owner marker, and stage cleanup no longer uses uncontrolled recursive deletion. A separate developer-only `tools/Inspect-Fixture-Stage.ps1` examines **one nominated stage** read-only, checking ownership metadata, file hashes and unexpected contents, but never deletes anything. Orphan cleanup remains a future manual workflow. [Milestone 22 documentation](docs/INSTALLER-MILESTONE-22.md).

## Read-only preflight tools

Download the repository ZIP and drag your WoW folder onto `tools/Check-Naxxramas-Client.bat` to check mandatory patches and client structure. V/Z reference fingerprints are retained in `patchset-0001`; the new optional TBC reference is recorded in `patchset-0002` from the owner's 9 October 2026 hash report. Use `tools/Get-Core-Patch-Hashes.bat` to independently check locally held copies. These tools only read files; **they do not install or modify anything**. The preflight displays the active patchset reference, validates mandatory V/Z hashes, and reports existing optional J/C/U patches separately from selected installation options.

See [Installer Development — Milestone 1](docs/INSTALLER-MILESTONE-1.md) for the exact steps, caveats, and the next implementation phase.

## Updating core and optional patches

When patch-V, patch-Z, Patch-J, Patch-C or Patch-U changes, **do not rename a patch or overwrite its old version record**. Download a fresh repository copy and drag the folder containing `Wow.exe` onto `tools/Prepare-Patch-Update.bat`. This generates `tools/patch-update-proposal.json` (hashes, sizes and proposed next version only; no game binaries, personal paths or automatic uploads). Send the proposal for review, test the patched client, and then commit the new reference plus an immutable history entry. See [Patch Updates](docs/PATCH-UPDATES.md). The application updater/rollback system is **not implemented yet**.

## Current client review

We reviewed the owner's read-only inventory and inspected the contents of both optional MPQ archives on 9 October 2026. See [Client inventory review](docs/CLIENT-INVENTORY-REVIEW.md) for the custom patch candidates, addon selection rules, and the remaining checks before an installer can be safely built.

## Development roadmap

1. Identify the working client's folder structure and required custom modifications.
2. Create an allowlist of files we are permitted to distribute.
3. Build a backup-first installer that works against an existing client copy.
4. Test install, update, rollback, and uninstall on a disposable copy.
5. Publish versioned installer releases and documentation after validation.

## Other Naxxramas projects

- [Naxxramas Resource Hub](https://github.com/CosmicCuddle/Naxxramas-Resource-Hub)
- [N-Addon-Collection](https://github.com/CosmicCuddle/N-Addon-Collection)

This project is independent of the AzerothCore server repository and does not modify server-side code.
