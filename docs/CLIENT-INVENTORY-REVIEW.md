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
| `Data/Patch-J.mpq` | 5.5 MB | **Optional login-screen visuals**, plus supporting login music and some loading-screen textures (contents inspected) |
| `Data/Patch-U.mpq` | 10.5 MB | **Optional Vanilla loading-screen visuals** for Eastern Kingdoms and Kalimdor, standard and widescreen (contents inspected) |
| `Data/patch-V.mpq` | 429.8 MB | **Mandatory core Naxxramas patch: required for a complete client setup** |
| `Data/patch-Z.mpq` | 45.1 MB | **Mandatory core Naxxramas patch: required for a complete client setup** |

**Source:** The server owner confirmed the optional/mandatory split, and both J/U MPQ archives were inspected directly from copies supplied on 9 October 2026. The analysis confirms J includes login-screen model, textures, and music; U includes only four loading-screen BLP files. The exact visual appearance and combined in-game behavior have not been tested. The core V and Z archive **contents and dependencies** remain uninspected. Their owner-reported SHA-256 and byte sizes are now pinned under `patchset-0001`.

### J and U archive inspection

**Patch-J.mpq:** 5,739,890 bytes (39 named game assets, excluding MPQ bookkeeping files). Includes the model `Interface/GLUES/MODELS/UI_MainMenu_Northrend/UI_MainMenu_Northrend.m2`, associated `.skin` and `.blp` files, `Sound/Music/GlueScreenMusic/Wotlk_Main_title.mp3`, several glue screen buttons/logos, and several loading-screen textures.

**Patch-U.mpq:** 11,050,502 bytes (four named game assets, excluding MPQ bookkeeping files):

- `Interface/GLUES/LOADINGSCREENS/LoadScreenEasternKingdom.blp`
- `Interface/GLUES/LOADINGSCREENS/LoadScreenEasternKingdomWide.blp`
- `Interface/GLUES/LOADINGSCREENS/LoadScreenKalimdor.blp`
- `Interface/GLUES/LOADINGSCREENS/LoadScreenKalimdorWide.blp`

**Interaction:** J and U both contain `LoadScreenEasternKingdom.blp` and `LoadScreenKalimdor.blp`, with **different file contents**. The installer's UI must mention this, and all combinations (neither, J only, U only, both) must be tested in-game before publishing. MPQ load precedence has not been validated. Neither patch should be merged with the other automatically.

SHA-256 integrity checks for the uploaded copies are recorded in [`config/client-patches.json`](../config/client-patches.json). These reference hashes **are not** evidence of licensing, origin, or visual quality.

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
- `Data/Patch-J.mpq` is the optional login-screen visual patch (with additional loading-screen data); `Data/Patch-U.mpq` is the optional loading-screen patch. Warn that they have two conflicting texture paths; validate both-together behavior in-game.
- Do not accidentally remove the core patches during updates or optional-feature changes; explicit uninstall/rollback must restore the player's prior state, never delete pre-existing files owned by the player.
- All changed local files must be backed up, logged in an install manifest, and restorable on uninstall.
- Optional N Addon Suite should be obtained from **its published approved release**, with version pinning, hash verification, and correct folder layout.
- Owner-confirmed patch roles are recorded in [`../config/client-patches.json`](../config/client-patches.json) as a **design-only policy**, not as proof of distribution permission. No custom MPQ is approved to distribute until its contents, source, and permissions are confirmed.

## Next information needed

1. Confirm the in-game appearance of J only, U only, and both together; establish patch origin and redistribution rights before public packaging. Owner-reported V/Z hashes are pinned in `patchset-0001`, but contents and provenance have not been inspected.
2. The realmlist **public DNS name or IP** players should use; do not confuse this with the owner's private network address.
3. Version metadata for `Wow.exe` to verify build 12340.
4. A final decision on whether the standalone Talent Calculator and any other non-suite addons belong in the *optional* installer catalog.

No cleanup, modification, or client installation has been performed by this review.
