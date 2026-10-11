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

This script **does not install, download, copy, repair, replace or remove any game files**. Windows PowerShell synthetic fixture tests have passed. An optional `-BackupRoot` argument can check an **existing backup folder** for safe location and estimated capacity, including distinct logical Windows-volume budgets; see [Installer Plan](docs/INSTALLER-PLAN.md) and [Volume Preflight](docs/WINDOWS-VOLUME-PREFLIGHT.md). These checks are approximate and do not approve an installation or distribution.

## Read-only recovery preview (Milestone 3 foundation)

The [Recovery Preview](docs/RECOVERY-PREVIEW.md) can inspect **synthetic development session records** and compare saved hashes, original backups and current files to show where a future rollback would encounter conflicts. The script is `tools/Review-Naxxramas-Recovery.ps1`. Windows PowerShell fixture tests passed on 10 October 2026. **It does not restore, delete, replace or change files, and no production installer creates session records yet.**

## Read-only Windows folder identity (developer-only)

The [Windows Directory Identity preview](docs/WINDOWS-DIRECTORY-IDENTITY.md) observes a selected local directory's Windows filesystem ID through a **read-only directory handle**. Synthetic Windows tests confirm that renaming the same folder preserves its identity, while an identical copied folder has a different identity. Unsafe paths are rejected. The result is **not** a secure registration or installer ownership proof. There is no file-writing installer or rollback engine.

## Read-only original backup readiness (developer-only)

The [Original Backup Readiness Review](docs/BACKUP-ORIGINALS-READINESS.md) combines the existing **live installer planner** with the real Windows **read-only open-file handle** inventory to list precisely which recognized existing patch or realmlist files a future installer would have to back up before replacing them. It compares planned original hashes against observed file contents, checks selected local source patches and reuses the selected separate backup directory and capacity preflight. Windows synthetic fixtures cover recognized old V, differing realmlist, new Z, missing/invalid sources and no write to backup directory. Every candidate is explicitly **`NOT_CREATED`**, not a backup.

## Read-only Windows open-file handle inspection (developer-only)

The [Open-file Handle Review](docs/OPEN-FILE-HANDLE-REVIEW.md) inspects exactly the allowed client V/Z/J/U/realmlist files or local source V/Z/J/U files on Windows using **read-only handles held throughout hashing**. It observes the same open handles' Win32 file IDs and SHA-256, detects incompatible active writers, rejects junctions, and warns if mandatory V/Z is missing. Windows CI tests use only fake tiny files. The scanner **does not modify files, hold locks after finishing, create backups, prove ownership or approve installation**.

## Two-pass live inspection consistency (developer-only)

The [Live Plan Recheck](docs/LIVE-PLAN-RECHECK.md) now performs **two complete sequential planner and Win32 directory identity inspections**, refusing snapshot capture if they disagree. Windows CI triggers a change to a **disposable fake realmlist** between passes and confirms the reviewer detects it. This remains read-only and not atomic: matching scans cannot exclude later edits or A–B–A races, nor do they authenticate approval or authorise an installation.

## Live read-only plan recheck (developer-only)

The [Live Plan Recheck](docs/LIVE-PLAN-RECHECK.md) now connects the **actual local read-only installer planner** and **Win32 directory identity** inspector. It prints an unsigned plan/folder snapshot to stdout or compares a previously held snapshot against fresh hashes and Win32 directory IDs. Windows synthetic filesystem tests cover changed core bytes, realmlist and options, source/backup folder swaps and preflight blockers. It never writes client data or authenticates installation approval.

## Read-only single-use consent lifecycle (developer-only)

The [Consent Lifecycle Review](docs/CONSENT-LIFECYCLE-REVIEW.md) tests a hypothetical issued → approved → use_started → finished receipt and revocation/expiry paths using **only synthetic JSON**. Windows tests detect repeated use, incorrect nonce/plan hash, changed claimed plan and invalid transitions. No actual player consent, Windows key, protected used-token state, automatic installation or rollback exists. Even a caller-forged unused approval is **NOT authenticated**.

