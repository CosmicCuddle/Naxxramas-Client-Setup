# N Addon Suite — Offline ZIP Audit & Future Recovery Plan

**Status: engineering design / local analysis tool ONLY. No installation approval.**

## What is being checked now

The owner's [N Addon Suite v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) release advertises the following ZIP:

| Field | Published reference |
| --- | --- |
| Filename | N-Addon-Collection-v2.0.0.zip |
| Size | 26,762,217 bytes |
| SHA-256 | 07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324 |
| Contents advertised | NCore, IndividualProgressionAddon, DungeonJournal, MultiBot, NaxxLootLottery |

**Published metadata is not the same thing as independently checking the bytes.** The development utility below requires the exact expected size and SHA-256 of an *already locally obtained* ZIP, then reads its ZIP directory metadata. It does **not** download files, extract files, read Lua or TOC contents, launch any code, create backups, modify a WoW client or distribute game resources.

It rejects ZIP paths that use traversal (..), absolute paths, Windows reserved names, backslashes, suspicious symlink/reparse metadata, case-insensitive duplicate names, unexpected root folders, missing root-level TOC manifests, unexpected ZIP size/hash, and unusually large entry counts/decompressed metadata. These are safety filters, **not proof** that an archive is suitable for installation. It does not check payload CRCs or execute addons.

## Owner/developer manual usage

Use **Windows PowerShell 5.1**, in a trusted checkout of this GitHub repository, after obtaining the archive separately through the owner's official release page. Keep the ZIP **outside your WoW folder**. The following command only reads it (replace YOURNAME with your Windows username):

    powershell.exe -NoProfile -File ".\tools\Test-Naxxramas-AddonArchive.ps1" -ArchivePath "C:\Users\YOURNAME\Downloads\N-Addon-Collection-v2.0.0.zip"

If your execution policy blocks trusted scripts, do not permanently change policy without reviewing what you run first. The tool uses a read-only file stream and reports a JSON summary with five folder counts and hard-coded denials of install, backups, redistribution and game compatibility certification.

**The tool was introduced and tested against synthetic ZIPs only**, unless a separate dated note explicitly records a successful owner-provided, independently downloaded release ZIP audit. A CI result from fake archives does *not* prove the owner's v2.0.0 archive was actually inspected.

## Test and distribution boundaries

The developer-only source is tools/Test-Naxxramas-AddonArchive.ps1; its synthetic CI fixtures are tests/Test-AddonArchiveAudit.ps1 and run only under .github/workflows/offline-addon-archive-audit.yml.

The development ZIP auditor, an addon ZIP, original player addons, WTF/SavedVariables, MPQs and game executables must **never** be included in the separate allowlisted player scripts-only ZIP candidate. Do not add a download button or installer action to the user-facing wizard. Selecting the addon suite must remain **BLOCKED**. Refuse untrusted ZIP metadata and linked archive paths; never try to repair, extract or delete such an archive automatically.

## Before any future write-capable addon installer could be designed

This section is a **review checklist, not implementation instructions to run now**. Actual support requires a separate reviewed architecture and the owner's explicit decision.

1. **Evidence and rights.** Independently rehash the exact release bytes, review all five directory manifests, bundled third-party licences, packager provenance, dependencies and client build 12340 compatibility. Document permitted distribution and whether releases may be used as installation sources. Keep NaxxLootLottery's WIP limitations explicit.
2. **Existing installation classification.** Safely inspect folder names without traversing links. Distinguish absent, trusted same-version, older known version, unknown modified folder, and suspicious or legacy duplicate. Never overwrite unknown files.
3. **Legacy duplicates.** The upstream release warns about standalone NClassicBattlegrounds and older ServerDungeonJournal; treat them as manual review blockers, never automatic removal instructions.
4. **Settings retention.** Before considering changes, make verified backups of every impacted addon directory AND relevant WTF SavedVariables for every account/character. Do not assume one character/profile.
5. **Close-game and filesystem checks.** Ensure game is closed, target build correct, permissions and space sufficient, original vs backup volumes identified, no locks, and race-resistant directory and file handles. A matching Windows volume GUID alone proves neither independent disk nor crash durability.
6. **Genuine consent.** Explain each proposed folder operation and require separate one-time authenticated, replay-resistant approval. Review Only, checkboxes and module preferences do NOT grant authority.
7. **Atomicity and recovery.** Use independently audited protected journal and durable verified original backups so interrupted operations can resume or roll back without deleting unknown files.
8. **Rollback.** Test restoring original folders and SavedVariables after interruptions, incomplete backups, insufficient space, permission errors and independently updated user files. Never destroy a modified or unknown copy during automatic cleanup.
9. **Human QA.** Complete 100%, 125%, 150%, 200% physical Windows DPI, keyboard, screen reader, High Contrast and test fresh install, v1 upgrade, duplicate legacy folders, actual game/server compatibility and rollback. Record per-test results.

**Until every separate gate is met, no client modification, installation or public redistribution is authorised.**
