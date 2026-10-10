# Milestone 18 — Private non-MPQ support candidate audit

**Development only. Read-only. No full game installation or file download enabled.**

## Why this milestone exists

The owner has completed the private M14 full-hash inventory and M16 consistency review, and the M17 locale MPQ count reconciliation. Recognising 21 MPQ filenames does **not** establish the rest of a compatible WoW client. M14 only covers eight preselected root filenames and the MPQs. Before designing real-world copy/update behavior, we need to see which additional **non-MPQ support file candidates** exist on the owner's separate development client.

## New tool

- `tools/Inspect-Client-Support-Files.ps1` and a drag/drop BAT wrapper.
- Fixed list of **13 root-level candidate filenames** (Wow.exe, Launcher.exe, Repair.exe, BackgroundDownloader.exe, Scan.dll, Storm.dll, DivxDecoder.dll, unicows.dll, WowError.exe, fmod.dll, fmodex.dll, ijl15.dll, dbghelp.dll).
- Four **directory presence** checks only: `Data`, `Data/enUS`, `Interface`, `Interface/AddOns`.
- **Never** reads directory contents, personal files, unknown filenames, AddOns, realmlist, WTF, Cache, Logs, Screenshots or SavedVariables.
- Checks exact filenames for presence, and retrieves byte sizes for present candidates. It **does not hash, open, copy, modify or upload any game file**.
- Refuses linked/junction paths and refuses a selection without `Wow.exe`; writes **no report**.
- Absent optional filenames are **not** failures or proof of a damaged installation. This list is a *working observation scope*, not an authenticated full-game reference or a requirement list.

## Owner steps

1. Keep the known-working client backed up, and only use a **separate development copy**.
2. Download the latest **passing** Windows Actions preview ZIP and extract it outside WoW.
3. Drag the development copy folder containing `Wow.exe` onto `tools/Inspect-Client-Support-Files.bat`.
4. Read the local summary of present/absent candidate files and four directory-presence states. Share a screenshot privately if comfortable. Do not upload the WoW directory, private JSON or client binaries.
5. Do **not** delete, rename or change a support file because it is present, missing or unrecognised.

## Limits and next steps

This feature does not prove complete game file coverage. A root-file checklist may miss necessary system dependencies, client folders, patched executables, DLLs or assets. The listed candidates are **not yet approved for redistribution** and are not cryptographically authenticated against an authorised original installation.

Next review should compare the local presence findings with M14's root file candidates, agree a privacy-safe support-file coverage policy, and continue synthetic crash/recovery/disk/concurrent-change tests. M15's marker-locked tiny-file copy tool is **not** modified or connected to a real WoW client. Fresh full-client sources remain disabled in `config/base-client-source.json`.

**Verified Windows CI:** [run 38058231220](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38058231220) completed successfully on implementation checkpoint `477b138e46714fcf6579cb50b205b4081f82ce0e`. New synthetic non-MPQ audit tests, previous safety fixtures, GUI smoke tests and preview ZIP packaging all passed. No real-client installation or actual WoW binary execution was tested.


## Owner's completed local audit (10 October 2026)

The owner confirmed 6/13 candidate root files present and 7/13 absent, and all four directory-presence checks passed. Exact filenames and sizes, and the non-requirement of absent candidates, are documented in [Milestone 19](INSTALLER-MILESTONE-19.md). No production repair or file changes were requested. This read-only observation supports adding only `ijl15.dll` and `dbghelp.dll` to the existing private inventory allowlist; it does not authenticate those DLLs.
