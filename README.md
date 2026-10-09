# Naxxramas Client Setup

Official setup and update project for the **Naxxramas World of Warcraft 3.3.5a server**.

> **Project status: preflight plus test-only backup/rollback alpha.** No production installer or downloadable game client is available yet.

## Purpose

The goal is to make joining the Naxxramas server straightforward for players who already have a legitimate, compatible **World of Warcraft 3.3.5a (build 12340)** installation.

Planned features:

- Guided connection setup, including a server-specific realmlist configuration.
- Installation and updating of **redistributable** Naxxramas-specific files.
- Validation of mandatory `patch-V.mpq` and `patch-Z.mpq`; optional Vanilla visual patches `Patch-J.mpq` and `Patch-U.mpq`.
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

The server owner requires **both `Data/patch-V.mpq` and `Data/patch-Z.mpq`** for a complete Naxxramas client installation. Neither may be skipped or disabled. `Data/Patch-J.mpq` is the optional login-screen patch (also including some loading-screen assets); `Data/Patch-U.mpq` is the optional loading-screen patch. Their two overlapping loading-screen paths require in-game compatibility testing when both options are selected.

The [patch policy manifest](config/client-patches.json) records those installer requirements. **It does not provide or license the MPQ files.** No installer has been implemented yet.

## Test-only local installer alpha

A transaction prototype is under development in `tools/Setup-Prototype.ps1`. It plans patch/realmlist changes and selected local N Addon Suite folders, stages files, backs up originals, and supports interrupted-session recovery and rollback in disposable test fixtures. **All write operations are deliberately locked to disposable test fixtures**, not real game installations. See [Milestone 2](docs/INSTALLER-MILESTONE-2.md) and [Milestone 3 safety checks](docs/INSTALLER-MILESTONE-3.md).

## Approved addon ZIP fingerprint (local verification only)

The N Addon Suite v2.0.0 release metadata specifies SHA-256 `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324` for its `N-Addon-Collection-v2.0.0.zip`. The expected bytes and checksum are stored in [addon-suite.json](config/addon-suite.json).

Drag the **locally downloaded official ZIP** onto `tools/Verify-Addon-Release.bat` to verify it against the pinned reference without installing anything. **An extracted folder is not yet authenticated against this ZIP**. The working installer remains limited to synthetic test fixtures.

## Offline verified addon ZIP extraction

The [Milestone 4 extractor](docs/INSTALLER-MILESTONE-4.md) validates the approved v2.0.0 addon archive and can extract only the five approved folders to a **new folder outside the WoW client**. Default is a read-only preview; extraction requires `-Extract`. A verification report is recorded for inspection, but the folder is not automatically trusted as a future installation source. The [Milestone 5 test installer](docs/INSTALLER-MILESTONE-5.md) can now take the **verified ZIP directly** and stage selected addons from it, without relying on an extracted directory.

## Read-only preflight tools

Download the repository ZIP and drag your WoW folder onto `tools/Check-Naxxramas-Client.bat` to check mandatory patches and client structure. V/Z reference fingerprints are now recorded as `patchset-0001` from the owner's 9 October 2026 hash report. Use `tools/Get-Core-Patch-Hashes.bat` to independently check locally held copies. These tools only read files; **they do not install or modify anything**. The preflight displays the active patchset reference, validates mandatory V/Z hashes, and reports existing optional J/U patches separately from selected installation options.

See [Installer Development — Milestone 1](docs/INSTALLER-MILESTONE-1.md) for the exact steps, caveats, and the next implementation phase.

## Updating core and optional patches

When patch-V, patch-Z, Patch-J or Patch-U changes, **do not rename a patch or overwrite its old version record**. Download a fresh repository copy and drag the folder containing `Wow.exe` onto `tools/Prepare-Patch-Update.bat`. This generates `tools/patch-update-proposal.json` (hashes, sizes and proposed next version only; no game binaries, personal paths or automatic uploads). Send the proposal for review, test the patched client, and then commit the new reference plus an immutable history entry. See [Patch Updates](docs/PATCH-UPDATES.md). The application updater/rollback system is **not implemented yet**.

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
