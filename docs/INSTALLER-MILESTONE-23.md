# Milestone 23 — Synthetic disk-space and changing-file fault checks

**Development-only; Windows CI passed** ([run 38063285602](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38063285602), implementation checkpoint `1bccc4df469e6e6709864db818ccbbab34cf2834`). This milestone strengthens the tiny disposable M15 fixture experiment. It does **not** install, copy or distribute any real WoW client.

## Starting point

- M21: marker-locked, verified and resumable synthetic rollback.
- M22: stage ownership marker, guarded nonrecursive cleanup and read-only single-stage inspector; Windows CI passed ([run 38062628104](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38062628104)).
- The base-client download source remains explicitly disabled. Draft PR #1 is not merged.
- Fixed path allowlist of eight dummy names, maximum 256 KiB per fixture file, maximum 1 MiB combined. Two separate exact source/destination markers and explicit `-ConfirmDisposableFixture` remain mandatory.

## Implementation

Added three **deterministic synthetic-only injection switches** to `tools/Test-Client-Copy-Fixture.ps1`, all restricted to explicitly confirmed `-Action Copy`:

| Switch | What it simulates | Required result |
| --- | --- | --- |
| `-SimulateAvailableDiskBytes 0` | An artificial free-space reading of zero; no real disk filling | Refuse before creating a stage or destination journal |
| `-SimulateDiskWriteFailureAfterStagedFiles 2` | Controlled failure after copying two tiny files to staging | Stop; safely remove only verified owned stage content and leave the destination marker-only |
| `-SimulateStagedFileMutationBeforePromotion` | Changes **only a disposable staged copy**, never source game files | Final stage hash/size verification must block promotion and journal creation; M22 guarded cleanup retains the changed stage |

Additional checks re-verify each source file before staging, re-verify **all staged files and original source files** after staging, and check the staged and source copies again immediately before each file promotion. No unknown destination paths, overwriting, unapproved sources or complete-client writes are introduced.

The Windows test file `tests/Test-Client-Copy-Fixture.ps1` was expanded to verify Plan-mode flag refusal, explicit confirmation enforcement, no writes on simulated zero disk space, safe partial-stage cleanup on injected write failure, stage quarantine when its bytes change, M22 inspector's refusal of that altered stage, and invalid fault-count rejection.

## Recovery and safety limitations

- These injections do **not** create true OS low-disk-space conditions, simulate a real power outage, or prove crash-atomic writes. No large filler files are written.
- Mutation occurs only at a deterministic checkpoint on the disposable stage. It is **not** a test of a true parallel process altering files during I/O.
- A real concurrent change **between a checksum and a subsequent file operation** can still create a time-of-check/time-of-use race; the current checks narrow but do not eliminate that risk.
- Stage owner metadata is local and self-declared, not tamperproof. Unknown, modified or unmarked stages must not be automatically deleted.
- The synthetic copy catch block retains a journal when it cannot verify all owned promoted files; owner files and unexpected directories remain protected by the existing policy.
- These tiny-file tests cannot demonstrate free-space requirements or safe streaming for a 17+ GB client. That requires a separate authorised architecture, independent sources and explicit approval before production work.
- Keep original working client backups, never commit private M14 inventory JSON or proprietary MPQ/EXE content, and never merge the draft into `main` without owner approval.

## Owner action

None. Do **not** run the fixture copy tool on a real WoW folder, perform another 17+ GB hash scan, or alter the live client for this test.

## Next engineering stage

After Windows CI passes, expand **synthetic-only** fault coverage to: external process changes between verification and promotion, interrupted owner-marker writes and cleanup, journal-replacement power-loss residues, and controlled manual orphan inspection. Do not claim the fault switches prove a production installer safe.

**CI result:** Windows [run 38063285602](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38063285602) completed successfully. Expanded copy/rollback fault simulations, M20/M22 read-only recovery and stage checks, prior security tests, WinForms smoke tests, and preview ZIP upload all passed. This validates disposable fixture behavior only, not actual game-installation durability.
