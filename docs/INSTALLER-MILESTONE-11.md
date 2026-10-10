# Milestone 11 — Fresh client setup (planning only)

The project owner wants **one launcher** usable by players starting with **no WoW files**. It must eventually obtain an authorised *complete* World of Warcraft 3.3.5a (build 12340, enUS) client and apply all of the Naxxramas additions.

## Two paths in the launcher

| Mode | Current capability |
|---|---|
| **Existing client - check and prepare** | Read-only preview, verified patch-source download into a separate folder, addon selection; real-client installation remains disabled |
| **Fresh client - planning only** | Select an existing **EMPTY** destination folder and preview the planned installation, but do not download, extract or modify any game files |

The second mode deliberately disables **Get patches** and **Inspect** until a verified base client is available. It does not pretend to work as a complete-game download yet.

## Full installation sequence once legally and technically ready

1. Player downloads the small launcher, chooses **Fresh client**, and selects a new empty games folder.
2. Installer checks a **specifically authorised** source and its verifiable redistribution permission. The current `config/base-client-source.json` explicitly blocks this stage.
3. Downloads a pinned full-game archive into a **separate staging directory** (never into the final client folder while downloading).
4. Verifies the complete SHA-256 and expected byte count, rejects unsafe paths, and checks the extracted `Wow.exe` file version/build 12340.
5. Prepares mandatory `patch-V.mpq` and `patch-Z.mpq`, with mutually exclusive optional Vanilla login J / Burning Crusade login C and independent loading screens U.
6. Obtains and verifies the N-Addon Collection archive from the pinned GitHub release; includes **NCore** by default and installs any selected optional modules.
7. Creates the correct enUS `realmlist.wtf` using `config/realm.json`.
8. Performs a post-install integrity check, writes a local install manifest, preserves recoverable backups and provides a safe uninstall path.
9. Offers a clear final status; it must **never** claim success after a failed file verification.

## Licensing and source gate

Blizzard's ownership and licence terms do not grant everyone permission to redistribute a 3.3.5a game archive. The user may have a personal historical copy, but **a personal copy is not automatically a legally distributable installer source**. A checksum proves byte identity, not rights.

The current `config/base-client-source.json` has no download URL, SHA-256, archive size or legal authorisation record. It is disabled and is only a schema for future development. `tools/Plan-Fresh-Client.ps1` refuses to enable downloads or writes, even if somebody manually switches `enabled` to true.

Before continuing with the complete-client downloader, the owner needs to supply a source and documented redistribution authorisation. If that is not available, a practical alternative is to let players **supply their own legally obtained WoW 3.3.5a copy** and automate all the Naxxramas additions.

## Safety and test coverage

The new read-only planner validates that the destination folder exists, is truly empty (including hidden files), is not the launcher folder or a parent, not a root/system directory and is not a symlink or junction. Tests verify the blocked source state, no writes to existing files, conflict rejection for J/C and the absence of any Install or Download action from the fresh-client GUI mode.

This is an engineering planning milestone, **not a working full-client installer**.
