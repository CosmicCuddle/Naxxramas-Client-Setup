# Milestone 4: verified addon ZIP extraction

**Development-only source preparation. Not a player installer.**

The new standalone [Extract-Verified-Addon-Suite.ps1](../tools/Extract-Verified-Addon-Suite.ps1) checks the archived N Addon Suite v2.0.0 against our pinned size and SHA-256, validates every ZIP entry path, then can unpack **only** the five approved addon directories.

## How it works

- **Default is a read-only preview.** It reports the archive fingerprint, selected file count, total extracted bytes and destination.
- The optional `-Extract` flag creates a **new** `NAddonSuite-v2.0.0-extracted` folder beneath the selected output parent.
- The program refuses to write into (or under) an existing WoW client folder, and refuses to overwrite an existing output directory.
- It rejects path traversal, absolute paths, invalid Windows names, case-insensitive filename collisions, ZIP symbolic links, and unexpectedly large archive contents.
- It ignores ancillary documentation outside the five installed addon folders.
- It validates all five required addon TOC names and copies files into a temporary folder first. If extraction fails, it removes only its own temporary folder, not existing files.
- The completed folder contains an `EXTRACTION-REPORT.json` with the source ZIP fingerprint and hashes of every extracted file.

**Important:** The report describes integrity **at extraction time**. Someone can later modify either the files or the report, so the test-only installer does *not* treat the folder as a cryptographic proof of origin. A production installer should read directly from the independently verified ZIP, or independently verify every extracted file against a trusted signed/pinned content manifest.

## Example command (PowerShell 5.1)

With the official N Addon Suite v2.0.0 archive saved locally:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\Extract-Verified-Addon-Suite.ps1" -ArchivePath "D:\Downloads\N-Addon-Collection-v2.0.0.zip" -OutputParent "D:\Naxxramas-Downloads"
~~~

The command above is a **read-only preview**. Adding `-Extract` opts in to new files under the designated output parent.

The output folder must not already exist. Do not choose the game installation or a parent folder containing the game executable as the destination.

## Automated tests

Windows synthetic ZIP tests exercise the read-only preview, successful extraction, refusal to overwrite existing output, refusal to write inside a fake WoW folder, changed archive bytes, traversal and duplicate-case entries. They use only small synthetic data.

## Not yet ready for players

No game client or MPQ is downloaded or bundled. No installer write guard has been removed. The suite release must still be validated against an actual archive in a separate controlled manual test and integrated with secure transaction-aware installation. Power-loss, permissions and disk-full behavior beyond current fixture tests also require review.
