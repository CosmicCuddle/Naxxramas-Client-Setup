# Naxxramas Client Setup

Official setup and update project for the **Naxxramas World of Warcraft 3.3.5a server**.

> **Project status: read-only client checks and installer-plan preview prototype.** There is no finished installer or downloadable game client in this repository yet. Windows PowerShell 5.1 synthetic fixture suites passed on 10 October 2026; actual install/update/rollback are not implemented.

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

## Read-only preflight tools

Download the repository ZIP and drag your WoW folder onto `tools/Check-Naxxramas-Client.bat` to check mandatory patches and client structure. V/Z reference fingerprints are now recorded as `patchset-0001` from the owner's 9 October 2026 hash report. Use `tools/Get-Core-Patch-Hashes.bat` to independently check locally held copies. These tools only read files; **they do not install or modify anything**. The preflight displays the active patchset reference, validates mandatory V/Z hashes, and reports existing optional J/U patches separately from selected installation options.

See [Installer Development — Milestone 1](docs/INSTALLER-MILESTONE-1.md) for the exact steps, caveats, and the next implementation phase.

## Read-only installer plan (Milestone 2)

The new **[installer-plan preview](docs/INSTALLER-PLAN.md)** describes what an eventual setup *might* need to do. Drag a WoW folder onto `tools/Plan-Naxxramas-Install.bat` to preview the existing client without changing any files. A separate local patch source and optional J/U selections are supported through `tools/Plan-Naxxramas-Install.ps1`. The preview can classify current, missing, known older or unrecognised patches, check the realmlist, and show backups and blockers.

This script **does not install, download, copy, repair, replace or remove any game files**. Windows PowerShell synthetic fixture tests have passed. An optional `-BackupRoot` argument can check an **existing backup folder** for safe location and estimated capacity, including separate-drive budgets; see [Installer Plan](docs/INSTALLER-PLAN.md). These checks are approximate and do not approve an installation or distribution.

## Read-only recovery preview (Milestone 3 foundation)

The [Recovery Preview](docs/RECOVERY-PREVIEW.md) can inspect **synthetic development session records** and compare saved hashes, original backups and current files to show where a future rollback would encounter conflicts. The script is `tools/Review-Naxxramas-Recovery.ps1`. Windows PowerShell fixture tests passed on 10 October 2026. **It does not restore, delete, replace or change files, and no production installer creates session records yet.**

## Updating core and optional patches

When patch-V, patch-Z, Patch-J or Patch-U changes, **do not rename a patch or overwrite its old version record**. Download a fresh repository copy and drag the folder containing `Wow.exe` onto `tools/Prepare-Patch-Update.bat`. This generates `tools/patch-update-proposal.json` (hashes, sizes and proposed next version only; no game binaries, personal paths or automatic uploads). Send the proposal for review, test the patched client, and then commit the new reference plus an immutable history entry. See [Patch Updates](docs/PATCH-UPDATES.md). The application updater/rollback system is **not implemented yet**.

## Current client review

We reviewed the owner's read-only inventory and inspected the contents of both optional MPQ archives on 9 October 2026. See [Client inventory review](docs/CLIENT-INVENTORY-REVIEW.md) for the custom patch candidates, addon selection rules, and the remaining checks before an installer can be safely built.

## Development roadmap and project handover

The detailed, continuously updated project records are:

- [Development Roadmap](docs/ROADMAP.md) — milestones, acceptance criteria, test gates and current next task.
- [Project Handover](docs/PROJECT-HANDOVER.md) — confirmed decisions, exact patch rules, implemented and untested features, backup policy and session continuation log.

**Current next task:** review a versioned and authenticated journal format in [Journal Authority](docs/JOURNAL-AUTHORITY.md), verify authoritative Windows volume identity, and settle [Journal Durability](docs/JOURNAL-DURABILITY.md) before any separately reviewed fixture-only write experiment. The installer planner and recovery inspector remain **read-only**; actual installation, updating and rollback are still unimplemented. Keep both documents updated with every meaningful code or policy change.

## Other Naxxramas projects

- [Naxxramas Resource Hub](https://github.com/CosmicCuddle/Naxxramas-Resource-Hub)
- [N-Addon-Collection](https://github.com/CosmicCuddle/N-Addon-Collection)

This project is independent of the AzerothCore server repository and does not modify server-side code.
