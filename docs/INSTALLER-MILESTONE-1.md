# Naxxramas installer — development milestone 1

**Status: READ-ONLY PREFLIGHT. THIS IS NOT AN INSTALLER YET.**

The client archive is ~18.6 GB, but the planned setup tool does **not** distribute a complete game client. Players must supply an independently obtained, compatible WoW 3.3.5a installation. Do not publish Blizzard game archives or custom assets without the necessary permissions.

## Completed in milestone 1

- Check that a selected game folder contains Wow.exe and Data/enUS.
- Check that mandatory Data/patch-V.mpq and Data/patch-Z.mpq are present, or available from an explicitly selected local patch source.
- Support optional Vanilla login visuals (Patch-J.mpq) and optional Vanilla loading screens (Patch-U.mpq).
- Verify optional MPQs against their recorded SHA-256 fingerprints.
- Validate V/Z and J/U against pinned reference fingerprints (patchset-0001; V/Z values supplied by the server owner). The owner has now supplied an executable-version screenshot reporting 3.3.5 build 12340; independent executable/runtime verification remains outside the scope of this read-only tool.
- Check optional extracted N Addon Suite folder layout: NCore is required within the suite; other suite modules are individually selectable.
- Read the default realm from config/realm.json, validate an optional command-line override, and compare an existing Data/enUS/realmlist.wtf without writing it.
- Never modify, copy, upload, rename, or remove game files.

## Easy way to run a check on Windows

1. Download and extract this repository ZIP **outside** your WoW folder.
2. Open the tools folder.
3. Drag the folder containing Wow.exe onto **Check-Naxxramas-Client.bat**.
4. Read the results. The checker now prints the reference patch set and clearly distinguishes installed optional patches from installation selections. If a client lacks version metadata or has an unrecognised patch hash, the checker will warn or reject it as appropriate. The owner supplied a default realmlist host, which the checker compares against the game client's local file.

The check may calculate file hashes, so large patches can take time to read. It never edits the original client.

For additional options, use Windows PowerShell with the script directly, for example:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Test-Naxxramas-Client.ps1" -ClientPath "D:\My-WoW-Client" -VanillaLogin -VanillaLoading -RealmHost "example.realm.invalid"
~~~

The example host is a placeholder. This command is a **check**, not a real server configuration. If checking a clean WoW installation, use -PatchSourcePath to point to a separate, locally held Naxxramas client containing the core patches. This does not grant permission to redistribute their contents.

For an approved extracted N Addon Suite, -AddonSuitePath can point to the folder containing NCore, and -Addons can specify optional suite addons, e.g. "DungeonJournal","MultiBot". The tool checks TOC paths only and does not independently authenticate the release.

## Prepare future patch revisions

Run `tools/Prepare-Patch-Update.bat` against your working client after modifying any J, U, V or Z patch. The small `patch-update-proposal.json` report lets us prepare a new versioned manifest without copying MPQ binaries into GitHub. See [Patch Updates](PATCH-UPDATES.md). Do not treat this as an automatic installer or an approved public release.

## Calculate the mandatory core fingerprints

1. Open tools.
2. Drag the folder containing your **current working Wow.exe** onto **Get-Core-Patch-Hashes.bat**.
3. Two SHA-256 lines will appear for patch-V.mpq and patch-Z.mpq.
4. Share **only those two lines** in the development chat. Do not upload the MPQs to the public repository.

A checksum identifies exact bytes; it does **not** establish licensing or provenance.

## Planned installer transaction rules (not yet implemented)

Future installation should use an **existing, separate copy of a legitimately obtained WoW client** as the destination.

- Validate client build and available free disk space.
- Reject incomplete setups without V and Z.
- Confirm the source and destination are different folders.
- Stage writes; take backups of every existing file before overwriting.
- Record file paths and before/after SHA-256 hashes in a session manifest.
- Offer J/U as separate switches; do not silently remove pre-existing optional files.
- Install an explicitly approved N Addon Suite release, not the owner's full collection of personal addons.
- Configure Data/enUS/realmlist.wtf using the public realm address only after approval.
- On rollback, restore the prior contents and do not overwrite files changed by the player after installation.
- Test install, repeated install, failure during install, rollback and uninstall on disposable game-folder fixtures.

The full installer and public Release will not be presented as ready until these tests pass and the redistribution rights for included assets are understood.

## Known open points

1. **Completed:** V/Z owner-supplied hash and byte-size references recorded as `patchset-0001`. Future versions use the proposal process.
2. Verify the actual Wow.exe build 12340 on the owner's working client.
3. **Owner-supplied:** 85.190.254.242 is the player realmlist setting. External network reachability remains untested.
4. Test J and U individually and together in-game; their Eastern Kingdoms and Kalimdor loading textures overlap.
5. Decide which approved addons are part of the default setup, and how future updates are pinned.
