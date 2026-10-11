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

For further details, open `docs/GUIDED-WINDOWS-SETUP.md`. For current project status visit https://github.com/CosmicCuddle/Naxxramas-Client-Setup .
