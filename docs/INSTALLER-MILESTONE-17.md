# Milestone 17 — Owner inventory coverage and local MPQ classification

**Status:** small read-only inspection enhancement. Production installation, full client downloading and real-game file copying remain disabled.

## Owner-provided private M14 report (reviewed 10 October 2026)

The owner privately shared a `read_only_whitelisted_game_file_inventory` JSON generated in full `sha256_per_file` mode. The M16 reviewer displayed **REPORT STRUCTURE: CONSISTENT**.

Aggregated, non-sensitive results only (do **not** commit the original JSON):

| Property | Result |
| --- | --- |
| WoW target | enUS 3.3.5a build 12340, build metadata reported |
| Allowlisted files | 23 |
| Total bytes across **all 23** allowlisted files | 17,585,778,958 (not the MPQ-only total) |
| Base archive candidates | 16; all usual root/locale filenames in this narrow allowlist are present |
| Mandatory pinned Naxxramas MPQs | V and Z, both full hash/size matches |
| Installed optional pinned MPQs | U full hash/size match; J and C absent |
| Client root binary candidates | 4, with recorded hashes, but no independent base reference pin |
| Unclassified MPQ filenames hidden by inventory tool | 2 |
| Known MPQ files | 19 (16 base candidates + V/Z/U); plus 2 unclassified = 21 MPQs if the same Data scopes are compared |

The report does **not** authenticate those 16 base-file candidate hashes against an independently trusted original-client reference, inventory every required client file, prove runtime operation, or give redistribution rights. Its unknown MPQ files are not classified as good or bad. The earlier 21-MPQ aggregate is consistent with this count but is not proof of identical snapshots or file contents.

**Privacy:** only these aggregate results belong in the public repository. The original owner's private JSON, actual WoW bytes, account files, local path names, unpublished hashes, and screenshots are not committed.

## Local-only follow-up

`tools/Inspect-Unclassified-MPQs.ps1` (drag/drop `.bat` wrapper) lists the names and exact byte sizes of MPQs that are outside the M14 allowlist, scanning only direct MPQ files in `Data` and `Data/enUS`. This is a **read-only filename/metadata** check, not game-file hashing or a client change. It writes no report and uploads nothing.

1. Keep your original WoW backup untouched; use a **separate development copy**.
2. Extract the latest development preview outside WoW.
3. Drag the development copy's folder containing `Wow.exe` onto `tools/Inspect-Unclassified-MPQs.bat`.
4. Read the two reported relative filenames and byte sizes *locally*. Share them privately only after reviewing them; do not upload MPQs.
5. Never delete, rename or overwrite those files merely because they are outside the allowlist.

## Remaining coverage and technical gates

- Learn the purpose of the 2 unclassified MPQs; distinguish expected client resources, optional custom data, private backups or unknown content without guessing.
- Establish a trusted, independently verified, adequately authorised base-client identity source before certifying all base MPQs as complete or safe to redistribute.
- Audit necessary non-MPQ game assets and support files without collecting account, SavedVariables, screenshots, Cache, or other private files.
- Add safe recovery and concurrent-file-change tests to **synthetic, marker-locked** multi-file workflows. Large-file support and disk exhaustion must be tested before real-game copying.
- Fresh client downloading remains blocked in `config/base-client-source.json`. No real-client installation or public release is authorised.

**Testing:** dummy-only offline Windows fixtures check recognised vs unclassified MPQs, direct-scope enumeration, private-directory omission, and no additional files or modified archives.