## Read-only v2 approval plan digest (developer-only)

[Approval Plan Digest v2](docs/APPROVAL-PLAN-DIGEST-V2.md) adds **unkeyed SHA-256 of a validated synthetic plan**, checks stale or falsified frozen snapshots, and keeps legacy v1 fixture support. New Windows regressions verify the canonical digest against an independent known value. The hash is **not authenticated consent**; a caller who can replace both JSON records can compute a new matching hash. No real-game files or installation permissions are involved.

## Read-only frozen approval snapshot review (developer-only)

The [Approval Snapshot Review](docs/APPROVAL-SNAPSHOT-REVIEW.md) tests whether two **untrusted synthetic JSON records** agree on selected client/backup/source identity, mandatory V/Z, optional J/U, realmlist, patchset, source hashes and originals. It rejects stale, revoked, missing or changed consent claims and invalid file/backup actions. A matching test record is **NOT authenticated user consent** and cannot authorise writes or distribution. The Windows tests never touch an actual WoW client.

## Read-only trust continuity and migration review (developer-only)

The [Trust Continuity Review](docs/TRUST-CONTINUITY-REVIEW.md) models lost keys, different Windows accounts/computers, copied clients, damaged backups and stale recovery anchors using **untrusted synthetic JSON only**. Windows tests confirm all problems are reported independently and **never** enable writing, automatic resume, rollback or silent client re-registration. Neither DPAPI nor real WoW files are accessed; a coherent replay of all old records remains outside the trust guarantees.

## Read-only checkpoint ordering review (developer-only)

The [Checkpoint Ordering Review](docs/CHECKPOINT-ORDER-REVIEW.md) tests 13 proposed backup, replacement, journal and latest-anchor stages using **synthetic JSON**. Missing/out-of-order checkpoints, lagging/ahead anchor claims and key-loss labels lead to manual-review classifications. Even a fully matching fixture **never authorises installation, resume or rollback**. Windows flush, signing and anti-rollback protections are still unimplemented.

## Read-only V/Z crash-boundary checks (developer-only)

The [V/Z Crash Boundary Fixtures](docs/CRASH-BOUNDARY-FIXTURES.md) classify fabricated interruption states before backup, after backup, between required patches and before the final journal checkpoint. They refuse automatic install, resume and rollback for **every** result. The input is untrusted JSON—not an actual client, recovered backup or authenticated journal. Windows tests use only throwaway fixtures and do **not** prove crash durability.

## Synthetic registration and interruption checks (developer-only)

The [registration fixture review](docs/REGISTRATION-FIXTURE-REVIEW.md) combines the existing **read-only Windows folder identity observation** with deliberately unsigned, caller-controlled test registration and session records. Synthetic Windows tests cover copied and renamed folders, missing records, mismatched or stale sequences and interrupted checkpoints. Even when values match, the output explicitly **never authorises installation or rollback**; it is not a secure registration service or crash-safe journal.

## Synthetic signed journal checks (developer-only)

The [signed journal v2 fixture](docs/JOURNAL-V2-FIXTURE.md) demonstrates **read-only** HMAC/event-chain checks and an optional **independently keyed synthetic witness** on generated records in Windows PowerShell. A newer, separately retained witness detects an older journal and its old anchor, but replaying all inputs together remains possible. It does not create trusted installation records or verify ownership of any real client. No DPAPI-protected key, durable replay-proof anchor, write-capable installer or rollback engine exists. This developer tool is separate from the existing recovery preview and **must not be used to justify file changes**.

## Updating core and optional patches

