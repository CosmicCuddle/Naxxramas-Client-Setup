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
