# Milestone 12 — Validating the working Naxxramas reference client

## Confirmed reference state

The owner's working **WoW 3.3.5a build 12340** client is the baseline. It already has **`Data/patch-V.mpq` and `Data/patch-Z.mpq`**. The optional visual patches **J, C and U** and the N-Addon Collection are **not installed in this copy**. Missing them is normal, not an error.

That separation is important: a future installer should treat the original game's files, mandatory Naxxramas patches, optional visuals, NCore and selected addons as **distinct inputs**.

## First action for the owner

1. Make a complete **backup** of the known-working client in a separate folder or drive. Do not work on the only good copy.
2. Download the latest GitHub preview ZIP and extract it **outside** your WoW folder.
3. Open the extracted `tools` folder.
4. Drag your existing WoW **folder containing `Wow.exe`** onto `Inspect-Reference-Client.bat`.
5. The checker will read `Wow.exe`, V and Z, then write a uniquely named `client-reference-*.json` file in the extracted `tools` folder.
6. Review this report and share **only the JSON report** in our chat when you're ready. Do not share the whole client, your `WTF` folder, Cache, screenshots, SavedVariables or account settings.

The checksums of V and Z may take a little time because they are comparatively large. The tool does **not** modify the WoW client. Only the optional JSON report is created outside it.

## What the report includes

- Whether `Wow.exe` was found and whether its version metadata confirms build 12340
- Whether the `Data/enUS` folder is present
- Current `patchset-0002` reference, including required V/Z fingerprint and byte-size matching
- Optional J/C/U status (missing is fine; J and C together is a conflict)
- Whether known Naxxramas addon `.toc` files are present (missing is fine)
- Count and combined byte size of MPQs immediately under `Data` and `Data/enUS`
- Whether a realmlist file exists, **without reading its contents**
- Warnings and reference-client validation result

The report contains **no complete-game files, no personal account names, no absolute local directory names and no SavedVariables**. Test fixtures explicitly check for leakage and game-file modification.

A dummy or unrecognised `Wow.exe` cannot be marked as a valid reference just because matching dummy V/Z patches are present.

## Future engineering path

1. Use the sanitised report to establish the source client's exact **game build and mandatory patch identity**.
2. Build a reversible local **copy-and-verify** proof of concept using a separate backup/test client. The original client must remain intact.
3. Keep optional patch downloads, the N-Addon Collection, NCore and realmlist setup modular and independently verifiable.
4. Test crash recovery, insufficient disk space, symlinks, partial transfers, repeat runs and uninstall before enabling changes to live client files.
5. Treat **public full-client distribution** separately: having a personal copy, even one modified or reverse engineered, doesn't itself establish rights to redistribute Blizzard's game assets. The complete-client download source remains disabled until suitable authorisation is established.

No in-game installation or public game archive was created in this milestone.
