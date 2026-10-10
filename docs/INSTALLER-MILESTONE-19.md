# Milestone 19 — Add observed support DLLs to the private inventory

**Status:** implementation on draft development PR. Production install/download remains disabled.

## Owner's Milestone 18 local result (10 October 2026)

The owner ran \`Inspect-Client-Support-Files.bat\` on a development copy and shared a local console screenshot. This is **file presence and byte size metadata only**, not authenticated proof of a complete game installation.

| Candidate root file | Reported result |
| --- | --- |
| Wow.exe | Present, 7,699,456 bytes |
| Scan.dll | Present, 47,876 bytes |
| DivxDecoder.dll | Present, 413,696 bytes |
| unicows.dll | Present, 245,408 bytes |
| ijl15.dll | Present, 372,736 bytes |
| dbghelp.dll | Present, 1,039,728 bytes |
| Launcher.exe | Not present |
| Repair.exe | Not present |
| BackgroundDownloader.exe | Not present |
| Storm.dll | Not present |
| WowError.exe | Not present |
| fmod.dll | Not present |
| fmodex.dll | Not present |

All four checked directories (\`Data\`, \`Data/enUS\`, \`Interface\`, \`Interface/AddOns\`) were reported present. **Six of thirteen candidates were present; seven absent.** The missing candidates are **not automatically required or an indicator of a damaged client**. Never repair, install, copy or delete based on this checklist.

## Implemented change

Two filenames identified by the owner as present but not previously covered by the M14 root allowlist have been added:

- \`ijl15.dll\`
- \`dbghelp.dll\`

Both become **client_binary_candidate** entries under **\`not_pinned\`**, not signed/original/verified binaries. M14's full scan reads their bytes for SHA-256 only if the owner deliberately runs a new full inventory on a backed-up development copy; \`-Quick\` collects only sizes. M16's review tool accepts those same entries in JSON and checks their consistency without reading files from the WoW folder.

The scanner still only enumerates a fixed root allowlist and named Data/enUS MPQ archives. The absence of other candidates in M18 does not trigger any new action. No arbitrary root files, personal folders, addons, SavedVariables, realmlist, logs, screenshots or account records are added to the scan.

### Numerical expectation — not a new scan

The private 23-file M14 inventory excluded two now-recognised enUS MPQs (196,422,831 bytes combined). The M18 screenshot shows the additional two DLLs above (1,412,464 bytes combined). **If those files are unchanged and the same development copy is scanned, we expect**:

| Metric | Expected result |
| --- | --- |
| Files in the M14 allowlist | 27 |
| Base MPQ archive candidates | 18 |
| Installed Naxxramas MPQs | V, Z, U — 3 |
| Root client binary candidates | 6 |
| Remaining unclassified MPQs in inspected folders | 0 |
| Total allowlisted bytes | 17,783,614,253 |

These are calculated from previous private observations. They do **not** prove base-file authenticity, binary correctness, support requirements, client playability or distribution authorisation. The original private JSON remains unchanged and must not be published.

## Regression/safety requirements

Windows fixture tests check that the M14 scanner and M16 reviewer both accept \`ijl15.dll\` and \`dbghelp.dll\` as **unpinned** binary candidates. Full scans contain well-formed SHA-256 fields; quick scans may never pretend to have file hashes. Other unsupported candidates (for example \`fmodex.dll\`) are still not added to the allowlist automatically. All fixture data is synthetic.

**No changes** are made to the player's game installation, the M15 marker-locked copy tool, or disabled fresh-client download source.

## Owner's optional next step

Once Windows CI passes, a future full-hash scan on a **separate backed-up development copy** would verify the *local* file inventory coverage numerically. Use a **new JSON report path** and review privately with M16, preserving the previous report. No need to repeat the lengthy hash scan merely for this milestone. Never upload MPQs or client executables to GitHub.

## Beyond this milestone

Continue developing synthetic-only interruption/crash recovery, disk-space and concurrent-change protections before any legitimate local client-copy feature is considered. Keep full-client distribution blocked until source permissions and file authenticity are independently resolved.

**Windows CI:** awaiting run result.
