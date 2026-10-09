# Milestone 2: backup-first local installer alpha

**Status: development-only and locked to disposable test fixtures. Do NOT attempt to use this installer on a real WoW installation.**

## What is implemented

- Read-only plan of local, owner-provided V and Z (mandatory) and J/U (optional).
- Check SHA-256 and file sizes against the pinned patchset before any file writes.
- Read public realm settings from config/realm.json.
- Stage intended files; make and verify backups of every overwritten destination.
- Write a per-session JSON journal and active session marker before changing files.
- Apply from the local staged copies and verify hashes afterward.
- Rollback to the exact backed-up files; remove only files created by this session.
- Refuse rollback when a player has edited files since installation.
- Handle an injected mid-install failure by attempting automatic rollback.

**Not implemented:** real-client installation, production-approved addon distribution, downloadable MPQ assets, automatic patch downloads, unattended upgrades, graphical user interface, a public release or verified network reachability. The script includes no external network requests.

## Why is it locked?

The first transactional engine must be proven safe before allowing writes to a real game folder. The alpha refuses Install or Rollback unless BOTH switches \`-Apply\` and \`-ConfirmDisposableFixture\` are present and the destination contains an exact marker named \`.naxx-test-fixture\` with the text \`NAXXRAMAS_DISPOSABLE_FIXTURE_V1\`.

**Do not create that marker in your normal client.** It is an internal test-only switch, not a shortcut for players.

## How to inspect the plan (read only)

In PowerShell, using a separate client and local authorised patch source, execute:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Setup-Prototype.ps1" -Action Plan -ClientPath "D:\TEST-WoW" -PatchSourcePath "D:\My-Local-Patches"
~~~

The patch source must have a \`Data\` subfolder and may not be the destination itself or nested inside the destination. The tool will never download or distribute Blizzard assets.

For J/U selection, append \`-VanillaLogin\` and/or \`-VanillaLoading\`; both remain optional. It does not uninstall either optional file merely because an option is not selected.


## Recovery after a simulated hard interruption (test fixtures ONLY)

The alpha can simulate a process stopping without running its exception handler (`-SimulateCrashAfter 2`). An incomplete session retains its journal and `active.json` state.

The explicit `-Action Recover` command applies only to incomplete `prepared`, `applying` or `restoring` sessions. It checks all recorded backups and destinations before attempting restoration. It refuses a damaged backup or a player-modified file. Successfully completed installations use `-Action Rollback` instead.

A power failure during the transaction journal write may leave a partial `.writing` file. The alpha will **not** automatically remove or trust these files; manual inspection would be required. Additional power-loss cases need testing before a production release.

Both Recover and Rollback are locked to synthetic disposable fixtures.

## Automated tests

The Windows GitHub Actions job runs \`tests/Test-Installer-Prototype.ps1\`. This creates a **small fake WoW tree with dummy files**, then tests:

1. Preview creates no writes.
2. Missing explicit test confirmation blocks install.
3. Injected mid-install error triggers rollback.
4. Successful install verifies the four fake patch files and realmlist.
5. A repeated installation cannot overwrite an active session.
6. A player-modified realmlist blocks unsafe rollback.
7. Manual rollback restores original bytes and removes only newly installed files.
8. A corrupt update source fails checksum validation.

These are fixture tests only; they do **not** establish production safety or redistribution rights. Review the CI results before merging.


## N Addon Collection integration (test-only)

The suite reference is [N Addon Suite v2.0.0](https://github.com/CosmicCuddle/N-Addon-Collection/releases/tag/v2.0.0). Its five installed addon folders are:

- **NCore** — always included when selecting the suite; N Classic Battlegrounds is embedded
- IndividualProgressionAddon — optional
- DungeonJournal — optional
- MultiBot — optional
- NaxxLootLottery — optional, with ongoing WIP features

NTalentCalculator is not included in suite v2.0.0. The prototype also blocks known conflicting legacy folders (NClassicBattlegrounds and ServerDungeonJournal) instead of deleting them.

Provide a separately obtained extracted local suite using `-AddonSuitePath` and the optional folder names using `-Addons`. Example for READ-ONLY PLAN mode:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Setup-Prototype.ps1" -Action Plan -ClientPath "D:\TEST-WoW" -PatchSourcePath "D:\LocalPatches" -AddonSuitePath "D:\N-Addon-Suite" -Addons "DungeonJournal","MultiBot"
~~~

The suite folder must contain `NCore\NCore.toc` or `Interface\AddOns\NCore\NCore.toc`. The alpha will refuse to merge or overwrite any pre-existing addon folder. In disposable fixtures only, the selected addon files are included in the staged, journalled, reversible installation.

The GitHub Release v2.0.0 ZIP SHA-256 and byte size are now pinned, and a separate read-only ZIP verifier is provided. **An extracted directory is still not authenticated or cryptographically bound to that ZIP**, so the prototype must remain test-only. No actual addon files are downloaded or distributed by this repository.

## Next milestones

- Pass and review Windows CI, then conduct manual disposable client-directory tests.
- **Implemented and tested:** hard-interruption simulation, explicit Recover and damaged-backup refusal. Additional power-loss scenarios remain.
- Confirm Windows overwrite behavior and free disk space handling.
- Implement version-aware updates without deleting mandatory V/Z.
- **Test-only implemented:** local N Addon Suite selection and per-file reversible staging, pending release authentication and broader tests.
- Remove the write guard only after substantial safety validation and owner approval.
