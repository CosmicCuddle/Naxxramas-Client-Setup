# Milestone 27 — Separate-process file mutation tests on disposable fixtures

**Status: Windows CI passed** ([run 38067600841](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38067600841), tested implementation checkpoint `9872b1cec15d4e0d6b176ccf93d205fb47049d01`). All operations are restricted to synthetic, explicitly marked, tiny M15 test folders. This is **not** a production game installer or proof of race-free Windows filesystem operation.

## Purpose

M24 simulated unexpected file changes from inside the copy process. M27 tests a more realistic overlap: **a separate Windows PowerShell process copies dummy files, while the independent test harness changes a file after the copy journal is written but before promotion starts.**

The existing M15 source and staged SHA-256 checks, destination occupancy check and guarded stage cleanup must refuse altered content and preserve unowned bytes.

## Implementation

Added a narrow development-only parameter to `tools/Test-Client-Copy-Fixture.ps1`: `-SyntheticExternalPauseBeforePromotionSeconds` (0–15; default 0). It is valid only for `-Action Copy`, after explicit `-ConfirmDisposableFixture` and all the existing source/destination marker, fixed allowlist, size and free-space checks. It sleeps after flushing the `applying` journal but **before** the first promotion; it does not create signaling files or change game content.

Added `tests/Test-External-Process-Mutations.ps1`. The synthetic Windows test creates separate isolated dummy fixtures for three independent scenarios. The copy executes inside a separate `powershell.exe` child process. The parent waits until the flushed journal can be parsed, and then changes the following file using a second process context:

| Independent change | Expected behavior |
| --- | --- |
| **Source:** append external test bytes to dummy `Wow.exe` under the synthetic source | The next source checksum blocks copying; externally changed source bytes are preserved; clean owned stage is safely removed |
| **Stage:** append external test bytes to the staged dummy `Wow.exe` | Staged-file checksum blocks copying; the altered stage is retained for M22 manual review, not silently deleted |
| **Destination:** create a new unowned dummy `Wow.exe` after staging | Destination existence check blocks promotion; foreign bytes remain unchanged; verified owned stage is cleaned |

The test checks that Copy exits nonzero, **no unexpected applying journal remains**, unrelated source bytes are unchanged, altered or unowned bytes are preserved, and any leftover stage is retained only in the appropriate scenario. It then cleans up its **own temporary synthetic test root**, which is a test harness operation, not a user-facing cleaner.

## Safety constraints and limitations

- Same M15 **eight fixed dummy filenames**, ≤256 KiB per file, ≤1 MiB total; separately marked source and destination, no overlapping roots, and explicit confirmation.
- Default operation remains unchanged; no pause unless the developer deliberately requests it on disposable fixtures. Plan and Rollback reject the new switch.
- The test never modifies real World of Warcraft game files, private directories or settings, never downloads the complete client and never uploads any owner's original MPQs, binaries or private inventory hashes.
- Windows CI must run the original copy/recovery/security, addon/patch and GUI tests as well as this new isolated worker test and preview ZIP packaging.
- **Not an exhaustive or adversarial race test.** Pausing at a known checkpoint does not eliminate time-of-check/time-of-use races between a digest verification, later rename/move or deletion. Symlink swaps, unexpected crash timing and OS-level identity/locking protections remain unresolved.
- The complete-client source remains disabled and Draft PR #1 stays unmerged without owner approval. No live client installation or full base-client redistribution has been approved.

## Following engineering task

M28 should study a file-handle-based or otherwise race-resistant transaction design, including defensive checks for external directory swaps/links, atomic journal updates, exclusive file identity, and explicit manual recovery. Continue isolated synthetic Windows tests; no real-client copying.

**Owner action:** None. Maintain the original known-good client backup.

**Windows CI passed:** [run 38067600841](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38067600841). All three actual second-process source/stage/destination mutation scenarios passed, followed by the older synthetic copy/rollback, read-only recovery/status/plan, patch/addon safety tests, Windows GUI smoke tests and preview ZIP packaging. This confirms only controlled disposable fixtures, not race-free production installation.
