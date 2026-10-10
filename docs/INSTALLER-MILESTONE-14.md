# Milestone 14 — Private game-file inventory with per-file hashes

## Purpose

The previous `client-reference-*.json` report proved build 12340 and hashes for V, Z and U, while 21 MPQs totalling 17,773,795,353 bytes was only a combined total. Milestone 14 introduces `tools/Inventory-Game-Files.ps1` and `Inventory-Game-Files.bat` for a more detailed **local** inventory. The resulting report is a development aid, not a redistributable game archive or complete installer manifest.

## What is read

The scanner **does not recurse** into arbitrary game subdirectories. It can read and hash:

- A small allowlist of expected client root executables/libraries such as `Wow.exe` and `Launcher.exe`.
- Recognised original WoW MPQ names directly inside `Data`, including `common`, `common-2`, `expansion`, `lichking`, and `patch` (and numeric patch suffixes).
- Recognised `enUS` locale/speech/patch MPQs directly inside `Data/enUS`.
- Known Naxxramas MPQs `patch-V`, `patch-Z`, `Patch-J`, `Patch-C`, `Patch-U`, each compared to the existing pinned SHA-256 and byte size.

Unknown MPQ filenames are **not published in the report**; only their count is recorded, because arbitrary filenames could expose personal details. Likewise `WTF`, `Cache`, `Screenshots`, `Logs`, `Errors`, all addon folders, `SavedVariables`, and `realmlist.wtf` are not scanned or exported.

**Limitation:** This allowlist intentionally does **not** cover every file a functioning WoW installation may need, nor prove that a file belongs to a legitimately licensed base distribution. The scanner refuses symlinked/Junction game root and scanned files, and it never writes to the WoW folder.

## Steps for the owner

1. Make or confirm your current WoW 3.3.5a backup. Do not alter the original client.
2. On Windows, create a separate **development copy** of the game, outside the launcher folder.
3. Download and extract the latest development preview ZIP **outside** your WoW folder.
4. Locate `tools/Inventory-Game-Files.bat` and drag the **development copy's folder containing Wow.exe** onto it.
5. The scanner hashes the approved MPQs and binaries. The full SHA-256 mode may take several minutes for a 17+ GB game.
6. Look for `game-files-*.json` in the launcher `tools` folder. Review it privately before sharing. Do **not** upload it or any game archive to public GitHub.

To run the quick *non-verifying* inventory in a Windows PowerShell terminal instead:

~~~powershell
.\tools\Inventory-Game-Files.ps1 -ClientPath "D:\Games\WoW-Development-Copy" -ReportPath "C:\Naxxramas-Reports\game-files-quick.json" -Quick
~~~

The parent report directory must exist. The report path must not be in WoW or point to an existing file. The full mode omits `-Quick` and creates SHA-256 for each allowlisted file. It can take substantially longer.

## Report safety and semantics

The JSON contains relative file names, expected-build metadata, file sizes, hashes (full mode), pinned patch verification, an aggregate byte count, and an excluded-unknown-MPQ count. It contains **no absolute client path or personal folder contents**. `-Quick` must never be considered a verified hash manifest.

The tool cannot install, delete, copy or download game files. It cannot declare the base client complete. Do not mistake `build_confirmed` alone for permission to redistribute or proof of a full valid installation.

GitHub Actions runs synthetic Windows tests with tiny dummy MPQs (not game binaries) to verify checksum recognition, optional absence, tampered required patches, uppercase MPQ extensions, privacy exclusions, the Quick mode, refusal to overwrite an existing report, and rejection of report paths inside WoW.

## Next milestone

Review the owner's **local** game-file report and investigate whether the limited file set is complete enough for an integrity-checked **local copy-and-verify prototype in disposable folders**. Develop a formal coverage policy first. Never publish client files or inferred private paths. Existing- and fresh-client workflows must continue to back up affected files and support rollback/uninstall; real-client installs remain disabled.

## Verified Windows CI checkpoint

Milestone 14's dummy-file inventory, privacy checks, pre-existing safeguards, launcher smoke tests and ZIP packaging all passed on [Windows run 38053138014](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38053138014), using implementation commit `f69aa14938d0e2fc944025afbc02176b9aaf0c22`. This is **not** an in-game compatibility or full-client completeness test.
