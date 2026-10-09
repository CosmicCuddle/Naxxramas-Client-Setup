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

**Not implemented:** real-client installation, downloadable MPQ assets, addon installation, automatic patch downloads, unattended upgrades, graphical user interface, a public release or verified network reachability. The script includes no external network requests.

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

## Next milestones

- Pass and review Windows CI, then conduct manual disposable client-directory tests.
- Additional interruption cases and tampered journal/backup tests.
- Confirm Windows overwrite behavior and free disk space handling.
- Implement version-aware updates without deleting mandatory V/Z.
- Handle approved addons as separate, independently reversible operations.
- Remove the write guard only after substantial safety validation and owner approval.
