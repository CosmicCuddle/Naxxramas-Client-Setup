# Naxxramas Client Setup — Review Only

**This is NOT an installer. It does not install, update, remove, back up or restore game files.**

This ZIP contains only PowerShell and Windows batch scripts, reviewed JSON reference policy and explanatory documentation. It does **not** contain World of Warcraft, custom MPQ patches, addons, any launcher executable, personal settings or distribution rights for third-party material.

## Getting started on Windows

1. Extract the ZIP to a new, ordinary folder **outside your WoW client folder**. Preserve the included `tools`, `config` and `docs` subfolders.
2. Open `tools` and double-click **Start-Naxxramas-SetupWizard.bat**. Windows PowerShell 5.1 is required.
3. Choose the existing compatible WoW **3.3.5a build 12340 enUS** client folder. Optionally select a *separate* folder holding files you legally possess, and a different existing backup folder for future planning.
4. Patch-V and Patch-Z are **always required** for a complete setup. Choose Patch-J (Vanilla login screen) and Patch-U (Vanilla loading screens) independently. They overlap in some loading-screen textures; in-game behaviour with both has not been approved.
5. Choose **Review Only** and, if needed, **View File Details**. Check any issues and original files marked as needing a future backup. **No backups are created.**
6. Choose **Close**. Nothing has been installed, approved or changed by the wizard.

The ZIP itself includes a `BUNDLE-MANIFEST.json` with byte lengths and SHA-256 fingerprints for the included files. This identifies the packaged scripts but does not prove developer identity or establish a signed release.

**Safety reminders:** never use this as a reason to overwrite an existing client or personal customizations; work from a separate backed-up test copy for development. No official write-capable installer or uninstaller exists. A "no blockers" result is not permission to modify files. The project has **not** approved patch redistribution.

For further details, open `docs/GUIDED-WINDOWS-SETUP.md`. For the **still-unverified** 100%, 125%, 150% and 200% Windows display and screen-reader acceptance checklist, open `docs/WINDOWS-ACCESSIBILITY-ACCEPTANCE.md`. For current project status visit https://github.com/CosmicCuddle/Naxxramas-Client-Setup .

## Additional optional content (planning only)

The preview also identifies optional **Patch-C (TBC login screen)**, which **cannot be combined with Patch-J (Vanilla login screen)**. Patch-U (Vanilla loading screens) is independent. Patch-C's file name/path casing, SHA-256, size, contents and redistribution permissions have not yet been verified. Selecting Patch-C **blocks** optional-content approval and does not place it among the existing five verified file actions.

The optional [N Addon Suite v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) appears in a separate catalogue. Its required folder is `NCore`; optional folders are `IndividualProgressionAddon`, `DungeonJournal`, `MultiBot` and `NaxxLootLottery`. N Talent Calculator is not included in this release. **No addons or MPQs are downloaded, installed, merged, backed up, deleted or made available as game assets by this preview.** Selecting the suite similarly blocks approval until a reviewed archive hash, licensing, install and rollback procedure exist.

## Patch-C reference fingerprint (owner release `optional-v1.0`)

The owner's [optional-v1.0 GitHub release](https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/tag/optional-v1.0) now supplies an exact asset filename `Patch-C.mpq`, 26,753,640-byte length and SHA-256 `16b339522ca9394c11a5afe505e25cf9f326325eb2518dfde328ff08a99920c8`. The official published Patch-J and Patch-U release digests also agree with the existing setup policy. These are **release-asset metadata**, not an independent download-and-rehash of the MPQ bytes or in-game compatibility verification.

The candidate path is `Data/Patch-C.mpq`; Patch-C is optional and **mutually exclusive** with Vanilla-login J. U is independent. **Patch-C still remains a BLOCKED planning choice** outside the immutable four-patch/`patchset-0001` five-file review until a separately reviewed versioned planner supports it. No file download, install, overwrite, client backup, or redistribution is authorised.

## Six-file read-only review — patchset-0002 (PR #41)

The **current** read-only client preview now inspects **six entries** in this order: mandatory `Data/patch-V.mpq`, mandatory `Data/patch-Z.mpq`, optional `Data/Patch-J.mpq` (Vanilla login), optional `Data/Patch-C.mpq` (Burning Crusade login), optional `Data/Patch-U.mpq` (Vanilla loading screens), then `Data/enUS/realmlist.wtf`. It uses new immutable reference `config/patch-versions/patchset-0002.json`; `patchset-0001.json` remains unchanged as prior history.

Patch-C's SHA-256/size come from the owner's public `optional-v1.0` release **metadata**, not an independent MPQ inspection. Its read-only file action is based on the pinned fingerprint of an **existing local client or source file**, using the same no-links and unknown-hash preservation rules as other patches. Patch-C and Patch-J cannot both be selected; importantly, an **existing incompatible J or C** makes the result **BLOCKED** even if its checkbox is off. The preview NEVER removes either file. U is independent; J+U retains its overlapping-loading-texture warning. The separate N Addon Suite remains optional and blocked when selected pending approved package/update rules.

**No installation, client file changes, download, backup creation, rollback, patch redistribution or public release is authorised.** Real-player desktop accessibility and C/J/U in-game compatibility testing remain outstanding. Older paragraphs below/above record the historical planning-only state prior to PR #41.

## Addon module preferences and read-only inventory (PR #42)

The optional N Addon Suite v2.0.0 can now be planned with four individually controlled **future NCore settings** (IndividualProgressionAddon, DungeonJournal, MultiBot, NaxxLootLottery); NCore is mandatory within the suite and N Classic Battlegrounds is integrated into it. These settings do **not** selectively extract the ZIP, modify player addons, or change WoW SavedVariables. The review reads **only direct addon directory names/types** under a selected existing client `Interface/AddOns`, reports known suite and legacy folder presence, and warns about existing `NClassicBattlegrounds` and `ServerDungeonJournal` without deleting anything. Linked or unsafe addon paths block review. A present folder is **not** certified as a legitimate/compatible version.

Owner GitHub release v2.0.0 publishes `N-Addon-Collection-v2.0.0.zip` at 26,762,217 bytes and SHA-256 `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324`. This is pinned reference metadata only: independent ZIP inspection, licensing, backup and rollback gates remain **unapproved**. The selected suite is always **BLOCKED** for actual file operations. No addon ZIP, MPQ, game files, installation/writer or public release is included in the script-only internal CI candidate.
