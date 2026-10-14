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

## Original Necropolis illustration and optional rune glow

The **source-only review prototype** now includes an original illustrated gothic-citadel hero banner with soft optional rune-glow animation. It honours Windows reduced-motion and High Contrast, never moves input controls, and has no game files or copyrighted textures. This is **still not an installer**. [How to review the art safely at 300%](docs/NECROPOLIS-ARTWORK-PREVIEW.md). Actual 300% rendering and contrast/motion comfort require human verification.

## Naxxramas-inspired visual preview (not a finished installer)

The Windows read-only wizard now has an **original dark stone/teal/gold Naxxramas-inspired theme**, rather than generic light Windows colours. It is still built with native Windows Forms controls and is **not** a working client installer. Windows High Contrast uses the system palette, and the owner's 300% scaling needs fresh physical visual confirmation after this theme change. Read [visual theme and accessibility safeguards](docs/WINDOWS-VISUAL-THEME-PREVIEW.md). No game artwork or assets are bundled, and no install, backup, restore or download action has been granted.

## Try the review-only Windows interface without touching WoW

For an initial **hands-on accessibility check**, download and extract the full source repository outside your game installation. On Windows, double-click `tests/Start-Accessibility-ManualCheck.bat`. It opens the existing read-only setup wizard with **disposable fake files**, first in Ready mode and then in Blocked mode. No real WoW client path is accepted and no game, account, addon, or SavedVariables files are accessed. This source-only developer QA launcher is **not** an installer and is **not** part of the player ZIP.

Check your actual Windows display scaling at 100%, 125%, 150%, 200% and (where available) 300%, reopening the launcher at each scale you can test. Record actual observations; an owner-reported partial 300% visual review is not full acceptance. See [Windows accessibility test record](docs/WINDOWS-ACCESSIBILITY-TEST-RECORD.md). Automated tests do not establish physical usability or gameplay compatibility.

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

## Guided Windows setup wizard — READ ONLY

The first actual [guided Windows setup window](docs/GUIDED-WINDOWS-SETUP.md) is available for users who already have a legitimate WoW 3.3.5a client. On **Windows**, double-click **`tools/Start-Naxxramas-SetupWizard.bat`** in a downloaded repository checkout. It displays three existing-folder pickers (client, optional local patch source, separate backup folder), independent optional J/U checkboxes, optional realm address and a scrollable **Review Only** result. The required V/Z patches cannot be deselected.

**Nothing is installed:** the wizard has no Apply/Install/Approve/Backup/Rollback action, does not download MPQs or change any game files, and does not create backup copies or genuine consent. **View File Details...** (available only after Review Only) opens a larger, non-editable five-file table and shows which **original backups have not been created**; changing an option clears and disables previous details. Missing folders get plain-language guidance. Follow [GUIDED-WINDOWS-SETUP.md](docs/GUIDED-WINDOWS-SETUP.md) for keyboard controls, manual display-scaling QA and developer-only diagnostics. Test your separately backed-up client copy, not your sole original.

## Player-readable, offline installation review (read-only)

[Player Installation Review](docs/PLAYER-INSTALL-REVIEW.md) is the first **player-facing** presentation of the actual Windows installer planner. It explains required V/Z, independent optional J/U and realmlist actions in plain language, including which **existing originals would need backing up**, estimated storage, and missing-source/unknown-file blockers. It only prints to the console or JSON, without changing your files or recording consent.

Run it on an existing separately backed-up test client using Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Show-Naxxramas-InstallReview.ps1" -ClientPath "D:\WoW-TEST" -PatchSourcePath "E:\Local-Naxx-Patches" -BackupRoot "F:\Independent-Backups" -VanillaLoading
```

The example paths are placeholders. **There is no install, approve or rollback button.** The preview does not authenticate ownership or create originals; the offline-vs-independent-history architecture remains undecided.

## Offline and migrated-client recovery policy (developer-only)

The [Owner Recovery Policy](docs/OWNER-RECOVERY-POLICY.md) adds a **read-only synthetic** Windows PowerShell decision matrix for offline play, lost/rotated credentials, copied or migrated clients, a different Windows account, revoked consent and inconsistent recovery history. Its rule is always to preserve the client and original backups: **never silently re-register, re-key, install, resume or restore**. It compares only caller-controlled labels, not real accounts or an independent service. Coherent historical replay remains possible and every output denies file writes.

## Read-only recovery receipt and ownership claims (developer-only)

The [Recovery Ownership and Authority Review](docs/RECOVERY-OWNERSHIP-AUTHORITY.md) compares a **caller-written approval/receipt claim** and a separate **caller-written latest-state claim** with the actual current `session.json` fingerprint, observed Win32 client/session folder identities and the existing read-only recovery conflict safeguard. It reports mismatched/revoked/expired/consumed claims, and tests coordinated replay. **Matching claim files are not genuine player consent, protected monotonic history, proof of ownership or permission to restore/install anything.** Windows tests contain only fake client/session data and no runtime writes.

## Read-only interrupted recovery and player-change preservation (developer-only)

The [Recovery Conflict Safeguard](docs/RECOVERY-CONFLICT-SAFEGUARD.md) combines two synthetic session recovery reviews with actual held-file-handle observations, explicitly preserving files changed by the player, missing or corrupt backups and incomplete journals. It never accepts a previous restore/delete suggestion as approval, and all statuses always deny write/rollback. Windows synthetic tests exercise real fake-file edits and mid-review mutations; the production tool is **read-only**.

## Read-only transaction backup checkpoints (developer-only)

The [Transaction Backup Checkpoint](docs/TRANSACTION-BACKUP-CHECKPOINT.md) inspector reviews **existing** transaction-specific backup folders and untrusted checkpoint claims against the read-only original/source and existing-copy reviewers. It flags missing/altered originals, inconsistent phase/hash claims and leftover `.part` files. Only the Windows **test harness** writes fake staged copies, confined to fresh disposable directories; the production tool writes nothing. A matching checkpoint is **NOT durable backup proof or authenticated consent**, and cannot authorise installation or rollback.

## Read-only verification of existing original copies (developer-only)

The [Existing Backup Copies](docs/EXISTING-BACKUP-COPIES.md) tool checks **already-present** mirrored copies in a separately selected backup directory against the original files that PR #21 identified for potential replacement. It compares SHA-256, size and **Windows file ID**, rejecting a hard link that points back to the original file. Windows disposable-fixture tests cover a corrupted/missing copy and prove the tool never creates, alters or restores backups. Even a distinct byte-matching copy is **not authenticated or durable recovery proof**.

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

**Current next task:** perform hands-on Windows testing of the expanded **read-only file details**, keyboard focus, screen readers and scaling, then consider distributing only the repository scripts. Follow the [Guided Windows Setup guide](docs/GUIDED-WINDOWS-SETUP.md) and [Project Handover](docs/PROJECT-HANDOVER.md). **No installation, backup writing, approval, update, rollback or uninstall is enabled.** The owner's offline-versus-independent latest-state choice, genuine one-use consent, original backup durability, Windows race safety, recovery and patch rights remain unresolved.

## Other Naxxramas projects

- [Naxxramas Resource Hub](https://github.com/CosmicCuddle/Naxxramas-Resource-Hub)
- [N-Addon-Collection](https://github.com/CosmicCuddle/N-Addon-Collection)

This project is independent of the AzerothCore server repository and does not modify server-side code.
