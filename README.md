# Naxxramas Client Setup

Official setup and update project for the **Naxxramas World of Warcraft 3.3.5a server**.

> **Project status: preflight plus test-only backup/rollback alpha.** No production installer or downloadable game client is available yet.

## Purpose

The goal is to make joining the Naxxramas server straightforward for players who already have a legitimate, compatible **World of Warcraft 3.3.5a (build 12340)** installation.

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

The path selectors support a dedicated **Paste** button for folder and addon ZIP paths copied from Windows File Explorer, including quoted **Copy as path** entries. You can also enter or paste directly into the dark path fields using Ctrl+V. Invalid or missing folders show a helpful message instead of an unhandled exception.

A first Windows graphical interface is available at `tools/Launch-Naxxramas-Preview.bat`. It allows users to select their existing client, an optional separate patch source, and a locally downloaded official N Addon Suite ZIP; choose optional Vanilla or TBC login visuals, Vanilla loading screens, and addon modules; and run a **read-only installation preview** or transaction-state inspection. Large file checks run in the background. The interface has **no Install, Apply or Rollback** action for real clients. An explicit **Get patches** action downloads validated files only into a separate source folder, never into the game. A confirmation dialog appears before network access or writing sources.

See [Milestone 7: Windows GUI preview](docs/INSTALLER-MILESTONE-7.md). This is a **development preview**, not a finished player installer. It uses Windows PowerShell 5.1 and WinForms; Windows CI validates window construction at narrow and wide sizes without showing it. The preview now supports Tab navigation, Alt+P / Alt+I shortcuts, Escape to close and cancelling a running check.

## Classic-era launcher redesign (preview)

The graphical preview now follows the familiar *classic WoW launcher* arrangement: a large hero-art panel and framed news/verification log on the left, compact setup choices on the right, and a fixed row of launcher-style controls with a prominent **PREVIEW** button. The main window no longer scrolls as a long form; the narrow right-hand options panel and verification log scroll independently when needed.

The launcher displays a single owner-managed image: `assets/default/launcher-art.png` (and an optional `launcher-logo.png`). To change the artwork in a future release, replace the file using the **same filename** and rebuild the ZIP. There are no player-facing artwork buttons, overrides or status messages. Do not distribute imagery without appropriate rights.

A Windows CI job produces a **downloadable preview ZIP artifact** once its tests pass. The ZIP includes scripts and configuration but does not contain a WoW client, MPQs, Blizzard logos or other proprietary artwork; it cannot install files. See [Milestone 8](docs/INSTALLER-MILESTONE-8.md).

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
