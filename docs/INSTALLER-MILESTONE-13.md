# Milestone 13 — Classifying verified reference-client components

## Verified reference inputs

The owner's `client-reference-*.json` file was read and reviewed privately, **not committed to GitHub**. It confirms the following:

| Group | Reference result | What a future installer should do |
|---|---|---|
| WoW 3.3.5a executable | Build 12340 confirmed | Verify again on the player's client |
| Required Patch V + Patch Z | Both SHA-256 and byte-size verified | Reuse exact existing bytes; never downgrade or disable |
| Optional Patch U | Installed and verified | Preserve; reuse if selected, never silently remove |
| Optional Patch J + Patch C | Neither installed | Allow at most one; download and verify selected one when applicable |
| NCore + 4 selected-eligible addons | All five TOC files present | **Do not call these versions verified** until ZIP and addon files are compared |
| Realmlist | File present, text not read | Only configure after backup and confirmation |
| MPQ inventory | 21 MPQs, 17,773,795,353 bytes | Not a complete verified list of original game files |

## Classification tool

`tools/Plan-Reference-Components.ps1` reads a sanitised JSON report **only**—not the WoW folder itself. It loads the existing patch, addon and realm policies and returns a JSON plan with:

- `required_patches`: V and Z, which cannot be disabled
- `optional_patches`: J, C and U, with selection, recorded status and suggested future action
- `addons`: required NCore and optional Naxxramas addons, explicitly distinguishing **TOC present** from a verified release
- `realm`: file-presence status only; the IP address or realmlist contents are never copied from the user
- `base_client`: aggregate count and bytes, with the lack of a complete base-game inventory clearly marked
- `blockers`: missing/mismatched required patches, unconfirmed game build, J/C conflicts and other safety problems
- `safe_to_mutate_client=false`: always. The component plan cannot copy, remove or install files

The tool does not alter the WoW installation, the original report, or any filesystem directory.

## How to review the component plan

1. Keep your working client's backup untouched.
2. Extract the latest development preview **outside** World of Warcraft.
3. Find the sanitised report previously created by `Inspect-Reference-Client.bat`.
4. Drag that JSON report onto `tools/Plan-Reference-Components.bat`.
5. The PowerShell window shows the structured read-only plan. You do not need to install anything.

For optional selections, Windows PowerShell can call the underlying tool directly:

~~~powershell
.\tools\Plan-Reference-Components.ps1 -ReportPath "C:\Path\To\client-reference.json" -VanillaLoading -Addons DungeonJournal,MultiBot
~~~

The default plan requests only mandatory V/Z and NCore. It leaves the existing Patch U and unrelated personal addons untouched when not selected.

**Important:** Using the reference report alone does not permit distributing a full WoW client. A private personal archive is useful for developing copy/verification on a separately backed-up test directory, but an authorised full-client source and further file-level manifest work are needed before a public fresh-client installer.

## Testing and next engineering stage

Synthetic Windows fixtures model the observed reference state without using or publishing the owner's JSON file. They test verified V/Z/U reuse, missing optional J/C, preserving unselected addons, independently selecting the TBC login patch, blocking mismatched core files, detecting existing J/C conflicts, rejecting unknown addon names and leaving simulated private account files unchanged.

Next is a **full file-level, privacy-safe local inventory** for a *disposable copy* of the client's game binaries and MPQs. Its purpose is to establish reproducible integrity checks, **not** to upload proprietary game data. Build backup, storage-space and undo verification into any actual copy workflow before a real-client install button is enabled.
