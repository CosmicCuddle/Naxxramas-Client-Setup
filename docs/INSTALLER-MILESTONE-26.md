# Milestone 26 — Read-only recovery decision plan for disposable fixtures

**Status: Windows CI pending.** The planner handles **synthetic, intentionally marked, tiny M15 copy experiments only**. It cannot operate as a real WoW game installer, restore utility, or automatic cleanup program.

## Purpose

Milestone 25 distinguishes a healthy dummy destination, a verified copy journal, an interrupted rollback and unsafe transaction or staging state. Milestone 26 takes those **existing inspected results** and translates them into a clear and conservative *human decision plan*.

New developer-only tool: `tools/Plan-Fixture-Recovery.ps1`, with three required explicit inputs (`-SourcePath`, `-DestinationPath`, `-ManifestPath`) and one optional `-StagePath`.

- Starts the proven **read-only M25 transaction status inspector**, which itself invokes M20 and M22's hash- and path-checking inspectors.
- Validates the child result's exact known status vocabulary, single status fields, status/exit-code consistency and read-only marker before accepting its result.
- **Never prints raw child exceptions, absolute paths, unknown file names, account information, file contents or hash digests.** Only fixed status and review labels appear.
- **Never discovers adjacent stage folders**: if one is inspected, it must be provided explicitly.
- Does not save a report, run the existing Rollback action, download files, or create/delete/rename/modify client files.

## Transaction review categories

| Verified M25 transaction result | M26 review guidance |
| --- | --- |
| `EMPTY_MARKED_DESTINATION_NO_JOURNAL` | `NO_TRANSACTION_JOURNAL_RECORDED`: no recorded transaction to recover; this is not proof of source completeness |
| `VERIFIED_PARTIAL_APPLYING` | `REVIEW_INTERRUPTED_COPY_AGAINST_BACKUP`: independently compare journal, source, destination and known-good backup |
| `VERIFIED_COPIED` | `VERIFY_EXPECTED_COPIED_RESULT_MANUALLY`: complete verified dummy copy does not require automatic rollback |
| `VERIFIED_PARTIAL_ROLLBACK` | `REVIEW_INTERRUPTED_ROLLBACK_AGAINST_BACKUP`: administrator must inspect before separately confirming any further fixture-only action |
| Any `BLOCKED_...` | `STOP_AND_PRESERVE_UNCERTAIN_TRANSACTION`: do not attempt cleanup, overwrite or an improvised journal fix |

Optional stage state is reported independently: `NO_STAGE_SELECTED_OR_DISCOVERED`, `INSPECT_NOMINATED_STAGE_NO_CLEANUP_AUTHORISED`, or `PRESERVE_UNTRUSTED_STAGE_FOR_MANUAL_REVIEW`.

The overall decisions are **NO_TRANSACTION_ACTION_SUGGESTED**, **HUMAN_REVIEW_ONLY**, and **STOP_PRESERVE_AND_ESCALATE**. Every possible plan displays `PERMITTED AUTOMATIC ACTIONS: NONE`. A consistent stage is still **not** permission to delete it.

## Windows regression coverage

New `tests/Test-Fixture-Recovery-Plan.ps1` uses strictly disposable fake archive bytes and the existing M25 scenario framework. Cases cover empty marked destination, unowned destination entry, applying/copied/rolling_back journals, copied-but-incomplete state, journal sidecars, truncated journal, a modified expected file, a nominated intact stage, an unknown stage folder and a truncated stage-owner marker. The tests verify private fixture paths/content are never disclosed in the resulting status, and that read-only inspection does not change fixture file counts or source checksums.

The CI test suite must also pass all prior synthetic copy/rollback tests, M20/M22/M25 audits, addon/patch tests, Windows GUI smoke tests and preview ZIP packaging.

## Safety limits and handover

- This is a **human-readable proposal to inspect**, not an executable set of commands, a recovery token, an authenticated ownership proof, or a production-ready transaction manager.
- Self-declared dummy markers and hash-matched bytes can change immediately after inspection. Parallel path changes, power loss and OS-level file identity races remain unresolved and require separate isolated testing.
- Preserve the M15 eight-file dummy filename allowlist, 256 KiB/file, 1 MiB total cap, explicit markers, read-only checks and write/action separation.
- Never operate against real World of Warcraft folders or disclose private inventory JSON, proprietary MPQs or client executables in GitHub.
- The complete-client source remains **disabled** until rights, verified provenance and integrity validation are separately settled. Keep Draft PR #1 unmerged without owner approval.
- Owner has **nothing to run or download locally** for M26.

## Next planned milestone

Add deterministic **external-process file/path mutation** tests between inspect and operation, strictly against tiny disposable fixtures, and design explicit manual recovery review screens without implementing automatic destructive cleanup.

**Windows CI:** pending.
