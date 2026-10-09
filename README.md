# Naxxramas Client Setup

Official setup and update project for the **Naxxramas World of Warcraft 3.3.5a server**.

> **Project status: planning and client inventory.** There is no finished installer or downloadable game client in this repository yet.

## Purpose

The goal is to make joining the Naxxramas server straightforward for players who already have a legitimate, compatible **World of Warcraft 3.3.5a (build 12340)** installation.

Planned features:

- Guided connection setup, including a server-specific realmlist configuration.
- Installation and updating of **redistributable** Naxxramas-specific files.
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