When patch-V, patch-Z, Patch-J or Patch-U changes, **do not rename a patch or overwrite its old version record**. Download a fresh repository copy and drag the folder containing `Wow.exe` onto `tools/Prepare-Patch-Update.bat`. This generates `tools/patch-update-proposal.json` (hashes, sizes and proposed next version only; no game binaries, personal paths or automatic uploads). Send the proposal for review, test the patched client, and then commit the new reference plus an immutable history entry. See [Patch Updates](docs/PATCH-UPDATES.md). The application updater/rollback system is **not implemented yet**.

## Current client review

We reviewed the owner's read-only inventory and inspected the contents of both optional MPQ archives on 9 October 2026. See [Client inventory review](docs/CLIENT-INVENTORY-REVIEW.md) for the custom patch candidates, addon selection rules, and the remaining checks before an installer can be safely built.

## Development roadmap and project handover

The detailed, continuously updated project records are:

- [Development Roadmap](docs/ROADMAP.md) — milestones, acceptance criteria, test gates and current next task.
- [Project Handover](docs/PROJECT-HANDOVER.md) — confirmed decisions, exact patch rules, implemented and untested features, backup policy and session continuation log.

**Current next task:** design a genuine backup-first transaction with authenticated one-use approval, stable identity/handle checks, independently trusted journal latest state and real byte-for-byte original backup verification. The [read-only backup candidate review](docs/BACKUP-ORIGINALS-READINESS.md) now identifies the observed original files that must be preserved, but **does not create or verify any actual backup**, permit game writes or grant redistribution rights. The new [read-only open-file inventory](docs/OPEN-FILE-HANDLE-REVIEW.md) demonstrates handle-based SHA-256 and ordinary Windows write-share conflict detection, but is **not durable ownership or permission to write**. The [two-pass read-only live recheck](docs/LIVE-PLAN-RECHECK.md) now detects some intra-scan changes, but is **not an atomic scan or installation authorisation**. The [live recheck](docs/LIVE-PLAN-RECHECK.md) improves read-only data observations but is **not consent, installer ownership, a race-free write preflight or an authenticated history**. The [synthetic consent lifecycle](docs/CONSENT-LIFECYCLE-REVIEW.md) tests failure labels only and cannot store or authenticate user approval. The new [v2 plan digest](docs/APPROVAL-PLAN-DIGEST-V2.md) is an **unkeyed, synthetic-only test**; it cannot authenticate consent or prevent replay. Backup preservation, source rights, Win32 persistence and client migration remain blocking prerequisites. The [approval snapshot comparison](docs/APPROVAL-SNAPSHOT-REVIEW.md) is **synthetic only** and does not grant installation rights. Independent latest-state and Windows persistence issues are still open. The new trust-continuity tool models **lost keys, migration and replay using untrusted synthetic status claims only**, without authenticating any key, registration or journal. [Journal Authority](docs/JOURNAL-AUTHORITY.md) and [Journal Durability](docs/JOURNAL-DURABILITY.md) remain unresolved. The new 13-stage ordering model checks only **untrusted synthetic labels**, not filesystem durability. The new V/Z crash-cutpoint prototype is strictly read-only and models **untrusted fixture claims**, not real crash recovery. The new registration review tests use **untrusted synthetic records only**; spoofed/replayed values are still possible and never authorise changes. The new directory identity preview is an observed filesystem object ID, **not a secure owner registration**. Windows logical volume identification is now checked read-only, but it does not prove physical-disk separation or durability. The signed v2 prototype is fixture-only and **not a production authority**; no file-writing installer or rollback is available. The installer planner and recovery inspector remain **read-only**; actual installation, updating and rollback are still unimplemented. Keep both documents updated with every meaningful code or policy change.

## Other Naxxramas projects

- [Naxxramas Resource Hub](https://github.com/CosmicCuddle/Naxxramas-Resource-Hub)
- [N-Addon-Collection](https://github.com/CosmicCuddle/N-Addon-Collection)

This project is independent of the AzerothCore server repository and does not modify server-side code.
