# Client inventory review — 9 October 2026

**Source:** local read-only client inventory supplied by the server owner. This report documents filenames only; none of the archive contents have been inspected.

## Summary

- WoW locale: enUS (inferred from the locale MPQ archive names).
- 22 MPQ archives, approximately **16.56 GiB** total using the scanner's displayed rounded MB sizes.
- 174 addon directories, including bundled Blizzard UI modules, third-party addons, and Naxxramas-specific addons.
- `Wow.exe` is present; **build 12340 has not been independently verified** because the inventory does not include executable version metadata.
- The archive's full ZIP size (18.6 GB, supplied separately by the owner) is **not** evidence that its contents are redistributable.

## Custom MPQ requirements confirmed by the server owner

| Relative path | Displayed size | Action |
| --- | ---: | --- |
| `Data/Patch-J.mpq` | 5.5 MB | Optional cosmetic patch — one of Vanilla login screen / Vanilla loading screens |
| `Data/Patch-U.mpq` | 10.5 MB | Optional cosmetic patch — the other Vanilla screen modification |
| `Data/patch-V.mpq` | 429.8 MB | **Mandatory core Naxxramas patch: required for a complete client setup** |
| `Data/patch-Z.mpq` | 45.1 MB | **Mandatory core Naxxramas patch: required for a complete client setup** |

**Source:** the server owner confirmed these roles on 9 October 2026. We have not determined whether J or U is specifically the login-screen patch (rather than loading-screen patch). Both are optional. The exact contents and dependencies of V and Z remain uninspected.

**Do not merge, delete, rename, disable, or silently replace either mandatory core patch.** Setup is invalid if either V or Z is absent or fails verification. J and U must never be enforced as mandatory. All four patches still require content/provenance and redistribution-rights review before public packaging.

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
- Install validation must require both `Data/patch-V.mpq` and `Data/patch-Z.mpq` and verify them against trusted checksums once established. There must be no option to omit/disable either patch in a complete Naxxramas setup.
- `Data/Patch-J.mpq` and `Data/Patch-U.mpq` are independent optional selections for Vanilla login/loading presentation. Which filename maps to which option still requires confirmation.
- Do not accidentally remove the core patches during updates or optional-feature changes; explicit uninstall/rollback must restore the player's prior state, never delete pre-existing files owned by the player.
- All changed local files must be backed up, logged in an install manifest, and restorable on uninstall.
- Optional N Addon Suite should be obtained from **its published approved release**, with version pinning, hash verification, and correct folder layout.
- Owner-confirmed patch roles are recorded in [`../config/client-patches.json`](../config/client-patches.json) as a **design-only policy**, not as proof of distribution permission. No custom MPQ is approved to distribute until its contents, source, and permissions are confirmed.

## Next information needed

1. Confirm whether `Patch-J.mpq` is the Vanilla login screen or loading screens (and thus the role of `Patch-U.mpq`); inspect content lists for provenance and redistribution rights without uploading whole MPQs.
2. The realmlist **public DNS name or IP** players should use; do not confuse this with the owner's private network address.
3. Version metadata for `Wow.exe` to verify build 12340.
4. A final decision on whether the standalone Talent Calculator and any other non-suite addons belong in the *optional* installer catalog.

No cleanup, modification, or client installation has been performed by this review.
