# N Addon Suite v2.0.0 — Source-tag packaging and settings inventory

**Scope:** read-only inspection of the public GitHub source at `CosmicCuddle/N-Addon-Collection`, tag **v2.0.0**, on 12 October 2026. **Not** a byte-level inspection of the GitHub release ZIP. No game/client data was accessed.

## Evidence and precise limitations

The public v2.0.0 GitHub release advertises `N-Addon-Collection-v2.0.0.zip`, **26,762,217 bytes**, SHA-256 `07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324`. In this development environment the release archive itself could not be retrieved. Therefore its actual fingerprint, ZIP entry list, payload contents, CRCs and packaging provenance **have not been independently verified**. Do not claim that a source checkout proves what bytes are in the published archive.

The tagged source provides `scripts/build_bundle.py`, `scripts/test_suite_bundle.py`, `sources.lock.json`, `suite/NCore` and five source snapshots beneath `addons/`. Its build recipe packages exactly **NCore + four optional addon folders**, without a sixth standalone NClassicBattlegrounds or NTalentCalculator root, and adds generated NCore files and optional addon NCore dependencies. The source-lock commits are evidence about *the tagged source*, not proof the posted ZIP was built from it.

| Source snapshot | Commit recorded in tag v2.0.0 | Source version |
| --- | --- | --- |
| DungeonJournal | `a35e4404b421228d6b881a674a62d2167bf6187f` | 0.6.1 |
| IndividualProgressionAddon | `6872cc726052f7d271a28ba48baa9bb5c7ad36e9` | 5.2.0 |
| MultiBot | `d1606832a083ebf660d67b629b07207b184590dd` | 4.0 |
| NClassicBattlegrounds (embedded into NCore) | `74e45933454385b3b1168bf2c03da34ee1027985` | 1.0.0 |
| NaxxLootLottery (WIP) | `7169f5d7b8e959d1f0b86f9b7f98913d5288b1bb` | 0.1.0.27 |

## Canonical ZIP entry markers expected from the v2.0.0 build script

The developer-only `tools/Test-Naxxramas-AddonArchive.ps1` checks the ZIP central directory, if and when an independently obtained local ZIP is supplied, for **all twelve** exact names:

| Addon folder | Required ZIP entry names |
| --- | --- |
| NCore | `NCore/NCore.toc`, `NCore/ExpectedVersions.lua`, `NCore/LegacyCheck.lua`, `NCore/Settings.lua`, `NCore/ClassicBattlegrounds/NClassicBattlegrounds.lua` |
| IndividualProgressionAddon | `IndividualProgressionAddon/IndividualProgressionAddon.toc` |
| DungeonJournal | `DungeonJournal/DungeonJournal.toc`, `DungeonJournal/LICENSE-GPL-2.0.txt`, `DungeonJournal/CREDITS.txt` |
| MultiBot | `MultiBot/MultiBot.toc`, `MultiBot/LICENSE` |
| NaxxLootLottery | `NaxxLootLottery/NaxxLootLottery.toc` |

The auditor also refuses unsupported ZIP roots, suspicious executable extensions, file-vs-directory collisions, unsafe Windows names and unreasonably large metadata. **Marker presence alone is not executable-code, licence or dependency validation**, and does not authorise installation. The source-tag build tests say the optional TOCs gain a dependency on NCore, but the offline ZIP metadata auditor deliberately does not read their contents.

## SavedVariables inventory — source TOCs only

The original `addons/*/*.toc` files at tag v2.0.0 declare the following settings. Some addons may use additional or changed storage in future releases. A future backup strategy must preserve **all relevant `WTF` files**, not only these named variables.

| Addon | Account-wide SavedVariables | Per-character SavedVariables |
| --- | --- | --- |
| IndividualProgressionAddon | `IndividualProgressionDB` | No declaration in inspected root TOC |
| DungeonJournal | `DungeonJournalDB` | No declaration in inspected root TOC |
| MultiBot | `MultiBotGlobalSave` | `MultiBotSave`, `MultiBotDB`, `MultiBotSaved` |
| NaxxLootLottery | `NaxxLootLotteryDB` | No declaration in inspected root TOC |
| NCore | None declared in inspected root TOC | None declared in inspected root TOC |

**Safety:** do not attempt to rename/delete legacy addons automatically; `NClassicBattlegrounds` and `ServerDungeonJournal` require careful manual migration review. Even if TOC declarations are understood, keep all `WTF` files intact. No real client backups, file copies, recovery or installation code were created by this research.

## Remaining release gating

1. Independently obtain the published v2.0.0 ZIP through a user-approved trusted path **outside the WoW client**, run the developer audit against that local file, and record its SHA/size/structural results. Do not upload/share personal client data.
2. Manually review actual .toc/.lua payload and third-party licence obligations; reconcile archive contents with the tagged source recipe.
3. Finalise owner-approved backup, multi-account settings preservation, recovery journal and nondestructive rollback design on isolated fake clients. Do not enable a client writer as a side effect of a successful metadata audit.
4. Complete physical Windows 100/125/150/200% scaling, keyboard, High Contrast, screen-reader and in-game compatibility acceptance separately. Any public release requires its own explicit approval.

**Status:** reference and developer test design only, **no publication or installation approval**.

### Verified actual v2.0.0 payload, read-only Windows CI — 12 October 2026 (PR #46)

The developer-only real-release CI job https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38249356120 **passed**, after independently downloading and rehashing the exact v2.0.0 release ZIP in an ephemeral Windows runner. The Python ZIP reader streamed **796 compressed members** to EOF (checking ZIP CRC), inspected **187 .toc referenced load paths**, and checked five Interface 30300 addon manifests, NCore dependencies, pinned versions, account-/character-level SavedVariables names and GPLv2/GPLv3 licence text presence. Adversarial synthetic tests (https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38249350958) also passed, including intentionally corrupted CRC bytes, invalid dependencies and missing manifests. The runner then discarded its downloaded ZIP; nothing was extracted, installed, uploaded or copied to a user client. These checks do NOT constitute Lua security analysis, full copyright/licence permission, gameplay validation, backup verification, transaction-safe rollback or approval to redistribute/install. The suite selection remains blocked; all installer approval flags in config/optional-content.json stay false.

## Rights and attribution follow-up — public source evidence (12 October 2026)

The earlier release-asset SHA/CRC/TOC verification remains valid; it is **not** licence clearance. A dedicated [release-rights/source review](RELEASE-RIGHTS-AND-SOURCE-REVIEW.md) now records observed source licences and unresolved artwork permissions. The tagged DungeonJournal credits explicitly distinguish some Blizzard-derived images **outside GPL coverage**, and MultiBot carries GPLv3. The suite's installed folders remain exactly five; the source snapshot of Classic Battlegrounds is embedded into NCore. Pinned source hashes and included credit/licence text do not establish a general right to repackage or redistribute. The new evidence snapshot and tests leave all install/download/public-release flags false.
