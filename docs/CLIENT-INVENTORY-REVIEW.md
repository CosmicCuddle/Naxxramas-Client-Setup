# Client inventory review — 9 October 2026

**Source:** local read-only client inventory supplied by the server owner. This report documents filenames only; none of the archive contents have been inspected.

## Summary

- WoW locale: enUS (inferred from the locale MPQ archive names).
- 22 MPQ archives, approximately **16.56 GiB** total using the scanner's displayed rounded MB sizes.
- 174 addon directories, including bundled Blizzard UI modules, third-party addons, and Naxxramas-specific addons.
- `Wow.exe` is present; **build 12340 has not been independently verified** because the inventory does not include executable version metadata.
- The archive's full ZIP size (18.6 GB, supplied separately by the owner) is **not** evidence that its contents are redistributable.

## Custom MPQ candidates requiring inspection

| Relative path | Displayed size | Action |
| --- | ---: | --- |
| `Data/Patch-J.mpq` | 5.5 MB | Identify archive contents and dependencies |
| `Data/Patch-U.mpq` | 10.5 MB | Identify archive contents and dependencies |
| `Data/patch-V.mpq` | 429.8 MB | Identify archive contents and dependencies |
| `Data/patch-Z.mpq` | 45.1 MB | Identify archive contents and dependencies |

These filenames match common custom-patch conventions; this alone **does not establish ownership, provenance, server dependency, or redistribution permission**. Do not merge, delete, rename, or publish the archives before checking their contents and compatibility.

## Likely standard game archives

`common.MPQ`, `common-2.MPQ`, `expansion.MPQ`, `lichking.MPQ`, `patch.MPQ`, `patch-2.MPQ`, `patch-3.MPQ`, and the reported enUS locale and speech archives. Treat these as part of the player's independently obtained game installation, **not assets for this repository**.

`Data/enUS/backup-enUS.MPQ` was also reported; its content and role have not been verified, so do not remove it based on the name.

## Addon policy

The approved [N Addon Suite v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0) documents **five** installed folders:

1. `NCore` (required for the suite)
2. `IndividualProgressionAddon` (optional)
3. `DungeonJournal` (optional)
4. `MultiBot` (optional)
5. `NaxxLootLottery` (optional; development/testing still ongoing)

The standalone `NTalentCalculator` is **not part of Suite v2.0.0**. It should remain a separately offered, optional download if and when approved. Extra local folders such as `NaxxramasCodex`, `NaxxramasCompanion`, `PlayerBotManager`, and `NCore` must not all be assumed to be current, approved suite content.

Potential duplicate or extracted-package leftovers to review (no automatic cleanup): `ElvUI-6.09` alongside `ElvUI`; `WeakAuras-WotLK-master` alongside `WeakAuras`; `__MACOSX`; `docs`. Folder names alone do not prove an issue.

Other third-party addons require their own redistribution and license review. No plan to redistribute every personal addon is approved.

## Personal and unknown files

Exclude the owner's `WTF`, `Cache`, `Screenshots`, `Logs`, `Errors`, and `Backup Addon` contents from all public packages.

Investigate before using or distributing `Customsounds`, `Battle.net.dll`, `ReShadePreset.ini`, `uid.ini`, `Set_Language_enUS.bat`, and any third-party executable or DLL. The inventory cannot validate their safety, compatibility, or provenance.

## Install/update design decisions

- This repository distributes an **installer/configurator and only files confirmed to be redistributable**, not the whole copyrighted WoW client.
- Installer starts with an existing legitimate 3.3.5a build-12340 client selected by the player, and checks compatibility.
- For connection setup, update `Data/enUS/realmlist.wtf` (or the selected locale's corresponding file) **after** receiving the server's public realmlist address from the owner.
- Installer should prompt to work on a **separate copy**, check free space, and confirm each write before proceeding.
- All changed local files must be backed up, logged in an install manifest, and restorable on uninstall.
- Optional N Addon Suite should be obtained from **its published approved release**, with version pinning, hash verification, and correct folder layout.
- No custom MPQ is approved to distribute until its contents, permissions, source, and relationship to Naxxramas are confirmed.

## Next information needed

1. Archive content listing (filenames **inside**) for `Patch-J.mpq`, `Patch-U.mpq`, `patch-V.mpq`, and `patch-Z.mpq`, using the owner's MPQ editor. Share screenshots or a list privately; do not upload full MPQs.
2. The realmlist **public DNS name or IP** players should use; do not confuse this with the owner's private network address.
3. Version metadata for `Wow.exe` to verify build 12340.
4. A final decision on whether the standalone Talent Calculator and any other non-suite addons belong in the *optional* installer catalog.

No cleanup, modification, or client installation has been performed by this review.
