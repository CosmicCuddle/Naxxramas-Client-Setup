# Milestone 9 — Optional Burning Crusade login patch

**Status:** Registered and fixture-tested in the development branch. The Windows launcher remains **read-only** and no MPQs are distributed.

## Confirmed release metadata

Source: https://github.com/CosmicCuddle/Naxxramas-Server-Patches/releases/tag/optional-v1.0

- File: `Patch-C.mpq`
- Target path: `Data/Patch-C.mpq`
- SHA-256: `16b339522ca9394c11a5afe505e25cf9f326325eb2518dfde328ff08a99920c8`
- Size: `26753640` bytes
- Purpose: Burning Crusade-style Dark Portal login screen, Hellfire-themed artwork, and replacement login music.

The SHA-256 and size come from GitHub's *release asset metadata*. They establish an expected file fingerprint; they do not imply permission to redistribute the MPQ or demonstrate compatibility with a particular player's full game client.

## Installer behaviour

- `patch-V.mpq` and `patch-Z.mpq` remain mandatory.
- `Patch-J.mpq` is optional **Vanilla login**.
- `Patch-C.mpq` is optional **Burning Crusade login**.
- `Patch-U.mpq` is optional **Vanilla loading screens**.
- **Patch J and Patch C are mutually exclusive.** The launcher checks only one login-screen box at a time, and both the read-only preflight and installer backend refuse conflicting selections.
- Patch U may be chosen with either J or C. J+U has a documented loading-texture overlap requiring in-game testing.
- The preview refuses a selected login screen that conflicts with an **existing** J/C patch file. It does not remove another person's patch to satisfy a new choice.
- No new downloads, installation permissions or production write paths are enabled.

## Version history

This is now `patchset-0002`: the original `config/patch-versions/patchset-0001.json` is preserved unchanged, and the new immutable reference record is `config/patch-versions/patchset-0002.json`.

Version 2 adds only the Patch C metadata and compatibility policy; all existing V/Z/J/U fingerprints remain unchanged.

## To test locally

For a read-only preview, point **Local patch source** to your own separate directory containing `Data/Patch-C.mpq`, then select **TBC login (C)**. The script hashes the source and rejects missing or altered files. You can select **Vanilla loading (U)** as well.

For a player switching from an existing J installation to C (or vice versa), back up the old MPQ first, then resolve the conflict intentionally; the installer will not silently delete it.

Further testing is required before making a real-client installer available. Synthetic fixture tests cover J/C conflict rejection and TBC+U rollback; they do **not** replace in-game visual testing.
